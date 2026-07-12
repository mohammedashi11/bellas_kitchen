import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/providers/auth_state.dart';
import '../theme/admin_colors.dart';

/// Admin email/password login. Navy/blue identity, distinct from the customer
/// app. On success the router guard redirects to the admin dashboard; failures
/// (wrong credentials / not an admin / network) show inline.
class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    ref.read(authControllerProvider.notifier).signInAsAdmin(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    final isLoading = state is AuthLoading;

    ref.listen<AuthState>(authControllerProvider, (prev, next) {
      // Success navigation is handled by the router guard (admin → dashboard).
      if (next is AuthError) {
        setState(() => _error = next.failure.message);
      } else if (next is AuthLoading) {
        setState(() => _error = null);
      }
    });

    return Scaffold(
      backgroundColor: AdminColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _Logo(),
                  const SizedBox(height: 24),
                  Text('Admin Panel',
                      style: GoogleFonts.poppins(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AdminColors.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Secure Administrative Access',
                      style: GoogleFonts.poppins(
                          fontSize: 15, color: AdminColors.textSecondary)),
                  const SizedBox(height: 32),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FieldLabel('EMAIL ADDRESS'),
                        const SizedBox(height: 8),
                        _AdminField(
                          controller: _email,
                          hint: 'name@company.com',
                          icon: Icons.mail_outline_rounded,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            _FieldLabel('PASSWORD'),
                            const Spacer(),
                            Text('Forgot?',
                                style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AdminColors.accent)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _AdminField(
                          controller: _password,
                          hint: '••••••••',
                          icon: Icons.lock_outline_rounded,
                          obscure: _obscure,
                          onToggleObscure: () =>
                              setState(() => _obscure = !_obscure),
                          onSubmitted: _submit,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 14),
                          _ErrorText(_error!),
                        ],
                        const SizedBox(height: 22),
                        _LoginButton(isLoading: isLoading, onPressed: _submit),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text('System monitoring active.',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: AdminColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text('v4.2.0-STABLE   •   EN-US',
                      style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          letterSpacing: 1,
                          color: AdminColors.textHint)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AdminColors.border, width: 0.5),
      ),
      child: const Icon(Icons.settings_suggest_rounded,
          color: AdminColors.logoTeal, size: 44),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AdminColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border, width: 0.8),
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: GoogleFonts.robotoMono(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: AdminColors.textSecondary));
  }
}

class _AdminField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType? keyboardType;
  final VoidCallback? onToggleObscure;
  final VoidCallback? onSubmitted;

  const _AdminField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.keyboardType,
    this.onToggleObscure,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: AdminColors.inputFill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminColors.border, width: 0.8),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          Icon(icon, color: AdminColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              obscureText: obscure,
              keyboardType: keyboardType,
              cursorColor: AdminColors.accent,
              style: GoogleFonts.poppins(
                  fontSize: 15, color: AdminColors.textPrimary),
              onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: GoogleFonts.poppins(
                    fontSize: 15, color: AdminColors.textHint),
              ),
            ),
          ),
          if (onToggleObscure != null)
            GestureDetector(
              onTap: onToggleObscure,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                    obscure
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AdminColors.textSecondary,
                    size: 20),
              ),
            )
          else
            const SizedBox(width: 14),
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _LoginButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AdminColors.accent,
          foregroundColor: const Color(0xFF0A0E1A),
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: isLoading ? null : onPressed,
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Color(0xFF0A0E1A)),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Log In',
                      style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0A0E1A))),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded, size: 20),
                ],
              ),
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
      children: [
        const Icon(Icons.error_outline_rounded,
            color: AdminColors.danger, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Text(message,
              style: GoogleFonts.poppins(
                  fontSize: 13, color: AdminColors.danger)),
        ),
      ],
    );
  }
}
