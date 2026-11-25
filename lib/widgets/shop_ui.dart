import 'package:flutter/material.dart';

import '../services/shop_profile.dart';

abstract final class ShopColors {
  static const primary = Color(0xFF002E7B);
  static const primaryContainer = Color(0xFF1244A2);
  static const orange = Color(0xFFFE6B00);
  static const surface = Color(0xFFF7F9FD);
  static const pale = Color(0xFFF2F4F8);
  static const paleBlue = Color(0xFFDAE2FF);
  static const text = Color(0xFF191C1F);
  static const muted = Color(0xFF434652);
  static const outline = Color(0xFFC4C6D4);
  static const green = Color(0xFF005539);
  static const greenPale = Color(0xFFE1F6EC);
  static const red = Color(0xFFBA1A1A);
}

const pageRoutes = <String>[
  '/home',
  '/inventory',
  '/sales',
  '/reports',
  '/settings',
];

/// Navigation destinations available to the signed-in role. Employees only
/// reach Sales and Reports (daily information); owners get the full shell.
List<String> navRoutesForRole(String? role) {
  switch (role) {
    case 'employee':
      return const ['/sales', '/reports'];
    case 'owner':
    default:
      return pageRoutes;
  }
}

IconData _navIcon(String route) => switch (route) {
  '/home' => Icons.home_outlined,
  '/inventory' => Icons.inventory_2_outlined,
  '/sales' => Icons.point_of_sale_outlined,
  '/reports' => Icons.bar_chart_rounded,
  '/settings' => Icons.settings_outlined,
  _ => Icons.home_outlined,
};

String _navLabel(String route) => switch (route) {
  '/home' => 'Home',
  '/inventory' => 'Inventory',
  '/sales' => 'Sales',
  '/reports' => 'Reports',
  '/settings' => 'Settings',
  _ => route,
};

Widget brandMark({double size = 42}) => Container(
  width: size,
  height: size,
  decoration: BoxDecoration(
    color: ShopColors.primary,
    borderRadius: BorderRadius.circular(13),
  ),
  child: Icon(Icons.checkroom_rounded, color: Colors.white, size: size * .58),
);

Widget brandTitle({bool compact = false}) => Row(
  children: [
    brandMark(size: compact ? 38 : 44),
    const SizedBox(width: 10),
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Clothing Shop Manager',
          style: TextStyle(
            color: ShopColors.primary,
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w800,
            letterSpacing: -.3,
          ),
        ),
        Text(
          'Zambia Retail POS',
          style: TextStyle(
            color: ShopColors.muted,
            fontSize: compact ? 11 : 12,
          ),
        ),
      ],
    ),
  ],
);

/// Company name entered at registration (falls back to the Urban7 brand
/// until the shop profile loads).
class ShopCompanyName extends StatelessWidget {
  const ShopCompanyName({
    super.key,
    required this.style,
    this.maxLines = 1,
    this.textAlign,
    this.overflow = TextOverflow.ellipsis,
  });

  final TextStyle style;
  final int maxLines;
  final TextAlign? textAlign;
  final TextOverflow overflow;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: shopProfile,
    builder: (context, _) {
      shopProfile.ensureLoaded();
      return Text(
        shopProfile.companyName,
        maxLines: maxLines,
        overflow: overflow,
        textAlign: textAlign,
        style: style,
      );
    },
  );
}

/// Shop logo from the shop profile, with the clothing icon as a fallback
/// when no logo was uploaded (or it cannot be fetched).
class ShopBrandLogo extends StatelessWidget {
  const ShopBrandLogo({
    super.key,
    this.size = 40,
    this.backgroundColor = Colors.white,
    this.iconColor = ShopColors.primary,
    this.borderRadius = 8,
    this.icon = Icons.checkroom_outlined,
    this.logoUrl,
  });

  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final double borderRadius;
  final IconData icon;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: shopProfile,
    builder: (context, _) {
      shopProfile.ensureLoaded();
      final url = (logoUrl ?? shopProfile.logoUrl).trim();
      final fallback = Icon(icon, color: iconColor, size: size * .62);
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: url.isEmpty
            ? Center(child: fallback)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Center(child: fallback),
              ),
      );
    },
  );
}

