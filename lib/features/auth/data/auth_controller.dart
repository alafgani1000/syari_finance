import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';

enum AuthPhase { loading, setupRequired, signedOut, authenticated }

class AuthState {
  const AuthState({required this.phase, this.user, this.error});

  const AuthState.loading() : this(phase: AuthPhase.loading);

  final AuthPhase phase;
  final AppUser? user;
  final String? error;

  bool get isAdmin => user?.isAdmin ?? false;
}

final authRepositoryProvider =
    Provider<AuthRepository>((ref) => AuthRepository());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.read(authRepositoryProvider))..initialize();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository) : super(const AuthState.loading());

  final AuthRepository _repository;

  Future<void> initialize() async {
    state = const AuthState.loading();
    try {
      state = AuthState(
        phase: await _repository.hasUsers()
            ? AuthPhase.signedOut
            : AuthPhase.setupRequired,
      );
    } catch (_) {
      state = const AuthState(
        phase: AuthPhase.signedOut,
        error: 'Data pengguna belum dapat dibaca.',
      );
    }
  }

  Future<String?> createFirstAdmin({
    required String name,
    required String pin,
  }) async {
    try {
      final user = await _repository.createUser(
        name: name,
        pin: pin,
        role: UserRole.admin,
      );
      state = AuthState(phase: AuthPhase.authenticated, user: user);
      return null;
    } catch (error) {
      return error.toString().replaceFirst('Invalid argument(s): ', '');
    }
  }

  Future<String?> signIn({required String userId, required String pin}) async {
    try {
      final user = await _repository.authenticate(userId: userId, pin: pin);
      if (user == null) return 'PIN tidak sesuai.';
      state = AuthState(phase: AuthPhase.authenticated, user: user);
      return null;
    } catch (_) {
      return 'Login belum dapat diproses. Coba lagi.';
    }
  }

  void signOut() => state = const AuthState(phase: AuthPhase.signedOut);
}
