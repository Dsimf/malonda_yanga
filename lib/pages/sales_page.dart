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
  int get _subtotal => _cart.entries.fold<int>(0, (total, item) {
    final product = _productForId(item.key);
    return total + ((product.price * item.value.quantity).round());
  });
  int get _discountAmount => _discountType == 'value'
      ? _discountValue.round().clamp(0, _subtotal)
      : (_subtotal * _discountPercent / 100).round();
  int get _total => _subtotal - _discountAmount;
  int get _laybyBalance =>
      _paymentMethod == 'Layby' ? (_total - _laybyDeposit.round()).clamp(0, _total) : 0;

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
          deposit: _laybyDeposit.round(),
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
      Navigator.pushNamed(
        context,
        '/sale/success',
        arguments: {
          'subtotal': (result['subtotal'] as num?)?.round() ?? 0,
          'discount': (result['discount'] as num?)?.round() ?? 0,
          'total': (result['total'] as num?)?.round() ?? 0,
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

class _SaleProduct {
  const _SaleProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.sku,
    required this.price,
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
    required this.onPaymentChanged,
    required this.onComplete,
    this.laybyBalance = 0,
    this.onSetLaybyDeposit,
  });

  final int itemCount;
  final int subtotal;
  final String discountType;
  final double discountPercent;
  final double discountValue;
  final int discountAmount;
  final int total;
  final TextEditingController discountController;
  final void Function(String type, String value) onDiscountChanged;
  final ValueChanged<String> onDiscountTypeChanged;
  final ValueChanged<String> onSaleTypeChanged;
  final ValueChanged<String> onCustomerNameChanged;
  final String paymentMethod;
  final String saleType;
  final String customerName;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback? onComplete;
  final int laybyBalance;
  final ValueChanged<double>? onSetLaybyDeposit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D192033),
          blurRadius: 20,
          offset: Offset(0, 7),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ORDER SUMMARY',
                    style: TextStyle(
                      color: Color(0xFF777A89),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Total Items: $itemCount',
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'TOTAL DUE',
                  style: TextStyle(
                    color: Color(0xFF777A89),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                  ),
                ),
                Text(
                  'K$total',
                  style: const TextStyle(
                    color: ShopColors.primary,
                    fontSize: 28,
                    height: 1.05,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 13),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Sale Type',
                style: TextStyle(
                  color: ShopColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: DropdownButtonFormField<String>(
                key: const Key('saleTypeDropdown'),
                initialValue: saleType,
                isExpanded: true,
                items: Urban7.saleTypes
                    .map(
                      (type) => DropdownMenuItem(value: type, child: Text(type)),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onSaleTypeChanged(value);
                },
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: ShopColors.pale,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('receiptCustomerNameField'),
          onChanged: onCustomerNameChanged,
          decoration: InputDecoration(
            labelText: 'Customer name on receipt (optional)',
            hintText: 'Appears on the receipt',
            prefixIcon: const Icon(
              Icons.receipt_long_rounded,
              size: 19,
              color: ShopColors.primary,
            ),
            isDense: true,
            filled: true,
            fillColor: ShopColors.pale,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Discount',
                style: TextStyle(
                  color: ShopColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(
              width: 132,
              height: 42,
              child: DropdownButtonFormField<String>(
                key: const Key('discountTypeDropdown'),
                initialValue: discountType == 'value'
                    ? 'Kwacha Value (K)'
                    : 'Percentage (%)',
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'Percentage (%)', child: Text('Percentage (%)')),
                  DropdownMenuItem(value: 'Kwacha Value (K)', child: Text('Kwacha Value (K)')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  onDiscountTypeChanged(
                    value == 'Kwacha Value (K)' ? 'value' : 'percent',
                  );
                },
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: ShopColors.pale,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 104,
              height: 42,
              child: TextField(
                key: const Key('discountPercentField'),
                controller: discountController,
                onChanged: (value) => onDiscountChanged(discountType, value),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textAlign: TextAlign.end,
                decoration: InputDecoration(
                  suffixText: discountType == 'value' ? 'K' : '%',
                  hintText: '0',
                  filled: true,
                  fillColor: ShopColors.pale,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Subtotal',
                style: TextStyle(color: ShopColors.muted, fontSize: 12),
              ),
            ),
            Text(
              'K$subtotal',
              style: const TextStyle(color: ShopColors.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                discountType == 'value'
                    ? 'Discount (K${discountValue.toStringAsFixed(discountValue % 1 == 0 ? 0 : 2)})'
                    : 'Discount (${discountPercent.toStringAsFixed(discountPercent % 1 == 0 ? 0 : 2)}%)',
                style: const TextStyle(color: ShopColors.green, fontSize: 12),
              ),
            ),
            Text(
              '-K$discountAmount',
              style: const TextStyle(
                color: ShopColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const Divider(height: 17),
        const SizedBox(height: 16),
        const Text(
          'Payment Method',
          style: TextStyle(
            color: ShopColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
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
            const SizedBox(width: 5),
            Expanded(
              child: _PaymentOption(
                label: 'Airtel / MTN',
                icon: Icons.phone_iphone_rounded,
                selected: paymentMethod == 'Airtel / MTN',
                onTap: () => onPaymentChanged('Airtel / MTN'),
              ),
            ),
            const SizedBox(width: 5),
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
        const SizedBox(height: 7),
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
class _LaybyConfirmDialog extends StatefulWidget {
  const _LaybyConfirmDialog({required this.deposit, required this.balance});

  final int deposit;
  final int balance;

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

