import 'package:flutter/material.dart';

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
      boxShadow: const [
        BoxShadow(
          color: Color(0x0C192033),
          blurRadius: 16,
          offset: Offset(0, 5),
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
  const ShopBottomNavigation({super.key, required this.selectedIndex});

  final int selectedIndex;

  @override
  Widget build(BuildContext context) => NavigationBar(
    height: 68,
    selectedIndex: selectedIndex,
    backgroundColor: Colors.white,
    indicatorColor: ShopColors.paleBlue,
    onDestinationSelected: (index) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        pageRoutes[index],
        (route) => route.isFirst,
      );
    },
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
      NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        label: 'Inventory',
      ),
      NavigationDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        label: 'Sales',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_rounded),
        label: 'Reports',
      ),
      NavigationDestination(
        icon: Icon(Icons.settings_outlined),
        label: 'Settings',
      ),
    ],
  );
}

class ShopScaffold extends StatelessWidget {
  const ShopScaffold({
    super.key,
    required this.body,
    required this.selectedIndex,
    this.floatingActionButton,
  });

  final Widget body;
  final int selectedIndex;
  final Widget? floatingActionButton;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(child: body),
    bottomNavigationBar: ShopBottomNavigation(selectedIndex: selectedIndex),
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
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      ),
    );
}
