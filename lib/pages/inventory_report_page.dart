import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/shop_ui.dart';

/// Per-product inventory summary shown when a product card is tapped.
///
/// Opened with the product id as the route argument (`/inventory/report`).
class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({super.key});

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _errorMessage;
  String? _productId;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final arguments = ModalRoute.of(context)?.settings.arguments;
    // Two argument shapes are accepted: a bare product id (String), or the
    // full product map sent from the inventory card. With the map we can
    // render the whole report instantly, without waiting for the server
    // (which on a cold Render instance can take a minute to wake up).
    if (arguments is Map<String, dynamic> && arguments['id'] is String) {
      _productId = arguments['id'] as String;
      _products = [arguments];
      _loading = false;
      _refreshInBackground();
    } else {
      if (arguments is String && arguments.isNotEmpty) _productId = arguments;
      // Defer the first load until after the build phase so we never call
      // setState() from within didChangeDependencies (which caused a rebuild
      // loop / freeze).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  void _refreshInBackground() {
    // Best-effort refresh of an already-rendered report; failures are
    // ignored because the page is showing the passed-in data. It must not
    // touch _loading, and must never fire more than once per visit —
    // overlapping refreshes re-trigger layout of the whole page and feel
    // like a freeze while the (often cold) server responds.
    if (_refreshInFlight) return;
    _refreshInFlight = true;
    _load(silent: true).whenComplete(() => _refreshInFlight = false);
  }

  bool _refreshInFlight = false;

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }
    try {
      final products = await ApiClient.products();
      if (!mounted) return;
      if (silent) {
        final index = products.indexWhere((p) => p['id'] == _productId);
        if (index >= 0) {
          setState(() {
            _products = [products[index]];
          });
        }
        return;
      }
      setState(() {
        _products = products;
        _loading = false;
      });
    } on ApiException catch (error) {
      // A silent refresh must never blank out an already-rendered report.
      if (silent) return;
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _loading = false;
        });
      }
    }
  }

  Map<String, dynamic>? get _product {
    final id = _productId;
    if (id == null) return null;
    for (final product in _products) {
      if (product['id'] == id) return product;
    }
    return null;
  }

  String _str(Map<String, dynamic> json, String key) =>
      json[key] as String? ?? '';

  double _num(Map<String, dynamic> json, String key) =>
      (json[key] as num?)?.toDouble() ?? 0;

  int _int(Map<String, dynamic> json, String key) =>
      (json[key] as num?)?.toInt() ?? 0;

  String _money(num value) {
    final rounded = value.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${rounded < 0 ? '-' : ''}K$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      backgroundColor: ShopColors.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _ReportAppBar(title: _str(product ?? const {}, 'name')),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                  ? _ErrorState(message: _errorMessage!, onRetry: _load)
                  : product == null
                  ? const _ErrorState(
                      message: 'This product could not be found.',
                    )
                  : _buildReport(product),
            ),
            if (product != null) _BottomActions(product: product),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(Map<String, dynamic> product) {
    final name = _str(product, 'name');
    final mainCategory = _str(product, 'category').trim().isEmpty
        ? 'Uncategorized'
        : _str(product, 'category').trim();
    final subCategory = _str(product, 'sub_category').trim();
    final sku = _str(product, 'sku');
    final size = _str(product, 'size');
    final color = _str(product, 'color');
    final imageUrl = _str(product, 'image_url');
    final cost = _num(product, 'cost');
    final price = _num(product, 'price');
    final stock = _int(product, 'quantity');
    final margin = price - cost;
    final marginPercent = price > 0 ? margin / price * 100 : 0.0;
    final costValue = cost * stock;
    final retailValue = price * stock;
    final projectedProfit = retailValue - costValue;

    final low = stock > 0 && stock <= 5;
    final out = stock <= 0;
    final statusLabel = out ? 'Out of Stock' : (low ? 'Low Stock' : 'In Stock • Healthy');
    final statusColor = out
        ? ShopColors.red
        : (low ? ShopColors.orange : ShopColors.green);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        // Status + quick actions
        Row(
          children: [
            Flexible(
              child: _StatusChip(label: statusLabel, color: statusColor),
            ),
            const SizedBox(width: 8),
            const _InfoChip(label: 'POS Ready'),
            const Spacer(),
            _CircleAction(
              icon: Icons.share_outlined,
              onTap: () => showShopMessage(
                context,
                'Share is not available on this device.',
              ),
            ),
            const SizedBox(width: 8),
            _CircleAction(
              icon: Icons.edit_outlined,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Hero profile
        _HeroCard(
          name: name,
          imageUrl: imageUrl,
          category: mainCategory,
          subCategory: subCategory,
          sku: sku,
          price: price,
          cost: cost,
          margin: margin,
          marginPercent: marginPercent,
        ),
        const SizedBox(height: 16),
        const Text(
          'Inventory & Capital Valuation',
          style: TextStyle(
            color: ShopColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'ZMW Audit',
          style: TextStyle(color: ShopColors.muted, fontSize: 11),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.35,
          children: [
            _ValuationTile(
              label: 'Stock on Hand',
              value: '$stock',
              unit: 'pcs',
              icon: Icons.inventory_2_outlined,
              accent: ShopColors.primary,
              note: low ? 'Low stock — reorder soon' : 'Available to sell',
            ),
            _ValuationTile(
              label: 'Potential Revenue',
              value: _money(retailValue),
              icon: Icons.payments_outlined,
              accent: ShopColors.orange,
              note: '$stock × ${_money(price)} retail',
            ),
            _ValuationTile(
              label: 'Tied Capital (Cost)',
              value: _money(costValue),
              icon: Icons.account_balance_wallet_outlined,
              accent: ShopColors.muted,
              note: '$stock pcs × ${_money(cost)} cost',
            ),
            _ValuationTile(
              label: 'Projected Profit',
              value: _money(projectedProfit),
              icon: Icons.savings_outlined,
              accent: ShopColors.green,
              note: 'Gross upon complete sell',
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Stock by variant
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Stock by Variant',
                      style: TextStyle(
                        color: ShopColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ShopColors.pale,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '1 variant',
                      style: const TextStyle(
                        color: ShopColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: ShopColors.pale,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          size.isEmpty ? '—' : size,
                          style: const TextStyle(
                            color: ShopColors.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            color.isEmpty ? 'Default' : color,
                            style: const TextStyle(
                              color: ShopColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'SKU: ${sku.isEmpty ? '—' : sku}',
                            style: const TextStyle(
                              color: ShopColors.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$stock pcs',
                          style: TextStyle(
                            color: out
                                ? ShopColors.red
                                : (low ? ShopColors.orange : ShopColors.text),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReportAppBar extends StatelessWidget {
  const _ReportAppBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    padding: const EdgeInsets.symmetric(horizontal: 8),
    color: ShopColors.primaryContainer,
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 24,
          ),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            title.isEmpty ? 'Product Details' : title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/sales'),
          icon: const Icon(
            Icons.shopping_cart_outlined,
            color: Colors.white,
            size: 22,
          ),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 6),
        CircleAvatar(
          radius: 16,
          backgroundColor: ShopColors.primary,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
        ),
        const SizedBox(width: 6),
      ],
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: ShopColors.pale,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: ShopColors.muted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ShopColors.pale,
    shape: const CircleBorder(),
    child: InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: ShopColors.primaryContainer, size: 20),
      ),
    ),
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.subCategory,
    required this.sku,
    required this.price,
    required this.cost,
    required this.margin,
    required this.marginPercent,
  });

  final String name;
  final String imageUrl;
  final String category;
  final String subCategory;
  final String sku;
  final double price;
  final double cost;
  final double margin;
  final double marginPercent;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bounded height so the Expanded/Spacer inside the right-hand column
        // are legal. Unbounded (inside the scrollable) this crashed layout —
        // the "freeze" when opening the report.
        SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 112,
                height: 128,
                color: ShopColors.pale,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        // A plain Image.network can keep serving a stale
                        // cached (failed) response for an unchanged URL.
                        // A short cache-buster makes Flutter refetch once.
                        () {
                          final uri = Uri.parse(imageUrl);
                          return uri.replace(
                            queryParameters: {
                              ...uri.queryParameters,
                              'v': '2',
                            },
                          ).toString();
                        }(),
                        fit: BoxFit.cover,
                        width: 112,
                        height: 128,
                        cacheWidth: 224,
                        cacheHeight: 256,
                        frameBuilder: (context, child, frame, wasSync) =>
                            wasSync
                            ? child
                            : AnimatedOpacity(
                                opacity: frame == null ? 0 : 1,
                                duration: const Duration(milliseconds: 180),
                                child: child,
                              ),
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.inventory_2_outlined,
                          color: ShopColors.muted,
                          size: 44,
                        ),
                      )
                    : const Icon(
                        Icons.inventory_2_outlined,
                        color: ShopColors.muted,
                        size: 44,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: ShopColors.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      subCategory.isEmpty
                          ? category.toUpperCase()
                          : '${category.toUpperCase()} › ${subCategory.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShopColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: .4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'SKU: ${sku.isEmpty ? '—' : sku}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ShopColors.muted,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'RETAIL SELLING PRICE',
                    style: TextStyle(
                      color: ShopColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .5,
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        'K${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: ShopColors.primaryContainer,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Flexible(
                        child: Text(
                          '/ unit',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: ShopColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: ShopColors.pale,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Cost Price',
                      style: TextStyle(color: ShopColors.muted, fontSize: 12),
                    ),
                    Text(
                      'K${cost.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: ShopColors.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Profit Margin',
                    style: TextStyle(color: ShopColors.muted, fontSize: 12),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.trending_up_rounded,
                        color: ShopColors.green,
                        size: 17,
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          'K${margin.toStringAsFixed(2)} '
                          '(${marginPercent.toStringAsFixed(1)}%)',
                          style: const TextStyle(
                            color: ShopColors.green,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
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

class _ValuationTile extends StatelessWidget {
  const _ValuationTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.note,
    this.unit,
  });

  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color accent;
  final String note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(color: Color(0x0A192033), blurRadius: 5, offset: Offset(0, 2)),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ShopColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 15),
            ),
          ],
        ),
        const Spacer(),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: const TextStyle(
                    color: ShopColors.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          note,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ShopColors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: Color(0x0A192033), blurRadius: 5, offset: Offset(0, 2)),
      ],
    ),
    child: child,
  );
}

class _BottomActions extends StatelessWidget {
  const _BottomActions({required this.product});

  final Map<String, dynamic> product;

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(color: Color(0x14002E7B), blurRadius: 16, offset: Offset(0, -4)),
      ],
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => showShopMessage(
                    context,
                    'Open this product in the inventory list to adjust stock.',
                  ),
                  icon: const Icon(Icons.tune, size: 20),
                  label: const Text('Stock Count'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ShopColors.primaryContainer,
                    side: const BorderSide(color: ShopColors.outline),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SizedBox(
                height: 50,
                child: FilledButton.icon(
                  onPressed: () =>
                      Navigator.pushNamed(context, '/product/new'),
                  icon: const Icon(Icons.add_shopping_cart, size: 20),
                  label: const Text('Order Restock'),
                  style: FilledButton.styleFrom(
                    backgroundColor: ShopColors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: ShopColors.red,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ShopColors.text, fontSize: 13),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    ),
  );
}