import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/app_failure.dart';
import '../../../../core/utils/result.dart';
import '../../../user/domain/entities/app_user.dart';
import '../../data/repositories/firebase_auth_repository.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/validators/phone_validator.dart';
import 'auth_state.dart';

/// Swap the concrete implementation here (or override in tests).
final authRepositoryProvider =
    Provider<AuthRepository>((ref) => FirebaseAuthRepository());

/// Convenience: the current [AppUser] or null.
final currentUserProvider = Provider<AppUser?>((ref) {
  final state = ref.watch(authControllerProvider);
  return state is Authenticated ? state.user : null;
});

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

/// Drives the phone/OTP flow. Holds `verificationId` / `resendToken` / phone as
/// instance fields (not globals), exposing discrete [AuthState]s to the UI.
class AuthController extends Notifier<AuthState> {
  String? _verificationId;
  int? _resendToken;
  String? _phoneNumber;

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    final repo = ref.read(authRepositoryProvider);
    final sub = repo.authStateChanges().listen(_onAuthChanged);
    ref.onDispose(sub.cancel);
    final current = repo.currentUser();
    return current == null ? const Unauthenticated() : Authenticated(current);
  }

  void _onAuthChanged(AppUser? user) {
    if (user != null) {
      state = Authenticated(user);
    } else if (state is Authenticated) {
      // External sign-out. Don't clobber an in-progress CodeSent/loading flow.
      state = const Unauthenticated();
    }
  }

  /// Validates input, then requests an OTP for the given number.
  Future<void> sendOtp({required String dialCode, required String rawPhone}) async {
    final validation = validatePhone(rawPhone);
    if (validation != null) {
      state = AuthError(validation);
      return;
    }
    _phoneNumber = toE164(dialCode: dialCode, raw: rawPhone);
    await _requestCode(_phoneNumber!);
  }

  /// Re-requests an OTP for the number already in flight (uses the resend token).
  Future<void> resend() async {
    final phone = _phoneNumber;
    if (phone == null) return;
    await _requestCode(phone);
  }

  Future<void> _requestCode(String phone) async {
    state = const AuthLoading();
    final result = await _repo.sendOtp(phone, resendToken: _resendToken);
    state = result.fold(
      onSuccess: (otp) {
        _verificationId = otp.verificationId;
        _resendToken = otp.resendToken;
        return CodeSent(
          verificationId: otp.verificationId,
          resendToken: otp.resendToken,
          phoneNumber: phone,
        );
      },
      onFailure: (failure) => AuthError(failure),
    );
  }

  /// Completes sign-in with the entered [smsCode].
  Future<void> verify(String smsCode) async {
    final vid = _verificationId;
    if (vid == null) {
      state = const AuthError(ValidationFailure('Please request a code first.'));
      return;
    }
    state = const AuthLoading();
    final result = await _repo.verifyOtp(verificationId: vid, smsCode: smsCode);
    state = result.fold(
      onSuccess: (user) => Authenticated(user),
      onFailure: (failure) => AuthError(failure),
    );
  }

  /// Admin email/password sign-in. The repository enforces the admin gate
  /// (a non-admin is signed out and returns an UnauthorizedFailure).
  Future<void> signInAsAdmin(String email, String password) async {
    state = const AuthLoading();
    final result = await _repo.signInWithEmailPassword(email, password);
    state = result.fold(
      onSuccess: (user) => Authenticated(user),
      onFailure: (failure) => AuthError(failure),
    );
  }

  Future<void> signOut() async {
    await _repo.signOut();
    _verificationId = null;
    _resendToken = null;
    _phoneNumber = null;
    state = const Unauthenticated();
  }

  /// The number currently being verified (for the OTP subtitle), if any.
  String? get phoneNumber => _phoneNumber;
}
