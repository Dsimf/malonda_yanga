/// Central Urban7 Trading Limited branding constants used across the app.
library;

class Urban7 {
  static const companyName = 'Urban7 Trading Limited';
  static const appName = 'Urban7 Shop Manager';
  static const email = 'Urban7.trading@gmail.com';

  static const facebook = 'Urban7';
  static const instagram = 'urban7trading';
  static const tiktok = 'urban7trading';

  static const whatsappNumbers = ['0961667079', '0979409750'];
  static const callNumbers = ['0961667079', '0979409750'];
  static const whatsappJoined = '0961667079 / 0979409750';
  static const callsJoined = '0961667079 / 0979409750';

  static const logoAsset = 'assets/urban7_logo.png';

  /// Exchange policy printed at the bottom of every receipt.
  static const String returnPolicy =
      'Purchased goods can only be returned for exchange only if:\n'
      "1. It's within the first 3 days from day of purchase,\n"
      '2. All tags should be intact,\n'
      '3. Same colour and type.';

  static const contactBlock =
      'Email: $email\n'
      'Facebook: $facebook\n'
      'Instagram: $instagram\n'
      'TikTok: $tiktok\n'
      'WhatsApp: $whatsappJoined\n'
      'Calls: $callsJoined';

  /// Letter sizes offered across the app (extended to 5XL).
  static const List<String> letterSizes = [
    'S',
    'M',
    'L',
    'XL',
    'XXL',
    '3XL',
    '4XL',
    '5XL',
  ];

  /// Numeric sizes offered across the app (extended to 45).
  static const List<String> numericSizes = [
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

  /// Sale channels recorded on every sale.
  static const saleTypes = ['Walk-in', 'Online'];

  /// Operating expense categories used on the reports page.
  static const expenseCategories = [
    'Salaries',
    'Rent',
    'Food',
    'Transport',
    'GRZ Taxes',
    'Other',
  ];
}
