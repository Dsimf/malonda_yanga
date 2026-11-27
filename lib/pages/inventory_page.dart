import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_client.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

class InventoryPage extends StatefulWidget {
  const InventoryPage({super.key});

  @override
  State<InventoryPage> createState() => _InventoryPageState();
}

class _InventoryPageState extends State<InventoryPage> with RouteAware {
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();
  String _category = 'All Items';
  String _subCategory = 'All';
  String _query = '';
  List<_Product> _products = [];
  bool _loading = true;
  String? _errorMessage;

  /// Main categories currently expanded in the grouped (All Items) view.
  final Set<String> _expanded = {};

  String _mainCategoryOf(_Product product) =>
      product.category.trim().isEmpty ? 'Uncategorized' : product.category.trim();

  List<String> get _mainCategories {
    final categories = _products.map(_mainCategoryOf).toSet().toList();
    categories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return categories;
  }

  List<String> _subCategoriesFor(String mainCategory) {
    final subCategories = _products
        .where(
          (product) =>
              _mainCategoryOf(product) == mainCategory &&
              product.subCategory.trim().isNotEmpty,
        )
        .map((product) => product.subCategory.trim())
        .toSet()
        .toList();
    subCategories.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return subCategories;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ApiClient.isEmployee) {
        Navigator.pushNamedAndRemoveUntil(context, '/sales', (route) => false);
      }
    });
    _loadProducts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void didPopNext() {
    // Page became visible again (e.g. after completing a sale),
    // so refresh stock counts to reflect the latest quantities.
    _loadProducts();
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
        _products = products.map(_Product.fromJson).toList();
        _loading = false;
        if (_expanded.isEmpty) {
          final categories = _mainCategories;
          if (categories.isNotEmpty) _expanded.add(categories.first);
        }
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

  Future<void> _editProduct(_Product product) async {
    final result = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (_) => _EditProductDialog(product: product),
    );
    if (result == null || !mounted) return;
    final photo = result.remove('_photo') as XFile?;
    try {
      await ApiClient.updateProduct(product.id, result);
      if (photo != null) {
        await ApiClient.uploadProductImage(
          product.id,
          contentType: photo.mimeType ?? 'image/jpeg',
          imageBase64: base64Encode(await photo.readAsBytes()),
        );
      }
      if (mounted) await _loadProducts();
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _deleteProduct(_Product product) async {
    final confirmed = await showShopConfirm(
      context: context,
      title: 'Delete product',
      message:
          'Are you sure you want to delete "${product.name}"? This cannot be undone.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await ApiClient.deleteProduct(product.id);
      if (mounted) {
        showShopMessage(context, '"${product.name}" deleted.');
        await _loadProducts();
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _showLowStockProducts() async {
    try {
      final products = await ApiClient.products();
      if (!mounted) return;
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
                                'SKU: ${product['sku']} · Stock: ${product['quantity']}',
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
      if (mounted) showShopMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filteredProducts = _products.where((product) {
      final matchesText = product.name.toLowerCase().contains(query);
      final matchesCategory =
          _category == 'All Items' || _mainCategoryOf(product) == _category;
      final matchesSubCategory =
          _subCategory == 'All' || product.subCategory.trim() == _subCategory;
      return matchesText && matchesCategory && matchesSubCategory;
    }).toList();

    final mainCategories = _mainCategories;
    final subCategories = _category == 'All Items'
        ? <String>[]
        : _subCategoriesFor(_category);
    final groupedView = _category == 'All Items' && query.isEmpty;
    final addProductButton = SizedBox(
      height: 55,
      child: FilledButton.icon(
        onPressed: () => Navigator.pushNamed(context, '/product/new'),
        icon: const Icon(Icons.add_rounded, size: 25),
        label: const Text(
          'Add Product',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF194AA2),
          foregroundColor: Colors.white,
          elevation: 3,
          shadowColor: ShopColors.primary.withValues(alpha: .25),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: ShopColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _InventoryAppBar(
              onSearch: () =>
                  FocusScope.of(context).requestFocus(_searchFocusNode),
              onLowStock: _showLowStockProducts,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
                children: [
                  SizedBox(
                    height: 45,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (value) => setState(() => _query = value),
                      style: const TextStyle(
                        color: ShopColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Search products...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF777A89),
                          fontSize: 14,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: Color(0xFF777A89),
                          size: 22,
                        ),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: ShopColors.primary,
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  SizedBox(
                    height: 39,
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      scrollDirection: Axis.horizontal,
                      itemCount: mainCategories.length + 1,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final category = index == 0
                            ? 'All Items'
                            : mainCategories[index - 1];
                        final selected = category == _category;
                        final label = category == 'All Items'
                            ? 'All Items (${_products.length})'
                            : category;
                        return ChoiceChip(
                          label: Text(label),
                          selected: selected,
                          onSelected: (_) => setState(() {
                            _category = category;
                            _subCategory = 'All';
                          }),
                          selectedColor: const Color(0xFF194AA2),
                          backgroundColor: Colors.white,
                          side: BorderSide.none,
                          elevation: selected ? 1 : 0,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : ShopColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        );
                      },
                    ),
                  ),
                  if (subCategories.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 34,
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        scrollDirection: Axis.horizontal,
                        itemCount: subCategories.length + 1,
                        separatorBuilder: (context, index) =>
                            const SizedBox(width: 6),
                        itemBuilder: (context, index) {
                          final sub = index == 0 ? 'All' : subCategories[index - 1];
                          final selected = sub == _subCategory;
                          return ChoiceChip(
                            label: Text(sub),
                            selected: selected,
                            onSelected: (_) =>
                                setState(() => _subCategory = sub),
                            selectedColor: const Color(0xFF45D9A2),
                            backgroundColor: Colors.white,
                            side: BorderSide.none,
                            elevation: selected ? 1 : 0,
                            labelStyle: TextStyle(
                              color: selected
                                  ? const Color(0xFF005539)
                                  : ShopColors.text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _InventoryMetric(
                          label: 'TOTAL ITEMS',
                          value:
                              '${_products.fold<int>(0, (sum, p) => sum + p.stock)}',
                          color: Color(0xFF777A89),
                        ),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: _InventoryMetric(
                          label: 'IN STOCK',
                          value:
                              '${_products.where((p) => p.stock > 0).fold<int>(0, (sum, p) => sum + p.stock)}',
                          color: ShopColors.green,
                        ),
                      ),
                      SizedBox(width: 9),
                      Expanded(
                        child: _InventoryMetric(
                          label: 'LOW STOCK',
                          value:
                              '${_products.where((p) => p.stock <= 5).fold<int>(0, (sum, p) => sum + p.stock)}',
                          color: Color(0xFFB63F00),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 17),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    _LoadInventoryError(
                      message: _errorMessage!,
                      onRetry: _loadProducts,
                    )
                  else if (groupedView && mainCategories.isEmpty)
                    _EmptyInventory(
                      onReset: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _category = 'All Items';
                          _subCategory = 'All';
                        });
                      },
                    )
                  else if (groupedView) ...[
                    for (final main in mainCategories)
                      _CategorySection(
                        title: main,
                        products: _products
                            .where((p) => _mainCategoryOf(p) == main)
                            .toList(),
                        expanded: _expanded.contains(main),
                        onToggle: () => setState(() {
                          if (_expanded.contains(main)) {
                            _expanded.remove(main);
                          } else {
                            _expanded.add(main);
                          }
                        }),
                        onTapProduct: (product) => Navigator.pushNamed(
                          context,
                          '/sales',
                          arguments: product.id,
                        ),
                        onOpenProduct: (product) => Navigator.pushNamed(
                          context,
                          '/inventory/report',
                          arguments: product.id,
                        ),
                        onEditProduct: _editProduct,
                        onDeleteProduct: _deleteProduct,
                      ),
                    const SizedBox(height: 20),
                    addProductButton,
                  ]
                  else if (filteredProducts.isEmpty)
                    _EmptyInventory(
                      onReset: () {
                        _searchController.clear();
                        setState(() {
                          _query = '';
                          _category = 'All Items';
                          _subCategory = 'All';
                        });
                      },
                    )
                  else ...[
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredProducts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: .9,
                          ),
                      itemBuilder: (context, index) => _ProductCard(
                        product: filteredProducts[index],
                        onTap: () => Navigator.pushNamed(
                          context,
                          '/sales',
                          arguments: filteredProducts[index].id,
                        ),
                        onOpen: () => Navigator.pushNamed(
                          context,
                          '/inventory/report',
                          arguments: filteredProducts[index].id,
                        ),
                        onEdit: () =>
                            _editProduct(filteredProducts[index]),
                        onDelete: () =>
                            _deleteProduct(filteredProducts[index]),
                      ),
                    ),
                    const SizedBox(height: 20),
                    addProductButton,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const _InventoryBottomNavigation(),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.title,
    required this.products,
    required this.expanded,
    required this.onToggle,
    required this.onTapProduct,
    required this.onOpenProduct,
    required this.onEditProduct,
    required this.onDeleteProduct,
  });

  final String title;
  final List<_Product> products;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<_Product> onTapProduct;
  final ValueChanged<_Product> onOpenProduct;
  final ValueChanged<_Product> onEditProduct;
  final ValueChanged<_Product> onDeleteProduct;

  @override
  Widget build(BuildContext context) {
    final totalStock = products.fold<int>(0, (sum, p) => sum + p.stock);

    // Group this main category's products by sub category (empty -> "No sub category").
    final grouped = <String, List<_Product>>{};
    for (final product in products) {
      final sub = product.subCategory.trim().isEmpty
          ? 'No sub category'
          : product.subCategory.trim();
      grouped.putIfAbsent(sub, () => []).add(product);
    }
    final subNames = grouped.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(color: Color(0x0A192033), blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(15),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: ShopColors.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.category_outlined,
                      color: ShopColors.primary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${products.length} product${products.length == 1 ? '' : 's'} · ${subNames.length} sub categor${subNames.length == 1 ? 'y' : 'ies'} · $totalStock in stock',
                          style: const TextStyle(
                            color: ShopColors.muted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: ShopColors.muted,
                      size: 26,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final sub in subNames) ...[
                    _SubCategoryHeader(
                      title: sub,
                      count: grouped[sub]!.length,
                      stock: grouped[sub]!.fold<int>(
                        0,
                        (sum, p) => sum + p.stock,
                      ),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: grouped[sub]!.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                            childAspectRatio: .9,
                          ),
                      itemBuilder: (context, index) {
                        final product = grouped[sub]![index];
                        return _ProductCard(
                          product: product,
                          onTap: () => onTapProduct(product),
                          onOpen: () => onOpenProduct(product),
                          onEdit: () => onEditProduct(product),
                          onDelete: () => onDeleteProduct(product),
                        );
                      },
                    ),
                    const SizedBox(height: 6),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SubCategoryHeader extends StatelessWidget {
  const _SubCategoryHeader({
    required this.title,
    required this.count,
    required this.stock,
  });

  final String title;
  final int count;
  final int stock;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
    child: Row(
      children: [
        const Icon(
          Icons.subdirectory_arrow_right_rounded,
          color: ShopColors.primary,
          size: 16,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ShopColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: ShopColors.pale,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count · $stock in stock',
            style: const TextStyle(
              color: ShopColors.muted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InventoryAppBar extends StatelessWidget {
  const _InventoryAppBar({required this.onSearch, required this.onLowStock});

  final VoidCallback onSearch;
  final VoidCallback onLowStock;

  static const _blue = Color(0xFF194AA2);

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    color: _blue,
    child: Row(
      children: [
        const Expanded(
          child: ShopHeaderBrand(
            title: 'Inventory',
            logoSize: 34,
            nameStyle: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
            titleStyle: TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _InventoryAppBarAction(icon: Icons.search_rounded, onPressed: onSearch),
        _InventoryAppBarAction(
          icon: Icons.notifications_none_rounded,
          onPressed: onLowStock,
        ),
        _InventoryAppBarAction(
          icon: Icons.shopping_cart_outlined,
          onPressed: () => Navigator.pushNamed(context, '/sales'),
        ),
        const SizedBox(width: 2),
        CircleAvatar(
          radius: 18,
          backgroundColor: const Color(0xFF083982),
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            icon: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 19,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InventoryAppBarAction extends StatelessWidget {
  const _InventoryAppBarAction({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, color: Colors.white, size: 22),
  );
}

class _InventoryMetric extends StatelessWidget {
  const _InventoryMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: .5,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            color: color == const Color(0xFF777A89) ? ShopColors.text : color,
            fontSize: 17,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _LoadInventoryError extends StatelessWidget {
  const _LoadInventoryError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        TextButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    ),
  );
}

class _Product {
  const _Product({
    required this.name,
    required this.category,
    required this.subCategory,
    required this.price,
    required this.stock,
    required this.icon,
    required this.tint,
    required this.productColor,
    required this.id,
    required this.sku,
    required this.size,
    required this.color,
    required this.cost,
    required this.imageUrl,
    this.supplierName = '',
  });

  factory _Product.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String? ?? '';
    final lowerCategory = category.toLowerCase();
    final isFootwear = lowerCategory.contains('footwear');
    final isTrouser = lowerCategory.contains('trouser');
    final isOuterwear =
        lowerCategory.contains('hoodie') || lowerCategory.contains('jacket');
    return _Product(
      id: json['id'] as String,
      name: json['name'] as String,
      category: category,
      subCategory: json['sub_category'] as String? ?? '',
      sku: json['sku'] as String? ?? '',
      size: json['size'] as String? ?? '',
      color: json['color'] as String? ?? '',
      cost: (json['cost'] as num?)?.toDouble() ?? 0,
      price: (json['price'] as num).toDouble(),
      stock: (json['quantity'] as num).toInt(),
      imageUrl: json['image_url'] as String? ?? '',
      supplierName: json['supplier_name'] as String? ?? '',
      icon: isFootwear
          ? Icons.directions_run_rounded
          : isTrouser
          ? Icons.straighten_rounded
          : isOuterwear
          ? Icons.hiking_rounded
          : Icons.checkroom_rounded,
      tint: isFootwear ? const Color(0xFFE6EFF3) : const Color(0xFFECEBE7),
      productColor: const Color(0xFF263B59),
    );
  }

  final String id;
  final String name;
  final String category;
  final String subCategory;
  final String sku;
  final String size;
  final String color;
  final double cost;
  final double price;
  final int stock;
  final String imageUrl;
  final String supplierName;
  final IconData icon;
  final Color tint;
  final Color productColor;
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
  });

  final _Product product;
  final VoidCallback onTap;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    child: InkWell(
      borderRadius: BorderRadius.circular(15),
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: product.tint,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: product.imageUrl.isNotEmpty
                          ? Image.network(
                              product.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                    product.icon,
                                    size: 76,
                                    color: product.productColor,
                                  ),
                            )
                          : Icon(
                              product.icon,
                              size: 76,
                              color: product.productColor,
                            ),
                    ),
                    Positioned(
                      top: 7,
                      right: 7,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.sell_outlined,
                          size: 14,
                          color: Color(0xFF777A89),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ShopColors.text,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 2),
            if (product.subCategory.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  product.subCategory.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ShopColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              'K${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                color: ShopColors.primary,
                fontWeight: FontWeight.w900,
                fontSize: 23,
              ),
            ),
            if (product.supplierName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Supplier: ${product.supplierName}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: ShopColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 5),
            Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6FFBBE),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Stock: ${product.stock}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShopColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                _ProductCardAction(
                  icon: Icons.edit_outlined,
                  color: ShopColors.primary,
                  tooltip: 'Edit product',
                  onPressed: onEdit,
                ),
                const SizedBox(width: 2),
                _ProductCardAction(
                  icon: Icons.delete_outline_rounded,
                  color: ShopColors.red,
                  tooltip: 'Delete product',
                  onPressed: onDelete,
                ),
                _ProductCardAction(
                  icon: Icons.sell_outlined,
                  color: ShopColors.orange,
                  tooltip: 'Sell product',
                  onPressed: onTap,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _ProductCardAction extends StatelessWidget {
  const _ProductCardAction({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(9),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, color: color, size: 18),
      ),
    ),
  );
}

class _EmptyInventory extends StatelessWidget {
  const _EmptyInventory({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.inventory_2_outlined,
          size: 42,
          color: ShopColors.outline,
        ),
        const SizedBox(height: 10),
        const Text(
          'No Products Found',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 5),
        const Text(
          'Try refining your search keyword or selecting a different category.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ShopColors.muted, fontSize: 12),
        ),
        TextButton(onPressed: onReset, child: const Text('Reset Filters')),
      ],
    ),
  );
}

class _InventoryBottomNavigation extends StatelessWidget {
  const _InventoryBottomNavigation();

  @override
  Widget build(BuildContext context) => Container(
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
          children: [
            _InventoryNavItem(
              icon: Icons.home_outlined,
              label: 'Home',
              route: '/home',
            ),
            _InventoryNavItem(
              icon: Icons.inventory_2_outlined,
              label: 'Inventory',
              selected: true,
            ),
            _InventoryNavItem(
              icon: Icons.point_of_sale_outlined,
              label: 'Sales',
              route: '/sales',
            ),
            _InventoryNavItem(
              icon: Icons.bar_chart_rounded,
              label: 'Reports',
              route: '/reports',
            ),
            _InventoryNavItem(
              icon: Icons.settings_outlined,
              label: 'Settings',
              route: '/settings',
            ),
          ],
        ),
      ),
    ),
  );
}

class _InventoryNavItem extends StatelessWidget {
  const _InventoryNavItem({
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
    final color = selected ? const Color(0xFF194AA2) : const Color(0xFF777A89);
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

// ---------------------------------------------------------------------------
// Modern edit-product dialog. Owns all of its text controllers and disposes
// them in its own State.dispose() — i.e. AFTER the widget tree is fully torn
// down. The previous inline version disposed 8 controllers the instant
// showDialog returned, while the pop animation was still rebuilding the
// dialog's TextFields — which is what froze the app when saving an image.
// ---------------------------------------------------------------------------

class _EditProductDialog extends StatefulWidget {
  const _EditProductDialog({required this.product});

  final _Product product;

  @override
  State<_EditProductDialog> createState() => _EditProductDialogState();
}

class _EditProductDialogState extends State<_EditProductDialog> {
  late final _name = TextEditingController(text: widget.product.name);
  late final _category = TextEditingController(text: widget.product.category);
  late final _subCategory = TextEditingController(
    text: widget.product.subCategory,
  );
  late final _sku = TextEditingController(text: widget.product.sku);
  late final _size = TextEditingController(text: widget.product.size);
  late final _color = TextEditingController(text: widget.product.color);
  late final _cost = TextEditingController(text: widget.product.cost.toString());
  late final _price = TextEditingController(text: widget.product.price.toString());
  late final _stock = TextEditingController(text: widget.product.stock.toString());
  late final _supplier = TextEditingController(
    text: widget.product.supplierName,
  );
  final _formKey = GlobalKey<FormState>();
  XFile? _newPhoto;
  bool _popped = false;

  @override
  void dispose() {
    for (final controller in [
      _name,
      _category,
      _subCategory,
      _sku,
      _size,
      _color,
      _cost,
      _price,
      _stock,
      _supplier,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _pop(Map<String, Object?>? result) {
    if (_popped) return;
    _popped = true;
    Navigator.pop(context, result);
  }

  Future<void> _pickPhoto() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (photo != null && mounted) setState(() => _newPhoto = photo);
    } on Exception {
      if (mounted) {
        showShopMessage(context, 'Could not open camera or gallery.');
      }
    }
  }

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: ShopColors.pale,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: const BorderSide(color: ShopColors.primary, width: 1.3),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    IconData? icon,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: TextFormField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: _fieldDecoration(label).copyWith(
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 19, color: ShopColors.primary),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) return 'Required';
        if (number) {
          final parsed = num.tryParse(value.trim());
          if (parsed == null) return 'Enter a valid number';
          if (label == 'Cost' && parsed < 0) return 'Must be 0 or more';
          if (label == 'Retail price' && parsed <= 0) {
            return 'Must be greater than 0';
          }
          if (label == 'Stock quantity' && (parsed < 0 || parsed % 1 != 0)) {
            return 'Enter a whole number of 0 or more';
          }
        }
        return null;
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(18, 16, 12, 14),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEF0F4))),
              ),
              child: Row(
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: ShopColors.primary.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.edit_outlined,
                      color: ShopColors.primary,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 11),
                  const Expanded(
                    child: Text(
                      'Edit product',
                      style: TextStyle(
                        color: ShopColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _pop(null),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
            Flexible(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Photo preview
                      GestureDetector(
                        onTap: _pickPhoto,
                        child: Stack(
                          children: [
                            Container(
                              height: 150,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: ShopColors.pale,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _newPhoto != null
                                    ? Image.file(
                                        File(_newPhoto!.path),
                                        fit: BoxFit.cover,
                                      )
                                    : product.imageUrl.isNotEmpty
                                    ? Image.network(
                                        product.imageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (
                                              context,
                                              error,
                                              stackTrace,
                                            ) => const Icon(
                                              Icons.add_a_photo_outlined,
                                              size: 36,
                                              color: Color(0xFF777A89),
                                            ),
                                      )
                                    : const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 36,
                                        color: Color(0xFF777A89),
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 8,
                              bottom: 8,
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: ShopColors.primary,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x33002E7B),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 17,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 10),
                        child: Text(
                          _newPhoto != null
                              ? 'New photo selected — tap to change'
                              : 'Tap photo to change product image',
                          style: const TextStyle(
                            color: ShopColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      _field(_name, 'Product name', icon: Icons.label_outline),
                      _field(
                        _category,
                        'Main Category',
                        icon: Icons.category_outlined,
                      ),
                      _field(
                        _subCategory,
                        'Sub Category',
                        icon: Icons.subdirectory_arrow_right_rounded,
                      ),
                      _field(_sku, 'SKU', icon: Icons.qr_code_rounded),
                      _field(_size, 'Size', icon: Icons.straighten_rounded),
                      _field(_color, 'Color', icon: Icons.palette_outlined),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _field(_cost, 'Cost', number: true),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: _field(_price, 'Retail price', number: true),
                          ),
                        ],
                      ),
                      _field(
                        _stock,
                        'Stock quantity',
                        number: true,
                        icon: Icons.inventory_outlined,
                      ),
                      _field(
                        _supplier,
                        'Supplier name',
                        icon: Icons.local_shipping_outlined,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Footer actions
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pop(null),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: ShopColors.muted,
                        side: const BorderSide(color: Color(0xFFDDE0E8)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        _pop({
                          'name': _name.text.trim(),
                          'category': _category.text.trim(),
                          'sub_category': _subCategory.text.trim(),
                          'sku': _sku.text.trim(),
                          'size': _size.text.trim(),
                          'color': _color.text.trim(),
                          'cost': double.parse(_cost.text),
                          'price': double.parse(_price.text),
                          'quantity': int.parse(_stock.text),
                          'supplier_name': _supplier.text.trim(),
                          '_photo': ?_newPhoto,
                        });
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared modern bottom sheet for choosing a photo source.
Future<ImageSource?> showImageSourceSheet(BuildContext context) =>
    showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(
                  'Add product photo',
                  style: TextStyle(
                    color: ShopColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _PhotoSourceTile(
                      icon: Icons.photo_camera_rounded,
                      label: 'Camera',
                      onTap: () =>
                          Navigator.pop(sheetContext, ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PhotoSourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () =>
                          Navigator.pop(sheetContext, ImageSource.gallery),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

class _PhotoSourceTile extends StatelessWidget {
  const _PhotoSourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ShopColors.pale,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            Icon(icon, color: ShopColors.primary, size: 26),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: ShopColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
