import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/entry.dart';
import '../models/family.dart';
import '../models/profile.dart';

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
  String? authError;

  StreamSubscription<AuthState>? _authSub;

  void bootstrap() {
    _authSub = _client.auth.onAuthStateChange.listen((data) {
      _handleAuthChange(data.session);
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  Future<void> _handleAuthChange(Session? session) async {
    if (session == null) {
      currentProfile = null;
      currentFamily = null;
      familyMembers = [];
      entries = [];
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
    if (currentProfile!.isAdmin && currentProfile!.inFamily) {
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
  /// this session started - call it on pull-to-refresh or tab entry).
  Future<void> refreshFamilyMembers() async {
    if (!(currentProfile?.isAdmin ?? false) || !(currentProfile?.inFamily ?? false)) {
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
    if (currentProfile!.isAdmin && currentProfile!.inFamily) {
      await _loadFamilyMembers();
    }
    notifyListeners();
  }

  /// Completes the onboarding wizard: stores height/unit/theme preferences
  /// and logs the very first weight entry in one go. If a goal is set, the
  /// just-entered weight becomes its starting point for progress tracking.
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
      'theme_pref': themePref,
      'onboarded': true,
    }).eq('id', currentProfile!.id);

    currentProfile = currentProfile!.copyWith(
      heightCm: heightCm,
      goalWeightKg: goalWeightKg,
      clearGoal: goalWeightKg == null,
      goalType: goalType,
      goalStartWeightKg: goalWeightKg == null ? null : initialWeightKg,
      unitPref: unitPref,
      themePref: themePref,
      onboarded: true,
    );
    await addEntry(date: DateTime.now(), weightKg: initialWeightKg);
    phase = AppPhase.ready;
    notifyListeners();
  }

  /// Applies the theme change immediately (optimistic update) and syncs it
  /// to Supabase in the background - awaiting the network round-trip first
  /// (as every other AppState mutation does) makes a supposedly-instant
  /// toggle feel laggy, since this now goes over the network instead of a
  /// local database. Reverts quietly if the sync ends up failing.
  Future<void> updateThemePref(String themePref) async {
    final previous = currentProfile;
    currentProfile = currentProfile!.copyWith(themePref: themePref);
    notifyListeners();
    try {
      await _client.from('profiles').update({'theme_pref': themePref}).eq('id', currentProfile!.id);
    } catch (_) {
      currentProfile = previous;
      notifyListeners();
    }
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
    } catch (e) {
      return 'Não foi possível enviar a foto. Tente novamente.';
    }
  }

  Future<void> updateHeight(double heightCm) async {
    await _client.from('profiles').update({'height_cm': heightCm}).eq('id', currentProfile!.id);
    currentProfile = currentProfile!.copyWith(heightCm: heightCm);
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
  /// - the data behind the admin-only contribution heatmap on Hoje. One
  /// query across every member (RLS already lets an admin read their whole
  /// family's weight_entries) instead of one round-trip per person.
  Future<Map<DateTime, int>> familyContributionCounts({int days = 126}) async {
    if (familyMembers.isEmpty) return {};
    final memberIds = familyMembers.map((m) => m.id).toList();
    final since = DateTime.now().subtract(Duration(days: days));
    final sinceDate = '${since.year.toString().padLeft(4, '0')}-${since.month.toString().padLeft(2, '0')}-${since.day.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('weight_entries')
        .select('date, user_id')
        .inFilter('user_id', memberIds)
        .gte('date', sinceDate);
    final counts = <DateTime, int>{};
    for (final r in rows) {
      final d = DateTime.parse(r['date'] as String);
      final key = DateTime(d.year, d.month, d.day);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }
}
