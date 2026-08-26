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
    notifyListeners();
  }

  /// Completes the onboarding wizard: stores height/unit/theme preferences
  /// and logs the very first weight entry in one go.
  Future<void> completeOnboarding({
    required double heightCm,
    required double initialWeightKg,
    double? goalWeightKg,
    required String unitPref,
    required String themePref,
  }) async {
    await _client.from('profiles').update({
      'height_cm': heightCm,
      'goal_weight_kg': goalWeightKg,
      'unit_pref': unitPref,
      'theme_pref': themePref,
      'onboarded': true,
    }).eq('id', currentProfile!.id);

    currentProfile = currentProfile!.copyWith(
      heightCm: heightCm,
      goalWeightKg: goalWeightKg,
      clearGoal: goalWeightKg == null,
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

  Future<void> updateBodyProfile({double? heightCm, double? goalWeightKg, bool clearGoal = false}) async {
    await _client.from('profiles').update({
      if (heightCm != null) 'height_cm': heightCm,
      'goal_weight_kg': clearGoal ? null : goalWeightKg,
    }).eq('id', currentProfile!.id);
    currentProfile = currentProfile!.copyWith(heightCm: heightCm, goalWeightKg: goalWeightKg, clearGoal: clearGoal);
    notifyListeners();
  }

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

  /// Entries for another member of the same family - only succeeds for a
  /// family admin looking at one of their own members (enforced by RLS).
  Future<List<WeightEntry>> entriesFor(String userId) async {
    final rows = await _client.from('weight_entries').select().eq('user_id', userId).order('date', ascending: false);
    return rows.map((r) => WeightEntry.fromMap(r)).toList();
  }
}
