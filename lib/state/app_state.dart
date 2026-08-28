import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entry.dart';
import '../models/family.dart';
import '../models/pet.dart';
import '../models/pet_entry.dart';
import '../models/profile.dart';
import '../services/notification_service.dart';

/// A pet counts against its owner's 3-pet limit - kept in one place since
/// the app enforces it client-side too (a friendlier message before the
/// round-trip, not instead of the server-side trigger in
/// supabase/010_pets.sql).
const maxPetsPerOwner = 3;

/// SharedPreferences key for the device-local theme preference - exposed
/// (not private) so main.dart can read it before the first frame, without
/// waiting on AppState/bootstrap.
const themePrefStorageKey = 'suma.theme_pref';

/// SharedPreferences key for the device-local height display unit ('cm' or
/// 'in') - same reasoning as [themePrefStorageKey]: how measurements are
/// *shown* on this device, not account data. See [AppState.heightUnitPref].
const heightUnitPrefStorageKey = 'suma.height_unit_pref';

/// SharedPreferences keys for the device-local weigh-in reminder settings -
/// exposed so main.dart can read them before the first frame and re-arm the
/// schedule at startup (covers app updates/reinstalls, which clear Android's
/// AlarmManager state but not SharedPreferences). See
/// [AppState.updateNotificationSettings] and [NotificationService].
const notifEnabledStorageKey = 'suma.notif_enabled';
const notifDaysStorageKey = 'suma.notif_days'; // comma-separated DateTime.weekday ints (1=Mon..7=Sun)
const notifHourStorageKey = 'suma.notif_hour';
const notifMinuteStorageKey = 'suma.notif_minute';

enum AppPhase { loading, needsAuth, needsOnboarding, ready }

