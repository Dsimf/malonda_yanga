import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'shop_ui.dart';

/// Opens a fullscreen barcode scanner and returns the scanned raw value
/// (or null if cancelled). Duplicate detections within the debounce window
/// are ignored so one scan returns exactly one result.
Future<String?> scanBarcode(BuildContext context) =>
    Navigator.of(context, rootNavigator: true).push<String>(
      PageRouteBuilder(
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: const _BarcodeScannerPage(),
        ),
      ),
    );

class _BarcodeScannerPage extends StatefulWidget {
  const _BarcodeScannerPage();

  @override
  State<_BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<_BarcodeScannerPage> {
  final _controller = MobileScannerController(
    detectionTimeoutMs: 800,
    formats: const [
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    ],
  );
  bool _returned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_returned || !mounted) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _returned = true;
        if (mounted) Navigator.of(context).pop(value);
        return;
      }
    }
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } on Exception {
      // Torch unsupported on this device — ignore.
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          // Dark vignette so the overlay controls stay readable.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x99000000),
                    Colors.transparent,
                    Color(0xB3000000),
                  ],
                  stops: [0, .35, 1],
                ),
              ),
            ),
          ),
          // Scanning reticle.
          Center(
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 150,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2.5),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x66FFFFFF),
                      blurRadius: 2,
                      spreadRadius: .5,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 120,
            child: Text(
              'Align the barcode inside the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: .2,
              ),
            ),
          ),
          // Top bar: close + torch.
          Positioned(
            top: safeTop + 8,
            left: 10,
            right: 10,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _ScannerButton(
                  icon: Icons.close_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                _ScannerButton(
                  icon: _torchOn
                      ? Icons.flashlight_on_rounded
                      : Icons.flashlight_off_rounded,
                  onTap: _toggleTorch,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScannerButton extends StatelessWidget {
  const _ScannerButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: .18),
    shape: const CircleBorder(),
    child: InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    ),
  );
}

/// Shared scaffold for modern edit pop-ups: icon-tile header with title and
/// close button, scrollable rounded content, and a Cancel/Confirm footer.
class ShopEditDialog extends StatelessWidget {
  const ShopEditDialog({
    super.key,
    required this.title,
    required this.content,
    required this.onCancel,
    required this.onConfirm,
    this.confirmLabel = 'Save changes',
    this.icon = Icons.edit_outlined,
    this.maxWidth = 420,
  });

  final String title;
  final Widget content;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final IconData icon;
  final double maxWidth;

  InputDecoration editFieldDecoration(String label, {IconData? icon}) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: ShopColors.pale,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
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
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 19, color: ShopColors.primary),
      );

  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: Colors.white,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 15, 10, 13),
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
                  child: Icon(icon, color: ShopColors.primary, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: content,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
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
                    onPressed: onConfirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmLabel),
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

/// Modern bottom-sheet style prompt dialog (rounded, centered icon column,
/// soft shadow) used for text-entry pop-ups across the app.
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    required this.labelText,
    required this.confirmLabel,
    this.icon = Icons.edit_note_rounded,
  });

  final String title;
  final String labelText;
  final String confirmLabel;
  final IconData icon;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller;
  bool _popped = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pop([String? value]) {
    if (_popped) return;
    _popped = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 36),
    contentPadding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
    actionsPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: ShopColors.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(widget.icon, color: ShopColors.primary, size: 21),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                widget.title,
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: widget.labelText,
            filled: true,
            fillColor: ShopColors.pale,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 13,
            ),
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
              borderSide: const BorderSide(
                color: ShopColors.primary,
                width: 1.3,
              ),
            ),
          ),
          onSubmitted: (value) => _pop(value.trim()),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => _pop(),
        style: TextButton.styleFrom(foregroundColor: ShopColors.muted),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => _pop(_controller.text.trim()),
        style: FilledButton.styleFrom(
          backgroundColor: ShopColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
        ),
        child: Text(widget.confirmLabel),
      ),
    ],
  );
}
