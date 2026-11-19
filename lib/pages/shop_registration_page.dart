import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../pages/inventory_page.dart' show showImageSourceSheet;
import '../services/api_client.dart';
import '../services/shop_profile.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

class ShopRegistrationPage extends StatefulWidget {
  const ShopRegistrationPage({super.key});

  @override
  State<ShopRegistrationPage> createState() => _ShopRegistrationPageState();
}

class _ShopRegistrationPageState extends State<ShopRegistrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _tiktokController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _callsController = TextEditingController();
  String _storeType = 'Boutique';
  String? _location;
  bool _obscurePassword = true;
  bool _termsAccepted = false;
  bool _creatingShop = false;
  String? _errorMessage;
  XFile? _shopLogo;

  @override
  void dispose() {
    _shopNameController.dispose();
    _ownerNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _contactEmailController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _tiktokController.dispose();
    _whatsappController.dispose();
    _callsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(
      child: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
          children: [
            const _RegistrationBrandHeader(),
            const SizedBox(height: 17),
            const _RegistrationProgressCard(),
            const SizedBox(height: 16),
            _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle(
                    icon: Icons.store_outlined,
                    title: 'Store Identity',
                  ),
                  const SizedBox(height: 25),
                  const _FieldLabel(
                    label: 'Shop / Business Name',
                    required: true,
                  ),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('shopNameField'),
                    controller: _shopNameController,
                    decoration: _registrationDecoration(
                      'e.g., Lusaka Fashion Hub, Salaula Boutique',
                      icon: Icons.shopping_bag_outlined,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 17),
                  const _FieldLabel(label: 'Owner Full Name', required: true),
                  const SizedBox(height: 7),
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: _registrationDecoration(
                      'e.g., Kondwani Phiri',
                      icon: Icons.person_outline_rounded,
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 17),
                  const _FieldLabel(
                    label: 'Owner Email Address',
                    required: true,
                  ),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('ownerEmailField'),
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: _registrationDecoration(
                      'you@example.com',
                      icon: Icons.email_outlined,
                    ),
                    validator: (value) =>
                        value == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(value.trim())
                        ? 'Enter a valid email address'
                        : null,
                  ),
                  const SizedBox(height: 17),
                  const _FieldLabel(label: 'Password', required: true),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('ownerPasswordField'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration:
                        _registrationDecoration(
                          'At least 8 characters',
                          icon: Icons.lock_outline_rounded,
                        ).copyWith(
                          suffixIcon: IconButton(
                            key: const Key('toggleRegistrationPassword'),
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                          ),
                        ),
                    validator: (value) => value == null || value.length < 8
                        ? 'Password must be at least 8 characters'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel(
                    label: 'Shop Location / City',
                    required: true,
                  ),
                  const SizedBox(height: 7),
                  ShopDropdown<String>(
                    key: const Key('shopLocationDropdown'),
                    value: _location,
                    label: 'Shop Location / City',
                    icon: Icons.location_on_outlined,
                    options: const [
                      'Lusaka (Central / Kamwala / East Park)',
                      'Kitwe (Copperbelt Hub)',
                      'Ndola',
                      'Livingstone (Tourist & Market)',
                      'Chipata',
                      'Kabwe',
                      'Solwezi',
                    ],
                    display: (location) => location,
                    validator: (value) =>
                        value == null ? 'Select your shop location' : null,
                    onChanged: (value) => setState(() => _location = value),
                  ),
                  const SizedBox(height: 17),
                  const _FieldLabel(
                    label: 'Store Merchandising Type',
                    required: true,
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: 2.45,
                    children: [
                      _StoreTypeCard(
                        title: 'Boutique',
                        subtitle: 'New Apparels',
                        icon: Icons.checkroom_outlined,
                        selected: _storeType == 'Boutique',
                        onTap: () => setState(() => _storeType = 'Boutique'),
                      ),
                      _StoreTypeCard(
                        title: 'Salaula / 2nd Hand',
                        subtitle: 'Bale & Racks',
                        icon: Icons.inventory_2_outlined,
                        selected: _storeType == 'Salaula / 2nd Hand',
                        onTap: () =>
                            setState(() => _storeType = 'Salaula / 2nd Hand'),
                      ),
                      _StoreTypeCard(
                        title: 'Footwear',
                        subtitle: 'Shoes & Boots',
                        icon: Icons.hiking_outlined,
                        selected: _storeType == 'Footwear',
                        onTap: () => setState(() => _storeType = 'Footwear'),
                      ),
                      _StoreTypeCard(
                        title: 'Wholesale',
                        subtitle: 'Bulk Garments',
                        icon: Icons.warehouse_outlined,
                        selected: _storeType == 'Wholesale',
                        onTap: () => setState(() => _storeType = 'Wholesale'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle(
                    icon: Icons.contact_mail_outlined,
                    title: 'Contact Details (Optional)',
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel(label: 'Contact Email'),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('contactEmailField'),
                    controller: _contactEmailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: _registrationDecoration(
                      'Urban7.trading@gmail.com',
                      icon: Icons.email_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(label: 'Facebook Page'),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('contactFacebookField'),
                    controller: _facebookController,
                    decoration: _registrationDecoration(
                      'Urban7',
                      icon: Icons.facebook_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(label: 'Instagram'),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('contactInstagramField'),
                    controller: _instagramController,
                    decoration: _registrationDecoration(
                      'urban7trading',
                      icon: Icons.photo_camera_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(label: 'TikTok'),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('contactTiktokField'),
                    controller: _tiktokController,
                    decoration: _registrationDecoration(
                      'urban7trading',
                      icon: Icons.music_note_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(label: 'WhatsApp Numbers'),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('contactWhatsappField'),
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: _registrationDecoration(
                      '0961667079 / 0979409750',
                      icon: Icons.chat_outlined,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const _FieldLabel(label: 'Call Numbers'),
                  const SizedBox(height: 7),
                  TextFormField(
                    key: const Key('contactCallsField'),
                    controller: _callsController,
                    keyboardType: TextInputType.phone,
                    decoration: _registrationDecoration(
                      '0961667079 / 0979409750',
                      icon: Icons.call_outlined,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _FieldLabel(label: 'Company Logo (Optional)'),
                  const SizedBox(height: 8),
                  _ShopLogoPicker(
                    logo: _shopLogo,
                    onTap: _pickShopLogo,
                    onClear: () => setState(() => _shopLogo = null),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _FormCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _CardTitle(
                    icon: Icons.account_circle_outlined,
                    title: 'Owner Account & Currency',
                  ),
                  const SizedBox(height: 23),
                  const _FieldLabel(label: 'Primary POS Currency'),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6E8EC),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Row(
                      children: [
                        Container(
                          height: 32,
                          width: 32,
                          decoration: const BoxDecoration(
                            color: ShopColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'K',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Expanded(
                          child: Text(
                            'Zambian Kwacha (K / ZMW)',
                            style: TextStyle(
                              color: ShopColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6FFBBE),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.lock_outline,
                                color: ShopColors.green,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Default',
                                style: TextStyle(
                                  color: ShopColors.green,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _TermsAgreement(
              value: _termsAccepted,
              onChanged: (value) => setState(() => _termsAccepted = value),
            ),
            const SizedBox(height: 12),
            if (_errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _errorMessage!,
                  key: const Key('registrationError'),
                  style: TextStyle(color: ShopColors.red, fontSize: 13),
                ),
              ),
            ],
            SizedBox(
              height: 58,
              child: FilledButton.icon(
                onPressed: _creatingShop ? null : _createShop,
                icon: const Icon(Icons.arrow_forward_rounded, size: 22),
                label: Text(
                  _creatingShop
                      ? 'Creating account…'
                      : 'Create Shop & Continue',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: ShopColors.orange,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shadowColor: ShopColors.orange.withValues(alpha: .25),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account? ',
                    style: TextStyle(color: ShopColors.text, fontSize: 13),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/login'),
                    style: TextButton.styleFrom(
                      foregroundColor: ShopColors.primary,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'This field is required' : null;

  Future<void> _pickShopLogo() async {
    final source = await showImageSourceSheet(context);
    if (source == null || !mounted) return;
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
      if (photo != null && mounted) setState(() => _shopLogo = photo);
    } on Exception {
      if (mounted) {
        showShopMessage(context, 'Could not open camera or gallery.');
      }
    }
  }

  Future<void> _createShop() async {
    if (!_termsAccepted) {
      showShopMessage(context, 'Please accept the terms to continue.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _creatingShop = true;
      _errorMessage = null;
    });
    try {
      final result = await ApiClient.register({
        'shop_name': _shopNameController.text.trim(),
        'owner_name': _ownerNameController.text.trim(),
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'location': _location!,
        'business_type': _storeType,
        'contact_email': _contactEmailController.text.trim(),
        'facebook': _facebookController.text.trim(),
        'instagram': _instagramController.text.trim(),
        'tiktok': _tiktokController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'calls': _callsController.text.trim(),
      });
      if (!mounted) return;
      if (result['requires_email_confirmation'] == true) {
        showShopMessage(
          context,
          'Account created. Confirm your email, then sign in.',
        );
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
      final shop = result['shop'];
      if (shop is Map<String, dynamic>) shopProfile.apply(shop);
      if (_shopLogo != null) {
        try {
          final uploaded = await ApiClient.uploadShopLogo(
            contentType: _shopLogo!.mimeType ?? 'image/jpeg',
            imageBase64: base64Encode(await _shopLogo!.readAsBytes()),
          );
          final logoUrl = uploaded['logo_url'] as String?;
          final current = shopProfile.shop;
          if (logoUrl != null && current != null) {
            shopProfile.apply({...current, 'logo_url': logoUrl});
          }
        } on ApiException {
          // Logo upload is optional — don't block the rest of the flow.
        }
      }
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
        });
      }
    } finally {
      if (mounted) setState(() => _creatingShop = false);
    }
  }
}

class _RegistrationBrandHeader extends StatelessWidget {
  const _RegistrationBrandHeader();

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: ShopColors.primary,
          borderRadius: BorderRadius.circular(15),
        ),
        child: const Icon(
          Icons.checkroom_rounded,
          color: Colors.white,
          size: 27,
        ),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Clothing Shop Manager',
              style: TextStyle(
                color: ShopColors.primary,
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: -.3,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Zambia Retail POS',
              style: TextStyle(color: ShopColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFE6E8EC),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text(
          'v2.4',
          style: TextStyle(
            color: ShopColors.text,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ],
  );
}

class _RegistrationProgressCard extends StatelessWidget {
  const _RegistrationProgressCard();

  @override
  Widget build(BuildContext context) => _FormCard(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 15),
    child: Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Register Your Shop',
                    style: TextStyle(
                      color: ShopColors.text,
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Step 1 of 2: Basic Business Details',
                    style: TextStyle(color: ShopColors.text, fontSize: 14),
                  ),
                ],
              ),
            ),
            Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: ShopColors.paleBlue,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '1/2',
                  style: TextStyle(
                    color: ShopColors.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(7),
          child: const LinearProgressIndicator(
            value: .5,
            minHeight: 8,
            backgroundColor: Color(0xFFECEEF2),
            color: ShopColors.orange,
          ),
        ),
        const SizedBox(height: 11),
        Row(
          children: [
            Expanded(
              child: Row(
                children: const [
                  Icon(
                    Icons.storefront_outlined,
                    size: 15,
                    color: Color(0xFFB63F00),
                  ),
                  SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Shop Profile',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Color(0xFFB63F00),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: const [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 15,
                    color: Color(0xFF777A89),
                  ),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'Opening Stock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        color: Color(0xFF777A89),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.child,
    this.padding = const EdgeInsets.all(17),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 8,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: ShopColors.primary, size: 20),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});

  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        TextSpan(text: label),
        if (required)
          const TextSpan(
            text: ' *',
            style: TextStyle(color: ShopColors.red),
          ),
      ],
    ),
    style: const TextStyle(
      color: ShopColors.text,
      fontSize: 13,
      fontWeight: FontWeight.w500,
    ),
  );
}

class _StoreTypeCard extends StatelessWidget {
  const _StoreTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: selected ? ShopColors.paleBlue : ShopColors.pale,
    borderRadius: BorderRadius.circular(11),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? ShopColors.primary : const Color(0xFFB63F00),
              size: 21,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: ShopColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _TermsAgreement extends StatelessWidget {
  const _TermsAgreement({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 32,
        height: 30,
        child: Checkbox(
          value: value,
          onChanged: (checked) => onChanged(checked ?? false),
          activeColor: ShopColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
      const SizedBox(width: 5),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text.rich(
            TextSpan(
              style: const TextStyle(
                color: ShopColors.text,
                fontSize: 12,
                height: 1.4,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: const TextStyle(
                    color: ShopColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: ' & '),
                TextSpan(
                  text: 'Zambian Retail Merchant Privacy Policy',
                  style: const TextStyle(
                    color: ShopColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(text: '.'),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}

class _ShopLogoPicker extends StatelessWidget {
  const _ShopLogoPicker({
    required this.logo,
    required this.onTap,
    required this.onClear,
  });

  final XFile? logo;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: ShopColors.pale,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 64,
            width: 64,
            child: logo == null
                ? const ColoredBox(
                    color: Colors.white,
                    child: Icon(
                      Icons.storefront_outlined,
                      color: ShopColors.primary,
                      size: 30,
                    ),
                  )
                : FutureBuilder<Uint8List>(
                    future: logo!.readAsBytes(),
                    builder: (context, snapshot) {
                      final bytes = snapshot.data;
                      if (bytes == null) {
                        return const ColoredBox(
                          color: Colors.white,
                          child: Center(
                            child: SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      return Image.memory(bytes, fit: BoxFit.cover);
                    },
                  ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                logo == null ? 'Upload a company logo' : 'Logo selected',
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'PNG or JPG, shown on headers and receipts.',
                style: TextStyle(color: ShopColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        if (logo != null)
          IconButton(
            onPressed: onClear,
            tooltip: 'Remove logo',
            icon: const Icon(
              Icons.close_rounded,
              color: ShopColors.muted,
              size: 19,
            ),
            visualDensity: VisualDensity.compact,
          ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: ShopColors.primary,
            visualDensity: VisualDensity.compact,
          ),
          child: Text(
            logo == null ? 'Choose' : 'Change',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ],
    ),
  );
}

InputDecoration _registrationDecoration(String hint, {IconData? icon}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF777A89), fontSize: 14),
      prefixIcon: icon == null
          ? null
          : Icon(icon, color: ShopColors.text, size: 22),
      filled: true,
      fillColor: ShopColors.pale,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: ShopColors.primary, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: ShopColors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: ShopColors.red, width: 1.3),
      ),
    );
