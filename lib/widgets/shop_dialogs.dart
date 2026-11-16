import 'package:flutter/material.dart';

import 'shop_ui.dart';

/// Shared "upgrade" toolkit for every pop-up in the app.
///
/// Replaces the default Material `AlertDialog` look with a modern
/// brand-consistent card: rounded 24px frame, soft shadow, icon-tile header
/// with a close button, scrollable content and a Cancel/Confirm footer.

const _kDivider = Color(0xFFEEF0F4);
const _kOutlineBtnBorder = Color(0xFFDDE0E8);

/// Base frame for all upgraded pop-ups.
class ShopPopup extends StatelessWidget {
  const ShopPopup({
    super.key,
    required this.title,
    required this.content,
    this.icon = Icons.edit_outlined,
    this.accent = ShopColors.primary,
    this.maxWidth = 420,
    this.footer,
    this.padding = const EdgeInsets.fromLTRB(18, 14, 18, 8),
  });

  final String title;
  final Widget content;
  final IconData icon;
  final Color accent;
  final double maxWidth;
  final Widget? footer;
  final EdgeInsetsGeometry padding;

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
              border: Border(bottom: BorderSide(color: _kDivider)),
            ),
            child: Row(
              children: [
                Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: accent, size: 19),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(padding: padding, child: content),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: footer!,
            ),
        ],
      ),
    ),
  );
}

/// Cancel + confirm footer used by form pop-ups.
class ShopPopupActions extends StatelessWidget {
  const ShopPopupActions({
    super.key,
    required this.onCancel,
    required this.onConfirm,
    this.confirmLabel = 'Save changes',
    this.cancelLabel = 'Cancel',
    this.accent = ShopColors.primary,
    this.confirmEnabled = true,
  });

  final VoidCallback onCancel;
  final VoidCallback onConfirm;
  final String confirmLabel;
  final String cancelLabel;
  final Color accent;
  final bool confirmEnabled;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: ShopColors.muted,
            side: const BorderSide(color: _kOutlineBtnBorder),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(cancelLabel),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: FilledButton(
          onPressed: confirmEnabled ? onConfirm : null,
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: accent.withValues(alpha: .35),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(confirmLabel),
        ),
      ),
    ],
  );
}

/// Single full-width action footer (e.g. "Done", "Close").
class ShopPopupSingleAction extends StatelessWidget {
  const ShopPopupSingleAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent = ShopColors.primary,
  });

  final String label;
  final VoidCallback onPressed;
  final Color accent;

  @override
  Widget build(BuildContext context) => FilledButton(
    onPressed: onPressed,
    style: FilledButton.styleFrom(
      backgroundColor: accent,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
  );
}

/// Upgraded destructive-confirmation pop-up (delete, etc.).
Future<bool> showShopConfirm({
  required BuildContext context,
  required String title,
  required String message,
  IconData icon = Icons.delete_outline_rounded,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ShopPopup(
      title: title,
      icon: icon,
      accent: ShopColors.red,
      maxWidth: 380,
      content: Text(
        message,
        style: const TextStyle(
          color: ShopColors.muted,
          fontSize: 14,
          height: 1.45,
        ),
      ),
      footer: ShopPopupActions(
        accent: ShopColors.red,
        confirmLabel: confirmLabel,
        onCancel: () => Navigator.pop(dialogContext, false),
        onConfirm: () => Navigator.pop(dialogContext, true),
      ),
    ),
  );
  return result == true;
}

/// Upgraded list pop-up (low stock alerts, etc.).
Future<void> showShopListPopup({
  required BuildContext context,
  required String title,
  required IconData icon,
  required List<Widget> children,
  Color accent = ShopColors.primary,
  String closeLabel = 'Close',
  EdgeInsetsGeometry padding = const EdgeInsets.fromLTRB(18, 14, 18, 8),
}) => showDialog<void>(
  context: context,
  builder: (dialogContext) => ShopPopup(
    title: title,
    icon: icon,
    accent: accent,
    padding: padding,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
    footer: ShopPopupSingleAction(
      label: closeLabel,
      onPressed: () => Navigator.pop(dialogContext),
    ),
  ),
);

/// Rounded, brand-styled text field for pop-ups.
InputDecoration shopFieldDecoration(String label, {IconData? icon}) =>
    InputDecoration(
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
      prefixIcon: icon == null
          ? null
          : Icon(icon, size: 19, color: ShopColors.primary),
    );
