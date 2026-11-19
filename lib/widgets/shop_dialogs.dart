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

/// Decoration shared by every dropdown in the app — same rounded 13px frame
/// as [shopFieldDecoration] but with a soft chevron instead of the default
/// arrow, and a subtle hover/focus treatment.
InputDecoration shopDropdownDecoration(String label, {IconData? icon}) =>
    shopFieldDecoration(label, icon: icon).copyWith(
      suffixIcon: const Padding(
        padding: EdgeInsets.only(right: 12),
        child: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 22,
          color: ShopColors.muted,
        ),
      ),
      suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
      hintStyle: const TextStyle(
        color: ShopColors.muted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    );

/// Brand-styled dropdown used across the app.
///
/// Consistent rounded frame, prefix icon, chevron, styled menu items with a
/// checkmark on the selected value and a smooth open animation.
class ShopDropdown<T> extends StatelessWidget {
  const ShopDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.display,
    required this.label,
    required this.onChanged,
    this.icon,
    this.itemIcon,
    this.validator,
    this.hint,
  });

  final T? value;
  final List<T> options;
  final String Function(T) display;
  final String label;
  final IconData? icon;
  final IconData? Function(T)? itemIcon;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final empty =
        value == null || (value is String && (value as String).isEmpty);
    return DropdownButtonFormField<T>(
      initialValue: empty ? null : value,
      isExpanded: true,
      iconSize: 0,
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 10,
      menuMaxHeight: 300,
      style: const TextStyle(
        color: ShopColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      decoration: shopDropdownDecoration(label, icon: icon).copyWith(
        hintText: empty ? (hint ?? 'Select $label') : null,
      ),
      items: [
        for (final option in options)
          DropdownMenuItem<T>(
            value: option,
            child: Row(
              children: [
                if (itemIcon != null)
                  ...[
                    Icon(itemIcon!(option), size: 17, color: ShopColors.primary),
                    const SizedBox(width: 10),
                  ],
                Expanded(
                  child: Text(
                    display(option),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: ShopColors.text,
                    ),
                  ),
                ),
                if (option == value)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: ShopColors.primary,
                  ),
              ],
            ),
          ),
      ],
      validator: validator,
      onChanged: onChanged,
    );
  }
}

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
