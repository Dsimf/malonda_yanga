import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'urban7_branding.dart';

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

  /// Builds the receipt contact block for [shop], skipping blank channels.
  /// Falls back to the Urban7 defaults for shops saved before contact
  /// details could be captured.
  static String contactBlockFor(Map<String, dynamic> shop) {
    final lines = <String>[];
    void add(String label, String value) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) lines.add('$label: $trimmed');
    }

    add('Email', (shop['contact_email'] as String?) ?? '');
    add('Facebook', (shop['facebook'] as String?) ?? '');
    add('Instagram', (shop['instagram'] as String?) ?? '');
    add('TikTok', (shop['tiktok'] as String?) ?? '');
    add('WhatsApp', (shop['whatsapp'] as String?) ?? '');
    add('Calls', (shop['calls'] as String?) ?? '');
    if (lines.isEmpty && ((shop['phone'] as String?) ?? '').trim().isNotEmpty) {
      add('Phone', (shop['phone'] as String?) ?? '');
    }
    return lines.isEmpty ? Urban7.contactBlock : lines.join('\n');
  }
}

final shopProfile = ShopProfile();
