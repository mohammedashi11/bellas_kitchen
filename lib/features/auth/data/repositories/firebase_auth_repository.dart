import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../user/data/models/app_user_model.dart';
import '../../../user/domain/entities/app_user.dart';
import '../../domain/entities/otp_verification.dart';
import '../../domain/repositories/auth_repository.dart';
import '../auth_error_mapper.dart';

/// firebase_auth-backed implementation of [AuthRepository].
///
/// [_auth]/[_firestore] are nullable and resolved defensively so the repository
/// can be constructed before Firebase is initialized (or when it's unavailable)
/// without throwing — calls then return a graceful [Failure] instead of
/// crashing, keeping the rest of the app (mock menu, browsing) usable.
class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth? _auth;
  final FirebaseFirestore? _firestore;

  FirebaseAuthRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? _tryAuth(),
        _firestore = firestore ?? _tryFirestore();

  static FirebaseAuth? _tryAuth() {
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  static FirebaseFirestore? _tryFirestore() {
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static const _unavailable =
      Failure<Never>(NetworkFailure('Sign-in is unavailable right now.'));

  @override
  Future<Result<OtpVerification>> sendOtp(
    String phoneNumber, {
    int? resendToken,
  }) async {
    final auth = _auth;
    if (auth == null) return _unavailable;

    // verifyPhoneNumber is callback-based; bridge the first terminal callback
    // (codeSent / verificationFailed / autoRetrievalTimeout) into a Future.
    final completer = Completer<Result<OtpVerification>>();
    void complete(Result<OtpVerification> r) {
      if (!completer.isCompleted) completer.complete(r);
    }

    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        forceResendingToken: resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {
          // Android auto-retrieval. The manual OTP flow ignores this and waits
          // for the user to enter the code, so we don't complete here.
        },
        verificationFailed: (e) =>
            complete(Failure(authFailureForCode(e.code, message: e.message))),
        codeSent: (verificationId, token) => complete(
          Success(OtpVerification(
            verificationId: verificationId,
            resendToken: token,
          )),
        ),
        codeAutoRetrievalTimeout: (verificationId) => complete(
          Success(OtpVerification(
            verificationId: verificationId,
            resendToken: resendToken,
          )),
        ),
      );
    } catch (e) {
      complete(Failure(_mapGeneric(e)));
    }
    return completer.future;
  }

  @override
  Future<Result<AppUser>> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    final auth = _auth;
    if (auth == null) return _unavailable;

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final result = await auth.signInWithCredential(credential);
      final user = result.user;
      if (user == null) {
        return const Failure(
            UnknownFailure('Sign-in failed. Please try again.'));
      }
      return Success(await _ensureUserDocument(user));
    } on FirebaseAuthException catch (e) {
      return Failure(authFailureForCode(e.code, message: e.message));
    } catch (e) {
      return Failure(_mapGeneric(e));
    }
  }

  @override
  Future<Result<AppUser>> signInAnonymously() async {
    final auth = _auth;
    if (auth == null) return _unavailable;
    try {
      final result = await auth.signInAnonymously();
      final user = result.user;
      if (user == null) {
        return const Failure(
            UnknownFailure('Sign-in failed. Please try again.'));
      }
      // Anonymous users have no phone number; _ensureUserDocument records an
      // empty phoneNumber and creates the users/{uid} doc if absent.
      return Success(await _ensureUserDocument(user));
    } on FirebaseAuthException catch (e) {
      return Failure(authFailureForCode(e.code, message: e.message));
    } catch (e) {
      return Failure(_mapGeneric(e));
    }
  }

  @override
  Future<Result<AppUser>> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    final auth = _auth;
    if (auth == null) return _unavailable;
    try {
      final result = await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = result.user;
      if (user == null) {
        return const Failure(
            UnknownFailure('Sign-in failed. Please try again.'));
      }

      // App-side admin gate (real enforcement is Firestore rules). Admins are
      // provisioned via the console, so we READ the profile (never create one).
      // Fail-closed: if the role can't be confirmed as admin — including when
      // Firestore is unreachable and the read falls back to a customer — sign
      // the user back out so no non-admin can sit in an admin session.
      final appUser = await _loadUser(user);
      if (!appUser.isAdmin) {
        await auth.signOut();
        return const Failure(
            UnauthorizedFailure("This account doesn't have admin access."));
      }
      return Success(appUser);
    } on FirebaseAuthException catch (e) {
      return Failure(authFailureForCode(e.code, message: e.message));
    } catch (e) {
      return Failure(_mapGeneric(e));
    }
  }

  /// Reads the user's Firestore profile WITHOUT creating it (used for the admin
  /// gate and the auth-state stream). Falls back to an auth-derived [AppUser]
  /// (role: customer) when the doc is absent or Firestore is unreachable.
  Future<AppUser> _loadUser(User user) async {
    final firestore = _firestore;
    if (firestore == null) return _mapUser(user);
    try {
      final snap = await firestore
          .collection(AppConstants.usersCollection)
          .doc(user.uid)
          .get()
          .timeout(AppConstants.firestoreTimeout);
      if (snap.exists && snap.data() != null) {
        return AppUserModel.fromMap(snap.id, snap.data()!);
      }
      return _mapUser(user);
    } catch (e) {
      debugPrint('Auth: could not load user document: $e');
      return _mapUser(user);
    }
  }

  /// Reads the user's Firestore profile, creating it on first sign-in.
  /// Never overwrites an existing document. If Firestore is unreachable, the
  /// user is still signed in — we return an auth-derived [AppUser] rather than
  /// failing the whole sign-in.
  Future<AppUser> _ensureUserDocument(User user) async {
    final firestore = _firestore;
    final phone = user.phoneNumber ?? '';
    final fallback = AppUser(
      uid: user.uid,
      phoneNumber: phone,
      displayName: user.displayName,
      createdAt: DateTime.now(),
    );
    if (firestore == null) return fallback;

    try {
      final ref =
          firestore.collection(AppConstants.usersCollection).doc(user.uid);
      final snap = await ref.get().timeout(AppConstants.firestoreTimeout);
      if (snap.exists) {
        return AppUserModel.fromMap(snap.id, snap.data()!);
      }
      final model = AppUserModel(
        uid: user.uid,
        phoneNumber: phone,
        displayName: null,
        savedAddresses: const [],
        createdAt: DateTime.now(),
      );
      await ref.set(model.toFirestore()).timeout(AppConstants.firestoreTimeout);
      return model;
    } catch (e) {
      debugPrint('Auth: could not ensure user document: $e');
      return fallback;
    }
  }

  @override
  Future<Result<void>> signOut() async {
    final auth = _auth;
    if (auth == null) return const Success(null);
    try {
      await auth.signOut();
      return const Success(null);
    } catch (e) {
      return Failure(_mapGeneric(e));
    }
  }

  @override
  AppUser? currentUser() {
    final user = _auth?.currentUser;
    return user == null ? null : _mapUser(user);
  }

  @override
  Stream<AppUser?> authStateChanges() {
    final auth = _auth;
    if (auth == null) return Stream<AppUser?>.value(null);
    // asyncMap so the emitted user carries its real role (from the users doc),
    // which the router's admin guard depends on. Falls back to a role-less
    // (customer) mapping if the doc read fails.
    return auth.authStateChanges().asyncMap((u) async {
      if (u == null) return null;
      return _loadUser(u);
    });
  }

  /// Lightweight mapping from a Firebase [User] using only auth-available fields.
  /// The full profile (savedAddresses, real createdAt) comes from Firestore via
  /// [verifyOtp] / the future Profile feature.
  AppUser _mapUser(User user) => AppUser(
        uid: user.uid,
        phoneNumber: user.phoneNumber ?? '',
        displayName: user.displayName,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  AppFailure _mapGeneric(Object e) {
    final s = e.toString().toLowerCase();
    if (s.contains('network') ||
        s.contains('unreachable') ||
        s.contains('timeout') ||
        s.contains('unavailable')) {
      return const NetworkFailure(
          'Network error. Check your connection and try again.');
    }
    return const UnknownFailure('Something went wrong. Please try again.');
  }
}
