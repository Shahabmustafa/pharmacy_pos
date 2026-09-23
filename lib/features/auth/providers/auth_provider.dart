import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/settings_repository.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  bool get isLoggedIn => user != null;
  bool get isAdmin => user?.role == 'admin';
  bool get isManager => user?.role == 'admin' || user?.role == 'manager';

  AuthState copyWith({User? user, bool? isLoading, String? error}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AppDatabase _db;

  AuthNotifier(this._db) : super(const AuthState());

  Future<bool> login(String username, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final user = await (_db.select(_db.users)
            ..where((u) =>
                u.username.equals(username.trim().toLowerCase()) &
                u.passwordHash.equals(password) &
                u.isActive.equals(true)))
          .getSingleOrNull();

      if (user == null) {
        state = state.copyWith(isLoading: false, error: 'Invalid username or password');
        return false;
      }

      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void logout() {
    state = const AuthState();
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (state.user == null) return false;

    final user = await (_db.select(_db.users)
          ..where((u) =>
              u.id.equals(state.user!.id) &
              u.passwordHash.equals(oldPassword)))
        .getSingleOrNull();

    if (user == null) return false;

    await (_db.update(_db.users)..where((u) => u.id.equals(state.user!.id)))
        .write(UsersCompanion(passwordHash: Value(newPassword)));
    return true;
  }

  Future<List<User>> getAllUsers() {
    return (_db.select(_db.users)
          ..orderBy([(u) => OrderingTerm.asc(u.name)]))
        .get();
  }

  Future<void> addUser({
    required String name,
    required String username,
    required String password,
    required String role,
    String? phone,
  }) async {
    await _db.into(_db.users).insert(UsersCompanion.insert(
      name: name,
      username: username.toLowerCase(),
      passwordHash: password,
      role: Value(role),
      phone: Value(phone),
    ));
  }

  Future<void> updateUser(int id, {String? name, String? role, bool? isActive}) async {
    await (_db.update(_db.users)..where((u) => u.id.equals(id))).write(
      UsersCompanion(
        name: name != null ? Value(name) : const Value.absent(),
        role: role != null ? Value(role) : const Value.absent(),
        isActive: isActive != null ? Value(isActive) : const Value.absent(),
      ),
    );
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier(ref.watch(databaseProvider));
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
