import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';

const int _otpLength = 6;
const int _resendSeconds = 59;

/// OTP verification screen. Matches 07_otp_verification.png.
class OtpScreen extends ConsumerStatefulWidget {
  /// The E.164 number being verified (shown in the subtitle).
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = _resendSeconds;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  void _verify() {
    final code = _controller.text;
    if (code.length < _otpLength) {
      setState(() => _error = 'Enter all $_otpLength digits.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).verify(code);
  }

  void _resend() {
    if (_secondsLeft > 0) return;
    _controller.clear();
    setState(() => _error = null);
    ref.read(authControllerProvider.notifier).resend();
    _startCountdown();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state is AuthLoading;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is Authenticated) {
        context.go(AppConstants.routeHome);
      } else if (next is AuthError) {
        setState(() => _error = next.failure.message);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary),
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 100),
                  const _OtpLogo(),
                  const SizedBox(height: 28),
                  Text('Enter verification code',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.appBarTitle.copyWith(fontSize: 26)),
                  const SizedBox(height: 12),
                  _SubtitleRow(
                    phoneNumber: _formatPhone(widget.phoneNumber),
                    onEdit: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(height: 36),
                  _OtpInput(
                    controller: _controller,
                    onChanged: (_) => setState(() => _error = null),
                    onCompleted: (_) => _verify(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorText(_error!),
                  ],
                  const SizedBox(height: 24),
                  _ResendRow(
                    secondsLeft: _secondsLeft,
                    onResend: _resend,
                  ),
                  const SizedBox(height: 32),
                  _VerifyButton(isLoading: isLoading, onPressed: _verify),
                  const SizedBox(height: 40),
                  Text("BELLA'S KITCHEN SECURITY",
                      style: AppTextStyles.itemDescription.copyWith(
                          color: AppColors.textHint,
                          fontSize: 12,
                          letterSpacing: 2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formats a +1 E.164 number to "+1 (555) 012-3456"; otherwise returns as-is.
String _formatPhone(String e164) {
  final digits = e164.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 11 && digits.startsWith('1')) {
    final n = digits.substring(1);
    return '+1 (${n.substring(0, 3)}) ${n.substring(3, 6)}-${n.substring(6)}';
  }
  return e164;
}

// ─── Logo ─────────────────────────────────────────────────────────────────────

class _OtpLogo extends StatelessWidget {
  const _OtpLogo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: const Icon(Icons.restaurant_rounded,
            color: AppColors.accent, size: 38),
      ),
    );
  }
}

// ─── Subtitle ─────────────────────────────────────────────────────────────────

class _SubtitleRow extends StatelessWidget {
  final String phoneNumber;
  final VoidCallback onEdit;
  const _SubtitleRow({required this.phoneNumber, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text('Sent to $phoneNumber',
              style: AppTextStyles.itemDescription.copyWith(fontSize: 15),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onEdit,
          child: Text('Edit',
              style: AppTextStyles.cartBarAction.copyWith(fontSize: 15)),
        ),
      ],
    );
  }
}

// ─── OTP input (6 boxes over a hidden field) ──────────────────────────────────

class _OtpInput extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  const _OtpInput({
    required this.controller,
    required this.onChanged,
    required this.onCompleted,
  });

  @override
  State<_OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<_OtpInput> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_otpLength, (i) {
              final filled = i < text.length;
              final active = i == text.length;
              return _OtpBox(
                digit: filled ? text[i] : '',
                active: active,
              );
            }),
          ),
          // Invisible field that actually captures input/focus.
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                autofocus: true,
                keyboardType: TextInputType.number,
                showCursor: false,
                enableInteractiveSelection: false,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_otpLength),
                ],
                onChanged: (v) {
                  setState(() {});
                  widget.onChanged(v);
                  if (v.length == _otpLength) widget.onCompleted(v);
                },
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final String digit;
  final bool active;
  const _OtpBox({required this.digit, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? AppColors.accent : AppColors.borderColor,
          width: active ? 1.6 : 0.8,
        ),
      ),
      child: Text(digit,
          style: AppTextStyles.heading1.copyWith(fontSize: 24)),
    );
  }
}

// ─── Resend row ───────────────────────────────────────────────────────────────

class _ResendRow extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback onResend;
  const _ResendRow({required this.secondsLeft, required this.onResend});

  @override
  Widget build(BuildContext context) {
    final canResend = secondsLeft <= 0;
    final m = (secondsLeft ~/ 60).toString().padLeft(2, '0');
    final s = (secondsLeft % 60).toString().padLeft(2, '0');
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Didn't receive code? ",
            style: AppTextStyles.itemDescription.copyWith(fontSize: 14)),
        GestureDetector(
          onTap: canResend ? onResend : null,
          child: Text(
            canResend ? 'Resend code' : 'Resend code in $m:$s',
            style: AppTextStyles.itemName.copyWith(
              fontSize: 14,
              color: canResend ? AppColors.accent : AppColors.textHint,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Verify button + error text ───────────────────────────────────────────────

class _VerifyButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _VerifyButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white),
              )
            : Text('Verify',
                style: AppTextStyles.heading2.copyWith(color: Colors.white)),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.accent, size: 16),
        const SizedBox(width: 6),
        Flexible(
          child: Text(message,
              textAlign: TextAlign.center,
              style: AppTextStyles.itemDescription
                  .copyWith(color: AppColors.accent, fontSize: 13)),
        ),
      ],
    );
  }
}
