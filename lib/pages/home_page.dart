import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

Future<void> _showLowStockNotifications(BuildContext context) async {
  try {
    final products = await ApiClient.products();
    if (!context.mounted) return;
    final lowStock = products
        .where((product) => (product['quantity'] as num) <= 5)
        .toList();
    await showShopListPopup(
      context: context,
      title: 'Low stock (${lowStock.length})',
      icon: Icons.warning_amber_rounded,
      accent: ShopColors.orange,
      children: lowStock.isEmpty
          ? const [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'All products have more than 5 items in stock.',
                  style: TextStyle(color: ShopColors.muted, fontSize: 14),
                ),
              ),
            ]
          : lowStock
              .map(
                (product) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.pale,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.inventory_2_rounded,
                        color: ShopColors.orange,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'] as String,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: ShopColors.text,
                              ),
                            ),
                            Text(
                              '${product['quantity']} remaining · SKU ${product['sku']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: ShopColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
    );
  } on ApiException catch (error) {
    if (context.mounted) showShopMessage(context, error.message);
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          const _HomeAppBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
              children: [
                const _WelcomeBanner(),
                const SizedBox(height: 14),
                const _DashboardMetrics(),
                const SizedBox(height: 14),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/sales'),
                    icon: const Icon(Icons.point_of_sale_rounded, size: 22),
                    label: const Text(
                      'Start Sales / Cashier',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.orange,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: ShopColors.orange.withValues(alpha: .28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    const Icon(
                      Icons.notifications_active_outlined,
                      color: Color(0xFFB63F00),
                      size: 20,
                    ),
                    const SizedBox(width: 7),
                    const Expanded(
                      child: Text(
                        'Urgent Stock Alerts',
                        style: TextStyle(
                          fontSize: 16,
                          color: ShopColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/inventory'),
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: ShopColors.primary,
                      ),
                      child: const Text(
                        'View Inventory',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                _UrgentStockAlerts(
                  onRestock: () => Navigator.pushNamed(context, '/product/new'),
                ),
                const SizedBox(height: 14),
                _NewInventoryCard(
                  onTap: () => Navigator.pushNamed(context, '/product/new'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _HomeBottomNavigation(role: ApiClient.role),
  );
}

class _DashboardMetrics extends StatefulWidget {
  const _DashboardMetrics();

  @override
  State<_DashboardMetrics> createState() => _DashboardMetricsState();
}

class _DashboardMetricsState extends State<_DashboardMetrics> {
  late Future<Map<String, dynamic>> _dashboard;

  @override
  void initState() {
    super.initState();
    _dashboard = ApiClient.dashboard();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _dashboard,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Text(
          'Could not load dashboard: ${snapshot.error}',
          style: const TextStyle(color: ShopColors.red, fontSize: 12),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final data = snapshot.data!;
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _DashboardMetric(
                  icon: Icons.checkroom_rounded,
                  label: 'Total Products',
                  value: '${data['product_count']}',
                  iconColor: ShopColors.primary,
                  onTap: () => Navigator.pushNamed(context, '/inventory'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardMetric(
                  icon: Icons.inventory_2_outlined,
                  label: 'Available Stock',
                  value: '${data['stock_count']}',
                  iconColor: ShopColors.green,
                  iconBackground: const Color(0xFFD3F9EB),
                  onTap: () => Navigator.pushNamed(context, '/inventory'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DashboardMetric(
                  icon: Icons.warning_amber_rounded,
                  label: 'Low Stock',
                  value: '${data['low_stock_count']}',
                  iconColor: ShopColors.orange,
                  iconBackground: const Color(0xFFFFF0E4),
                  valueColor: ShopColors.orange,
                  onTap: () => _showLowStockNotifications(context),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DashboardMetric(
                  icon: Icons.trending_up_rounded,
                  label: 'Today’s Sales',
                  value: 'K${data['today_sales']}',
                  iconColor: ShopColors.green,
                  iconBackground: const Color(0xFFD3F9EB),
                  valueColor: ShopColors.primary,
                  onTap: () => Navigator.pushNamed(context, '/reports'),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _UrgentStockAlerts extends StatefulWidget {
  const _UrgentStockAlerts({required this.onRestock});

  final VoidCallback onRestock;

  @override
  State<_UrgentStockAlerts> createState() => _UrgentStockAlertsState();
}

class _UrgentStockAlertsState extends State<_UrgentStockAlerts> {
  late Future<List<Map<String, dynamic>>> _products;

  @override
  void initState() {
    super.initState();
    _products = ApiClient.products();
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: _products,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Could not load stock alerts: ${snapshot.error}',
              style: const TextStyle(color: ShopColors.red, fontSize: 12),
            );
          }
          if (!snapshot.hasData) {
            return const LinearProgressIndicator();
          }
          final lowStock = snapshot.data!
              .where((product) => (product['quantity'] as num) <= 5)
              .toList();
          if (lowStock.isEmpty) {
            return const Text(
              'No products currently need restocking.',
              style: TextStyle(color: ShopColors.muted),
            );
          }
          return Column(
            children: lowStock.take(5).map((product) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 9),
                child: _StockAlert(
                  title: product['name'] as String,
                  price: 'K${product['price']}',
                  count: '${product['quantity']} left',
                  icon: Icons.inventory_2_outlined,
                  onRestock: widget.onRestock,
                ),
              );
            }).toList(),
          );
        },
      );
}

class _HomeAppBar extends StatelessWidget {
  const _HomeAppBar();

  static const _headerBlue = Color(0xFF194AA2);

  @override
  Widget build(BuildContext context) => Container(
    height: 72,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    color: _headerBlue,
    child: Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Icon(
            Icons.checkroom_outlined,
            color: _headerBlue,
            size: 26,
          ),
        ),
        const SizedBox(width: 9),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SHOP MANAGER',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .5,
                ),
              ),
              Text(
                'Home',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        _HomeAppBarAction(
          icon: Icons.search_rounded,
          onPressed: () => Navigator.pushNamed(context, '/inventory'),
        ),
        _HomeAppBarAction(
          icon: Icons.notifications_none_rounded,
          onPressed: () => _showLowStockNotifications(context),
        ),
        _HomeAppBarAction(
          icon: Icons.shopping_cart_outlined,
          onPressed: () => Navigator.pushNamed(context, '/sales'),
        ),
        const SizedBox(width: 2),
        CircleAvatar(
          radius: 21,
          backgroundColor: const Color(0xFF083982),
          child: IconButton(
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
            padding: EdgeInsets.zero,
          ),
        ),
      ],
    ),
  );
}

class _HomeAppBarAction extends StatelessWidget {
  const _HomeAppBarAction({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, color: Colors.white, size: 24),
  );
}

class _WelcomeBanner extends StatelessWidget {
  const _WelcomeBanner();

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 2),
    padding: const EdgeInsets.fromLTRB(17, 15, 13, 15),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(18),
      gradient: const LinearGradient(
        colors: [Color(0xFFDCEBFF), Color(0xFFF2F5FB), Color(0xFFFFEBD3)],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B192033),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Welcome Back!',
                  style: TextStyle(
                    color: ShopColors.primary,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Grow Your Business',
                style: TextStyle(
                  color: Color(0xFF333746),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 9),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .75),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Text(
                  'Store Online  •  Lusaka',
                  style: TextStyle(
                    color: ShopColors.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Container(
          height: 78,
          width: 94,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .75),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Color(0xFF5C9ED6),
            size: 54,
          ),
        ),
      ],
    ),
  );
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.iconBackground = const Color(0xFFF0F1F6),
    this.valueColor = ShopColors.text,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final Color iconBackground;
  final Color valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: 82,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
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
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 30),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF353746),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  style: TextStyle(
                    color: valueColor,
                    fontSize: 25,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: card,
      ),
    );
  }
}

