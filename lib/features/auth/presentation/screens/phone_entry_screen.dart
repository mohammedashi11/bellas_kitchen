import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';

/// Phone number entry — start of the sign-in flow. Matches 06_phone_entry.png.
class PhoneEntryScreen extends ConsumerStatefulWidget {
  const PhoneEntryScreen({super.key});

  @override
  ConsumerState<PhoneEntryScreen> createState() => _PhoneEntryScreenState();
}

class _PhoneEntryScreenState extends ConsumerState<PhoneEntryScreen> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).sendOtp(
          dialCode: AppConstants.defaultDialCode,
          rawPhone: _controller.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state is AuthLoading;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      if (next is CodeSent) {
        setState(() => _error = null);
        context.push(AppConstants.routeOtp, extra: next.phoneNumber);
      } else if (next is AuthError) {
        setState(() => _error = next.failure.message);
      } else if (next is AuthLoading) {
        setState(() => _error = null);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height -
                  MediaQuery.paddingOf(context).vertical,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  const _Logo(),
                  const SizedBox(height: 28),
                  Text(
                    "Welcome to Bella's Kitchen",
                    textAlign: TextAlign.center,
                    style: AppTextStyles.appBarTitle.copyWith(fontSize: 26),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Late-night comfort food, delivered\nto your door.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.itemDescription
                        .copyWith(fontSize: 15, height: 1.4),
                  ),
                  const SizedBox(height: 36),
                  _PhoneField(controller: _controller, onSubmitted: _submit),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    _ErrorText(_error!),
                  ],
                  const SizedBox(height: 16),
                  _SendCodeButton(isLoading: isLoading, onPressed: _submit),
                  const SizedBox(height: 24),
                  _SignUpRow(),
                  const Spacer(flex: 3),
                  Text(
                    'By continuing, you agree to our Terms of Service & Privacy '
                    'Policy.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.itemDescription
                        .copyWith(color: AppColors.textHint, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Logo ─────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.35),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.accent, width: 2),
              ),
              child: const Icon(Icons.restaurant_menu_rounded,
                  color: AppColors.accent, size: 30),
            ),
            const SizedBox(height: 8),
            Text(
              "Bella's Kitchen",
              style: AppTextStyles.itemName
                  .copyWith(color: AppColors.accent, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Phone field ──────────────────────────────────────────────────────────────

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmitted;
  const _PhoneField({required this.controller, required this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderColor, width: 0.8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          Text(AppConstants.defaultDialCode, style: AppTextStyles.itemName),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Container(width: 1, height: 26, color: AppColors.borderColor),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: TextInputType.phone,
              style: AppTextStyles.itemName,
              cursorColor: AppColors.accent,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9 ()\-]')),
              ],
              onSubmitted: (_) => onSubmitted(),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Phone number',
                hintStyle: AppTextStyles.searchHint,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
    );
  }
}

// ─── Send code button ─────────────────────────────────────────────────────────

class _SendCodeButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _SendCodeButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
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
            : Text('Send Code',
                style: AppTextStyles.heading2.copyWith(color: Colors.white)),
      ),
    );
  }
}

// ─── Sign-up row + error text ─────────────────────────────────────────────────

class _SignUpRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ",
            style: AppTextStyles.itemDescription.copyWith(fontSize: 14)),
        Text('Sign Up', style: AppTextStyles.cartBarAction.copyWith(fontSize: 14)),
      ],
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String message;
  const _ErrorText(this.message);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AppColors.accent, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message,
              style: AppTextStyles.itemDescription
                  .copyWith(color: AppColors.accent, fontSize: 13)),
        ),
      ],
    );
  }
}