/// Small logo + company name cluster used by page headers.
class ShopHeaderBrand extends StatelessWidget {
  const ShopHeaderBrand({
    super.key,
    required this.title,
    this.logoSize = 34,
    this.nameStyle = const TextStyle(
      color: Colors.white,
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: .5,
    ),
    this.titleStyle = const TextStyle(
      color: Colors.white,
      fontSize: 17,
      height: 1.1,
      fontWeight: FontWeight.w800,
    ),
    this.iconColor = ShopColors.primary,
  });

  final String title;
  final double logoSize;
  final TextStyle nameStyle;
  final TextStyle titleStyle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ShopBrandLogo(size: logoSize, iconColor: iconColor),
      const SizedBox(width: 9),
      Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShopCompanyName(style: nameStyle),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
          ],
        ),
      ),
    ],
  );
}


Widget pageHeader(
  String title, {
  String? subtitle,
  List<Widget> actions = const [],
  VoidCallback? onBack,
}) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
  child: Row(
    children: [
      if (onBack != null) ...[
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ShopColors.text,
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  subtitle,
                  style: const TextStyle(fontSize: 13, color: ShopColors.muted),
                ),
              ),
          ],
        ),
      ),
      ...actions,
    ],
  ),
);

class ShopCard extends StatelessWidget {
  const ShopCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.borderRadius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double borderRadius;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
     decoration: BoxDecoration(
       color: color,
       borderRadius: BorderRadius.circular(borderRadius),
       border: Border.all(color: const Color(0x0F000000)),
       boxShadow: const [
         BoxShadow(
           color: Color(0x0A192033),
           blurRadius: 24,
           offset: Offset(0, 8),
         ),
       ],
     ),
    child: child,
  );
}

class SectionHeading extends StatelessWidget {
  const SectionHeading(this.title, {super.key, this.action, this.onAction});

  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: ShopColors.text,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: ShopColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: Text(
              action!,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    ),
  );
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.backgroundColor = ShopColors.orange,
    this.foregroundColor = Colors.white,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 54,
    width: double.infinity,
    child: FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.arrow_forward_rounded, size: 20),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.note,
    this.color = ShopColors.primary,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? note;
  final Color color;

  @override
  Widget build(BuildContext context) => ShopCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const Spacer(),
            if (note != null)
              Text(
                note!,
                style: const TextStyle(
                  color: ShopColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: 13),
        Text(
          value,
          style: const TextStyle(
            color: ShopColors.text,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(color: ShopColors.muted, fontSize: 12),
        ),
      ],
    ),
  );
}

class ShopBottomNavigation extends StatelessWidget {
  const ShopBottomNavigation({
    super.key,
    required this.selectedIndex,
    this.role,
  });

  final int selectedIndex;
  final String? role;

  @override
  Widget build(BuildContext context) {
    final routes = navRoutesForRole(role);
    final clamped = selectedIndex.clamp(0, routes.length - 1);
    return NavigationBar(
      height: 68,
      selectedIndex: clamped,
      backgroundColor: Colors.white,
      indicatorColor: ShopColors.primary.withValues(alpha: .12),
      onDestinationSelected: (index) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          routes[index],
          (route) => route.isFirst,
        );
      },
      destinations: routes
          .map(
            (route) => NavigationDestination(
              icon: Icon(_navIcon(route)),
              label: _navLabel(route),
            ),
          )
          .toList(),
    );
  }
}

class ShopScaffold extends StatelessWidget {
  const ShopScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    this.role,
    this.floatingActionButton,
  });

  final Widget body;
  final int selectedIndex;
  final String? role;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(child: body),
    bottomNavigationBar: ShopBottomNavigation(
      selectedIndex: selectedIndex,
      role: role,
    ),
    floatingActionButton: floatingActionButton,
  );
}

InputDecoration shopInputDecoration(
  String hint, {
  IconData? icon,
  String? prefixText,
}) => InputDecoration(
  hintText: hint,
  prefixIcon: icon == null ? null : Icon(icon, color: ShopColors.muted),
  prefixText: prefixText,
  filled: true,
  fillColor: ShopColors.pale,
  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: ShopColors.primary, width: 1.4),
  ),
  labelStyle: const TextStyle(
    color: ShopColors.text,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
  floatingLabelStyle: const TextStyle(
    color: ShopColors.primary,
    fontSize: 14,
    fontWeight: FontWeight.w600,
  ),
);

void showShopMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        elevation: 8,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    );
}
