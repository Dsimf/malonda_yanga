import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../pages/inventory_page.dart' show showImageSourceSheet;
import '../services/api_client.dart';
import '../widgets/barcode_scanner.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

const _kSavedNames = 'savedProductNames';
const _kSavedCategories = 'savedCategories';
const _kSavedSubCategories = 'savedSubCategories';
const _kSavedColors = 'savedCustomColors';

class _AddProductPageState extends State<AddProductPage> {
  final _nameController = TextEditingController();
  final _nameFocus = FocusNode();
  final _costController = TextEditingController();
  final _priceController = TextEditingController();
  final _skuController = TextEditingController();
  final _supplierController = TextEditingController();
  final _subCategoryController = TextEditingController();
  XFile? _productPhoto;
  String _category = '';
  String _subCategory = '';
  String _supplierName = '';
  List<Map<String, dynamic>> _suppliers = [];
  String _selectedSize = 'M';
  String _selectedColor = 'Black';
  int _quantity = 50;
  bool _saving = false;
  int _supplierAutoKey = 0;
  List<String> _savedNames = [];
  List<String> _savedCategories = [];
  List<String> _savedSubCategories = [];
  List<Map<String, String>> _savedColors = [];

  @override
  void initState() {
    super.initState();
    _loadSavedOptions();
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    try {
      final suppliers = await ApiClient.suppliers();
      if (mounted) setState(() => _suppliers = suppliers);
    } on ApiException {
      // Supplier list is optional — the product can still be saved without one.
    }
  }