class _StockAlert extends StatelessWidget {
  const _StockAlert({
    required this.title,
    required this.price,
    required this.count,
    required this.icon,
    required this.onRestock,
  });

  final String title;
  final String price;
  final String count;
  final IconData icon;
  final VoidCallback onRestock;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
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
          height: 54,
          width: 54,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F1F4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFF353535), size: 31),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Selling Price: '),
                    TextSpan(
                      text: price,
                      style: const TextStyle(
                        color: ShopColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ShopColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                count,
                style: const TextStyle(
                  color: ShopColors.red,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(height: 2),
            TextButton(
              onPressed: onRestock,
              style: TextButton.styleFrom(
                foregroundColor: ShopColors.primary,
                padding: EdgeInsets.zero,
                minimumSize: const Size(54, 24),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Restock',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _NewInventoryCard extends StatelessWidget {
  const _NewInventoryCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFECEEF2),
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 25,
              backgroundColor: ShopColors.primaryContainer,
              child: Icon(
                Icons.add_business_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'New Inventory Arrived?',
                    style: TextStyle(
                      color: ShopColors.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Tap to add incoming stock items',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: ShopColors.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 7),
            OutlinedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.add_rounded, size: 17),
              label: const Text(
                'Add',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShopColors.primary,
                backgroundColor: Colors.white,
                side: BorderSide.none,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeBottomNavigation extends StatelessWidget {
  const _HomeBottomNavigation({this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    final routes = <_HomeNavInfo>[
      _HomeNavInfo(icon: Icons.point_of_sale_outlined, label: 'Sales', route: '/sales'),
      _HomeNavInfo(icon: Icons.bar_chart_rounded, label: 'Reports', route: '/reports'),
    ];
    if (role != 'employee') {
      routes.insertAll(0, [
        _HomeNavInfo(icon: Icons.home_outlined, label: 'Home', route: '/home'),
        _HomeNavInfo(icon: Icons.inventory_2_outlined, label: 'Inventory', route: '/inventory'),
      ]);
      routes.add(_HomeNavInfo(icon: Icons.settings_outlined, label: 'Settings', route: '/settings'));
    }
    final selectedRoute = role == 'employee' ? '/sales' : '/home';
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x10192033),
            blurRadius: 12,
            offset: Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: routes
                .map(
                  (info) => _HomeNavItem(
                    icon: info.icon,
                    label: info.label,
                    route: info.route,
                    selected: info.route == selectedRoute,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _HomeNavInfo {
  const _HomeNavInfo({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}

class _HomeNavItem extends StatelessWidget {
  const _HomeNavItem({
    required this.icon,
    required this.label,
    this.route,
    this.selected = false,
  });

  final IconData icon;
  final String label;
  final String? route;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? ShopColors.primary : const Color(0xFF777A89);
    return Expanded(
      child: InkWell(
        onTap: route == null
            ? null
            : () => Navigator.pushNamedAndRemoveUntil(
                context,
                route!,
                (route) => route.isFirst,
              ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 23),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
