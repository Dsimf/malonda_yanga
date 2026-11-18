import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/api_client.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

/// Operating-expenses manager ("Daily Outgoings"). Categories are fully
/// user-defined (no built-in defaults). Feeds the Net Profit figure on the
/// reports page.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;
  String? _errorMessage;

  /// Selected summary period: 0 = Today, 1 = This Week, 2 = This Month,
  /// 3 = All Time.
  int _periodIndex = 2;

  static const _periodLabels = ['Today', 'This Week', 'This Month', 'All Time'];

  DateTime get _periodStart {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return switch (_periodIndex) {
      0 => today,
      1 => today.subtract(const Duration(days: 6)),
      2 => DateTime(now.year, now.month),
      _ => DateTime(2000),
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final expenses = await ApiClient.expenses(
        start: _periodIndex == 3 ? DateTime(2000) : _periodStart,
        end: DateTime.now(),
      );
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _loading = false;
        });
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _addExpense() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _ExpenseDialog(),
    );
    if (result == null || !mounted) return;
    try {
      await ApiClient.createExpense({
        'category': result['category']!,
        'amount': num.tryParse(result['amount']!) ?? 0,
        'payment_method': result['source'] ?? 'Cash Drawer',
        'note': result['note'] ?? '',
      });
      if (mounted) {
        showShopMessage(
          context,
          'Logged K${result['amount']} for ${result['category']}',
        );
        _load();
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await ApiClient.deleteExpense(id);
      if (mounted) {
        showShopMessage(context, 'Expense record removed');
        _load();
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  DateTime? _expenseDate(Map<String, dynamic> expense) {
    final raw = expense['spent_on'] ?? expense['expense_date'] ?? expense['created_at'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  bool _inPeriod(Map<String, dynamic> expense) {
    final date = _expenseDate(expense);
    if (date == null) return true;
    final start = _periodStart;
    final end = DateTime.now().add(const Duration(days: 1));
    return !date.isBefore(start) && date.isBefore(end);
  }

  List<Map<String, dynamic>> get _periodExpenses =>
      _expenses.where(_inPeriod).toList();

  double get _periodTotal => _periodExpenses.fold(
    0,
    (sum, e) => sum + ((e['amount'] as num?)?.toDouble() ?? 0),
  );

  String get _periodTotalDisplay {
    final formatter = NumberFormat.currency(
      symbol: 'K ',
      decimalDigits: 2,
      customPattern: '#,##0.00',
    );
    return formatter.format(_periodTotal);
  }

  String _expenseDateLabel(Map<String, dynamic> expense) {
    final date = _expenseDate(expense);
    if (date == null) return '';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    if (day == today) return DateFormat('HH:mm').format(date);
    if (day == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM').format(date);
  }

  String _sourceLabel(Map<String, dynamic> expense) {
    final method = expense['payment_method'] as String? ?? '';
    return switch (method) {
      'Airtel Money' => 'Airtel',
      'MTN MoMo' => 'MoMo',
      'Zanaco / Bank' => 'Bank',
      '' => 'Cash',
      _ => 'Cash',
    };
  }

  IconData _categoryIcon(String category) => switch (category) {
    'Salaries' => Icons.badge_outlined,
    'Rent' => Icons.storefront_outlined,
    'Food' => Icons.restaurant_outlined,
    'Transport' => Icons.local_shipping_outlined,
    'Utilities' => Icons.bolt_outlined,
    'GRZ Taxes' => Icons.gavel_outlined,
    _ => Icons.receipt_long_outlined,
  };

  Color _categoryIconColor(String category) => switch (category) {
    'Salaries' => ShopColors.primary,
    'Rent' => ShopColors.orange,
    'Food' => ShopColors.green,
    'Transport' => ShopColors.primary,
    'Utilities' => ShopColors.orange,
    'GRZ Taxes' => ShopColors.red,
    _ => ShopColors.muted,
  };

  Color _categoryIconBackground(String category) => switch (category) {
    'Salaries' => ShopColors.paleBlue,
    'Rent' => const Color(0xFFFFDBCC),
    'Food' => ShopColors.greenPale,
    'Transport' => ShopColors.paleBlue,
    'Utilities' => const Color(0xFFFFDBCC),
    'GRZ Taxes' => const Color(0xFFFFDAD6),
    _ => ShopColors.pale,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          _ExpensesHeader(onBack: () => Navigator.pop(context)),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
              children: [
                // Top action strip
                Row(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: ShopColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Daily Outgoings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: ShopColors.text,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('openRecordOpexBtn'),
                      onPressed: _addExpense,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text(
                        'Log OPEX',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Summary metric dashboard card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TOTAL STORE OPEX',
                                  style: TextStyle(
                                    color: ShopColors.muted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .8,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _periodTotalDisplay,
                                  key: const Key('opexTotalDisplay'),
                                  style: const TextStyle(
                                    color: ShopColors.primary,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFFFDBCC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.trending_down_rounded,
                              color: ShopColors.orange,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: ShopColors.pale,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: ShopColors.primary,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'OPEX is automatically deducted from Gross '
                                'Profit to compute actual shop Net Profit.',
                                style: TextStyle(
                                  color: ShopColors.muted,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Filter pills
                      Row(
                        children: List.generate(_periodLabels.length, (index) {
                          final selected = _periodIndex == index;
                          return Expanded(
                            child: GestureDetector(
                              key: Key('opexPeriod${_periodLabels[index]}'),
                              onTap: () {
                             setState(() => _periodIndex = index);
                             _load();
                           },
                              child: Container(
                                margin: EdgeInsets.only(
                                  right: index == _periodLabels.length - 1
                                      ? 0
                                      : 6,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? ShopColors.primaryContainer
                                      : ShopColors.pale,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  _periodLabels[index],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : ShopColors.muted,
                                    fontSize: 10.5,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Recent expenses section
                Row(
                  children: [
                    const Text(
                      'Recent Expenses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ShopColors.text,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ShopColors.pale,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_periodExpenses.length} logs',
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_loading) const LinearProgressIndicator(),
                if (_errorMessage != null)
                  Text(
                    'Could not load expenses: $_errorMessage',
                    style: const TextStyle(color: ShopColors.red, fontSize: 12),
                  ),
                if (!_loading &&
                    _periodExpenses.isEmpty &&
                    _errorMessage == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No expenses recorded for this period.',
                        style: TextStyle(color: ShopColors.muted),
                      ),
                    ),
                  ),
                for (final expense in _periodExpenses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _categoryIconBackground(
                                expense['category'] as String? ?? 'Other',
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _categoryIcon(
                                expense['category'] as String? ?? 'Other',
                              ),
                              color: _categoryIconColor(
                                expense['category'] as String? ?? 'Other',
                              ),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        expense['category'] as String? ??
                                            'Other',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: ShopColors.text,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: ShopColors.pale,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        _expenseDateLabel(expense),
                                        style: const TextStyle(
                                          color: ShopColors.muted,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if ((expense['note'] as String? ?? '')
                                    .isNotEmpty)
                                  Text(
                                    expense['note'] as String,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ShopColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '-K${((expense['amount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: ShopColors.text,
                                ),
                              ),
                              Text(
                                _sourceLabel(expense),
                                style: const TextStyle(
                                  color: ShopColors.outline,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            tooltip: 'Delete expense',
                            onPressed: () =>
                                _deleteExpense(expense['id'] as String),
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: ShopColors.red,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'All expenses sync to the Reports page automatically.',
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
  );
}

class _ExpensesHeader extends StatelessWidget {
  const _ExpensesHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Container(
    height: 64,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    color: ShopColors.primary,
    child: Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        ),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'Operating Expenses',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ExpenseDialog extends StatefulWidget {
  const _ExpenseDialog();

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _source = 'Cash Drawer';
  String _expenseCategory = 'Salaries';

  static const _sources = [
    'Cash Drawer',
    'Airtel Money',
    'MTN MoMo',
    'Zanaco / Bank',
  ];

  static const _expenseCategories = [
    'Salaries',
    'Rent',
    'Food',
    'Transport',
    'Utilities',
    'GRZ Taxes',
    'Other',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Record shop expense',
    icon: Icons.receipt_long_outlined,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _expenseCategory,
          isExpanded: true,
          items: _expenseCategories
              .map(
                (category) => DropdownMenuItem(
                  value: category,
                  child: Text(category),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _expenseCategory = value);
          },
          decoration: shopFieldDecoration('Category'),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: shopFieldDecoration('Amount (K)'),
        ),
        const SizedBox(height: 9),
        DropdownButtonFormField<String>(
          initialValue: _source,
          isExpanded: true,
          items: _sources
              .map(
                (source) =>
                    DropdownMenuItem(value: source, child: Text(source)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _source = value);
          },
          decoration: shopFieldDecoration('Paid Via'),
        ),
        const SizedBox(height: 9),
        TextField(
          controller: _noteController,
          decoration: shopFieldDecoration('Notes / Voucher Reference'),
        ),
      ],
    ),
    footer: ShopPopupActions(
      confirmLabel: 'Save & Log Expense',
      onCancel: () => Navigator.pop(context),
      onConfirm: () {
        final category = _expenseCategory.trim();
        if (category.isEmpty) {
          showShopMessage(context, 'Choose a category for this expense.');
          return;
        }
        final amount = num.tryParse(_amountController.text.trim());
        if (amount == null || amount <= 0) {
          showShopMessage(context, 'Enter a valid amount.');
          return;
        }
        Navigator.pop(context, {
          'category': category,
          'amount': _amountController.text.trim(),
          'source': _source,
          'note': _noteController.text.trim(),
        });
      },
    ),
  );
}
