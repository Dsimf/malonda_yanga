import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/shop_ui.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  @override
  void initState() {
    super.initState();
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    if (!await ApiClient.hasSavedSession()) return;
    // Confirm the saved tokens still work. If both the access and refresh
    // tokens are expired, drop the session so the user lands on the login
    // screen instead of seeing 401/403 errors on every request.
    try {
      await ApiClient.me();
    } on ApiException catch (error) {
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          error.statusCode == 400) {
        // Covers both dead access tokens (401/403) and a failed refresh
        // with an invalid refresh token, which now signs out internally.
        await ApiClient.logout();
        return;
      }
      // Network/server issues shouldn't block a quick restore; let the
      // home page surface them like any other request would.
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF050B1A),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/landing_storefront.png',
          key: const Key('landingBackgroundImage'),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          excludeFromSemantics: true,
        ),
        // Dark gradient scrim like the HTML design.
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .5, 1],
              colors: [Color(0xD90A1128), Color(0xE6002E7B), Color(0xFA050B1A)],
            ),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _LandingHeader(),
                          SizedBox(height: 16),
                          _LandingHero(),
                          SizedBox(height: 10),
                          _FeatureGrid(),
                          SizedBox(height: 10),
                          _TrustStrip(),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 20),
                        child: _LandingActions(
                          onRegister: () =>
                              Navigator.pushNamed(context, '/register'),
                          onLogin: () => Navigator.pushNamed(context, '/login'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Frosted-glass pill with the brand row and ZMW currency chip.
class _LandingHeader extends StatelessWidget {
  const _LandingHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: .15)),
    ),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.bottomLeft,
              end: Alignment.topRight,
              colors: [ShopColors.orange, Color(0xFFF59E0B)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.checkroom_rounded,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'ShopManager',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.3,
                    ),
                  ),
                  SizedBox(width: 5),
                  _MiniChip(label: 'POS'),
                ],
              ),
              SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.circle, color: ShopColors.green, size: 8),
                  SizedBox(width: 5),
                  Text(
                    'Retail POS • Zambia 🇿🇲',
                    style: TextStyle(
                      color: Color(0xFFF2F4F8),
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: .20)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.payments_outlined, color: Color(0xFFFBBF24), size: 14),
              SizedBox(width: 5),
              Text(
                'ZMW (K)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .20),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .6,
      ),
    ),
  );
}

class _LandingHero extends StatelessWidget {
  const _LandingHero();

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('landingHeroPanel'),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .15),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: .20)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('✨', style: TextStyle(fontSize: 11)),
              SizedBox(width: 6),
              Text(
                'NEXT-GEN RETAIL OS FOR CLOTHING & FASHION',
                style: TextStyle(
                  color: Color(0xFFB2C5FF),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 11),
        const Text(
          'Run Your Fashion Store with Speed & Clarity',
          style: TextStyle(
            color: Colors.white,
            fontSize: 26,
            height: 1.18,
            fontWeight: FontWeight.w800,
            letterSpacing: -.5,
          ),
        ),
        const SizedBox(height: 9),
        const Text(
          'Complete inventory management, instant offline-ready cashier POS, '
          'Zambian Kwacha (K) sales tracking, and real-time profit insights '
          'built for boutique retailers.',
          style: TextStyle(
            color: Color(0xFFF2F4F8),
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) => Row(
    children: const [
      Expanded(
        child: _FeatureCard(
          icon: Icons.bolt_rounded,
          iconColor: Color(0xFFFBBF24),
          iconBg: Color(0x33F59E0B),
          title: 'Fast POS',
          subtitle: 'Barcode & Receipts',
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: _FeatureCard(
          icon: Icons.trending_up_rounded,
          iconColor: Color(0xFF34D399),
          iconBg: Color(0x3322C55E),
          title: 'Daily Profits',
          subtitle: 'Auto ZMW Calc',
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: _FeatureCard(
          icon: Icons.style_rounded,
          iconColor: Color(0xFF93C5FD),
          iconBg: Color(0x3360A5FA),
          title: 'Stock Alerts',
          subtitle: 'Size & Color Variants',
        ),
      ),
    ],
  );
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: .15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 17),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.5,
            height: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: const TextStyle(
            color: Color(0xCCF2F4F8),
            fontSize: 9.5,
            height: 1.1,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withValues(alpha: .10)),
    ),
    child: Row(
      children: [
        const Text('⭐️', style: TextStyle(fontSize: 13)),
        const SizedBox(width: 8),
        const Expanded(
          child: Text.rich(
            TextSpan(
              style: TextStyle(
                color: Color(0xFFF2F4F8),
                fontSize: 10.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
              children: [
                TextSpan(text: 'Trusted by '),
                TextSpan(
                  text: '1,200+',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text:
                      ' boutiques, salaula & apparel stores across Lusaka, '
                      'Ndola & Kitwe',
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _LandingActions extends StatelessWidget {
  const _LandingActions({required this.onRegister, required this.onLogin});

  final VoidCallback onRegister;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      // Orange gradient primary CTA.
      SizedBox(
        width: double.infinity,
        height: 52,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF6B00), Color(0xFFFF781A), Color(0xFFF97316)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                  color: const Color(0x4FFDE68A),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x664C1D00),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: FilledButton.icon(
            key: const Key('landingCreateShopButton'),
            onPressed: onRegister,
            icon: const Icon(Icons.rocket_launch_rounded, size: 19),
            label: const Text(
              'Get Started Free — Create Shop',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: FilledButton.icon(
          key: const Key('landingSignInButton'),
          onPressed: onLogin,
          icon: const Icon(Icons.login_rounded, size: 18),
          label: const Text(
            'Sign In to Existing Shop',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white.withValues(alpha: .15),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.white.withValues(alpha: .25)),
            ),
          ),
        ),
      ),
      const SizedBox(height: 12),
      TextButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/login'),
        icon: const Icon(
          Icons.visibility_outlined,
          size: 15,
          color: Color(0xFFFBBF24),
        ),
        label: const Text(
          'Explore Interactive Demo Store',
          style: TextStyle(
            color: Color(0xFFF2F4F8),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: Color(0x80F2F4F8),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Divider(color: Color(0x26FFFFFF), height: 1),
      const SizedBox(height: 10),
      Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0x66022C22),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                  color: const Color(0xFF34D399).withValues(alpha: .5)),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  size: 13,
                  color: Color(0xFF6EE7B7),
                ),
                SizedBox(width: 5),
                Text(
                  '100% Offline Capable • ZRA Compliant • Instant Setup',
                  style: TextStyle(
                    color: Color(0xFF6EE7B7),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            '© ShopManager POS Zambia • Built for African Fashion Retailers',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xB3F2F4F8),
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    ],
  );
}
