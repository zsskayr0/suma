import 'package:flutter/foundation.dart';

import '../db/database_service.dart';
import '../models/entry.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AppPhase { loading, needsSetup, needsLogin, needsOnboarding, ready }

/// Single source of truth for the running app: which phase we're in, who is
/// logged in, and the data that phase needs. Screens read it with
/// `context.watch<AppState>()` / `context.read<AppState>()` and never talk
/// to [DatabaseService] directly.
class AppState extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  AppPhase phase = AppPhase.loading;
  AppUser? currentUser;
  List<AppUser> users = [];
  List<WeightEntry> entries = [];
  String? authError;

  Future<void> bootstrap() async {
    final hasUser = await _db.hasAnyUser();
    phase = hasUser ? AppPhase.needsLogin : AppPhase.needsSetup;
    notifyListeners();
  }

  /// First-run only: creates the predefined admin account.
  Future<void> createInitialAdmin({
    required String name,
    required String username,
    required String password,
  }) async {
    final salt = AuthService.generateSalt();
    final admin = AppUser(
      name: name,
      username: username,
      passwordHash: AuthService.hashPassword(password, salt),
      passwordSalt: salt,
      role: 'admin',
      createdAt: DateTime.now(),
    );
    final created = await _db.createUser(admin);
    currentUser = created;
    phase = AppPhase.needsOnboarding;
    await _loadEntries();
    notifyListeners();
  }

  Future<bool> login(String username, String password) async {
    final user = await _db.getUserByUsername(username.trim());
    if (user == null || !AuthService.verifyPassword(password, user.passwordSalt, user.passwordHash)) {
      authError = 'Usuário ou senha inválidos.';
      notifyListeners();
      return false;
    }
    authError = null;
    currentUser = user;
    phase = user.onboarded ? AppPhase.ready : AppPhase.needsOnboarding;
    if (user.isAdmin) {
      await _loadUsers();
    }
    await _loadEntries();
    notifyListeners();
    return true;
  }

  // ---------------- Onboarding & preferences (current user) ----------------

  /// Completes the one-time onboarding wizard: stores height/unit/theme
  /// preferences and logs the very first weight entry in one go.
  Future<void> completeOnboarding({
    required double heightCm,
    required double initialWeightKg,
    double? goalWeightKg,
    required String unitPref,
    required String themePref,
  }) async {
    final updated = currentUser!.copyWith(
      heightCm: heightCm,
      goalWeightKg: goalWeightKg,
      clearGoal: goalWeightKg == null,
      unitPref: unitPref,
      themePref: themePref,
      onboarded: true,
    );
    await _db.updateUser(updated);
    currentUser = updated;
    await addEntry(date: DateTime.now(), weightKg: initialWeightKg);
    phase = AppPhase.ready;
    notifyListeners();
  }

  Future<void> updateThemePref(String themePref) async {
    final updated = currentUser!.copyWith(themePref: themePref);
    await _db.updateUser(updated);
    currentUser = updated;
    notifyListeners();
  }

  Future<void> updateUnitPref(String unitPref) async {
    final updated = currentUser!.copyWith(unitPref: unitPref);
    await _db.updateUser(updated);
    currentUser = updated;
    notifyListeners();
  }

  Future<void> updateBodyProfile({double? heightCm, double? goalWeightKg, bool clearGoal = false}) async {
    final updated = currentUser!.copyWith(
      heightCm: heightCm,
      goalWeightKg: goalWeightKg,
      clearGoal: clearGoal,
    );
    await _db.updateUser(updated);
    currentUser = updated;
    notifyListeners();
  }

  void logout() {
    currentUser = null;
    entries = [];
    users = [];
    phase = AppPhase.needsLogin;
    notifyListeners();
  }

  // ---------------- Entries (current user) ----------------

  Future<void> _loadEntries() async {
    if (currentUser == null) return;
    entries = await _db.getEntriesForUser(currentUser!.id!);
  }

  Future<void> addEntry({
    required DateTime date,
    required double weightKg,
    double? bodyFatPct,
    double? hydrationPct,
    String? notes,
  }) async {
    final entry = WeightEntry(
      userId: currentUser!.id!,
      date: date,
      weightKg: weightKg,
      bodyFatPct: bodyFatPct,
      hydrationPct: hydrationPct,
      notes: notes,
      createdAt: DateTime.now(),
    );
    await _db.createEntry(entry);
    await _loadEntries();
    notifyListeners();
  }

  Future<void> updateEntry(WeightEntry entry) async {
    await _db.updateEntry(entry);
    await _loadEntries();
    notifyListeners();
  }

  Future<void> deleteEntry(int id) async {
    await _db.deleteEntry(id);
    await _loadEntries();
    notifyListeners();
  }

  Future<List<WeightEntry>> entriesFor(int userId) => _db.getEntriesForUser(userId);

  // ---------------- User management (admin only) ----------------

  Future<void> _loadUsers() async {
    users = await _db.getUsers();
  }

  Future<void> refreshUsers() async {
    await _loadUsers();
    notifyListeners();
  }

  Future<String?> createManagedUser({
    required String name,
    required String username,
    required String password,
    required String role,
  }) async {
    final existing = await _db.getUserByUsername(username.trim());
    if (existing != null) return 'Já existe um usuário com esse nome de login.';

    final salt = AuthService.generateSalt();
    final user = AppUser(
      name: name.trim(),
      username: username.trim(),
      passwordHash: AuthService.hashPassword(password, salt),
      passwordSalt: salt,
      role: role,
      createdAt: DateTime.now(),
    );
    await _db.createUser(user);
    await _loadUsers();
    notifyListeners();
    return null;
  }

  Future<String?> resetPassword(AppUser user, String newPassword) async {
    final salt = AuthService.generateSalt();
    final updated = user.copyWith(
      passwordSalt: salt,
      passwordHash: AuthService.hashPassword(newPassword, salt),
    );
    await _db.updateUser(updated);
    await _loadUsers();
    notifyListeners();
    return null;
  }

  Future<String?> deleteManagedUser(AppUser user) async {
    if (user.isAdmin) {
      final adminCount = await _db.countAdmins();
      if (adminCount <= 1) {
        return 'Não é possível remover o último administrador.';
      }
    }
    await _db.deleteUser(user.id!);
    await _loadUsers();
    notifyListeners();
    return null;
  }
}