/// Single source of truth for the running app: which phase we're in, who is
/// signed in, and the data that phase needs. Screens read it with
/// `context.watch<AppState>()` / `context.read<AppState>()` and never talk
/// to Supabase directly.
///
/// Accounts live in Supabase Auth (email + password) so the same account
/// works from any device. [OnboardingScreen] handles both the one-time
/// "criar/entrar numa rede familiar" choice and the profile setup
/// (height/weight/unit/theme) - this class only exposes the primitives it
/// needs (see `completeOnboarding`, `createFamily`, `joinFamily`).
class AppState extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  AppPhase phase = AppPhase.loading;
  Profile? currentProfile;
  FamilyInfo? currentFamily;
  List<Profile> familyMembers = [];
  List<WeightEntry> entries = [];
  // Every pet *visible* to this account per RLS - own pets always, plus
  // every family member's pets too when this account is the family admin
  // (see supabase/010_pets.sql's pets_select_family_admin policy) - a
  // regular member's own-only visibility falls out of that same query
  // without needing a second one. [myPets] narrows it back down to just
  // this account's own, e.g. for Ajustes.
  List<Pet> pets = [];
  String? authError;

  List<Pet> get myPets => pets.where((p) => p.ownerId == currentProfile?.id).toList();

  /// 'system', 'light' or 'dark' - device-local (SharedPreferences), never
  /// synced through the account. Read directly by [main.dart] to pick
  /// MaterialApp's themeMode, independent of who's signed in.
  String themePref;

  /// A transient, in-flight preview of [themePref] while the Tema sheet is
  /// open - deliberately NOT wired through notifyListeners()/SharedPreferences
  /// like [updateThemePref] is. That version's full app-wide notify + disk
  /// write on every single tap, stacked on top of the sheet's own live
  /// backdrop-blur animation, was heavy enough to visibly stutter the
  /// picker's sun/moon animation. main.dart listens to this directly via a
  /// ValueListenableBuilder scoped to just the MaterialApp theme switch, so
  /// previewing a mode while flipping through options stays cheap - only
  /// the *final* choice (on "Confirmar") goes through the real,
  /// persisted/broadcast update.
  final ValueNotifier<String?> themePreviewOverride = ValueNotifier(null);

  /// 'cm' or 'in' - device-local, same reasoning as [themePref]. Weight's
  /// unit ([Profile.unitPref]) is genuine account data (you'd want your kg/lb
  /// choice to follow you to a new phone); this one is purely presentational.
  String heightUnitPref;

  /// Weigh-in reminder settings - device-local, same reasoning as
  /// [themePref]. [notifDays] holds DateTime.weekday values (1=Mon..7=Sun).
  /// See [updateNotificationSettings] and [NotificationService].
  bool notifEnabled;
  Set<int> notifDays;
  int notifHour;
  int notifMinute;

  StreamSubscription<AuthState>? _authSub;

  AppState({
    this.themePref = 'system',
    this.heightUnitPref = 'cm',
    this.notifEnabled = false,
    Set<int>? notifDays,
    this.notifHour = 8,
    this.notifMinute = 0,
  }) : notifDays = notifDays ?? {1, 2, 3, 4, 5, 6, 7};

  void bootstrap() {
    _authSub = _client.auth.onAuthStateChange.listen((data) {
      _handleAuthChange(data.session);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    themePreviewOverride.dispose();
    super.dispose();
  }

  Future<void> _handleAuthChange(Session? session) async {
    if (session == null) {
      currentProfile = null;
      currentFamily = null;
      familyMembers = [];
      entries = [];
      pets = [];
      phase = AppPhase.needsAuth;
      notifyListeners();
      return;
    }

    try {
      final row = await _client.from('profiles').select().eq('id', session.user.id).single();
      currentProfile = Profile.fromMap(row, email: session.user.email);
    } catch (_) {
      // Profile row missing (shouldn't happen - it's created by a DB
      // trigger right when the account is created) - bail out to a clean
      // signed-out state rather than getting stuck.
      authError = 'Não foi possível carregar seu perfil. Tente entrar novamente.';
      await _client.auth.signOut();
      return;
    }

    await _loadFamilyInfo();
    await _loadEntries();
    await _loadPets();
    if (currentProfile!.inFamily) {
      await _loadFamilyMembers();
    } else {
      familyMembers = [];
    }

    phase = currentProfile!.onboarded ? AppPhase.ready : AppPhase.needsOnboarding;
    notifyListeners();
  }

  Future<void> _loadFamilyInfo() async {
    final familyId = currentProfile?.familyId;
    if (familyId == null) {
      currentFamily = null;
      return;
    }
    final row = await _client.from('families').select().eq('id', familyId).maybeSingle();
    currentFamily = row == null ? null : FamilyInfo.fromMap(row);
  }

  Future<void> _loadFamilyMembers() async {
    final rows = await _client.from('profiles').select().eq('family_id', currentProfile!.familyId as Object).order('name');
    familyMembers = rows.map((r) => Profile.fromMap(r)).toList();
  }

  /// Re-fetches the family member list (there's no realtime subscription,
  /// so this is how screens pick up someone else having joined/left since
  /// this session started - call it on pull-to-refresh or tab entry). Any
  /// member of the family can see who else is in it (name/photo/role) -
  /// only the weight data itself stays admin-only, enforced by RLS on
  /// `weight_entries`, not by hiding the member list.
  Future<void> refreshFamilyMembers() async {
    if (!(currentProfile?.inFamily ?? false)) {
      familyMembers = [];
      notifyListeners();
      return;
    }
    await _loadFamilyMembers();
    notifyListeners();
  }

  // ---------------- Auth ----------------

  /// Returns null on success, or a user-facing error message.
  Future<String?> signUp({required String name, required String email, required String password}) async {
    authError = null;
    try {
      final response = await _client.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
      );
      if (response.session == null) {
        // Email confirmation is required on this project - there's no
        // session yet, so there's nothing more to do here; the person
        // needs to confirm via the email link, then use "Entrar".
        return 'CONFIRM_EMAIL';
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Não foi possível criar a conta. Tente novamente.';
    }
  }

  /// Returns null on success, or a user-facing error message.
  Future<String?> signIn({required String email, required String password}) async {
    authError = null;
    try {
      await _client.auth.signInWithPassword(email: email.trim(), password: password);
      return null;
    } on AuthException catch (e) {
      authError = e.message;
      notifyListeners();
      return e.message;
    } catch (e) {
      const msg = 'Não foi possível entrar. Verifique sua conexão e tente novamente.';
      authError = msg;
      notifyListeners();
      return msg;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Sends a password-reset e-mail. Returns null on success (Supabase
  /// doesn't reveal whether the address is actually registered, so this is
  /// "sent" either way) or a user-facing error message on an actual failure.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email.trim());
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Não foi possível enviar o e-mail. Tente novamente.';
    }
  }

  /// Returns null on success, or a user-facing error message.
  Future<String?> changePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(UserAttributes(password: newPassword));
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return 'Não foi possível atualizar a senha. Tente novamente.';
    }
  }

  // ---------------- Onboarding & family ----------------

  /// Creates a new family, with the caller as its admin. Returns the invite
  /// code to show them, or throws with a user-facing message on failure.
  Future<String> createFamily(String name) async {
    final code = await _client.rpc('create_family', params: {'family_name': name.trim()}) as String;
    await _refreshProfile();
    return code;
  }

  /// Joins an existing family by its invite code. Throws with a
  /// user-facing message (from the RPC) if the code is invalid.
  Future<void> joinFamily(String code) async {
    await _client.rpc('join_family_by_code', params: {'code': code.trim()});
    await _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    final uid = _client.auth.currentUser!.id;
    final row = await _client.from('profiles').select().eq('id', uid).single();
    currentProfile = Profile.fromMap(row, email: currentProfile?.email);
    await _loadFamilyInfo();
    if (currentProfile!.inFamily) {
      await _loadFamilyMembers();
    }
    notifyListeners();
  }

  /// Completes the onboarding wizard: stores height/unit preferences and
  /// logs the very first weight entry in one go. If a goal is set, the
  /// just-entered weight becomes its starting point for progress tracking.
  /// [themePref] is applied locally (see [updateThemePref]) - it was never
  /// an account-level setting, onboarding just happens to be where someone
  /// first picks it.
  Future<void> completeOnboarding({
    required double heightCm,
    required double initialWeightKg,
    double? goalWeightKg,
    String goalType = 'lose',
    required String unitPref,
    required String themePref,
  }) async {
    await _client.from('profiles').update({
      'height_cm': heightCm,
      'goal_weight_kg': goalWeightKg,
      'goal_type': goalType,
      'goal_start_weight_kg': goalWeightKg == null ? null : initialWeightKg,
      'unit_pref': unitPref,
      'onboarded': true,
    }).eq('id', currentProfile!.id);

    currentProfile = currentProfile!.copyWith(
      heightCm: heightCm,
      goalWeightKg: goalWeightKg,
      clearGoal: goalWeightKg == null,
      goalType: goalType,
      goalStartWeightKg: goalWeightKg == null ? null : initialWeightKg,
      unitPref: unitPref,
      onboarded: true,
    );
    await updateThemePref(themePref);
    await addEntry(date: DateTime.now(), weightKg: initialWeightKg);
    phase = AppPhase.ready;
    notifyListeners();
  }

  /// Applies the theme change immediately and remembers it in
  /// SharedPreferences - deliberately device-local, never sent to Supabase.
  /// Unit/height/goal are genuine account settings (you'd want your goal to
  /// follow you to a new phone); appearance is closer to a system setting,
  /// and syncing it meant signing into the same account on a different
  /// phone silently changed that phone's look, which read as a bug more
  /// than a feature.
  Future<void> updateThemePref(String pref) async {
    themePref = pref;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(themePrefStorageKey, pref);
  }

  /// Persists the reminder settings and re-arms [NotificationService]'s
  /// schedule to match - same device-local, optimistic-update reasoning as
  /// [updateThemePref]. Always writes all four fields together so the saved
  /// state can never end up with e.g. days chosen but no saved time.
  Future<void> updateNotificationSettings({
    required bool enabled,
    required Set<int> days,
    required int hour,
    required int minute,
  }) async {
    notifEnabled = enabled;
    notifDays = days;
    notifHour = hour;
    notifMinute = minute;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(notifEnabledStorageKey, enabled);
    await prefs.setString(notifDaysStorageKey, days.join(','));
    await prefs.setInt(notifHourStorageKey, hour);
    await prefs.setInt(notifMinuteStorageKey, minute);

    if (enabled && days.isNotEmpty) {
      await NotificationService.instance.scheduleWeekly(weekdays: days, hour: hour, minute: minute);
    } else {
      await NotificationService.instance.cancelAll();
    }
  }

  /// Same reasoning/pattern as [updateThemePref].
  Future<void> updateHeightUnitPref(String pref) async {
    heightUnitPref = pref;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(heightUnitPrefStorageKey, pref);
  }

  /// Same optimistic-update reasoning as [updateThemePref].
  Future<void> updateUnitPref(String unitPref) async {
    final previous = currentProfile;
    currentProfile = currentProfile!.copyWith(unitPref: unitPref);
    notifyListeners();
    try {
      await _client.from('profiles').update({'unit_pref': unitPref}).eq('id', currentProfile!.id);
    } catch (_) {
      currentProfile = previous;
      notifyListeners();
    }
  }

  /// Splits into "nome" and "sobrenome" for editing, but stored as the
  /// single `name` column ("Nome Sobrenome") - see [Profile.lastName].
  Future<void> updateName({required String firstName, required String lastName}) async {
    final name = [firstName.trim(), lastName.trim()].where((s) => s.isNotEmpty).join(' ');
    await _client.from('profiles').update({'name': name}).eq('id', currentProfile!.id);
    currentProfile = currentProfile!.copyWith(name: name);
    notifyListeners();
  }

  /// Uploads a picked image as the user's profile photo (bucket "avatars",
  /// one file per person at `uid/avatar.ext` - `upsert: true` so a new pick
  /// just overwrites the old one instead of accumulating files).
  /// Returns null on success, or a user-facing error message.
  Future<String?> updateAvatar({required List<int> bytes, required String extension}) async {
    final uid = currentProfile!.id;
    final path = '$uid/avatar.$extension';
    try {
      await _client.storage.from('avatars').uploadBinary(
            path,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(upsert: true, contentType: 'image/$extension'),
          );
      // The path never changes on a re-upload, so a plain getPublicUrl()
      // would keep resolving to whatever's cached client-side - a
      // cache-busting query param forces the new image to actually load.
      final url = '${_client.storage.from('avatars').getPublicUrl(path)}?v=${DateTime.now().millisecondsSinceEpoch}';
      await _client.from('profiles').update({'avatar_url': url}).eq('id', uid);
      currentProfile = currentProfile!.copyWith(avatarUrl: url);
      notifyListeners();
      return null;
    } on StorageException catch (e) {
      // Surfaces the real reason (bucket missing, RLS policy missing/
      // denying, etc.) instead of a generic message - this call fails
      // outright if supabase/005_avatars.sql was never run (no "avatars"
      // bucket, no upload policy), and a vague error made that
      // impossible to tell apart from an actual network/transient issue.
      if (e.statusCode == '404' || e.message.toLowerCase().contains('bucket not found')) {
        return 'O bucket "avatars" não existe no Supabase - rode a migration supabase/005_avatars.sql.';
      }
      if (e.statusCode == '403' || e.message.toLowerCase().contains('row-level security') || e.message.toLowerCase().contains('policy')) {
        return 'Sem permissão pra enviar a foto - confira se supabase/005_avatars.sql foi rodada (policies do bucket "avatars").';
      }
      return 'Não foi possível enviar a foto: ${e.message}';
    } catch (e) {
      return 'Não foi possível enviar a foto. Tente novamente. ($e)';
    }
  }

  /// Height, age and sex are edited together in the one "Altura" sheet, so
  /// they're saved together too.
  Future<void> updateBodyProfile({required double heightCm, required int age, required String sex}) async {
    await _client.from('profiles').update({'height_cm': heightCm, 'age': age, 'sex': sex}).eq('id', currentProfile!.id);
    currentProfile = currentProfile!.copyWith(heightCm: heightCm, age: age, sex: sex);
    notifyListeners();
  }

  /// Sets/changes/clears the weight goal. Only *creating* a goal (there
  /// wasn't one before) re-anchors [Profile.goalStartWeightKg] to the latest
  /// logged weight, so progress tracking starts fresh from "now" instead of
  /// from whatever the oldest entry in the person's whole history happens to
  /// be. Editing an existing goal (tweaking the target, switching
  /// emagrecer/ganhar peso) keeps the original anchor - otherwise every
  /// visit to "Meta de peso" would silently reset progress back to 0%.
  Future<void> updateGoal({double? goalWeightKg, String goalType = 'lose', bool clearGoal = false}) async {
    final hadGoal = currentProfile!.goalWeightKg != null;
    final snapshot = clearGoal
        ? null
        : (hadGoal ? (currentProfile!.goalStartWeightKg ?? _latestWeightOrNull()) : _latestWeightOrNull());
    await _client.from('profiles').update({
      'goal_weight_kg': clearGoal ? null : goalWeightKg,
      'goal_type': goalType,
      'goal_start_weight_kg': snapshot,
    }).eq('id', currentProfile!.id);
    currentProfile = currentProfile!.copyWith(
      goalWeightKg: goalWeightKg,
      clearGoal: clearGoal,
      goalType: goalType,
      goalStartWeightKg: snapshot,
    );
    notifyListeners();
  }

  double? _latestWeightOrNull() => entries.isNotEmpty ? entries.first.weightKg : null;

  /// Removes a member from the current family (admin only) - their account
  /// and data are untouched, they just stop being part of the network.
  Future<String?> removeFamilyMember(String memberId) async {
    try {
      await _client.rpc('remove_member_from_family', params: {'member_id': memberId});
      await _loadFamilyMembers();
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }

  /// Leaves the current family - own account/data untouched.
  Future<String?> leaveFamily() async {
    try {
      await _client.rpc('leave_family');
      await _refreshProfile();
      familyMembers = [];
      notifyListeners();
      return null;
    } on PostgrestException catch (e) {
      return e.message;
    }
  }

  // ---------------- Pets ----------------

  Future<void> _loadPets() async {
    // No .eq('owner_id', ...) filter - RLS already returns exactly what
    // this account can see (own pets always, every family member's too
    // when this account is the admin). Ordered oldest-first so a newly
    // added pet lands at the end of its owner's list, not shuffled in.
    final rows = await _client.from('pets').select().order('created_at');
    pets = rows.map((r) => Pet.fromMap(r)).toList();
  }

  /// Re-fetches the pet list - same "no realtime subscription" reasoning as
  /// [refreshFamilyMembers].
  Future<void> refreshPets() async {
    await _loadPets();
    notifyListeners();
  }

  /// Adds a pet to the current user's own subprofiles. Throws with a
  /// user-facing message if they're already at [maxPetsPerOwner] (checked
  /// client-side for a friendly message; supabase/010_pets.sql's trigger
  /// enforces the same limit server-side regardless).
  Future<void> addPet({required String name, DateTime? birthDate, required String species, String? breed}) async {
    if (myPets.length >= maxPetsPerOwner) {
      throw Exception('Você já tem o máximo de $maxPetsPerOwner pets cadastrados.');
    }
    final pet = Pet(ownerId: currentProfile!.id, name: name, birthDate: birthDate, species: species, breed: breed, createdAt: DateTime.now());
    await _client.from('pets').insert(pet.toInsertMap());
    await _loadPets();
    notifyListeners();
  }

  Future<void> updatePet(Pet pet) async {
    final b = pet.birthDate;
    await _client.from('pets').update({
      'name': pet.name,
      'birth_date': b == null ? null : '${b.year.toString().padLeft(4, '0')}-${b.month.toString().padLeft(2, '0')}-${b.day.toString().padLeft(2, '0')}',
      'species': pet.species,
      'breed': pet.breed,
    }).eq('id', pet.id as Object);
    await _loadPets();
    notifyListeners();
  }

  /// Deletes a pet and its entire weight history (cascades in the DB - see
  /// pet_weight_entries' foreign key).
  Future<void> deletePet(String petId) async {
    await _client.from('pets').delete().eq('id', petId);
    await _loadPets();
    notifyListeners();
  }

  /// A pet's own weight history - fetched on demand (not preloaded with
  /// every pet up front), same reasoning as [entriesFor] for another family
  /// member's human entries.
  Future<List<PetWeightEntry>> petEntriesFor(String petId) async {
    final rows = await _client.from('pet_weight_entries').select().eq('pet_id', petId).order('date', ascending: false);
    return rows.map((r) => PetWeightEntry.fromMap(r)).toList();
  }

  Future<void> addPetEntry({required String petId, required DateTime date, required double weightKg, String? notes}) async {
    final entry = PetWeightEntry(petId: petId, date: date, weightKg: weightKg, notes: notes, createdAt: DateTime.now());
    await _client.from('pet_weight_entries').upsert(entry.toInsertMap(), onConflict: 'pet_id,date');
  }

  Future<void> updatePetEntry(PetWeightEntry entry) async {
    await _client.from('pet_weight_entries').update(entry.toInsertMap()).eq('id', entry.id as Object);
  }

  Future<void> deletePetEntry(String id) async {
    await _client.from('pet_weight_entries').delete().eq('id', id);
  }

  // ---------------- Entries (current user) ----------------

  Future<void> _loadEntries() async {
    final rows = await _client
        .from('weight_entries')
        .select()
        .eq('user_id', currentProfile!.id)
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    entries = rows.map((r) => WeightEntry.fromMap(r)).toList();
  }

  Future<void> addEntry({
    required DateTime date,
    required double weightKg,
    double? bodyFatPct,
    double? hydrationPct,
    String? notes,
  }) async {
    final entry = WeightEntry(
      userId: currentProfile!.id,
      date: date,
      weightKg: weightKg,
      bodyFatPct: bodyFatPct,
      hydrationPct: hydrationPct,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _client.from('weight_entries').upsert(entry.toInsertMap(), onConflict: 'user_id,date');
    await _loadEntries();
    notifyListeners();
  }

  Future<void> updateEntry(WeightEntry entry) async {
    await _client.from('weight_entries').update(entry.toInsertMap()).eq('id', entry.id as Object);
    await _loadEntries();
    notifyListeners();
  }

  Future<void> deleteEntry(String id) async {
    await _client.from('weight_entries').delete().eq('id', id);
    await _loadEntries();
    notifyListeners();
  }

  /// Bulk-imports entries into the current user's own history (a single
  /// upsert instead of one round-trip per row). Same date as an existing
  /// entry overwrites it, matching [addEntry]'s behavior.
  Future<void> importEntries(List<WeightEntry> entries) async {
    if (entries.isEmpty) return;
    final rows = entries.map((e) => e.copyWith(userId: currentProfile!.id).toInsertMap()).toList();
    await _client.from('weight_entries').upsert(rows, onConflict: 'user_id,date');
    await _loadEntries();
    notifyListeners();
  }

  /// Entries for another member of the same family - only succeeds for a
  /// family admin looking at one of their own members (enforced by RLS).
  Future<List<WeightEntry>> entriesFor(String userId) async {
    final rows = await _client.from('weight_entries').select().eq('user_id', userId).order('date', ascending: false);
    return rows.map((r) => WeightEntry.fromMap(r)).toList();
  }

  /// How many family members logged an entry on each of the last [days] days
  /// - the data behind the contribution heatmap on Usuários. Goes through
  /// the `family_contribution_counts` RPC (SECURITY DEFINER) instead of a
  /// direct `weight_entries` select, so every member can see this - the
  /// function only ever returns day/count pairs, never whose entry it was
  /// or what they weighed.
  Future<Map<DateTime, int>> familyContributionCounts({int days = 126}) async {
    if (familyMembers.isEmpty) return {};
    final rows = await _client.rpc('family_contribution_counts', params: {'days': days});
    final counts = <DateTime, int>{};
    for (final r in rows as List) {
      final d = DateTime.parse(r['entry_date'] as String);
      final key = DateTime(d.year, d.month, d.day);
      counts[key] = (r['cnt'] as num).toInt();
    }
    return counts;
  }

  /// Ranks every family member who has a goal set by how close they are to
  /// it, as a 0..1 fraction - via the `family_goal_progress` RPC, which
  /// computes the percentage server-side and never returns anyone's actual
  /// weight. Available to any member, not just the admin.
  Future<List<({String id, String name, double progress})>> familyGoalProgress() async {
    if (familyMembers.isEmpty) return [];
    final rows = await _client.rpc('family_goal_progress');
    return [
      for (final r in rows as List)
        (id: r['member_id'] as String, name: r['member_name'] as String, progress: (r['progress'] as num).toDouble()),
    ];
  }

  /// Registro counts (last [days] days and all-time) for every member of
  /// the family, via the `family_entry_counts` RPC - counts only, never the
  /// underlying dates/weights. Available to any member, not just the admin.
  Future<Map<String, ({int total, int recent})>> familyEntryCounts({int days = 60}) async {
    if (familyMembers.isEmpty) return {};
    final rows = await _client.rpc('family_entry_counts', params: {'days': days});
    return {
      for (final r in rows as List)
        r['member_id'] as String: (total: (r['total_count'] as num).toInt(), recent: (r['recent_count'] as num).toInt()),
    };
  }
}
