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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final arguments = ModalRoute.of(context)?.settings.arguments;
    if (arguments is String && arguments.isNotEmpty) {
      _productId = arguments;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final products = await ApiClient.products();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } on ApiException catch (error) {
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

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      backgroundColor: ShopColors.surface,
      body: SafeArea(
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
                  : _buildReport(context, product),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(BuildContext context, Map<String, dynamic> product) {
    final name = _str(product, 'name');
    final mainCategory = _str(product, 'category').trim().isEmpty
        ? 'Uncategorized'
        : _str(product, 'category').trim();
    final subCategory = _str(product, 'sub_category').trim();
    final sku = _str(product, 'sku');
    final size = _str(product, 'size');
    final color = _str(product, 'color');
    final supplier = _str(product, 'supplier_name');
    final imageUrl = _str(product, 'image_url');
    final cost = _num(product, 'cost');
    final price = _num(product, 'price');
    final stock = _int(product, 'quantity');
    final margin = price - cost;
    final marginPercent = price > 0 ? margin / price * 100 : 0;
    final costValue = cost * stock;
    final retailValue = price * stock;

    final siblings = _products
        .where(
          (p) =>
              p['id'] != product['id'] &&
              _str(p, 'category').trim() == mainCategory &&
              (subCategory.isEmpty
                  ? _str(p, 'sub_category').trim().isEmpty
                  : _str(p, 'sub_category').trim() == subCategory),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeroCard(
          name: name,
          imageUrl: imageUrl,
          mainCategory: mainCategory,
          subCategory: subCategory,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'IN STOCK',
                value: '$stock',
                color: stock > 0 ? ShopColors.green : ShopColors.red,
                icon: Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'RETAIL PRICE',
                value: 'K${price.toStringAsFixed(0)}',
                color: ShopColors.primary,
                icon: Icons.sell_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'COST PRICE',
                value: 'K${cost.toStringAsFixed(0)}',
                color: ShopColors.text,
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _MetricTile(
                label: 'MARGIN / ITEM',
                value:
                    'K${margin.toStringAsFixed(0)} (${marginPercent.toStringAsFixed(0)}%)',
                color: ShopColors.green,
                icon: Icons.trending_up_rounded,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _ReportCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Stock Value',
                style: TextStyle(
                  color: ShopColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              _ValueRow(
                label: 'Value at cost',
                value: 'K${costValue.toStringAsFixed(0)}',
              ),
              _ValueRow(
                label: 'Value at retail',
                value: 'K${retailValue.toStringAsFixed(0)}',
              ),
              _ValueRow(
                label: 'Potential profit',
                value: 'K${(retailValue - costValue).toStringAsFixed(0)}',
                valueColor: ShopColors.green,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ReportCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Product Details',
                style: TextStyle(
                  color: ShopColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _ValueRow(label: 'Main category', value: mainCategory),
              _ValueRow(
                label: 'Sub category',
                value: subCategory.isEmpty ? '—' : subCategory,
              ),
              _ValueRow(label: 'SKU', value: sku.isEmpty ? '—' : sku),
              _ValueRow(label: 'Size', value: size.isEmpty ? '—' : size),
              _ValueRow(label: 'Color', value: color.isEmpty ? '—' : color),
              _ValueRow(
                label: 'Supplier',
                value: supplier.isEmpty ? '—' : supplier,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ReportCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                subCategory.isEmpty
                    ? 'Other products in $mainCategory'
                    : 'Other products in $subCategory',
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (siblings.isEmpty)
                const Text(
                  'No other products in this group.',
                  style: TextStyle(color: ShopColors.muted, fontSize: 12),
                )
              else
                for (final sibling in siblings)
                  _ValueRow(
                    label: _str(sibling, 'name'),
                    value: '${_int(sibling, 'quantity')} in stock',
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
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 10),
    color: ShopColors.primary,
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 23,
          ),
          visualDensity: VisualDensity.compact,
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Inventory Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ShopColors.paleBlue,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
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
      ],
    ),
  );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.name,
    required this.imageUrl,
    required this.mainCategory,
    required this.subCategory,
  });

  final String name;
  final String imageUrl;
  final String mainCategory;
  final String subCategory;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(color: Color(0x0A192033), blurRadius: 6, offset: Offset(0, 2)),
      ],
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 84,
            height: 84,
            color: ShopColors.pale,
            child: imageUrl.isNotEmpty
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.inventory_2_outlined,
                      color: ShopColors.muted,
                      size: 40,
                    ),
                  )
                : const Icon(
                    Icons.inventory_2_outlined,
                    color: ShopColors.muted,
                    size: 40,
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subCategory.isEmpty
                    ? mainCategory
                    : '$mainCategory › $subCategory',
                style: const TextStyle(
                  color: ShopColors.primary,
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

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: ShopColors.muted,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: .4,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [
        BoxShadow(color: Color(0x0A192033), blurRadius: 5, offset: Offset(0, 2)),
      ],
    ),
    child: child,
  );
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({
    required this.label,
    required this.value,
    this.valueColor = ShopColors.text,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ShopColors.muted, fontSize: 12),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
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