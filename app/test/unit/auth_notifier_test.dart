import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:salonemarket/core/constants/app_constants.dart';
import 'package:salonemarket/features/auth/data/auth_repository.dart';
import 'package:salonemarket/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FakeAuthRepository implements AuthRepository {
  bool shouldSucceed = true;
  String failureMessage = 'Simulated error';
  UserProfile? mockProfile;
  final StreamController<AuthState> _authStreamController =
      StreamController<AuthState>.broadcast();

  @override
  User? currentUser;

  @override
  Session? currentSession;

  @override
  bool get isAuthenticated => currentUser != null;

  @override
  Stream<AuthState> watchAuthState() => _authStreamController.stream;

  @override
  Future<AuthResult<AuthResponse>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldSucceed) {
      currentUser = const User(
        id: 'user-123',
        appMetadata: {},
        userMetadata: {'full_name': 'Amadu Bah'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
      mockProfile = const UserProfile(
        id: 'user-123',
        fullName: 'Amadu Bah',
        role: Roles.customer,
      );
      return AuthSuccess(AuthResponse(user: currentUser));
    }
    return AuthFailure(failureMessage);
  }

  @override
  Future<AuthResult<AuthResponse>> signUpWithEmail({
    required String email,
    required String password,
    String? fullName,
    String? phone,
  }) async {
    if (shouldSucceed) {
      currentUser = const User(
        id: 'user-new',
        appMetadata: {},
        userMetadata: {'full_name': 'Fatima Sesay'},
        aud: 'authenticated',
        createdAt: '2026-01-01',
      );
      mockProfile = const UserProfile(
        id: 'user-new',
        fullName: 'Fatima Sesay',
        role: Roles.customer,
      );
      return AuthSuccess(AuthResponse(user: currentUser));
    }
    return AuthFailure(failureMessage);
  }

  @override
  Future<AuthResult<UserProfile>> getUserProfile(String userId) async {
    if (shouldSucceed && mockProfile != null) {
      return AuthSuccess(mockProfile!);
    }
    return const AuthFailure('Profile not found');
  }

  @override
  Future<AuthResult<void>> resetPasswordForEmail({
    required String email,
    String? redirectTo,
  }) async {
    if (shouldSucceed) {
      return const AuthSuccess(null);
    }
    return AuthFailure(failureMessage);
  }

  @override
  Future<AuthResult<UserResponse>> updatePassword({
    required String newPassword,
  }) async {
    if (shouldSucceed) {
      return AuthSuccess(UserResponse.fromJson({'user': null}));
    }
    return AuthFailure(failureMessage);
  }

  @override
  Future<AuthResult<void>> signOut() async {
    currentUser = null;
    mockProfile = null;
    return const AuthSuccess(null);
  }

  @override
  Future<AuthResult<UserProfile>> updateUserProfile({
    required String userId,
    required String fullName,
    String? phone,
    String? avatarUrl,
  }) async {
    mockProfile = UserProfile(
      id: userId,
      fullName: fullName,
      role: mockProfile?.role ?? Roles.customer,
      phone: phone,
      avatarUrl: avatarUrl,
    );
    return AuthSuccess(mockProfile!);
  }

  @override
  Future<String?> uploadAvatar({
    required String userId,
    required dynamic bytes,
    required String fileExtension,
  }) async {
    return 'https://example.com/avatar.jpg';
  }
}

void main() {
  group('AuthNotifier Tests', () {
    late FakeAuthRepository fakeRepo;
    late AuthNotifier notifier;

    setUp(() {
      fakeRepo = FakeAuthRepository();
      notifier = AuthNotifier(repository: fakeRepo);
    });

    test('initial status is unauthenticated when no session exists', () {
      expect(notifier.status, equals(AuthStatus.unauthenticated));
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.profile, isNull);
      expect(notifier.errorMessage, isNull);
    });

    test('signIn success transitions status and populates profile', () async {
      fakeRepo.shouldSucceed = true;

      final result = await notifier.signIn(
        email: 'amadu@example.sl',
        password: 'Password123',
      );

      expect(result, isTrue);
      expect(notifier.status, equals(AuthStatus.authenticated));
      expect(notifier.isAuthenticated, isTrue);
      expect(notifier.profile?.fullName, equals('Amadu Bah'));
      expect(notifier.errorMessage, isNull);
    });

    test('signIn failure transitions to error and sets message', () async {
      fakeRepo.shouldSucceed = false;
      fakeRepo.failureMessage = 'Invalid email or password.';

      final result = await notifier.signIn(
        email: 'amadu@example.sl',
        password: 'WrongPassword123',
      );

      expect(result, isFalse);
      expect(notifier.status, equals(AuthStatus.error));
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.errorMessage, equals('Invalid email or password.'));
    });

    test('signUp success sets status to authenticated or unauthenticated', () async {
      fakeRepo.shouldSucceed = true;

      final result = await notifier.signUp(
        email: 'fatima@example.sl',
        password: 'Password123',
        fullName: 'Fatima Sesay',
      );

      expect(result, isTrue);
      expect(notifier.errorMessage, isNull);
    });

    test('sendPasswordReset handles success and failure', () async {
      fakeRepo.shouldSucceed = true;
      var success = await notifier.sendPasswordReset(email: 'test@example.sl');
      expect(success, isTrue);
      expect(notifier.errorMessage, isNull);

      fakeRepo.shouldSucceed = false;
      fakeRepo.failureMessage = 'Account not found.';
      success = await notifier.sendPasswordReset(email: 'notfound@example.sl');
      expect(success, isFalse);
      expect(notifier.errorMessage, equals('Account not found.'));
    });

    test('updatePassword updates password successfully', () async {
      fakeRepo.shouldSucceed = true;
      final success = await notifier.updatePassword(newPassword: 'NewPassword123');
      expect(success, isTrue);
      expect(notifier.status, equals(AuthStatus.authenticated));
    });

    test('signOut resets state to unauthenticated', () async {
      fakeRepo.shouldSucceed = true;
      await notifier.signIn(email: 'test@example.sl', password: 'Password123');
      expect(notifier.isAuthenticated, isTrue);

      await notifier.signOut();
      expect(notifier.isAuthenticated, isFalse);
      expect(notifier.status, equals(AuthStatus.unauthenticated));
      expect(notifier.profile, isNull);
    });

    test('clearError resets errorMessage', () async {
      fakeRepo.shouldSucceed = false;
      fakeRepo.failureMessage = 'Something went wrong';
      await notifier.signIn(email: 'x@x.com', password: 'p');

      expect(notifier.errorMessage, isNotNull);
      notifier.clearError();
      expect(notifier.errorMessage, isNull);
    });
  });
}
