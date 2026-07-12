/// An in-progress phone verification. Pure Dart.
///
/// Returned by `AuthRepository.sendOtp` and held in auth state (not globals) so
/// the subsequent `verifyOtp` call and any resend can reuse them.
class OtpVerification {
  /// Firebase's opaque id tying an SMS code back to this verification attempt.
  final String verificationId;

  /// Token used to force-resend to the same number without re-running captcha.
  final int? resendToken;

  const OtpVerification({required this.verificationId, this.resendToken});
}