  Future<void> _addSupplier() async {
    final values = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _QuickSupplierDialog(),
    );
    if (values == null || !mounted) return;
    try {
      final supplier = await ApiClient.createSupplier(values);
      if (!mounted) return;
      setState(() {
        _suppliers = [..._suppliers, supplier];
        _supplierName = supplier['name'] as String? ?? '';
        _supplierController.text = _supplierName;
        _supplierAutoKey++;
      });
      showShopMessage(context, 'Supplier added.');
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocus.dispose();
    _costController.dispose();
    _priceController.dispose();
    _skuController.dispose();
    _supplierController.dispose();
    _subCategoryController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedOptions() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _savedNames = prefs.getStringList(_kSavedNames) ?? [];
      _savedCategories = prefs.getStringList(_kSavedCategories) ?? [];
      _savedSubCategories = prefs.getStringList(_kSavedSubCategories) ?? [];
      _savedColors = (prefs.getStringList(_kSavedColors) ?? [])
          .map(
            (entry) => Map<String, String>.from(
              jsonDecode(entry) as Map<String, dynamic>,
            ),
          )
          .toList();
    });
  }

  Future<void> _rememberName(String name) async {
    if (_savedNames.contains(name)) return;
    _savedNames = [..._savedNames, name]..sort(
      (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedNames, _savedNames);
  }

  Future<void> _rememberCategory(String category) async {
    if (_savedCategories.contains(category)) {
      return;
    }
    _savedCategories = [..._savedCategories, category];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedCategories, _savedCategories);
  }

  Future<void> _rememberColor({required String label, required int hex}) async {
    if (_savedColors.any((c) => c['label'] == label)) return;
    _savedColors = [..._savedColors, {'label': label, 'hex': '0x${hex.toRadixString(16)}'}];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kSavedColors,
      _savedColors.map((c) => jsonEncode(c)).toList(),
    );
  }

  /// Bottom sheet that lists saved (custom) categories and lets the user
  /// delete any of them. Defaults cannot be removed.
  Future<void> _manageCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.category_rounded,
                      color: ShopColors.primary, size: 20),
                  SizedBox(width: 9),
                  Text(
                    'Saved categories',
                    style: TextStyle(
                      color: ShopColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 29),
                child: Text(
                  'Swipe-tap the bin to remove a category you added.',
                  style: TextStyle(color: ShopColors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              if (_savedCategories.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.pale,
                    borderRadius: BorderRadius.circular(14),
                  ),
child: const Row(
                      children: [
                        Icon(Icons.inbox_rounded,
                            color: Color(0xFF9BA0AE), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'No saved categories yet. Add one with the + button on the Category field above.',
                            style: TextStyle(
                              color: ShopColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final category in _savedCategories)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(
                            14,
                            4,
                            4,
                            4,
                          ),
                          decoration: BoxDecoration(
                            color: ShopColors.pale,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bookmark_added_rounded,
                                size: 16,
                                color: ShopColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  category,
                                  style: const TextStyle(
                                    color: ShopColors.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove $category',
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  await _removeCategory(category);
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: ShopColors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(height: MediaQuery.viewPaddingOf(sheetContext).bottom),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeCategory(String category) async {
    setState(() {
      _savedCategories = _savedCategories
          .where((c) => c != category)
          .toList();
      if (_category == category) {
        _category = _savedCategories.isNotEmpty ? _savedCategories.first : '';
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedCategories, _savedCategories);
    if (mounted) {
      showShopMessage(context, 'Removed "$category".');
    }
  }

  Future<void> _rememberSubCategory(String subCategory) async {
    if (_savedSubCategories.contains(subCategory)) {
      return;
    }
    _savedSubCategories = [..._savedSubCategories, subCategory];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedSubCategories, _savedSubCategories);
  }

  Future<void> _removeSubCategory(String subCategory) async {
    setState(() {
      _savedSubCategories = _savedSubCategories
          .where((c) => c != subCategory)
          .toList();
      if (_subCategory == subCategory) {
        _subCategory = _savedSubCategories.isNotEmpty
            ? _savedSubCategories.first
            : '';
        _subCategoryController.text = _subCategory;
      }
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedSubCategories, _savedSubCategories);
    if (mounted) {
      showShopMessage(context, 'Removed "$subCategory".');
    }
  }

  /// Bottom sheet that lists saved sub categories and lets the user delete any
  /// of them.
  Future<void> _manageSubCategories() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.subdirectory_arrow_right_rounded,
                      color: ShopColors.primary, size: 20),
                  SizedBox(width: 9),
                  Text(
                    'Saved sub categories',
                    style: TextStyle(
                      color: ShopColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 29),
                child: Text(
                  'Tap the bin to remove a sub category you added.',
                  style: TextStyle(color: ShopColors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              if (_savedSubCategories.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.pale,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inbox_rounded,
                          color: Color(0xFF9BA0AE), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No saved sub categories yet. Add one with the + button on the Sub Category field above.',
                          style: TextStyle(
                            color: ShopColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final subCategory in _savedSubCategories)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(
                            14,
                            4,
                            4,
                            4,
                          ),
                          decoration: BoxDecoration(
                            color: ShopColors.pale,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bookmark_added_rounded,
                                size: 16,
                                color: ShopColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  subCategory,
                                  style: const TextStyle(
                                    color: ShopColors.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove $subCategory',
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  await _removeSubCategory(subCategory);
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: ShopColors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(height: MediaQuery.viewPaddingOf(sheetContext).bottom),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _removeName(String name) async {
    setState(() {
      _savedNames = _savedNames.where((n) => n != name).toList();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSavedNames, _savedNames);
    if (mounted) {
      showShopMessage(context, 'Removed "$name".');
    }
  }

  /// Bottom sheet that lists saved product names and lets the user remove any
  /// of them.
  Future<void> _manageNames() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.history_rounded,
                      color: ShopColors.primary, size: 20),
                  SizedBox(width: 9),
                  Text(
                    'Saved product names',
                    style: TextStyle(
                      color: ShopColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(top: 4, left: 29),
                child: Text(
                  'Tap the bin to remove a product name you added.',
                  style: TextStyle(color: ShopColors.muted, fontSize: 11),
                ),
              ),
              const SizedBox(height: 12),
              if (_savedNames.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: ShopColors.pale,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.inbox_rounded,
                          color: Color(0xFF9BA0AE), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No saved product names yet. Add one with the + button on the Product Name field above.',
                          style: TextStyle(
                            color: ShopColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      for (final name in _savedNames)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
                          decoration: BoxDecoration(
                            color: ShopColors.pale,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.bookmark_added_rounded,
                                size: 16,
                                color: ShopColors.primary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    color: ShopColors.text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Remove $name',
                                onPressed: () async {
                                  Navigator.pop(sheetContext);
                                  await _removeName(name);
                                },
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20,
                                  color: ShopColors.red,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              SizedBox(height: MediaQuery.viewPaddingOf(sheetContext).bottom),
            ],
          ),
        ),
      ),
    );
  }

  double get _margin {
    final cost = _parseAmount(_costController.text) ?? 0;
    final price = _parseAmount(_priceController.text) ?? 0;
    return price - cost;
  }

  double get _marginPercent {
    final price = _parseAmount(_priceController.text) ?? 0;
    if (price == 0) return 0;
    return _margin / price * 100;
  }

  Future<void> _showPhotoSources() async {
    final source = await showImageSourceSheet(context);
    if (source == null) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (photo != null && mounted) setState(() => _productPhoto = photo);
    } on PlatformException catch (error) {
      if (mounted) {
        showShopMessage(
          context,
          error.message ?? 'Could not open camera or gallery.',
        );
      }
    }
  }

  Future<void> _scanSku() async {
    final code = await scanBarcode(context);
    if (code != null && mounted) {
      setState(() => _skuController.text = code);
    }
  }

  Future<void> _setCustomColor() async {
    final picked = await showDialog<_PickedColor>(
      context: context,
      builder: (_) => const _ColorPickerDialog(),
    );
    if (picked == null || !mounted) return;
    if (picked.remember) {
      await _rememberColor(label: picked.label, hex: picked.color.toARGB32());
    }
    setState(() => _selectedColor = picked.label);
  }

  Future<void> _saveProduct() async {
    final name = _nameController.text.trim();
    final sku = _skuController.text.trim();
    final cost = _parseAmount(_costController.text);
    final price = _parseAmount(_priceController.text);
    if (name.isEmpty) {
      showShopMessage(context, 'Enter a product name.');
      return;
    }
    if (sku.isEmpty) {
      showShopMessage(context, 'Enter a SKU or barcode.');
      return;
    }
    if (_category.trim().isEmpty) {
      showShopMessage(
        context,
        'Choose a category, or add a new one with the + button.',
      );
      return;
    }
    if (cost == null || !cost.isFinite || cost < 0) {
      showShopMessage(context, 'Enter a valid cost price of 0 or more.');
      return;
    }
    if (price == null || !price.isFinite || price <= 0) {
      showShopMessage(context, 'Enter a valid retail price greater than 0.');
      return;
    }
    setState(() => _saving = true);
    try {
      // Remember the name / category / color for next time.
      await _rememberName(name);
      await _rememberCategory(_category);
      if (_selectedColor.startsWith('#')) {
        await _rememberColor(
          label: _selectedColor,
          hex: parseHexColor(_selectedColor).toARGB32() & 0xFFFFFF,
        );
      }
      final product = await ApiClient.createProduct({
        'name': name,
        'category': _category,
        'sub_category': _subCategory,
        'sku': sku,
        'size': _selectedSize,
        'color': _selectedColor,
        'cost': cost,
        'price': price,
        'quantity': _quantity,
        'supplier_name': _supplierName,
      });
      if (!mounted) return;
      if (_productPhoto != null) {
        try {
          final image = _productPhoto!;
          await ApiClient.uploadProductImage(
            product['id'] as String,
            contentType: image.mimeType ?? 'image/jpeg',
            imageBase64: base64Encode(await image.readAsBytes()),
          );
        } on ApiException catch (error) {
          if (!mounted) return;
          showShopMessage(
            context,
            'Product saved, but its photo could not be uploaded: ${error.message}',
          );
          Navigator.pushReplacementNamed(context, '/inventory');
          return;
        }
      }
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/inventory');
      showShopMessage(context, 'Product saved to inventory.');
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          const _ProductAppBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
              children: [
                const _ArrivalBanner(),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _PhotoCard(
                        title: 'Primary angle',
                        primary: true,
                        imagePath: _productPhoto?.path,
                        onTap: _showPhotoSources,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: _PhotoCard(
                        title: 'Choose Photo',
                        primary: false,
                        imagePath: _productPhoto?.path,
                        onTap: _showPhotoSources,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _ProductForm(
                  nameController: _nameController,
                  nameFocus: _nameFocus,
                  costController: _costController,
                  priceController: _priceController,
                  skuController: _skuController,
                  category: _category,
                  subCategory: _subCategory,
                  subCategoryController: _subCategoryController,
                  subCategories: _savedSubCategories,
                  categories: _savedCategories,
                  supplierName: _supplierName,
                  supplierController: _supplierController,
                  suppliers: _suppliers,
                  onSupplierChanged: (value) =>
                      setState(() => _supplierName = value ?? ''),
                  onAddSupplier: _addSupplier,
                  supplierAutoKey: _supplierAutoKey,
                  savedNames: _savedNames,
                  savedColors: _savedColors,
                  selectedSize: _selectedSize,
                  selectedColor: _selectedColor,
                  quantity: _quantity,
                  margin: _margin,
                  marginPercent: _marginPercent,
                  onCategoryChanged: (value) =>
                      setState(() => _category = value),
                  onSubCategoryChanged: (value) =>
                      setState(() => _subCategory = value),
                  onAddCategory: () async {
                    final typed = _category.trim();
                    if (typed.isEmpty) {
                      showShopMessage(
                        context,
                        'Type a category name first, then tap + to save it.',
                      );
                      return;
                    }
                    await _rememberCategory(typed);
                    if (!mounted) return;
                    if (!context.mounted) return;
                    showShopMessage(context, 'Category "$typed" saved.');
                  },
                  onCategoryRemoved: _removeCategory,
                  onAddSubCategory: () async {
                    final typed = _subCategory.trim();
                    if (typed.isEmpty) {
                      showShopMessage(
                        context,
                        'Type a sub category name first, then tap + to save it.',
                      );
                      return;
                    }
                    await _rememberSubCategory(typed);
                    if (!mounted) return;
                    if (!context.mounted) return;
                    showShopMessage(context, 'Sub category "$typed" saved.');
                  },
                  onSubCategoryRemoved: _removeSubCategory,
                  onManageSubCategories: _manageSubCategories,
                  onManageCategories: _manageCategories,
                  onNameSaved: _rememberName,
                  onNameRemoved: _removeName,
                  onManageNames: _manageNames,
                  onSizeSelected: (value) =>
                      setState(() => _selectedSize = value),
                  onColorSelected: (value) =>
                      setState(() => _selectedColor = value),
                  onColorRemoved: (label) async {
                    _savedColors = _savedColors
                        .where((c) => c['label'] != label)
                        .toList();
                    setState(() {});
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setStringList(
                      _kSavedColors,
                      _savedColors.map((c) => jsonEncode(c)).toList(),
                    );
                  },
                  onQuantityChanged: (value) =>
                      setState(() => _quantity = value),
                  onPriceChanged: () => setState(() {}),
                  onSetCustomColor: _setCustomColor,
                  onScanSku: _scanSku,
                ),
              ],
            ),
          ),
          _SaveButton(onPressed: _saving ? null : _saveProduct),
        ],
      ),
    ),
  );
}

double? _parseAmount(String input) {
  var value = input.trim().replaceAll(RegExp(r'[\sKk]'), '');
  if (value.isEmpty) return null;

  final commaIndex = value.lastIndexOf(',');
  final periodIndex = value.lastIndexOf('.');
  if (commaIndex >= 0 && periodIndex >= 0) {
    value = commaIndex > periodIndex
        ? value.replaceAll('.', '').replaceAll(',', '.')
        : value.replaceAll(',', '');
  } else if (commaIndex >= 0) {
    final commaCount = ','.allMatches(value).length;
    final decimalComma = commaCount == 1 && value.length - commaIndex - 1 <= 2;
    value = decimalComma
        ? value.replaceAll(',', '.')
        : value.replaceAll(',', '');
  }
  return double.tryParse(value);
}

class _ProductAppBar extends StatelessWidget {
  const _ProductAppBar();

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 14),
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
        const SizedBox(width: 4),
        const Expanded(
          child: ShopHeaderBrand(
            title: 'Product Details',
            logoSize: 34,
            nameStyle: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
            titleStyle: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
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
        const SizedBox(width: 5),
        CircleAvatar(
          radius: 18,
          backgroundColor: ShopColors.primaryContainer,
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

class _ArrivalBanner extends StatelessWidget {
  const _ArrivalBanner();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: ShopColors.primary,
      borderRadius: BorderRadius.circular(14),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A002E7B),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        Container(
          height: 42,
          width: 42,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .13),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.inventory_2_outlined,
            color: Colors.white,
            size: 22,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Stock Arrival',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Lusaka Store Inventory • Shelf A3',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: ShopColors.paleBlue, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF005539),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const Text(
            'ACTIVE',
            style: TextStyle(
              color: Color(0xFF6FFBBE),
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: .5,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.title,
    required this.primary,
    required this.onTap,
    this.imagePath,
  });

  final String title;
  final bool primary;
  final VoidCallback onTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          children: [
            SizedBox(
              height: 142,
              child: imagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(imagePath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : primary
                  ? _PrimaryPhotoPlaceholder(onTap: onTap)
                  : _AddPhotoPlaceholder(),
            ),
            const SizedBox(height: 5),
            Text(
              title,
              style: TextStyle(
                color: primary ? ShopColors.text : ShopColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!primary)
              const Padding(
                padding: EdgeInsets.only(top: 2, bottom: 3),
                child: Text(
                  'Back or label',
                  style: TextStyle(color: ShopColors.muted, fontSize: 10),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PrimaryPhotoPlaceholder extends StatelessWidget {
  const _PrimaryPhotoPlaceholder({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFF7C8585), Color(0xFF121619)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.checkroom_rounded, color: Color(0xFF17191D), size: 90),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: ShopColors.primary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Main',
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 7,
          right: 7,
          child: Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: IconButton(
              onPressed: onTap,
              icon: const Icon(
                Icons.edit_outlined,
                color: ShopColors.text,
                size: 18,
              ),
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    ),
  );
}

class _AddPhotoPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        height: 58,
        width: 58,
        decoration: const BoxDecoration(
          color: Color(0xFFE6E8EC),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.camera_alt_outlined,
          color: ShopColors.primary,
          size: 28,
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Add Photo',
        style: TextStyle(
          color: ShopColors.primary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
    ],
  );
}

class _ProductForm extends StatelessWidget {
  const _ProductForm({
    required this.nameController,
    required this.nameFocus,
    required this.costController,
    required this.priceController,
    required this.skuController,
    required this.category,
    required this.subCategory,
    required this.subCategoryController,
    required this.subCategories,
    required this.categories,
    required this.supplierName,
    required this.supplierController,
    required this.suppliers,
    required this.onSupplierChanged,
    required this.onAddSupplier,
    required this.supplierAutoKey,
    required this.savedNames,
    required this.savedColors,
    required this.selectedSize,
    required this.selectedColor,
    required this.quantity,
    required this.margin,
    required this.marginPercent,
    required this.onCategoryChanged,
    required this.onSubCategoryChanged,
    required this.onAddCategory,
    required this.onAddSubCategory,
    required this.onSubCategoryRemoved,
    required this.onManageSubCategories,
    required this.onCategoryRemoved,
    required this.onManageCategories,
    required this.onNameSaved,
    required this.onNameRemoved,
    required this.onManageNames,
    required this.onSizeSelected,
    required this.onColorSelected,
    required this.onColorRemoved,
    required this.onQuantityChanged,
    required this.onPriceChanged,
    required this.onSetCustomColor,
    required this.onScanSku,
  });

  final TextEditingController nameController;
  final FocusNode nameFocus;
  final TextEditingController costController;
  final TextEditingController priceController;
  final TextEditingController skuController;
  final String category;
  final String subCategory;
  final TextEditingController subCategoryController;
  final List<String> subCategories;
  final List<String> categories;
  final String supplierName;
  final TextEditingController supplierController;
  final List<Map<String, dynamic>> suppliers;
  final ValueChanged<String?> onSupplierChanged;
  final VoidCallback onAddSupplier;
  final int supplierAutoKey;
  final List<String> savedNames;
  final List<Map<String, String>> savedColors;
  final String selectedSize;
  final String selectedColor;
  final int quantity;
  final double margin;
  final double marginPercent;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<String> onSubCategoryChanged;
  final VoidCallback onAddCategory;
  final VoidCallback onAddSubCategory;
  final ValueChanged<String> onSubCategoryRemoved;
  final VoidCallback onManageSubCategories;
  final ValueChanged<String> onCategoryRemoved;
  final VoidCallback onManageCategories;
  final ValueChanged<String> onNameSaved;
  final ValueChanged<String> onNameRemoved;
  final VoidCallback onManageNames;
  final ValueChanged<String> onSizeSelected;
  final ValueChanged<String> onColorSelected;
  final ValueChanged<String> onColorRemoved;
  final ValueChanged<int> onQuantityChanged;
  final VoidCallback onPriceChanged;
  final VoidCallback onSetCustomColor;
  final VoidCallback onScanSku;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 7,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldHeading(
          title: 'Main Category',
          required: true,
          trailing: 'Manage',
          trailingColor: ShopColors.primary,
          onTrailingTap: onManageCategories,
        ),
        const SizedBox(height: 6),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: category),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const Iterable<String>.empty();
            return categories.where(
              (item) => item.toLowerCase().contains(query),
            );
          },
fieldViewBuilder:
              (
                context,
                textController,
                focusNode,
                onFieldSubmitted,
              ) => TextField(
                controller: textController,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.words,
                onChanged: (value) => onCategoryChanged(value.trim()),
                decoration: _formDecoration(
                  prefixIcon: const Icon(
                    Icons.checkroom_outlined,
                    color: ShopColors.primary,
                    size: 21,
                  ),
                  hintText: 'Type a category name e.g. Sneakers',
                ).copyWith(
                  suffixIcon: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Save this category',
                    onPressed: () {
                      final name = textController.text.trim();
                      if (name.isEmpty) {
                        showShopMessage(context, 'Type a category name first.');
                        return;
                      }
                      onAddCategory();
                    },
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: ShopColors.primary,
                      size: 21,
                    ),
                  ),
                ),
              ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    for (final option in options)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.bookmark_added_rounded,
                          size: 15,
                          color: ShopColors.primary,
                        ),
                        title: Text(option),
                        trailing: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Remove $option',
                          onPressed: () => onCategoryRemoved(option),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 18,
                            color: ShopColors.red,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FieldHeading(
          title: 'Sub Category',
          required: false,
          trailing: 'Manage',
          trailingColor: ShopColors.primary,
          onTrailingTap: onManageSubCategories,
        ),
        const SizedBox(height: 6),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: subCategory),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            if (query.isEmpty) return const Iterable<String>.empty();
            return subCategories.where(
              (item) => item.toLowerCase().contains(query),
            );
          },
          fieldViewBuilder:
              (
                context,
                textController,
                focusNode,
                onFieldSubmitted,
              ) => TextField(
                controller: textController,
                focusNode: focusNode,
                textCapitalization: TextCapitalization.words,
                onChanged: (value) => onSubCategoryChanged(value.trim()),
                decoration: _formDecoration(
                  prefixIcon: const Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    color: ShopColors.primary,
                    size: 21,
                  ),
                  hintText: 'e.g. Running, Casual, Formal',
                ).copyWith(
                  suffixIcon: IconButton(
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    tooltip: 'Save this sub category',
                    onPressed: () {
                      final name = textController.text.trim();
                      if (name.isEmpty) {
                        showShopMessage(
                          context,
                          'Type a sub category name first.',
                        );
                        return;
                      }
                      onAddSubCategory();
                    },
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: ShopColors.primary,
                      size: 21,
                    ),
                  ),
                ),
              ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    for (final option in options)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.bookmark_added_rounded,
                          size: 15,
                          color: ShopColors.primary,
                        ),
                        title: Text(option),
                        trailing: IconButton(
                          visualDensity: VisualDensity.compact,
                          tooltip: 'Remove $option',
                          onPressed: () => onSubCategoryRemoved(option),
                          icon: const Icon(
                            Icons.remove_circle_outline_rounded,
                            size: 18,
                            color: ShopColors.red,
                          ),
                        ),
                        onTap: () => onSelected(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 13),
        _FieldHeading(
          title: 'Product Name',
          required: true,
          trailing: 'Manage',
          trailingColor: ShopColors.primary,
          onTrailingTap: onManageNames,
        ),
        const SizedBox(height: 6),
        _ProductNameField(
          controller: nameController,
          focusNode: nameFocus,
          savedNames: savedNames,
          onNameCommitted: onNameSaved,
          onNameRemoved: onNameRemoved,
        ),
        const SizedBox(height: 12),
        _FieldHeading(title: 'Supplier'),
        const SizedBox(height: 6),
        Autocomplete<String>(
          key: ValueKey('supplier-$supplierAutoKey'),
          initialValue: TextEditingValue(text: supplierName),
          optionsBuilder: (value) {
            final query = value.text.trim().toLowerCase();
            final names = suppliers
                .map((s) => s['name'] as String? ?? '')
                .toSet()
                .toList();
            if (query.isEmpty) return names;
            return names
                .where((n) => n.toLowerCase().contains(query))
                .toList();
          },
          fieldViewBuilder: (
            context,
            textController,
            focusNode,
            onFieldSubmitted,
          ) => TextField(
            controller: textController,
            textCapitalization: TextCapitalization.words,
            onChanged: (value) => onSupplierChanged(value.trim()),
            decoration: _formDecoration(
              prefixIcon: const Icon(
                Icons.local_shipping_rounded,
                color: ShopColors.primary,
                size: 21,
              ),
              hintText: 'Type or select a supplier',
            ).copyWith(
              suffixIcon: IconButton(
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                tooltip: 'Save supplier to your suppliers list',
                onPressed: onAddSupplier,
                icon: const Icon(
                  Icons.add_circle_outline_rounded,
                  color: ShopColors.primary,
                  size: 21,
                ),
              ),
            ),
          ),
          optionsViewBuilder: (context, onSelected, options) => Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(12),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 220, maxWidth: 340),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  children: [
                    for (final option in options)
                      ListTile(
                        dense: true,
                        leading: const Icon(
                          Icons.local_shipping_rounded,
                          size: 15,
                          color: ShopColors.primary,
                        ),
                        title: Text(option),
                        onTap: () => onSelected(option),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FieldHeading(
          title: 'Size',
          trailing: 'Size Guide',
          trailingColor: ShopColors.primary,
          onTrailingTap: () => showShopMessage(
            context,
            'Letter sizes: S–5XL. Numeric sizes: 28–45.',
          ),
        ),
        const SizedBox(height: 5),
        ShopDropdown<String>(
          key: const Key('productSizeDropdown'),
          value: selectedSize,
          label: 'Size',
          icon: Icons.straighten_rounded,
          options: const [..._kLetterSizes, ..._kNumericSizes],
          display: (size) => size,
          itemIcon: (size) => Icons.aspect_ratio_rounded,
          onChanged: (value) {
            if (value != null) onSizeSelected(value);
          },
        ),
        const SizedBox(height: 12),
        _FieldHeading(
          title: 'Color Palette',
          trailing: 'Classic $selectedColor',
        ),
        const SizedBox(height: 5),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _ColorSwatch(
              color: const Color(0xFF17191D),
              selected: selectedColor == 'Black',
              onTap: () => onColorSelected('Black'),
            ),
            _ColorSwatch(
              color: const Color(0xFFE6E8EC),
              selected: selectedColor == 'White',
              onTap: () => onColorSelected('White'),
            ),
            _ColorSwatch(
              color: const Color(0xFF194AA2),
              selected: selectedColor == 'Cobalt Blue',
              onTap: () => onColorSelected('Cobalt Blue'),
            ),
            _ColorSwatch(
              color: ShopColors.orange,
              selected: selectedColor == 'Crimson Red',
              onTap: () => onColorSelected('Crimson Red'),
            ),
            for (final saved in savedColors)
              _SavedColorSwatch(
                color: parseHexColor(saved['hex'] ?? '0x17191D'),
                label: saved['label'] ?? '',
                selected: selectedColor == saved['label'],
                onTap: () => onColorSelected(saved['label'] ?? ''),
                onRemove: () => onColorRemoved(saved['label'] ?? ''),
              ),
            _ColorSwatch(
              color: const Color(0xFFECEEF2),
              selected: false,
              icon: Icons.palette_outlined,
              onTap: onSetCustomColor,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _PriceField(
                label: 'Cost Price',
                controller: costController,
                onChanged: onPriceChanged,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _PriceField(
                label: 'Retail Price',
                controller: priceController,
                onChanged: onPriceChanged,
                emphasized: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFFE4F0EC),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Container(
                height: 26,
                width: 26,
                decoration: const BoxDecoration(
                  color: Color(0xFF45D9A2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  size: 16,
                  color: ShopColors.green,
                ),
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text(
                  'Gross Profit per Item',
                  style: TextStyle(
                    color: ShopColors.green,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '+K${margin.toStringAsFixed(0)} (${marginPercent.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  color: ShopColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Initial Stock',
                    style: TextStyle(
                      color: ShopColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'In-store quantity',
                    style: TextStyle(color: Color(0xFF777A89), fontSize: 10),
                  ),
                ],
              ),
            ),
            _StockButton(
              icon: Icons.remove,
              onTap: () =>
                  onQuantityChanged(quantity > 0 ? quantity - 1 : quantity),
            ),
            SizedBox(
              width: 46,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _StockButton(
              icon: Icons.add,
              onTap: () => onQuantityChanged(quantity + 1),
            ),
          ],
        ),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 7, 7, 7),
          decoration: BoxDecoration(
            color: ShopColors.pale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.qr_code_scanner_rounded,
                color: Color(0xFF777A89),
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Barcode / SKU',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(
                      height: 21,
                      child: TextField(
                        key: const Key('addProductSkuField'),
                        controller: skuController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        style: const TextStyle(
                          color: Color(0xFF777A89),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onScanSku,
                style: TextButton.styleFrom(
                  foregroundColor: ShopColors.primary,
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                child: const Text(
                  'Scan',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _FieldHeading extends StatelessWidget {
  const _FieldHeading({
    required this.title,
    this.required = false,
    this.trailing,
    this.trailingColor = const Color(0xFF777A89),
    this.onTrailingTap,
  });

  final String title;
  final bool required;
  final String? trailing;
  final Color trailingColor;
  final VoidCallback? onTrailingTap;

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
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      if (trailing != null)
        GestureDetector(
          onTap: onTrailingTap,
          child: Text(
            trailing!,
            style: TextStyle(
              color: trailingColor,
              fontSize: 10,
              fontWeight: trailingColor == ShopColors.primary
                  ? FontWeight.w700
                  : FontWeight.w400,
            ),
          ),
        ),
    ],
  );
}

/// Letter sizes offered on the add-product size dropdown.
const _kLetterSizes = ['S', 'M', 'L', 'XL', 'XXL', '3XL', '4XL', '5XL'];

/// Numeric sizes offered on the add-product size dropdown.
const _kNumericSizes = [
  '28',
  '30',
  '32',
  '34',
  '36',
  '38',
  '40',
  '42',
  '44',
  '45',
];

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final Color color;
  final bool selected;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    shape: const CircleBorder(),
    elevation: selected ? 2 : 0,
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: icon != null
              ? Icon(icon, size: 18, color: const Color(0xFF777A89))
              : selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 21)
              : null,
        ),
      ),
    ),
  );
}

class _PriceField extends StatelessWidget {
  const _PriceField({
    required this.label,
    required this.controller,
    required this.onChanged,
    this.emphasized = false,
  });

  final String label;
  final TextEditingController controller;
  final VoidCallback onChanged;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text.rich(
        TextSpan(
          children: [
            TextSpan(text: label),
            const TextSpan(
              text: ' (K)',
              style: TextStyle(
                color: Color(0xFF777A89),
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
        style: const TextStyle(
          color: ShopColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 5),
      SizedBox(
        height: 45,
        child: TextField(
          key: Key('addProduct${label.replaceAll(' ', '')}Field'),
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => onChanged(),
          decoration: InputDecoration(
            prefixText: 'K  ',
            prefixStyle: TextStyle(
              color: emphasized ? ShopColors.primary : const Color(0xFF777A89),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
            filled: true,
            fillColor: ShopColors.pale,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(9),
              borderSide: const BorderSide(
                color: ShopColors.primary,
                width: 1.2,
              ),
            ),
          ),
          style: TextStyle(
            color: emphasized ? ShopColors.primary : ShopColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    ],
  );
}

class _StockButton extends StatelessWidget {
  const _StockButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFECEEF2),
    borderRadius: BorderRadius.circular(8),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 36,
        width: 39,
        child: Icon(icon, color: ShopColors.text, size: 19),
      ),
    ),
  );
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 8),
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 10,
          offset: Offset(0, -3),
        ),
      ],
    ),
    child: SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.check_rounded, size: 21),
        label: const Text(
          'Save Product',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: ShopColors.orange,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    ),
  );
}

InputDecoration _formDecoration({Widget? prefixIcon, String? hintText}) =>
    InputDecoration(
  prefixIcon: prefixIcon,
  hintText: hintText,
  filled: true,
  fillColor: ShopColors.pale,
  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: BorderSide.none,
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: BorderSide.none,
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(9),
    borderSide: const BorderSide(color: ShopColors.primary, width: 1.2),
  ),
);

// ---------------------------------------------------------------------------
// Helper: parse a hex string like '0xFF17191D' or '#RRGGBB' into a Color.
// ---------------------------------------------------------------------------

Color parseHexColor(String input) {
  var value = input.replaceAll('#', '');
  if (value.startsWith('0x') || value.startsWith('0X')) {
    final parsed = int.tryParse(value);
    if (parsed != null) return Color(parsed);
    value = value.substring(2);
  }
  final hex = int.tryParse(value, radix: 16) ?? 0;
  if (value.length <= 6) {
    // Add full opacity when the value only encodes RGB.
    return Color(0xFF000000 | hex);
  }
  return Color(hex);
}

String _formatHexColor(Color color) {
  final rgb = color.toARGB32() & 0xFFFFFF;
  return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}

// ---------------------------------------------------------------------------
// Result object returned by the custom-color dialog.
// ---------------------------------------------------------------------------

class _PickedColor {
  const _PickedColor({required this.color, required this.label, required this.remember});

  final Color color;
  final String label;
  final bool remember;
}

// ---------------------------------------------------------------------------
// Product name field with suggestions from previously used names.
// ---------------------------------------------------------------------------

class _ProductNameField extends StatefulWidget {
  const _ProductNameField({
    required this.controller,
    required this.focusNode,
    required this.savedNames,
    required this.onNameCommitted,
    required this.onNameRemoved,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> savedNames;
  final ValueChanged<String> onNameCommitted;
  final ValueChanged<String> onNameRemoved;

  @override
  State<_ProductNameField> createState() => _ProductNameFieldState();
}

class _ProductNameFieldState extends State<_ProductNameField> {
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateSuggestions);
    widget.focusNode.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(_ProductNameField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedNames != widget.savedNames) _updateSuggestions();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateSuggestions);
    widget.focusNode.removeListener(_onFocusChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!widget.focusNode.hasFocus) {
      // Leaving the field (or pressing Done) remembers the name.
      final name = widget.controller.text.trim();
      if (name.isNotEmpty) widget.onNameCommitted(name);
      if (_suggestions.isNotEmpty) setState(() => _suggestions = []);
    } else {
      _updateSuggestions();
    }
  }

  void _updateSuggestions() {
    final query = widget.controller.text.trim().toLowerCase();
    final matches = widget.savedNames
        .where((name) => name.toLowerCase().contains(query) && query.isNotEmpty)
        .take(4)
        .toList();
    final next = (matches.length == 1 && matches.first == widget.controller.text.trim())
        ? const <String>[]
        : matches;
    if (next.length != _suggestions.length ||
        !const ListEquality<String>().equals(next, _suggestions)) {
      setState(() => _suggestions = next);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TextField(
        key: const Key('addProductNameField'),
        controller: widget.controller,
        focusNode: widget.focusNode,
        textCapitalization: TextCapitalization.sentences,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) {
          final name = value.trim();
          if (name.isNotEmpty) widget.onNameCommitted(name);
          setState(() => _suggestions = []);
        },
        decoration: _formDecoration().copyWith(
          suffixIcon: IconButton(
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            tooltip: 'Save this product name',
            onPressed: () {
              final name = widget.controller.text.trim();
              if (name.isEmpty) {
                showShopMessage(context, 'Type a product name first.');
                return;
              }
              widget.onNameCommitted(name);
              showShopMessage(context, 'Product name "$name" saved.');
            },
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: ShopColors.primary,
              size: 21,
            ),
          ),
        ),
      ),
      if (_suggestions.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _suggestions
                .map(
                  (name) => Material(
                    color: ShopColors.pale,
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        widget.controller.text = name;
                        widget.controller.selection = TextSelection.collapsed(
                          offset: name.length,
                        );
                        setState(() => _suggestions = []);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.history_rounded,
                              size: 13,
                              color: ShopColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 11,
                                color: ShopColors.text,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => widget.onNameRemoved(name),
                              child: const Icon(
                                Icons.remove_circle_outline_rounded,
                                size: 14,
                                color: ShopColors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Minimal ListEquality replacement (avoids importing package:collection).
// ---------------------------------------------------------------------------

class ListEquality<T> {
  const ListEquality();

  bool equals(List<T> a, List<T> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

// ---------------------------------------------------------------------------
// Saved custom color swatch (removable via long-press).
// ---------------------------------------------------------------------------

class _SavedColorSwatch extends StatelessWidget {
  const _SavedColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.onRemove,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onLongPress: onRemove,
    child: Material(
      color: color,
      shape: const CircleBorder(),
      elevation: selected ? 2 : 0,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 42,
          height: 42,
          child: selected
              ? const Icon(Icons.check_rounded, color: Colors.white, size: 21)
              : null,
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Custom color picker dialog: hue + lightness sliders, lightweight and
// GPU-friendly (no heavy rendering, no freezing).
// ---------------------------------------------------------------------------

class _ColorPickerDialog extends StatefulWidget {
  const _ColorPickerDialog();

  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  double _hue = 0;
  double _lightness = .5;
  final _nameController = TextEditingController();
  bool _remember = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  HSLColor get _hsl => HSLColor.fromAHSL(1, _hue, .85 - _lightness * .3, _lightness);

  Color get _color => _hsl.toColor();

  @override
  Widget build(BuildContext context) {
    final colorLabel = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _formatHexColor(_color);
    return ShopPopup(
      title: 'Product color',
      icon: Icons.palette_rounded,
      maxWidth: 360,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: _color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE6E8EC)),
              boxShadow: [
                BoxShadow(
                  color: _color.withValues(alpha: .35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              colorLabel,
              style: TextStyle(
                color: _lightness < .45 ? Colors.white : ShopColors.text,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const SizedBox(
                width: 34,
                child: Text('Hue', style: TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: Slider(
                  value: _hue,
                  min: 0,
                  max: 360,
                  activeColor: ShopColors.primary,
                  onChanged: (value) => setState(() => _hue = value),
                ),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(
                width: 34,
                child: Text('Light', style: TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: Slider(
                  value: _lightness,
                  min: .15,
                  max: .92,
                  activeColor: ShopColors.primary,
                  onChanged: (value) => setState(() => _lightness = value),
                ),
              ),
              const SizedBox(
                width: 34,
                child: Text('Dark', style: TextStyle(fontSize: 12),
                    textAlign: TextAlign.end),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            decoration: shopFieldDecoration(
              'Color name',
              icon: Icons.label_outline,
            ),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            dense: true,
            value: _remember,
            onChanged: (value) => setState(() => _remember = value ?? true),
            title: const Text(
              'Remember this color',
              style: TextStyle(fontSize: 12),
            ),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
        ],
      ),
      footer: ShopPopupActions(
        confirmLabel: 'Use color',
        onCancel: () => Navigator.pop(context),
        onConfirm: () => Navigator.pop(
          context,
          _PickedColor(color: _color, label: colorLabel, remember: _remember),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable text prompt dialog lives in lib/widgets/barcode_scanner.dart
// (shared with the rest of the app) as _TextPromptDialog — public there.
// ---------------------------------------------------------------------------

/// Quick add-supplier pop-up used from the Add Product page. Saves a minimal
/// supplier record (name required, phone optional) so the product can be
/// linked to it immediately.
class _QuickSupplierDialog extends StatefulWidget {
  const _QuickSupplierDialog();

  @override
  State<_QuickSupplierDialog> createState() => _QuickSupplierDialogState();
}

class _QuickSupplierDialogState extends State<_QuickSupplierDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _popped = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _pop(Map<String, String>? result) {
    if (_popped) return;
    _popped = true;
    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Add supplier',
    icon: Icons.local_shipping_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: shopFieldDecoration('Supplier name *'),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: shopFieldDecoration('Phone (optional)'),
        ),
      ],
    ),
    footer: ShopPopupActions(
      confirmLabel: 'Save Supplier',
      onCancel: () => _pop(null),
      onConfirm: () {
        final name = _nameController.text.trim();
        if (name.isEmpty) {
          showShopMessage(context, 'Enter the supplier name.');
          return;
        }
        _pop({
          'name': name,
          'phone': _phoneController.text.trim(),
        });
      },
    ),
  );
}
