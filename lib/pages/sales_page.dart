import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/urban7_branding.dart';
import '../widgets/barcode_scanner.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  final _searchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _searchFocusNode = FocusNode();
  final _cartSectionKey = GlobalKey();
  final _scrollController = ScrollController();
  final Map<String, _CartLine> _cart = {};
  List<_SaleProduct> _products = [];
  String _paymentMethod = 'Cash';
  String _saleType = 'Walk-in';
  String _discountType = 'percent'; // 'percent' or 'value'
  double _laybyDeposit = 0;
  double _discountPercent = 0;
  double _discountValue = 0;
  bool _loading = true;
  bool _completing = false;
  String? _errorMessage;
  String? _pendingProductId;
  String _receiptCustomerName = '';

  int get _itemCount =>
      _cart.values.fold(0, (total, item) => total + item.quantity);
  double get _subtotal => _cart.entries.fold<double>(0, (total, item) {
    final product = _productForId(item.key);
    return total + product.price * item.value.quantity;
  });
  double get _discountAmount => _discountType == 'value'
      ? _discountValue.clamp(0, _subtotal)
      : (_subtotal * _discountPercent / 100);
  double get _total => _subtotal - _discountAmount;
  double get _cogs => _cart.entries.fold<double>(0, (total, item) {
    final product = _productForId(item.key);
    return total + product.cost * item.value.quantity;
  });
  double get _grossProfit => _subtotal - _cogs;
  double get _netProfit => _total - _cogs;
  double get _laybyBalance =>
      _paymentMethod == 'Layby' ? (_total - _laybyDeposit).clamp(0, _total) : 0;

  bool _argumentsLoadedAndStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argumentsLoadedAndStarted) {
      _argumentsLoadedAndStarted = true;
      final arguments = ModalRoute.of(context)?.settings.arguments;
      if (arguments is String && arguments.isNotEmpty) {
        _pendingProductId = arguments;
      }
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final products = await ApiClient.products();
      if (!mounted) return;
      setState(() {
        _products = products.map(_SaleProduct.fromJson).toList();
        _loading = false;
      });
      final pending = _pendingProductId;
      if (pending != null && mounted) {
        _pendingProductId = null;
        final exists = _products.any((product) => product.id == pending);
        if (exists) {
          _addToCart(pending);
          _scrollToCart();
        } else {
          showShopMessage(
            context,
            'Could not find that product to add to the cart.',
          );
        }
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _loading = false;
        });
      }
    }
  }

  _SaleProduct _productForId(String id) =>
      _products.firstWhere((product) => product.id == id);

  @override
  void dispose() {
    _searchController.dispose();
    _discountController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _scanProductBarcode() async {
    final code = await scanBarcode(context);
    if (code != null && mounted) {
      setState(() => _searchController.text = code);
    }
  }

  void _scrollToCart() {
    final target = _cartSectionKey.currentContext;
    if (target != null) {
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) => ShopScaffold(
    selectedIndex: 2,
    body: Column(
      children: [
        _SalesAppBar(
          onSearch: () => _searchFocusNode.requestFocus(),
          onCart: _scrollToCart,
        ),
        Expanded(
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 54,
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search products or scan barcode',
                          hintStyle: const TextStyle(
                            color: Color(0xFF777A89),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: Color(0xFF777A89),
                            size: 23,
                          ),
                          suffixIcon: IconButton(
                            tooltip: 'Scan barcode',
                            onPressed: _scanProductBarcode,
                            icon: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: ShopColors.primary,
                              size: 22,
                            ),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(30),
                            borderSide: const BorderSide(
                              color: ShopColors.primary,
                              width: 1.4,
                            ),
                          ),
                        ),
                        focusNode: _searchFocusNode,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    child: IconButton(
                      tooltip: 'Clear cart',
                      onPressed: () => setState(_cart.clear),
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: ShopColors.red,
                        size: 23,
                      ),
                      style: IconButton.styleFrom(
                        fixedSize: const Size(52, 52),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else if (_errorMessage != null)
                Column(
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loadProducts,
                      child: const Text('Try again'),
                    ),
                  ],
                )
              else if (_searchController.text.trim().isNotEmpty)
                ..._products
                    .where((product) {
                      final query = _searchController.text.trim().toLowerCase();
                      return product.name.toLowerCase().contains(query) ||
                          product.sku.toLowerCase().contains(query);
                    })
                    .map(
                      (product) => ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: Container(
                            width: 46,
                            height: 46,
                            color: const Color(0xFFF0EDE7),
                            child: product.imageUrl.isNotEmpty
                                ? Image.network(
                                    product.imageUrl,
                                    fit: BoxFit.cover,
                                    width: 46,
                                    height: 46,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                      product.icon,
                                      color: ShopColors.text,
                                      size: 30,
                                    ),
                                  )
                                : Icon(
                                    product.icon,
                                    color: ShopColors.text,
                                    size: 30,
                                  ),
                          ),
                        ),
                        title: Text(product.name),
                        subtitle: Text(
                          'K${product.price} · Stock: ${product.stock}',
                        ),
                        trailing: IconButton(
                          onPressed: () => _addToCart(product.id),
                          icon: const Icon(Icons.add_shopping_cart_rounded),
                        ),
                      ),
                    ),
              KeyedSubtree(
                key: _cartSectionKey,
                child: Column(
                  children: [
                    if (_cart.isEmpty) const _EmptyCart(),
                    ..._cart.entries.map((item) {
                      final product = _productForId(item.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 9),
                        child: _CartItem(
                          name: product.name,
                          price: product.price.round(),
                          stock: product.stock,
                          quantity: item.value.quantity,
                          size: item.value.size,
                          color: item.value.color,
                          imageUrl: product.imageUrl,
                          icon: product.icon,
                          onDecrease: () => _changeQuantity(item.key, -1),
                          onIncrease: () => _changeQuantity(item.key, 1),
                          onOptions: () => _editOptions(item.key, item.value),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              _StaplesStrip(products: _products, onAdd: _addToCart),
              const SizedBox(height: 18),
              _OrderSummary(
                itemCount: _itemCount,
                subtotal: _subtotal,
                discountType: _discountType,
                discountPercent: _discountPercent,
                discountValue: _discountValue,
                discountAmount: _discountAmount,
                total: _total,
                cogs: _cogs,
                grossProfit: _grossProfit,
                netProfit: _netProfit,
                paymentMethod: _paymentMethod,
                saleType: _saleType,
                customerName: _receiptCustomerName,
                discountController: _discountController,
                onDiscountChanged: (type, value) {
                  setState(() {
                    if (type == 'value') {
                      _discountValue = (double.tryParse(value) ?? 0).clamp(
                        0,
                        _subtotal.toDouble(),
                      );
                    } else {
                      _discountPercent = (double.tryParse(value) ?? 0).clamp(
                        0,
                        100,
                      );
                    }
                  });
                },
                onDiscountTypeChanged: (type) =>
                    setState(() => _discountType = type),
                onSaleTypeChanged: (type) =>
                    setState(() => _saleType = type),
                onCustomerNameChanged: (name) =>
                    _receiptCustomerName = name,
                onPaymentChanged: (method) =>
                    setState(() => _paymentMethod = method),
                laybyBalance: _laybyBalance,
                onSetLaybyDeposit: (deposit) =>
                    setState(() => _laybyDeposit = deposit),
                onComplete: _itemCount == 0 || _completing || _loading
                    ? null
                    : _completeSale,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  void _changeQuantity(String name, int delta) {
    setState(() {
      final line = _cart[name];
      if (line == null) return;
      final next = line.quantity + delta;
      if (next <= 0) {
        _cart.remove(name);
      } else if (next <= _productForId(name).stock) {
        _cart[name] = line.copyWith(quantity: next);
      } else {
        showShopMessage(
          context,
          'There is not enough stock for this quantity.',
        );
      }
    });
  }

  void _addToCart(String productId) {
    final product = _productForId(productId);
    if (product.stock == 0) {
      showShopMessage(context, '${product.name} is out of stock.');
      return;
    }
    final line = _cart[productId] ?? const _CartLine(quantity: 0);
    if (line.quantity >= product.stock) {
      showShopMessage(context, 'There is not enough stock for this quantity.');
      return;
    }
    setState(() {
      _cart[productId] = line.copyWith(quantity: line.quantity + 1);
    });
    showShopMessage(context, '${product.name} added to cart.');
  }

  Future<void> _editOptions(String productId, _CartLine line) async {
    final options = await showDialog<_ProductOptions>(
      context: context,
      builder: (context) => _ProductOptionsDialog(
        initialSize: line.size,
        initialColor: line.color,
      ),
    );
    if (options == null || !mounted) return;
    setState(() {
      _cart[productId] = line.copyWith(
        size: options.size,
        color: options.color,
      );
    });
  }

  Future<void> _completeSale() async {
    String customerName = _receiptCustomerName.trim();
    String customerPhone = '';
    if (_paymentMethod == 'Layby') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => _LaybyConfirmDialog(
          deposit: _laybyDeposit,
          balance: _laybyBalance,
        ),
      );
      if (confirmed != true || !mounted) return;
      customerName = _LaybyConfirmDialog.lastNameEntered ?? '';
      customerPhone = _LaybyConfirmDialog.lastPhoneEntered ?? '';
      _LaybyConfirmDialog.lastNameEntered = null;
      _LaybyConfirmDialog.lastPhoneEntered = null;
    }
    setState(() {
      _completing = true;
      _errorMessage = null;
    });
    try {
      final result = await ApiClient.createSale({
        'discount_percent': _discountPercent,
        'discount_type': _discountType,
        'discount_value': _discountValue,
        'payment_method': _paymentMethod,
        'sale_type': _saleType,
        if (_paymentMethod == 'Layby') 'layby_deposit': _laybyDeposit.round(),
        'customer_name': customerName,
        if (_paymentMethod == 'Layby') 'customer_phone': customerPhone,
        'items': _cart.entries
            .map(
              (item) => {
                'product_id': item.key,
                'quantity': item.value.quantity,
                'size': item.value.size,
                'color': item.value.color,
              },
            )
            .toList(),
      });
      if (!mounted) return;
      // ReportsPage refreshes itself via didPopNext when the user returns,
      // so no synchronous refresh is needed here (it blocked navigation).
      if (mounted) setState(() => _cart.clear());
      Navigator.pushNamed(
        context,
        '/sale/success',
        arguments: {
          'subtotal': _parseMoney(result['subtotal']),
          'discount': _parseMoney(result['discount']),
          'total': _parseMoney(result['total']),
          'paymentMethod': _paymentMethod,
          'saleType': _saleType,
          'customerName': customerName,
          'itemCount': _itemCount,
          'items': _cart.entries.map((item) {
            final product = _productForId(item.key);
            return {
              'name': product.name,
              'quantity': item.value.quantity,
              'size': item.value.size,
              'color': item.value.color,
              'unitPrice': product.price.round(),
            };
          }).toList(),
        },
      );
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }
}

/// Safely converts a Postgres numeric value (may be a String like "40.00"
/// or already a num) to a double.  Returns 0.0 for null / unparseable values.
double _parseMoney(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return num.tryParse(value.toString())?.toDouble() ?? 0.0;
}

class _SaleProduct {
  const _SaleProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.sku,
    required this.price,
    required this.cost,
    required this.stock,
    required this.imageUrl,
    required this.icon,
  });

  factory _SaleProduct.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final category = (json['category'] as String? ?? '').toLowerCase();
    return _SaleProduct(
      id: json['id'] as String,
      name: name,
      category: category,
      sku: json['sku'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      stock: (json['quantity'] as num?)?.toInt() ?? 0,
      imageUrl: json['image_url'] as String? ?? '',
      icon: category.contains('footwear')
          ? Icons.directions_run_rounded
          : category.contains('trouser')
          ? Icons.straighten_rounded
          : category.contains('hoodie') || category.contains('jacket')
          ? Icons.hiking_rounded
          : Icons.checkroom_rounded,
    );
  }

  final String id;
  final String name;
  final String category;
  final String sku;
  final double price;
  final double cost;
  final int stock;
  final String imageUrl;
  final IconData icon;
}

class _CartLine {
  const _CartLine({this.quantity = 1, this.size = 'M', this.color = 'Black'});

  final int quantity;
  final String size;
  final String color;

  _CartLine copyWith({int? quantity, String? size, String? color}) => _CartLine(
    quantity: quantity ?? this.quantity,
    size: size ?? this.size,
    color: color ?? this.color,
  );
}

class _ProductOptions {
  const _ProductOptions({required this.size, required this.color});

  final String size;
  final String color;
}

class _SalesAppBar extends StatelessWidget {
  const _SalesAppBar({required this.onSearch, required this.onCart});

  final VoidCallback onSearch;
  final VoidCallback onCart;

  static const _blue = Color(0xFF194AA2);

  @override
  Widget build(BuildContext context) => Container(
    height: 82,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    color: _blue,
    child: Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(2),
          ),
          child: const Icon(Icons.checkroom_outlined, color: _blue, size: 26),
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
                'Sales',
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
        _AppBarAction(icon: Icons.search_rounded, onPressed: onSearch),
        _AppBarAction(icon: Icons.shopping_cart_outlined, onPressed: onCart),
        const SizedBox(width: 3),
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

class _AppBarAction extends StatelessWidget {
  const _AppBarAction({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, color: Colors.white, size: 24),
  );
}

class _CartItem extends StatelessWidget {
  const _CartItem({
    required this.name,
    required this.price,
    required this.stock,
    required this.quantity,
    required this.size,
    required this.color,
    required this.imageUrl,
    required this.icon,
    required this.onDecrease,
    required this.onIncrease,
    required this.onOptions,
  });

  final String name;
  final int price;
  final int stock;
  final int quantity;
  final String size;
  final String color;
  final String imageUrl;
  final IconData icon;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;
  final VoidCallback onOptions;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B192033),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58,
          height: 58,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: name.contains('Hoodie')
                ? const Color(0xFFE7E6E7)
                : const Color(0xFFF0EDE7),
            borderRadius: BorderRadius.circular(11),
          ),
          child: imageUrl.isNotEmpty
              ? Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: 58,
                  height: 58,
                  errorBuilder: (context, error, stackTrace) =>
                      Icon(icon, color: ShopColors.text, size: 39),
                )
              : Icon(icon, color: ShopColors.text, size: 39),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.text,
                ),
              ),
              Text(
                'K$price / unit',
                style: const TextStyle(
                  color: ShopColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Flexible(
                    child: OutlinedButton.icon(
                      key: Key('options-$name'),
                      onPressed: onOptions,
                      icon: const Icon(Icons.tune_rounded, size: 14),
                      label: Text(
                        '$size · $color',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ShopColors.primary,
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(color: ShopColors.outline),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _QuantityControl(
                    quantity: quantity,
                    onDecrease: onDecrease,
                    onIncrease: onIncrease,
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                'In stock: $stock',
                style: const TextStyle(
                  color: ShopColors.green,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ProductOptionsDialog extends StatefulWidget {
  const _ProductOptionsDialog({
    required this.initialSize,
    required this.initialColor,
  });

  final String initialSize;
  final String initialColor;

  @override
  State<_ProductOptionsDialog> createState() => _ProductOptionsDialogState();
}

class _ProductOptionsDialogState extends State<_ProductOptionsDialog> {
  late String _size = widget.initialSize;
  late String _color = widget.initialColor;

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Product options',
    icon: Icons.tune_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Size',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('saleSizeDropdown'),
          initialValue: _size,
          isExpanded: true,
          items: const [...Urban7.letterSizes, ...Urban7.numericSizes]
                  .map(
                    (size) => DropdownMenuItem(value: size, child: Text(size)),
                  )
                  .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _size = value);
          },
        ),
        const SizedBox(height: 14),
        const Text(
          'Color',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          key: const Key('saleColorDropdown'),
          initialValue: _color,
          isExpanded: true,
          items: const ['Black', 'White', 'Cobalt Blue', 'Crimson Red']
              .map(
                (color) => DropdownMenuItem(value: color, child: Text(color)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _color = value);
          },
        ),
      ],
    ),
    footer: ShopPopupActions(
      confirmLabel: 'Save options',
      onCancel: () => Navigator.pop(context),
      onConfirm: () =>
          Navigator.pop(context, _ProductOptions(size: _size, color: _color)),
    ),
  );
}

class _QuantityControl extends StatelessWidget {
  const _QuantityControl({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  @override
  Widget build(BuildContext context) => Container(
    height: 36,
    decoration: BoxDecoration(
      color: const Color(0xFFF0F1F4),
      border: Border.all(color: const Color(0xFFE6E8ED), width: 1.5),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _QuantityAction(icon: Icons.remove_rounded, onPressed: onDecrease),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: Text(
            '$quantity',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
        ),
        _QuantityAction(icon: Icons.add_rounded, onPressed: onIncrease),
      ],
    ),
  );
}

class _QuantityAction extends StatelessWidget {
  const _QuantityAction({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 29,
    height: 34,
    child: IconButton(
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      icon: Icon(icon, color: ShopColors.primary, size: 18),
    ),
  );
}

class _StaplesStrip extends StatelessWidget {
  const _StaplesStrip({required this.products, required this.onAdd});

  final List<_SaleProduct> products;
  final ValueChanged<String> onAdd;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(9, 8, 9, 10),
    decoration: BoxDecoration(
      color: const Color(0xFFF0F1F6),
      borderRadius: BorderRadius.circular(17),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'FAST ADD STAPLES',
                style: TextStyle(
                  color: Color(0xFF777A89),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .3,
                ),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pushNamed(context, '/inventory'),
              child: const Row(
                children: [
                  Text(
                    'Catalog',
                    style: TextStyle(
                      color: ShopColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(width: 3),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: ShopColors.primary,
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: products
                .take(5)
                .map(
                  (product) => Padding(
                    padding: const EdgeInsets.only(right: 7),
                    child: _StapleChip(
                      label:
                          '${product.name} (K${product.price.toStringAsFixed(0)})',
                      onTap: () => onAdd(product.id),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    ),
  );
}

class _StapleChip extends StatelessWidget {
  const _StapleChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(30),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        child: Row(
          children: [
            const Icon(
              Icons.add_circle_outline,
              color: Color(0xFFB63F00),
              size: 17,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({
    required this.itemCount,
    required this.subtotal,
    required this.discountType,
    required this.discountPercent,
    required this.discountValue,
    required this.discountAmount,
    required this.total,
    required this.discountController,
    required this.onDiscountChanged,
    required this.onDiscountTypeChanged,
    required this.onSaleTypeChanged,
    required this.onCustomerNameChanged,
    required this.paymentMethod,
    required this.saleType,
    required this.customerName,
    required this.cogs,
    required this.grossProfit,
    required this.netProfit,
    required this.onPaymentChanged,
    required this.onComplete,
    this.laybyBalance = 0,
    this.onSetLaybyDeposit,
  });

  final int itemCount;
  final double subtotal;
  final String discountType;
  final double discountPercent;
  final double discountValue;
  final double discountAmount;
  final double total;
  final TextEditingController discountController;
  final void Function(String type, String value) onDiscountChanged;
  final ValueChanged<String> onDiscountTypeChanged;
  final ValueChanged<String> onSaleTypeChanged;
  final ValueChanged<String> onCustomerNameChanged;
  final String paymentMethod;
  final String saleType;
  final String customerName;
  final double cogs;
  final double grossProfit;
  final double netProfit;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback? onComplete;
  final double laybyBalance;
  final ValueChanged<double>? onSetLaybyDeposit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D192033),
          blurRadius: 24,
          offset: Offset(-4, 8),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sale Channel / Type selector
        const Text(
          'SALE CHANNEL / TYPE',
          style: TextStyle(
            color: ShopColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: .6,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _ChannelToggle(
                icon: Icons.storefront_outlined,
                label: 'Walk-in Store Sale',
                selected: saleType == 'Walk-in',
                onTap: () => onSaleTypeChanged('Walk-in'),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _ChannelToggle(
                icon: Icons.public_rounded,
                label: 'Online / Remote',
                selected: saleType == 'Online',
                onTap: () => onSaleTypeChanged('Online'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Customer Name Input
        const Row(
          children: [
            Expanded(
              child: Text(
                'Customer Name (for Receipt)',
                style: TextStyle(
                  color: ShopColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'Optional',
              style: TextStyle(color: ShopColors.outline, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        TextField(
          key: const Key('receiptCustomerNameField'),
          onChanged: onCustomerNameChanged,
          decoration: InputDecoration(
            hintText: 'e.g. Kondwani Mwape (Optional)',
            hintStyle: const TextStyle(color: ShopColors.outline, fontSize: 14),
            prefixIcon: const Icon(
              Icons.person_outline_rounded,
              size: 20,
              color: ShopColors.outline,
            ),
            isDense: true,
            filled: true,
            fillColor: ShopColors.pale,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: ShopColors.outline.withValues(alpha: .4)),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: ShopColors.outline.withValues(alpha: .4)),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Discount card
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ShopColors.pale.withValues(alpha: .7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: ShopColors.outline.withValues(alpha: .55)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(Icons.sell_outlined, size: 16, color: ShopColors.orange),
                        SizedBox(width: 4),
                        Text(
                          'Apply Discount',
                          style: TextStyle(
                            color: ShopColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: ShopColors.pale,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _DiscountTypeToggle(
                          label: 'Percentage (%)',
                          selected: discountType == 'percent',
                          onTap: () => onDiscountTypeChanged('percent'),
                        ),
                        _DiscountTypeToggle(
                          label: 'Fixed (K)',
                          selected: discountType == 'value',
                          onTap: () => onDiscountTypeChanged('value'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: ShopColors.outline.withValues(alpha: .4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            discountType == 'value' ? 'K' : '%',
                            style: const TextStyle(
                              color: ShopColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: TextField(
                              key: const Key('discountPercentField'),
                              controller: discountController,
                              onChanged: (value) =>
                                  onDiscountChanged(discountType, value),
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: const InputDecoration(
                                hintText: '0',
                                border: InputBorder.none,
                                isDense: true,
                              ),
                            ),
                          ),
                          Text(
                            discountType == 'value' ? 'K off' : '% off',
                            style: const TextStyle(
                              color: ShopColors.outline,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ShopColors.primary,
                        backgroundColor: ShopColors.pale,
                        textStyle: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        side: BorderSide.none,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                      ),
                      child: const Text('Apply'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Order Totals Breakdown
        Container(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Subtotal ($itemCount items)',
                      style: const TextStyle(color: ShopColors.outline, fontSize: 12),
                    ),
                  ),
                  Text(
                    'K${subtotal.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.discount_outlined, size: 15, color: ShopColors.green),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      discountType == 'value'
                          ? 'Discount (K${discountValue.toStringAsFixed(discountValue % 1 == 0 ? 0 : 2)})'
                          : 'Discount (${discountPercent.toStringAsFixed(discountPercent % 1 == 0 ? 0 : 2)}%)',
                      style: const TextStyle(
                        color: ShopColors.green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '-K${discountAmount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ShopColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(height: 1, color: Color(0xFFC4C6D4)),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TOTAL DUE',
                          style: TextStyle(
                            color: ShopColors.outline,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .6,
                          ),
                        ),
                        Text(
                          'Tax Inclusive',
                          style: TextStyle(
                            color: ShopColors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'K${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ShopColors.primary,
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Profit insight card
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: ShopColors.pale,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: ShopColors.outline.withValues(alpha: .4),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Cost of Goods (COGS):',
                      style: TextStyle(
                        color: ShopColors.outline,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'K${cogs.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Gross Profit:',
                      style: TextStyle(
                        color: ShopColors.outline,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'K${grossProfit.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: ShopColors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Divider(
                height: 1,
                color: Color(0xFFC4C6D4),
              ),
              const SizedBox(height: 7),
              Row(
                children: [
                  const Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.trending_up_rounded,
                          size: 15,
                          color: ShopColors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Est. Net Profit',
                          style: TextStyle(
                            color: ShopColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: ShopColors.greenPale,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      'Net Profit: K${netProfit.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: ShopColors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Payment Method
        const Text(
          'Payment Method',
          style: TextStyle(
            color: ShopColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            Expanded(
              child: _PaymentOption(
                label: 'Cash',
                icon: Icons.payments_outlined,
                selected: paymentMethod == 'Cash',
                onTap: () => onPaymentChanged('Cash'),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _PaymentOption(
                label: 'Airtel / MTN',
                icon: Icons.smartphone_rounded,
                selected: paymentMethod == 'Airtel / MTN',
                onTap: () => onPaymentChanged('Airtel / MTN'),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _PaymentOption(
                label: 'Card POS',
                icon: Icons.credit_card_outlined,
                selected: paymentMethod == 'Card POS',
                onTap: () => onPaymentChanged('Card POS'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        _PaymentOption(
          label: 'Layby (pay deposit now, balance later)',
          icon: Icons.schedule_rounded,
          selected: paymentMethod == 'Layby',
          onTap: () => onPaymentChanged('Layby'),
        ),
        if (paymentMethod == 'Layby' && onSetLaybyDeposit != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (value) => onSetLaybyDeposit!(
                    double.tryParse(value) ?? 0,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Deposit paid now (K)',
                    prefixText: 'K',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Balance owed',
                    style: TextStyle(color: ShopColors.muted, fontSize: 11),
                  ),
                  Text(
                    'K$laybyBalance',
                    style: const TextStyle(
                      color: ShopColors.red,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          height: 53,
          child: FilledButton.icon(
            onPressed: onComplete,
            icon: const Icon(Icons.receipt_long_rounded, size: 20),
            label: Text(
              'Complete Sale (K$total)',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: ShopColors.orange,
              foregroundColor: Colors.white,
              elevation: 3,
              shadowColor: ShopColors.orange.withValues(alpha: .28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        const Row(
          children: [
            Icon(Icons.verified_outlined, color: ShopColors.green, size: 15),
            SizedBox(width: 5),
            Expanded(
              child: Text(
                'Instant Local Receipt',
                style: TextStyle(color: Color(0xFF777A89), fontSize: 11),
              ),
            ),
            Text(
              'Secure checkout',
              style: TextStyle(color: Color(0xFF777A89), fontSize: 11),
            ),
          ],
        ),
      ],
    ),
  );
}

/// Confirmation dialog for a layby sale.
///
/// Owns its own text controllers and disposes them in `dispose()`. The old
/// version disposed them immediately after `showDialog` returned, i.e. while
/// the dialog's pop animation was still rebuilding its TextFields — which
/// threw "used after being disposed" every time Cancel or Confirm was tapped
/// and froze the app on the modal barrier.
class _ChannelToggle extends StatelessWidget {
  const _ChannelToggle({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? ShopColors.primaryContainer : ShopColors.pale,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        height: 42,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 17,
              color: selected ? Colors.white : ShopColors.outline,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? Colors.white : ShopColors.text,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _DiscountTypeToggle extends StatelessWidget {
  const _DiscountTypeToggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(5),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(5),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x14192033),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          color: selected ? ShopColors.primary : ShopColors.outline,
        ),
      ),
    ),
  );
}

class _LaybyConfirmDialog extends StatefulWidget {
  const _LaybyConfirmDialog({required this.deposit, required this.balance});

  final double deposit;
  final double balance;

  static String? lastNameEntered;
  static String? lastPhoneEntered;

  @override
  State<_LaybyConfirmDialog> createState() => _LaybyConfirmDialogState();
}

class _LaybyConfirmDialogState extends State<_LaybyConfirmDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Confirm layby sale',
    icon: Icons.handshake_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: ShopColors.paleBlue.withValues(alpha: .45),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Deposit',
                      style: TextStyle(fontSize: 11, color: ShopColors.muted),
                    ),
                    Text(
                      'K${widget.deposit}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDBCC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Balance owed',
                      style: TextStyle(fontSize: 11, color: ShopColors.muted),
                    ),
                    Text(
                      'K${widget.balance}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _nameController,
          decoration: shopFieldDecoration(
            'Customer name *',
            icon: Icons.person_outline_rounded,
          ),
          autofocus: true,
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _phoneController,
          decoration: shopFieldDecoration(
            'Customer phone',
            icon: Icons.phone_outlined,
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    ),
    footer: ShopPopupActions(
      confirmLabel: 'Confirm layby',
      onCancel: () => Navigator.pop(context, false),
      onConfirm: () {
        if (_nameController.text.trim().isEmpty) {
          showShopMessage(context, 'Enter the customer name.');
          return;
        }
        _LaybyConfirmDialog.lastNameEntered = _nameController.text.trim();
        _LaybyConfirmDialog.lastPhoneEntered = _phoneController.text.trim();
        Navigator.pop(context, true);
      },
    ),
  );
}

class _PaymentOption extends StatelessWidget {
  const _PaymentOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? const Color(0xFF194AA2) : const Color(0xFFEFF0F3),
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        height: 55,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : ShopColors.text,
              size: 20,
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : ShopColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
    ),
    child: const Text(
      'Your cart is empty. Add a product to begin.',
      textAlign: TextAlign.center,
      style: TextStyle(color: ShopColors.muted, fontSize: 13),
    ),
  );
}

