import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// Shared cache of the signed-in shop profile (name, contacts and logo).
///
/// Headers, receipts and settings all read from this single source so a
/// company registered on one screen shows up everywhere without each page
/// having to fetch `/settings` on its own.
class ShopProfile extends ChangeNotifier {
  Map<String, dynamic>? _shop;
  Future<void>? _loading;
  bool _failed = false;

  Map<String, dynamic>? get shop => _shop;

  /// Shop name entered at registration. Empty until the profile loads —
  /// no default/vendor name is ever shown on the pages.
  String get companyName => (_shop?['name'] as String?)?.trim() ?? '';

  String get logoUrl => (_shop?['logo_url'] as String?)?.trim() ?? '';

  /// Loads the shop once. Safe to call from build methods.
  void ensureLoaded() {
    if (_shop != null || _loading != null || _failed) return;
    _loading = _fetch();
  }

  /// Forces a reload, e.g. after login or after editing shop information.
  Future<void> refresh() async {
    if (_loading != null) return _loading;
    _failed = false;
    _loading = _fetch();
    return _loading;
  }

  Future<void> _fetch() async {
    try {
      _shop = await ApiClient.shopSettings();
    } on ApiException {
      _failed = true;
    } finally {
      _loading = null;
      if (_shop != null) notifyListeners();
    }
  }

  /// Stores a shop row already returned by the API (no extra request).
  void apply(Map<String, dynamic> shop) {
    _shop = shop;
    _failed = false;
    notifyListeners();
  }

  void clear() {
    _shop = null;
    _loading = null;
    _failed = false;
    notifyListeners();
  }

  /// Contact channels as displayed lines on receipts, taken only from the
  /// details saved by this shop at registration or in settings.
  ///
  /// Related channels share a line: TikTok/Instagram and Call/WhatsApp are
  /// grouped together, and collapsed to a single label when the value is the
  /// same for both.
  static List<String> contactLinesFor(Map<String, dynamic> shop) {
    String value(String key) => (shop[key] as String?)?.trim() ?? '';

    final lines = <String>[];
    final email = value('contact_email');
    if (email.isNotEmpty) lines.add('Email: $email');
    final facebook = value('facebook');
    if (facebook.isNotEmpty) lines.add('Facebook: $facebook');

    final instagram = value('instagram');
    final tiktok = value('tiktok');
    if (instagram.isNotEmpty && instagram == tiktok) {
      lines.add('TikTok/Instagram: $instagram');
    } else {
      final social = <String>[
        if (instagram.isNotEmpty) 'Instagram: $instagram',
        if (tiktok.isNotEmpty) 'TikTok: $tiktok',
      ];
      if (social.isNotEmpty) lines.add(social.join('  •  '));
    }

    final calls = value('calls');
    final whatsapp = value('whatsapp');
    if (calls.isNotEmpty && calls == whatsapp) {
      lines.add('Call/WhatsApp: $calls');
    } else {
      final phones = <String>[
        if (calls.isNotEmpty) 'Call: $calls',
        if (whatsapp.isNotEmpty) 'WhatsApp: $whatsapp',
      ];
      if (phones.isNotEmpty) lines.add(phones.join('  •  '));
    }
    return lines;
  }

  /// Builds the receipt contact block for [shop] from the registered details,
  /// skipping blank channels. Returns an empty string when none were saved.
  static String contactBlockFor(Map<String, dynamic> shop) =>
      contactLinesFor(shop).join('\n');
}

final shopProfile = ShopProfile();
