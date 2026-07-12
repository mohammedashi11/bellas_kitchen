import '../../../../core/error/app_failure.dart';

/// Validates raw phone input BEFORE hitting Firebase. Pure Dart.
/// Returns a [ValidationFailure] describing the problem, or null when the input
/// is plausible enough to attempt verification.
AppFailure? validatePhone(String raw) {
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) {
    return const ValidationFailure('Please enter your phone number.');
  }
  if (digits.length < 7) {
    return const ValidationFailure('That phone number looks too short.');
  }
  // E.164 allows at most 15 digits including the country code.
  if (digits.length > 15) {
    return const ValidationFailure('That phone number looks too long.');
  }
  return null;
}

/// Combines a [dialCode] (e.g. "+1") and a raw national number into E.164
/// (e.g. "+15550123456"), stripping any spaces/dashes/parentheses.
String toE164({required String dialCode, required String raw}) {
  final cc = dialCode.replaceAll(RegExp(r'\D'), '');
  final digits = raw.replaceAll(RegExp(r'\D'), '');
  return '+$cc$digits';
}
