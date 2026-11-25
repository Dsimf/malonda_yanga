import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api_client.dart';
import '../services/shop_profile.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

/// Skip persisting credentials when running widget tests.
bool loginPrefsDisabledForTests = false;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _signingIn = false;
  bool _requestingPasswordReset = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    if (loginPrefsDisabledForTests) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      _emailController.text = prefs.getString('remembered_email') ?? '';
    });
  }

  Future<void> _storeCredentials(bool remember, String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (remember) {
      await prefs.setBool('remember_me', true);
      await prefs.setString('remembered_email', email);
    } else {
      await prefs.remove('remember_me');
      await prefs.remove('remembered_email');
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
        password.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a valid email address and password.';
      });
      return;
    }
    setState(() {
      _signingIn = true;
      _errorMessage = null;
    });
    try {
      final session = await ApiClient.login(
        email,
        password,
        rememberMe: _rememberMe,
      );
      final shop = session['shop'];
      if (shop is Map<String, dynamic>) shopProfile.apply(shop);
      if (!loginPrefsDisabledForTests) {
        await _storeCredentials(_rememberMe, email);
      }
      if (!mounted) return;
      // Cashiers (employees) land on the till; owners land on the home dashboard.
      final destination = ApiClient.isEmployee ? '/sales' : '/home';
      Navigator.pushNamedAndRemoveUntil(context, destination, (route) => false);
    } on ApiException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _requestPasswordReset() async {
    final email = await showDialog<String>(
      context: context,
      builder: (_) =>
          _PasswordResetDialog(initialEmail: _emailController.text.trim()),
    );
    if (email == null || !mounted) return;
    setState(() => _requestingPasswordReset = true);
    try {
      await ApiClient.requestPasswordReset(email);
      if (mounted) {
        showShopMessage(
          context,
          'If an account exists for that email, a password reset link has been sent.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _requestingPasswordReset = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
          child: Column(
            children: [
              const _LoginWelcomeCard(),
              const SizedBox(height: 17),
              const SizedBox(height: 17),
              _LoginFormCard(
                emailController: _emailController,
                passwordController: _passwordController,
                obscurePassword: _obscurePassword,
                rememberMe: _rememberMe,
                signingIn: _signingIn,
                requestingPasswordReset: _requestingPasswordReset,
                errorMessage: _errorMessage,
                onTogglePassword: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                onRememberMeChanged: (value) =>
                    setState(() => _rememberMe = value),
                onForgotPin: _requestPasswordReset,
                onSignIn: _signIn,
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in with the email and password registered for your shop.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ShopColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 17),
              const Row(
                children: [
                  Expanded(
                    child: _LoginInfoCard(
                      icon: Icons.currency_exchange_rounded,
                      title: 'Default Currency',
                      subtitle: 'Zambian Kwacha (K)',
                      iconColor: ShopColors.primary,
                      iconBackground: ShopColors.paleBlue,
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: _LoginInfoCard(
                      icon: Icons.sync_rounded,
                      title: 'Auto Cloud Sync',
                      subtitle: 'Backend API',
                      iconColor: Color(0xFFB63F00),
                      iconBackground: Color(0xFFFFDBCC),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Flexible(
                    child: Text(
                      "Don't have an account yet? ",
                      style: TextStyle(color: ShopColors.muted, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    style: TextButton.styleFrom(
                      foregroundColor: ShopColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Register Shop',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.support_agent_rounded,
                    size: 15,
                    color: ShopColors.muted,
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Cashier Helpdesk',
                    style: TextStyle(color: ShopColors.muted, fontSize: 11),
                  ),
                  SizedBox(width: 13),
                  Icon(Icons.circle, size: 4, color: ShopColors.muted),
                  SizedBox(width: 13),
                  Text(
                    'v2.4.0 (POS)',
                    style: TextStyle(color: ShopColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LoginWelcomeCard extends StatelessWidget {
  const _LoginWelcomeCard();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Stack(
      children: [
        Positioned(
          top: -25,
          right: -25,
          child: Container(
            height: 115,
            width: 115,
            decoration: const BoxDecoration(
              color: ShopColors.pale,
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: -45,
          left: -40,
          child: Container(
            height: 135,
            width: 135,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0E4),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(19, 20, 19, 16),
          decoration: const BoxDecoration(color: Colors.white),
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: ShopColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.checkroom_rounded,
                      color: Colors.white,
                      size: 47,
                    ),
                  ),
                  Positioned(
                    bottom: -3,
                    right: -5,
                    child: Container(
                      height: 34,
                      width: 34,
                      decoration: const BoxDecoration(
                        color: ShopColors.orange,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront_outlined,
                        color: Colors.white,
                        size: 19,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Clothing Shop Manager',
                  style: TextStyle(
                    color: ShopColors.primary,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Welcome back! Sign in to access your retail terminal and inventory.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ShopColors.muted,
                  height: 1.35,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE4F0EC),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: ShopColors.green, size: 10),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Secure sign-in • Supabase connected',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ShopColors.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LoginFormCard extends StatelessWidget {
  const _LoginFormCard({
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.rememberMe,
    required this.signingIn,
    required this.requestingPasswordReset,
    required this.errorMessage,
    required this.onTogglePassword,
    required this.onRememberMeChanged,
    required this.onForgotPin,
    required this.onSignIn,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool rememberMe;
  final bool signingIn;
  final bool requestingPasswordReset;
  final String? errorMessage;
  final VoidCallback onTogglePassword;
  final ValueChanged<bool> onRememberMeChanged;
  final VoidCallback onForgotPin;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.location_on_outlined,
              color: ShopColors.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Secure shop sign-in',
                    style: TextStyle(
                      color: ShopColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Use your owner email and password',
                    style: TextStyle(color: ShopColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: ShopColors.pale,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Text(
                'POS 01',
                style: TextStyle(
                  color: ShopColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        const _FormLabel(title: 'Email address', required: true),
        const SizedBox(height: 6),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: ShopColors.pale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            key: const Key('loginEmailField'),
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            style: const TextStyle(
              color: ShopColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.email_outlined),
              hintText: 'you@example.com',
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: _FormLabel(title: 'Password', required: true),
            ),
            TextButton(
              onPressed: requestingPasswordReset ? null : onForgotPin,
              style: TextButton.styleFrom(
                foregroundColor: ShopColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                requestingPasswordReset ? 'Sending…' : 'Forgot password?',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 55,
          decoration: BoxDecoration(
            color: ShopColors.pale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            key: const Key('loginPasswordField'),
            controller: passwordController,
            obscureText: obscurePassword,
            style: const TextStyle(
              color: ShopColors.text,
              fontSize: 17,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFF777A89),
                size: 21,
              ),
              suffixIcon: IconButton(
                onPressed: onTogglePassword,
                icon: Icon(
                  obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: const Color(0xFF777A89),
                  size: 21,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 15),
            ),
            style: const TextStyle(
              fontSize: 17,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            SizedBox(
              height: 40,
              width: 40,
              child: Checkbox(
                key: const Key('rememberMeCheckbox'),
                value: rememberMe,
                onChanged: (value) {
                  if (value != null) onRememberMeChanged(value);
                },
                activeColor: ShopColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
            GestureDetector(
              onTap: () => onRememberMeChanged(!rememberMe),
              child: const Text(
                'Remember me',
                style: TextStyle(
                  color: ShopColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (errorMessage != null) ...[
          Text(
            errorMessage!,
            key: const Key('loginError'),
            style: const TextStyle(color: ShopColors.red, fontSize: 13),
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            onPressed: signingIn ? null : onSignIn,
            icon: signingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.point_of_sale_rounded, size: 23),
            label: Text(
              signingIn ? 'Signing in…' : 'Sign In to Shop',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ShopColors.orange,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: ShopColors.orange.withValues(alpha: .25),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FormLabel extends StatelessWidget {
  const _FormLabel({required this.title, this.required = false});

  final String title;
  final bool required;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: title),
              if (required)
                const TextSpan(
                  text: ' *',
                  style: TextStyle(color: ShopColors.red),
                ),
            ],
          ),
          style: const TextStyle(
            color: ShopColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _LoginInfoCard extends StatelessWidget {
  const _LoginInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.iconColor,
    required this.iconBackground,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) => Container(
    height: 89,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 6,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          height: 52,
          width: 52,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 27),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ShopColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Upgraded password-reset pop-up. Owns its text controller and disposes it
/// only after the dialog route has fully left the screen.
class _PasswordResetDialog extends StatefulWidget {
  const _PasswordResetDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_PasswordResetDialog> createState() => _PasswordResetDialogState();
}

class _PasswordResetDialogState extends State<_PasswordResetDialog> {
  late final _controller = TextEditingController(text: widget.initialEmail);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Reset your password',
    icon: Icons.lock_reset_rounded,
    maxWidth: 380,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Enter the account email and we'll send you a reset link.",
          style: TextStyle(color: ShopColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 11),
        TextField(
          key: const Key('passwordResetEmailField'),
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: shopFieldDecoration(
            'Account email',
            icon: Icons.mail_outline_rounded,
          ),
        ),
      ],
    ),
    footer: ShopPopupActions(
      confirmLabel: 'Send reset link',
      onCancel: () => Navigator.pop(context),
      onConfirm: () {
        final value = _controller.text.trim();
        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value)) {
          showShopMessage(context, 'Enter a valid email address.');
          return;
        }
        Navigator.pop(context, value);
      },
    ),
  );
}
