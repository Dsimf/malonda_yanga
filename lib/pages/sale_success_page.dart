import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_client.dart';
import '../services/shop_profile.dart';
import '../services/urban7_branding.dart';
import '../widgets/shop_ui.dart';

class SaleSuccessPage extends StatefulWidget {
  const SaleSuccessPage({super.key});

  @override
  State<SaleSuccessPage> createState() => _SaleSuccessPageState();
}

class _SaleSuccessPageState extends State<SaleSuccessPage> {
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();
  final GlobalKey _receiptKey = GlobalKey();
  late Future<Map<String, dynamic>> _shop;

  @override
  void initState() {
    super.initState();
    _shop = ApiClient.shopSettings();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  String _receiptText({
    required String shopName,
    required String contactBlock,
    required List<_ReceiptLine> items,
    required double subtotal,
    required double discount,
    required double total,
    required String paymentMethod,
    String saleType = 'Walk-in',
    String customerName = '',
  }) {
    final itemLines = items
        .map(
          (item) =>
              '${item.name} (${item.size}, ${item.color}) x${item.quantity} - K${item.unitPrice * item.quantity}',
        )
        .join('\n');
    return '${shopName.trim().isEmpty ? '' : '$shopName\n'}Sales receipt\n'
        '${customerName.isEmpty ? '' : 'Customer: $customerName\n'}\n'
        '$itemLines\n\n'
        'Subtotal: K${subtotal.toStringAsFixed(2)}\nDiscount: K${discount.toStringAsFixed(2)}\nTotal: K${total.toStringAsFixed(2)}\n'
        'Payment: $paymentMethod ($saleType sale)\n\n'
        '${Urban7.returnPolicy}\n\n$contactBlock';
  }

  Future<String> _receiptMessage({
    required List<_ReceiptLine> items,
    required double subtotal,
    required double discount,
    required double total,
    required String paymentMethod,
    String saleType = 'Walk-in',
    String customerName = '',
  }) async {
    final shop = await _shop;
    return _receiptText(
      shopName: (shop['name'] as String?) ?? '',
      contactBlock: ShopProfile.contactBlockFor(shop),
      items: items,
      subtotal: subtotal,
      discount: discount,
      total: total,
      paymentMethod: paymentMethod,
      saleType: saleType,
      customerName: customerName,
    );
  }

  Future<Uint8List> _receiptPdf({
    required String shopName,
    required String contactBlock,
    required List<_ReceiptLine> items,
    required double subtotal,
    required double discount,
    required double total,
    required String paymentMethod,
    String logoUrl = '',
    String saleType = 'Walk-in',
    String customerName = '',
  }) async {
    pw.ImageProvider? logo;
    if (logoUrl.trim().isNotEmpty) {
      try {
        final response = await http
            .get(Uri.parse(logoUrl))
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          logo = pw.MemoryImage(response.bodyBytes);
        }
      } on Exception {
        // A missing logo must never block printing the receipt.
      }
    }
    final document = pw.Document();
    document.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null) ...[
              pw.Center(child: pw.Image(logo, height: 48)),
              pw.SizedBox(height: 6),
            ],
            if (shopName.trim().isNotEmpty)
              pw.Text(
                shopName,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            if (customerName.isNotEmpty) pw.Text('Customer: $customerName'),
            pw.SizedBox(height: 8),
            pw.Text('$saleType sale receipt'),
            pw.Divider(),
            for (final item in items)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 4),
                child: pw.Text(
                  '${item.name} (${item.size}, ${item.color}) x${item.quantity}  K${item.unitPrice * item.quantity}',
                ),
              ),
            pw.Divider(),
            pw.Text('Subtotal: K${subtotal.toStringAsFixed(2)}'),
            pw.Text('Discount: K${discount.toStringAsFixed(2)}'),
            pw.Text(
              'Total: K${total.toStringAsFixed(2)}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Payment: $paymentMethod ($saleType sale)'),
            pw.SizedBox(height: 10),
            pw.Text(Urban7.returnPolicy),
            pw.SizedBox(height: 6),
            pw.Text(contactBlock),
          ],
        ),
      ),
    );
    return document.save();
  }

  /// Captures the on-screen receipt card exactly as displayed and returns
  /// the PNG bytes, or null when the capture fails (message already shown).
  Future<Uint8List?> _captureReceiptCard() async {
    try {
      final boundary = _receiptKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        if (mounted) {
          showShopMessage(context, 'Receipt is not ready yet. Try again.');
        }
        return null;
      }
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      final bytes = byteData?.buffer.asUint8List();
      if (bytes == null && mounted) {
        showShopMessage(context, 'Could not capture the receipt image.');
      }
      return bytes;
    } on PlatformException catch (error) {
      if (mounted) {
        showShopMessage(context, error.message ?? 'Could not capture receipt.');
      }
      return null;
    }
  }

  /// Captures the receipt card exactly as displayed and saves it as a PNG
  /// in the temporary directory. Returns the file, or null when capture or
  /// writing fails (an error message has already been shown).
  Future<File?> _receiptImageFile() async {
    final bytes = await _captureReceiptCard();
    if (bytes == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/sales-receipt-${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } on FileSystemException catch (error) {
      if (mounted) {
        showShopMessage(
          context,
          'Could not prepare receipt file: ${error.message}',
        );
      }
      return null;
    }
  }

  /// Sends the receipt card image DIRECTLY to WhatsApp — WhatsApp opens
  /// itself (no app chooser) with the receipt PNG already attached.
  Future<void> _shareReceiptToWhatsAppDirect() async {
    final file = await _receiptImageFile();
    if (file == null) return;
    try {
      // Share the receipt image; the share sheet lets the user pick WhatsApp.
      await SharePlus.instance.share(
        ShareParams(
          text: 'Here is your receipt. Thank you for shopping with us!',
          files: [XFile(file.path)],
        ),
      );
    } on PlatformException catch (error) {
      if (mounted) {
        showShopMessage(
          context,
          error.message ?? 'Could not open WhatsApp.',
        );
      }
    }
  }

  /// Opens the system share sheet with the receipt card image so the
  /// cashier can pick ANY channel (Messaging/MMS, Telegram, Bluetooth...).
  Future<void> _shareReceiptImageEverywhere() async {
    final file = await _receiptImageFile();
    if (file == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Here is your receipt. Thank you for shopping with us!',
          files: [XFile(file.path, mimeType: 'image/png')],
          fileNameOverrides: const ['sales-receipt.png'],
        ),
      );
    } on PlatformException catch (error) {
      if (mounted) {
        showShopMessage(context, error.message ?? 'Could not share receipt.');
      }
    } on MissingPluginException {
      if (mounted) {
        showShopMessage(context, 'Sharing is not available on this device.');
      }
    }
  }

  /// Shares the receipt card image + text summary via the share sheet
  /// (email clients attach the PNG; MMS apps attach it to the draft).
  Future<void> _shareReceiptImageWithText() async {
    final file = await _receiptImageFile();
    if (file == null) return;
    try {
      final shop = await _shop;
      final shopName = (shop['name'] as String?) ?? '';
      await SharePlus.instance.share(
        ShareParams(
          subject: shopName.trim().isEmpty
              ? 'Sales receipt'
              : '$shopName sales receipt',
          text: 'Here is your receipt. Thank you for shopping with us!',
          files: [XFile(file.path, mimeType: 'image/png')],
          fileNameOverrides: const ['sales-receipt.png'],
        ),
      );
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        showShopMessage(context, error.message ?? 'Could not share receipt.');
      }
    } on MissingPluginException {
      if (mounted) {
        showShopMessage(context, 'Sharing is not available on this device.');
      }
    }
  }

  Future<void> _printReceipt({
    required List<_ReceiptLine> items,
    required double subtotal,
    required double discount,
    required double total,
    required String paymentMethod,
  }) async {
    try {
      final shop = await _shop;
      final bytes = await _receiptPdf(
        shopName: (shop['name'] as String?) ?? '',
        contactBlock: ShopProfile.contactBlockFor(shop),
        logoUrl: shop['logo_url'] as String? ?? '',
        items: items,
        subtotal: subtotal,
        discount: discount,
        total: total,
        paymentMethod: paymentMethod,
      );
      await Printing.layoutPdf(onLayout: (_) async => bytes);
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        showShopMessage(
          context,
          error.message ?? 'Could not open print dialog.',
        );
      }
    } on MissingPluginException {
      if (mounted) {
        showShopMessage(context, 'Printing is not available on this device.');
      }
    }
  }

  Future<void> _sendSms({
    required List<_ReceiptLine> items,
    required double subtotal,
    required double discount,
    required double total,
    required String paymentMethod,
  }) async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      showShopMessage(context, 'Enter the customer phone number first.');
      _phoneFocusNode.requestFocus();
      return;
    }
    try {
      final text = await _receiptMessage(
        items: items,
        subtotal: subtotal,
        discount: discount,
        total: total,
        paymentMethod: paymentMethod,
      );
      final uri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': text},
      );
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
          mounted) {
        showShopMessage(context, 'No SMS app is available on this device.');
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        showShopMessage(context, error.message ?? 'Could not open SMS app.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final arguments = ModalRoute.of(context)?.settings.arguments;
    final sale = arguments is Map ? arguments : const <Object?, Object?>{};
    final subtotal = (sale['subtotal'] as num?)?.toDouble() ?? 0.0;
    final discount = (sale['discount'] as num?)?.toDouble() ?? 0.0;
    final total = (sale['total'] as num?)?.toDouble() ?? 0.0;
    final paymentMethod = sale['paymentMethod'] as String? ?? 'Cash';
    final itemCount = (sale['itemCount'] as num?)?.toInt() ?? 0;
    final rawItems = sale['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => _ReceiptLine(
                  name: item['name']?.toString() ?? 'Product',
                  quantity: (item['quantity'] as num?)?.toInt() ?? 1,
                  size: item['size']?.toString() ?? 'M',
                  color: item['color']?.toString() ?? 'Black',
                  unitPrice: (item['unitPrice'] as num?)?.toDouble() ?? 0.0,
                ),
              )
              .toList()
        : const <_ReceiptLine>[];

    return Scaffold(
      backgroundColor: ShopColors.surface,
      body: SafeArea(
        child: Column(
          children: [
            _ReceiptAppBar(role: ApiClient.role),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                children: [
                  const _SuccessHeader(),
                  const SizedBox(height: 12),
                  _PaymentSummary(total: total, paymentMethod: paymentMethod),
                  const SizedBox(height: 13),
                  FutureBuilder<Map<String, dynamic>>(
                    future: _shop,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text(
                          'Could not load shop details: ${snapshot.error}',
                          style: const TextStyle(color: ShopColors.red),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final shop = snapshot.data!;
                      return RepaintBoundary(
                        key: _receiptKey,
                        child: _DigitalReceipt(
                        shopName: (shop['name'] as String?) ?? '',
                        contactBlock: ShopProfile.contactBlockFor(shop),
                        logoUrl: shop['logo_url'] as String? ?? '',
                        location: shop['location'] as String? ?? '',
                        phone: shop['phone'] as String? ?? '',
                        items: items,
                        subtotal: subtotal,
                        discount: discount,
                        total: total,
                        itemCount: itemCount,
                        saleType: sale['saleType'] as String? ?? 'Walk-in',
                        customerName: sale['customerName'] as String? ?? '',
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 13),
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Send to Customer',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: ShopColors.text,
                          ),
                        ),
                      ),
                      Text(
                        'Instant Delivery',
                        style: TextStyle(
                          color: ShopColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: _SendTile(
                          icon: Icons.chat_rounded,
                          label: 'WhatsApp',
                          detail: 'Receipt Card',
                          accent: ShopColors.green,
                          onTap: _shareReceiptToWhatsAppDirect,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SendTile(
                          icon: Icons.sms_outlined,
                          label: 'Direct SMS',
                          detail: 'Image Receipt',
                          onTap: _shareReceiptImageEverywhere,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _SendTile(
                          icon: Icons.mail_outline_rounded,
                          label: 'Email',
                          detail: 'Image Receipt',
                          onTap: _shareReceiptImageWithText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  _SendTile(
                    icon: Icons.ios_share_rounded,
                    label: 'Share Receipt Card',
                    detail: 'Any App • As Displayed',
                    onTap: _shareReceiptImageEverywhere,
                  ),
                  const SizedBox(height: 7),
                  _PhoneDelivery(
                    controller: _phoneController,
                    focusNode: _phoneFocusNode,
                    onSend: () => _sendSms(
                      items: items,
                      subtotal: subtotal,
                      discount: discount,
                      total: total,
                      paymentMethod: paymentMethod,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pushNamedAndRemoveUntil(
                        context,
                        '/sales',
                        (route) => false,
                      ),
                      icon: const Icon(Icons.point_of_sale_rounded, size: 19),
                      label: const Text(
                        'Start New Sale (POS)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.orange,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 45,
                    child: FilledButton.icon(
                      onPressed: () => _printReceipt(
                        items: items,
                        subtotal: subtotal,
                        discount: discount,
                        total: total,
                        paymentMethod: paymentMethod,
                      ),
                      icon: const Icon(Icons.print_outlined, size: 18),
                      label: const Text(
                        'Print Thermal Receipt',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF194AA2),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton.icon(
                    onPressed: () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/reports',
                      (route) => false,
                    ),
                    icon: const Icon(Icons.receipt_long_outlined, size: 16),
                    label: const Text(
                      'View Sales Register & Daily Report',
                      style: TextStyle(fontSize: 11),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: ShopColors.primary,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECEEF2),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.circle,
                          color: ShopColors.green,
                          size: 8,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Stock deducted ($itemCount items) • '
                            'Sale synced to Supabase',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ShopColors.muted,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
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

class _ReceiptLine {
  const _ReceiptLine({
    required this.name,
    required this.quantity,
    required this.size,
    required this.color,
    required this.unitPrice,
  });

  final String name;
  final int quantity;
  final String size;
  final String color;
  final double unitPrice;

  double get total => quantity * unitPrice;
}

class _ReceiptAppBar extends StatelessWidget {
  const _ReceiptAppBar({this.role});

  final String? role;

  @override
  Widget build(BuildContext context) => Container(
    height: 56,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    color: const Color(0xFF194AA2),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pushNamedAndRemoveUntil(
            context,
            '/sales',
            (route) => false,
          ),
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Colors.white,
            size: 22,
          ),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        const ShopBrandLogo(size: 32),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShopCompanyName(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .3,
                ),
              ),
              Text(
                'Sales Receipt',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
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
            size: 20,
          ),
          visualDensity: VisualDensity.compact,
        ),
        const SizedBox(width: 4),
        if (role != 'employee')
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFF083982),
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: 17,
              ),
            ),
          ),
      ],
    ),
  );
}

class _SuccessHeader extends StatelessWidget {
  const _SuccessHeader();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 73,
        width: 73,
        decoration: const BoxDecoration(
          color: ShopColors.green,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF6FFBBE),
          size: 47,
        ),
      ),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF6FFBBE),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_outlined, color: ShopColors.green, size: 12),
            SizedBox(width: 4),
            Text(
              'PAYMENT CONFIRMED',
              style: TextStyle(
                color: ShopColors.green,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                letterSpacing: .3,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 5),
      const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          'Sale Completed Successfully!',
          style: TextStyle(
            color: ShopColors.text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 3),
      const Text(
        'Receipt #REC-2024-0842 • 24 Oct 2024, 14:32',
        style: TextStyle(color: ShopColors.muted, fontSize: 10),
      ),
    ],
  );
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.total, required this.paymentMethod});

  final double total;
  final String paymentMethod;

  @override
  Widget build(BuildContext context) => _ReceiptCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TOTAL RECEIVED',
                    style: TextStyle(
                      color: ShopColors.muted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: .4,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'K${total.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: ShopColors.primary,
                      fontSize: 23,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'METHOD',
                  style: TextStyle(
                    color: ShopColors.muted,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.payments_outlined,
                      color: Color(0xFFB63F00),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      paymentMethod,
                      style: const TextStyle(
                        color: ShopColors.text,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Payment recorded',
                style: TextStyle(color: ShopColors.muted, fontSize: 9),
              ),
            ),
            Text(
              'Sales receipt',
              style: const TextStyle(color: ShopColors.muted, fontSize: 9),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DigitalReceipt extends StatelessWidget {
  const _DigitalReceipt({
    required this.shopName,
    required this.contactBlock,
    required this.logoUrl,
    required this.location,
    required this.phone,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.itemCount,
    this.saleType = 'Walk-in',
    this.customerName = '',
  });

  final String shopName;
  final String contactBlock;
  final String logoUrl;
  final String location;
  final String phone;
  final List<_ReceiptLine> items;
  final double subtotal;
  final double discount;
  final double total;
  final int itemCount;
  final String saleType;
  final String customerName;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        height: 7,
        decoration: const BoxDecoration(
          color: ShopColors.primaryContainer,
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
      ),
      _ReceiptCard(
        padding: const EdgeInsets.fromLTRB(16, 22, 16, 15),
        child: Column(
          children: [
            SizedBox(
              height: 42,
              width: 42,
              child: logoUrl.trim().isEmpty
                  ? Image.asset(
                      Urban7.logoAsset,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.checkroom_outlined,
                        color: ShopColors.primary,
                        size: 26,
                      ),
                    )
                  : Image.network(
                      logoUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => Image.asset(
                        Urban7.logoAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.checkroom_outlined,
                          color: ShopColors.primary,
                          size: 26,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: 5),
            if (shopName.trim().isNotEmpty)
              Text(
                shopName,
                style: TextStyle(
                  color: ShopColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            if (customerName.trim().isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Customer: $customerName',
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 2),
            Text(
              location,
              style: TextStyle(color: ShopColors.muted, fontSize: 10),
            ),
            Text(phone, style: TextStyle(color: ShopColors.muted, fontSize: 9)),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: ShopColors.pale,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '$saleType Sale Receipt',
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 13),
            const _ReceiptPerforation(),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'ITEMIZED BREAKDOWN',
                style: TextStyle(
                  color: ShopColors.text,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: .4,
                ),
              ),
            ),
            const SizedBox(height: 10),
            for (final item in items) ...[
              _ReceiptItem(
                title: item.name,
                details:
                    'Size ${item.size} • Color: ${item.color} (${item.quantity} × K${item.unitPrice.toStringAsFixed(2)})',
                price: 'K${item.total.toStringAsFixed(2)}',
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
              decoration: BoxDecoration(
                color: ShopColors.pale,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _ReceiptTotal(
                    label: 'Subtotal ($itemCount items)',
                    value: 'K${subtotal.toStringAsFixed(2)}',
                    strong: true,
                  ),
                  const SizedBox(height: 5),
                  _ReceiptTotal(
                    label: 'Discount',
                    value: '-K${discount.toStringAsFixed(2)}',
                    strong: true,
                  ),
                  const SizedBox(height: 6),
                  _ReceiptTotal(
                    label: 'Final Paid',
                    value: 'K${total.toStringAsFixed(2)}',
                    strong: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            const _ReceiptBarcode(),
            const SizedBox(height: 6),
            const Text(
              'REC-2024-0842-88401',
              style: TextStyle(
                color: ShopColors.text,
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Urban7.returnPolicy,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShopColors.muted,
                fontSize: 9,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              shopName.trim().isEmpty
                  ? 'Thank you for shopping with us!\n$contactBlock'
                  : 'Thank you for shopping with ${shopName.trim()}!\n$contactBlock',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: ShopColors.muted,
                fontSize: 8.5,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _ReceiptPerforation extends StatelessWidget {
  const _ReceiptPerforation();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      const Expanded(
        child: Divider(
          color: Color(0xFFC4C6D4),
          thickness: .8,
          height: 1,
          endIndent: 8,
        ),
      ),
      Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Color(0xFFE6E8EC),
          shape: BoxShape.circle,
        ),
      ),
      const Expanded(
        child: Divider(
          color: Color(0xFFC4C6D4),
          thickness: .8,
          height: 1,
          indent: 8,
        ),
      ),
    ],
  );
}

class _ReceiptBarcode extends StatelessWidget {
  const _ReceiptBarcode();

  static const _pattern = [
    2.0,
    1.0,
    3.0,
    1.0,
    2.0,
    2.0,
    1.0,
    3.0,
    1.0,
    1.0,
    2.0,
    3.0,
    1.0,
    2.0,
    1.0,
    2.0,
    3.0,
    1.0,
    1.0,
    2.0,
    2.0,
    1.0,
    3.0,
    1.0,
    2.0,
    1.0,
    3.0,
    2.0,
    1.0,
    1.0,
    3.0,
    1.0,
    2.0,
    2.0,
    1.0,
    3.0,
    1.0,
    2.0,
    1.0,
    2.0,
    3.0,
    1.0,
    2.0,
    1.0,
    1.0,
    3.0,
    2.0,
    1.0,
    2.0,
    3.0,
    1.0,
    2.0,
    1.0,
    1.0,
    3.0,
    2.0,
    1.0,
    2.0,
    3.0,
    1.0,
  ];

  @override
  Widget build(BuildContext context) => Container(
    height: 49,
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
    decoration: BoxDecoration(
      color: ShopColors.pale,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < _pattern.length; index++)
          Container(
            width: _pattern[index] * .75,
            color: index.isEven ? ShopColors.text : Colors.transparent,
          ),
      ],
    ),
  );
}

class _ReceiptItem extends StatelessWidget {
  const _ReceiptItem({
    required this.title,
    required this.details,
    required this.price,
  });

  final String title;
  final String details;
  final String price;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: ShopColors.text,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              details,
              style: const TextStyle(color: ShopColors.muted, fontSize: 9),
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      Text(
        price,
        style: const TextStyle(
          color: ShopColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    ],
  );
}

class _ReceiptTotal extends StatelessWidget {
  const _ReceiptTotal({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            color: strong ? ShopColors.primary : ShopColors.muted,
            fontSize: strong ? 12 : 9,
            fontWeight: strong ? FontWeight.w800 : FontWeight.w400,
          ),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: strong ? ShopColors.primary : ShopColors.text,
          fontSize: strong ? 12 : 9,
          fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
    ],
  );
}

class _SendTile extends StatelessWidget {
  const _SendTile({
    required this.icon,
    required this.label,
    required this.detail,
    required this.onTap,
    this.accent = ShopColors.primary,
  });

  final IconData icon;
  final String label;
  final String detail;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        height: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: accent == ShopColors.green
                  ? ShopColors.green
                  : const Color(0xFFE6E8EC),
              child: Icon(
                icon,
                color: accent == ShopColors.green
                    ? Colors.white
                    : ShopColors.primary,
                size: 17,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                color: ShopColors.text,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(detail, style: TextStyle(color: accent, fontSize: 8)),
          ],
        ),
      ),
    ),
  );
}

class _PhoneDelivery extends StatelessWidget {
  const _PhoneDelivery({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Container(
    height: 41,
    padding: const EdgeInsets.only(left: 9, right: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.phone_iphone_rounded,
          color: ShopColors.muted,
          size: 17,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            style: const TextStyle(color: ShopColors.text, fontSize: 11),
          ),
        ),
        FilledButton(
          onPressed: onSend,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF194AA2),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9),
            ),
          ),
          child: const Text(
            'Send',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [
        BoxShadow(
          color: Color(0x1A192033),
          blurRadius: 5,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}
