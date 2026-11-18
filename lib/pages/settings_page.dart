import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../pages/inventory_page.dart' show showImageSourceSheet;
import '../services/api_client.dart';
import '../services/shop_profile.dart';
import '../services/urban7_branding.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Future<Map<String, dynamic>> _shop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && ApiClient.isEmployee) {
        Navigator.pushNamedAndRemoveUntil(context, '/sales', (route) => false);
      }
    });
    _shop = ApiClient.shopSettings();
  }

  Future<void> _editShop(Map<String, dynamic> shop) async {
    final result = await showDialog<_ShopInfoResult>(
      context: context,
      builder: (dialogContext) => _ShopInfoDialog(shop: shop),
    );
    if (result == null || !mounted) return;
    try {
      var updated = await ApiClient.updateShopSettings(result.fields);
      final logo = result.logo;
      if (logo != null) {
        final uploaded = await ApiClient.uploadShopLogo(
          contentType: logo.mimeType ?? 'image/jpeg',
          imageBase64: base64Encode(await logo.readAsBytes()),
        );
        final logoUrl = uploaded['logo_url'];
        if (logoUrl is String) {
          updated = {...updated, 'logo_url': logoUrl};
        }
      }
      shopProfile.apply(updated);
      if (!mounted) return;
      setState(() {
        _shop = Future.value(updated);
      });
      showShopMessage(context, 'Shop information updated.');
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _openShopInformation() async {
    try {
      final shop = await _shop;
      if (mounted) await _editShop(shop);
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _checkCloudData() async {
    try {
      final summary = await ApiClient.dashboard();
      if (mounted) {
        showShopMessage(
          context,
          'Cloud data is available. ${summary['product_count']} products loaded.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          _SettingsHeader(onShopInformation: _openShopInformation),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
              children: [
                FutureBuilder<Map<String, dynamic>>(
                  future: _shop,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Text(
                        'Could not load shop settings: ${snapshot.error}',
                        style: const TextStyle(color: ShopColors.red),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    return _ShopProfileCard(
                      shop: snapshot.data!,
                      onEdit: () => _editShop(snapshot.data!),
                    );
                  },
                ),
                const SizedBox(height: 17),
                const _GroupLabel('SHOP OPERATIONS'),
                _SettingsGroup(
                  children: [
                    _SettingTile(
                      icon: Icons.store_outlined,
                      title: 'Shop Information',
                      subtitle: 'Branch address, tax ID & contact',
                      onTap: _openShopInformation,
                    ),
                    _SettingTile(
                      icon: Icons.local_shipping_outlined,
                      title: 'Suppliers',
                      subtitle: 'Garment vendors, orders & invoices',
                      onTap: () => Navigator.pushNamed(context, '/suppliers'),
                    ),
                    _SettingTile(
                      icon: Icons.payments_outlined,
                      title: 'Operating Expenses',
                      subtitle: 'Salaries, rent, transport, GRZ taxes',
                      onTap: () => Navigator.pushNamed(context, '/expenses'),
                    ),
                    _SettingTile(
                      icon: Icons.admin_panel_settings_outlined,
                      title: 'Staff & Access',
                      subtitle: 'Employee logins — Sales & Daily Sales only',
                      onTap: () => Navigator.pushNamed(context, '/employees'),
                    ),
                    _SettingTile(
                      icon: Icons.schedule_rounded,
                      title: 'Layby Sales',
                      subtitle: 'Track customers paying on layby',
                      onTap: () => Navigator.pushNamed(context, '/laybys'),
                      last: true,
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                const _GroupLabel('DATA & SYSTEM'),
                _SettingsGroup(
                  children: [
                    _SettingTile(
                      icon: Icons.receipt_long_outlined,
                      title: 'Sales History',
                      subtitle: 'Daily receipts & counter audit logs',
                      onTap: () => Navigator.pushNamed(context, '/reports'),
                    ),
                    _SettingTile(
                      icon: Icons.cloud_sync_outlined,
                      title: 'Backup Data',
                      subtitle: 'Check Supabase connection',
                      subtitleColor: ShopColors.green,
                      onTap: _checkCloudData,
                    ),
                    _SettingTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About App',
                      subtitle: 'Version 1.0.0 • Supabase-connected account',
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: Urban7.appName,
                        applicationVersion: Urban7.companyName,
                      ),
                      last: true,
                    ),
                  ],
                ),
                const SizedBox(height: 17),
                SizedBox(
                  height: 57,
                  child: FilledButton.icon(
                    onPressed: () async {
                      try {
                        await ApiClient.logout();
                        shopProfile.clear();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(
                            context,
                            '/login',
                            (route) => false,
                          );
                        }
                      } on ApiException catch (error) {
                        if (context.mounted) {
                          showShopMessage(context, error.message);
                        }
                      }
                    },
                    icon: const Icon(Icons.logout_rounded, size: 21),
                    label: const Text(
                      'Log Out',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFFFDAD6),
                      foregroundColor: ShopColors.red,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _SettingsBottomNavigation(role: ApiClient.role),
  );
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({required this.onShopInformation});

  final VoidCallback onShopInformation;

  @override
  Widget build(BuildContext context) => Container(
    height: 78,
    padding: const EdgeInsets.symmetric(horizontal: 20),
    decoration: const BoxDecoration(
      color: ShopColors.primary,
      boxShadow: [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: Row(
      children: [
        const ShopBrandLogo(size: 34),
        const SizedBox(width: 9),
        const Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShopCompanyName(
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .4,
                ),
              ),
              Text(
                'Settings',
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
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/inventory'),
          icon: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
        ),
        IconButton(
          onPressed: () => Navigator.pushNamed(context, '/sales'),
          icon: const Icon(
            Icons.shopping_bag_outlined,
            color: Colors.white,
            size: 23,
          ),
        ),
        const SizedBox(width: 4),
        CircleAvatar(
          radius: 20,
          backgroundColor: ShopColors.primary,
          child: IconButton(
            padding: EdgeInsets.zero,
            onPressed: onShopInformation,
            icon: const Icon(
              Icons.person_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ShopProfileCard extends StatelessWidget {
  const _ShopProfileCard({required this.shop, required this.onEdit});

  final Map<String, dynamic> shop;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 7,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ShopBrandLogo(
          size: 64,
          borderRadius: 14,
          icon: Icons.storefront_rounded,
          logoUrl: shop['logo_url'] as String?,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      (shop['name'] as String?) ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShopColors.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6FFBBE),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Active',
                          style: TextStyle(
                            color: ShopColors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  const Flexible(
                    child: Icon(
                      Icons.location_on_outlined,
                      size: 17,
                      color: Color(0xFFB63F00),
                    ),
                  ),
                  const SizedBox(width: 4),
                   Flexible(
                    child: Text(
                      shop['location'] as String? ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: ShopColors.muted, fontSize: 12),
                    ),
                  ),
                ],
              ),
              if (((shop['contact_email'] as String?) ?? '')
                      .trim()
                      .isNotEmpty ||
                  ((shop['phone'] as String?) ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.contact_mail_outlined,
                      size: 16,
                      color: ShopColors.muted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        [
                          (shop['contact_email'] as String?) ?? '',
                          (shop['phone'] as String?) ?? '',
                        ].where((value) => value.trim().isNotEmpty).join(' • '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 6),
        FilledButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 16),
          label: const Text(
            'Edit',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
          style: FilledButton.styleFrom(
            backgroundColor: ShopColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
        ),
      ],
    ),
  );
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(5, 0, 0, 6),
    child: Text(
      title,
      style: const TextStyle(
        color: ShopColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: .5,
      ),
    ),
  );
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 2),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 7,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(children: children),
  );
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor = ShopColors.muted,
    this.last = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color subtitleColor;
  final bool last;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: onTap,
          minVerticalPadding: 8,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 4,
          ),
          leading: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFE6E8EC),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: ShopColors.primary, size: 25),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: ShopColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: subtitleColor, fontSize: 12),
          ),
          trailing: const Icon(
            Icons.chevron_right_rounded,
            color: Color(0xFF777A89),
            size: 24,
          ),
        ),
      ),
      if (!last) const SizedBox(height: 4),
    ],
  );
}

class _SettingsBottomNavigation extends StatelessWidget {
  const _SettingsBottomNavigation({this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    final routes = <_SettingsNavInfo>[
      _SettingsNavInfo(icon: Icons.point_of_sale_outlined, label: 'Sales', route: '/sales'),
      _SettingsNavInfo(icon: Icons.bar_chart_rounded, label: 'Reports', route: '/reports'),
    ];
    if (role != 'employee') {
      routes.insertAll(0, [
        _SettingsNavInfo(icon: Icons.home_outlined, label: 'Home', route: '/home'),
        _SettingsNavInfo(icon: Icons.inventory_2_outlined, label: 'Inventory', route: '/inventory'),
      ]);
      routes.add(_SettingsNavInfo(icon: Icons.settings_outlined, label: 'Settings', route: '/settings'));
    }
    final selectedRoute = '/settings';
    return Container(
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
            children: routes
                .map(
                  (info) => _SettingsNavItem(
                    icon: info.icon,
                    label: info.label,
                    route: info.route,
                    selected: info.route == selectedRoute,
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _SettingsNavInfo {
  const _SettingsNavInfo({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}

class _SettingsNavItem extends StatelessWidget {
  const _SettingsNavItem({
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
    final color = selected ? ShopColors.primary : ShopColors.muted;
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
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Upgraded "edit shop information" pop-up. Owns its text controllers and
/// disposes them only after the dialog route has fully left the screen.
class _ShopInfoDialog extends StatefulWidget {
  const _ShopInfoDialog({required this.shop});

  final Map<String, dynamic> shop;

  @override
  State<_ShopInfoDialog> createState() => _ShopInfoDialogState();
}

class _ShopInfoDialogState extends State<_ShopInfoDialog> {
  late final _name = TextEditingController(
    text: widget.shop['name'] as String? ?? '',
  );
  late final _owner = TextEditingController(
    text: widget.shop['owner_name'] as String? ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.shop['phone'] as String? ?? '',
  );
  late final _location = TextEditingController(
    text: widget.shop['location'] as String? ?? '',
  );
  late final _contactEmail = TextEditingController(
    text: widget.shop['contact_email'] as String? ?? '',
  );
  late final _facebook = TextEditingController(
    text: widget.shop['facebook'] as String? ?? '',
  );
  late final _instagram = TextEditingController(
    text: widget.shop['instagram'] as String? ?? '',
  );
  late final _tiktok = TextEditingController(
    text: widget.shop['tiktok'] as String? ?? '',
  );
  late final _whatsapp = TextEditingController(
    text: widget.shop['whatsapp'] as String? ?? '',
  );
  late final _calls = TextEditingController(
    text: widget.shop['calls'] as String? ?? '',
  );
  XFile? _logo;
  Uint8List? _previewBytes;

  String get _savedLogoUrl => (widget.shop['logo_url'] as String? ?? '').trim();

  @override
  void dispose() {
    for (final controller in [
      _name,
      _owner,
      _phone,
      _location,
      _contactEmail,
      _facebook,
      _instagram,
      _tiktok,
      _whatsapp,
      _calls,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1200,
        imageQuality: 85,
      );
      if (photo == null) return;
      final bytes = await photo.readAsBytes();
      if (!mounted) return;
      setState(() {
        _logo = photo;
        _previewBytes = bytes;
      });
    } on Exception {
      if (mounted) {
        showShopMessage(context, 'Could not open camera or gallery.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Shop information',
    icon: Icons.storefront_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DialogSectionLabel('SHOP LOGO'),
        const SizedBox(height: 7),
        _DialogLogoPicker(
          previewBytes: _previewBytes,
          savedLogoUrl: _savedLogoUrl,
          onPick: _pickLogo,
          onClear: () => setState(() {
            _logo = null;
            _previewBytes = null;
          }),
        ),
        const SizedBox(height: 14),
        const _DialogSectionLabel('BUSINESS'),
        const SizedBox(height: 7),
        TextField(
          controller: _name,
          autofocus: true,
          decoration: shopFieldDecoration(
            'Shop name',
            icon: Icons.storefront_outlined,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _owner,
          decoration: shopFieldDecoration(
            'Owner name',
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: shopFieldDecoration('Phone', icon: Icons.phone_outlined),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _location,
          decoration: shopFieldDecoration(
            'Location',
            icon: Icons.location_on_outlined,
          ),
        ),
        const SizedBox(height: 14),
        const _DialogSectionLabel('CONTACT DETAILS (OPTIONAL)'),
        const SizedBox(height: 7),
        TextField(
          controller: _contactEmail,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: shopFieldDecoration(
            'Contact email',
            icon: Icons.email_outlined,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _facebook,
          decoration: shopFieldDecoration(
            'Facebook page',
            icon: Icons.facebook_outlined,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _instagram,
          decoration: shopFieldDecoration(
            'Instagram',
            icon: Icons.photo_camera_outlined,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _tiktok,
          decoration: shopFieldDecoration(
            'TikTok',
            icon: Icons.music_note_outlined,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
          decoration: shopFieldDecoration(
            'WhatsApp numbers',
            icon: Icons.chat_outlined,
          ),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _calls,
          keyboardType: TextInputType.phone,
          decoration: shopFieldDecoration(
            'Call numbers',
            icon: Icons.call_outlined,
          ),
        ),
      ],
    ),
    footer: ShopPopupActions(
      onCancel: () => Navigator.pop(context),
      onConfirm: () => Navigator.pop(
        context,
        _ShopInfoResult(
          {
            'name': _name.text.trim(),
            'owner_name': _owner.text.trim(),
            'phone': _phone.text.trim(),
            'location': _location.text.trim(),
            'contact_email': _contactEmail.text.trim(),
            'facebook': _facebook.text.trim(),
            'instagram': _instagram.text.trim(),
            'tiktok': _tiktok.text.trim(),
            'whatsapp': _whatsapp.text.trim(),
            'calls': _calls.text.trim(),
          },
          _logo,
        ),
      ),
    ),
  );
}

class _ShopInfoResult {
  const _ShopInfoResult(this.fields, this.logo);

  final Map<String, String> fields;
  final XFile? logo;
}

class _DialogSectionLabel extends StatelessWidget {
  const _DialogSectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: const TextStyle(
      color: ShopColors.muted,
      fontSize: 10,
      fontWeight: FontWeight.w800,
      letterSpacing: .6,
    ),
  );
}

class _DialogLogoPicker extends StatelessWidget {
  const _DialogLogoPicker({
    required this.previewBytes,
    required this.savedLogoUrl,
    required this.onPick,
    required this.onClear,
  });

  final Uint8List? previewBytes;
  final String savedLogoUrl;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(9),
    decoration: BoxDecoration(
      color: ShopColors.pale,
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 58,
            width: 58,
            child: previewBytes != null
                ? Image.memory(previewBytes!, fit: BoxFit.cover)
                : savedLogoUrl.isEmpty
                ? const ColoredBox(
                    color: Colors.white,
                    child: Icon(
                      Icons.storefront_outlined,
                      color: ShopColors.primary,
                      size: 27,
                    ),
                  )
                : Image.network(
                    savedLogoUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Colors.white,
                      child: Icon(
                        Icons.storefront_outlined,
                        color: ShopColors.primary,
                        size: 27,
                      ),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Shown on page headers and receipts.',
            style: TextStyle(color: ShopColors.muted, fontSize: 11),
          ),
        ),
        if (previewBytes != null)
          IconButton(
            onPressed: onClear,
            tooltip: 'Undo logo change',
            icon: const Icon(
              Icons.close_rounded,
              color: ShopColors.muted,
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
          ),
        TextButton(
          onPressed: onPick,
          style: TextButton.styleFrom(
            foregroundColor: ShopColors.primary,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            previewBytes == null ? 'Change' : 'Selected',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}
