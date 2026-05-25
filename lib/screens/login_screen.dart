import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_state.dart';
import '../theme/labmate_theme.dart';

class LoginScreen extends StatefulWidget {
  final AppState appState;
  final bool showDevWebDemo;
  final Future<void> Function()? onDevWebDemo;

  const LoginScreen({
    super.key,
    required this.appState,
    this.showDevWebDemo = false,
    this.onDevWebDemo,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final FocusNode passwordFocusNode = FocusNode();

  bool isLoading = false;

  Future<void> login() async {
    if (isLoading) {
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> enterDevWebDemo() async {
    final onDevWebDemo = widget.onDevWebDemo;
    if (onDevWebDemo == null) {
      return;
    }

    await onDevWebDemo();

    if (!mounted) {
      return;
    }

    Navigator.popUntil(context, (route) => route.isFirst);
  }

  void _openSignUp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SignUpScreen(appState: widget.appState),
      ),
    );
  }

  void _showForgotPasswordInfo() {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      const SnackBar(content: Text('Password reset is not available yet.')),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final decorationTheme = theme.inputDecorationTheme;

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      filled: decorationTheme.filled,
      fillColor: decorationTheme.fillColor,
      hintStyle: decorationTheme.hintStyle,
      labelStyle: decorationTheme.labelStyle,
      floatingLabelStyle: decorationTheme.floatingLabelStyle,
      helperStyle: decorationTheme.helperStyle,
      errorStyle: decorationTheme.errorStyle,
      border: decorationTheme.border,
      enabledBorder: decorationTheme.enabledBorder,
      focusedBorder: decorationTheme.focusedBorder,
      suffixIconColor: decorationTheme.suffixIconColor,
      prefixIconColor: decorationTheme.prefixIconColor,
    );
  }

  Widget _buildAuthDivider(BuildContext context) {
    final palette = context.labmate;

    return Row(
      children: [
        Expanded(child: Divider(color: palette.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: palette.mutedText),
          ),
        ),
        Expanded(child: Divider(color: palette.border)),
      ],
    );
  }

  Widget _buildAuthBackground(BuildContext context) {
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.alphaBlend(
              colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.05),
              palette.appBackground,
            ),
            palette.appBackground,
            Color.alphaBlend(
              colorScheme.secondary.withValues(alpha: isDark ? 0.06 : 0.03),
              palette.appBackground,
            ),
          ],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -32,
            right: -18,
            child: _BackdropOrb(
              size: 160,
              color: colorScheme.primary.withValues(
                alpha: isDark ? 0.12 : 0.08,
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 42,
            child: _BackdropOrb(
              size: 130,
              color: colorScheme.secondary.withValues(
                alpha: isDark ? 0.08 : 0.05,
              ),
            ),
          ),
          Positioned(
            top: 118,
            left: 28,
            child: Icon(
              Icons.bubble_chart_rounded,
              size: 44,
              color: colorScheme.primary.withValues(
                alpha: isDark ? 0.08 : 0.06,
              ),
            ),
          ),
          Positioned(
            right: 46,
            bottom: 140,
            child: Transform.rotate(
              angle: 0.35,
              child: Icon(
                Icons.science_outlined,
                size: 38,
                color: colorScheme.secondary.withValues(
                  alpha: isDark ? 0.09 : 0.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = context.labmate;
    final colorScheme = context.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWideLayout = constraints.maxWidth >= 700;
          final horizontalPadding = isWideLayout ? 24.0 : 16.0;
          final verticalPadding = isWideLayout ? 24.0 : 16.0;
          final minHeight = math.max(
            0.0,
            constraints.maxHeight - (verticalPadding * 2),
          );

          return Stack(
            children: [
              Positioned.fill(child: _buildAuthBackground(context)),
              if (Navigator.canPop(context))
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: palette.panel.withValues(
                          alpha: isDark ? 0.86 : 0.92,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => Navigator.maybePop(context),
                          child: Padding(
                            padding: const EdgeInsets.all(10),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: colorScheme.onSurface,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: minHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 460),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: palette.panel.withValues(
                                alpha: isDark ? 0.92 : 0.96,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: palette.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(
                                    alpha: isDark ? 0.28 : 0.08,
                                  ),
                                  blurRadius: 32,
                                  offset: const Offset(0, 18),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Center(
                                  child: Container(
                                    height: 72,
                                    width: 72,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorScheme.primary.withValues(
                                        alpha: isDark ? 0.18 : 0.10,
                                      ),
                                      border: Border.all(
                                        color: colorScheme.primary.withValues(
                                          alpha: isDark ? 0.22 : 0.16,
                                        ),
                                      ),
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.science_rounded,
                                          size: 32,
                                          color: colorScheme.primary,
                                        ),
                                        Positioned(
                                          right: 14,
                                          bottom: 14,
                                          child: Icon(
                                            Icons.bubble_chart_rounded,
                                            size: 14,
                                            color: colorScheme.secondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  'Welcome back',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurface,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to continue to your lab workspace',
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: palette.mutedText,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextField(
                                  controller: emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onSubmitted: (_) =>
                                      passwordFocusNode.requestFocus(),
                                  decoration: _inputDecoration(
                                    label: 'Email',
                                    icon: Icons.alternate_email_rounded,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                TextField(
                                  controller: passwordController,
                                  focusNode: passwordFocusNode,
                                  obscureText: true,
                                  textInputAction: TextInputAction.done,
                                  onSubmitted: (_) => login(),
                                  decoration: _inputDecoration(
                                    label: 'Password',
                                    icon: Icons.lock_outline_rounded,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordInfo,
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 0,
                                        vertical: 4,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: colorScheme.primary,
                                    ),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  height: 52,
                                  child: ElevatedButton(
                                    onPressed: isLoading ? null : login,
                                    style: ElevatedButton.styleFrom(
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            height: 22,
                                            width: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.4,
                                              valueColor:
                                                  AlwaysStoppedAnimation(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Text('Sign In'),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                _buildAuthDivider(context),
                                if (widget.showDevWebDemo &&
                                    widget.onDevWebDemo != null) ...[
                                  const SizedBox(height: 18),
                                  SizedBox(
                                    height: 50,
                                    child: OutlinedButton.icon(
                                      onPressed: isLoading
                                          ? null
                                          : () => enterDevWebDemo(),
                                      icon: const Icon(
                                        Icons.web_asset_rounded,
                                        size: 18,
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      label: const Text('Dev Web Demo'),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 18),
                                Center(
                                  child: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 4,
                                    children: [
                                      Text(
                                        "Don't have an account?",
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: palette.mutedText,
                                            ),
                                      ),
                                      TextButton(
                                        onPressed: _openSignUp,
                                        style: TextButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          foregroundColor: colorScheme.primary,
                                        ),
                                        child: const Text('Sign up'),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BackdropOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _BackdropOrb({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  final AppState appState;

  const SignUpScreen({super.key, required this.appState});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool isLoading = false;

  Future<void> createAccount() async {
    final password = passwordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (password != confirmPassword) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Passwords do not match.')));
      return;
    }

    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: password,
      );
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created. Please login.')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LoginScreen(appState: widget.appState),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Create account failed: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign Up', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 40),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Create Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : createAccount,
                child: isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Create Account'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
