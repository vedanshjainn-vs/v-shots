// ═════════════════════════════════════════════════════════════════════════════
// V Shots — AuthModal (Supabase Auth & Google OAuth Sign-In)
// ═════════════════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/backend/auth_service.dart';
import '../../core/backend/supabase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_input.dart';

class AuthModal extends StatefulWidget {
  const AuthModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AuthModal(),
    );
  }

  @override
  State<AuthModal> createState() => _AuthModalState();
}

class _AuthModalState extends State<AuthModal> {
  bool _isSignUp = false;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please fill in all fields.');
      return;
    }

    if (password.length < 6) {
      setState(() => _errorMessage = 'Password must be at least 6 characters.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (!SupabaseService.isAvailable) {
        // Fallback for offline mode
        await Future<void>.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logged in as Guest / Offline mode.'),
              backgroundColor: AppColors.surface2,
            ),
          );
        }
        return;
      }

      if (_isSignUp) {
        final name = _nameController.text.trim();
        final username = _usernameController.text.trim();

        await SupabaseService.client.auth.signUp(
          email: email,
          password: password,
          data: {
            'full_name': name.isNotEmpty ? name : 'V Shots Creator',
            'username': username.isNotEmpty
                ? username
                : 'user_${DateTime.now().millisecondsSinceEpoch % 10000}',
          },
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Account created! Welcome to V Shots.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        await SupabaseService.client.auth.signInWithPassword(
          email: email,
          password: password,
        );

        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome back to V Shots!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.instance.signInWithGoogle();
    if (mounted) {
      setState(() => _isLoading = false);
      if (result.isSuccess) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed in with Google!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (result.error != null) {
        setState(() => _errorMessage = result.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: 24 + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title & Switcher
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isSignUp ? 'Create Account' : 'Welcome Back',
                    style: const TextStyle(
                      color: AppColors.textMain,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isSignUp = !_isSignUp;
                        _errorMessage = null;
                      });
                    },
                    child: Text(
                      _isSignUp ? 'Sign In instead' : 'Sign Up',
                      style: const TextStyle(
                        color: AppColors.accent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Error banner if any
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            color: AppColors.error,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Google OAuth Button
              AppButton(
                text: 'Continue with Google',
                icon: Icons.g_mobiledata_rounded,
                variant: AppButtonVariant.secondary,
                size: AppButtonSize.large,
                isLoading: _isLoading,
                onPressed: _handleGoogleSignIn,
              ),
              const SizedBox(height: 18),

              // Divider
              const Row(
                children: [
                  Expanded(child: Divider(color: AppColors.borderSubtle)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or with email',
                      style: TextStyle(
                        color: AppColors.textSubtle,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: AppColors.borderSubtle)),
                ],
              ),
              const SizedBox(height: 18),

              // Form fields
              if (_isSignUp) ...[
                AppTextInput(
                  controller: _nameController,
                  label: 'Full Name',
                  hintText: 'e.g. Alex River',
                  prefixIcon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 14),
                AppTextInput(
                  controller: _usernameController,
                  label: 'Username',
                  hintText: 'e.g. alexriver',
                  prefixIcon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 14),
              ],

              AppTextInput(
                controller: _emailController,
                label: 'Email',
                hintText: 'name@example.com',
                keyboardType: TextInputType.emailAddress,
                prefixIcon: Icons.mail_outline_rounded,
              ),
              const SizedBox(height: 14),

              AppTextInput(
                controller: _passwordController,
                label: 'Password',
                hintText: '••••••••',
                obscureText: true,
                prefixIcon: Icons.lock_outline_rounded,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _handleEmailAuth(),
              ),
              const SizedBox(height: 24),

              // Submit Button
              AppButton(
                text: _isSignUp ? 'Sign Up' : 'Sign In',
                size: AppButtonSize.large,
                isFullWidth: true,
                isLoading: _isLoading,
                onPressed: _handleEmailAuth,
              ),
              const SizedBox(height: 12),

              // Guest mode option
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    'Continue as Guest',
                    style: TextStyle(color: AppColors.textSubtle, fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
