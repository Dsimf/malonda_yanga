import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../services/urban7_branding.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

/// Operating-expenses manager: Salaries, Rent, Food, Transport,
/// GRZ Taxes and Other. Feeds the Net Profit figure on the reports page.
class ExpensesPage extends StatefulWidget {
  const ExpensesPage({super.key});

  @override
  State<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends State<ExpensesPage> {
  List<Map<String, dynamic>> _expenses = [];
  bool _loading = true;
  String? _errorMessage;

  DateTime get _monthStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final expenses = await ApiClient.expenses(
        start: _monthStart,
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
        'note': result['note'] ?? '',
      });
      if (mounted) {
        showShopMessage(context, 'Expense recorded.');
        _load();
      }
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _deleteExpense(String id) async {
    try {
      await ApiClient.deleteExpense(id);
      if (mounted) _load();
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  double get _total =>
      _expenses.fold(0, (sum, e) => sum + ((e['amount'] as num?) ?? 0));

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
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Operating expenses this month',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: ShopColors.text,
                          ),
                        ),
                      ),
                      Text(
                        'K${_total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: ShopColors.red,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading) const LinearProgressIndicator(),
                if (_errorMessage != null)
                  Text(
                    'Could not load expenses: $_errorMessage',
                    style: const TextStyle(color: ShopColors.red, fontSize: 12),
                  ),
                for (final expense in _expenses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  expense['category'] as String? ?? 'Other',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                    color: ShopColors.text,
                                  ),
                                ),
                                if ((expense['note'] as String? ?? '')
                                    .isNotEmpty)
                                  Text(
                                    expense['note'] as String,
                                    style: const TextStyle(
                                      color: ShopColors.muted,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            'K${expense['amount']}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: ShopColors.red,
                            ),
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
                if (!_loading && _expenses.isEmpty && _errorMessage == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No expenses recorded this month.',
                        style: TextStyle(color: ShopColors.muted),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _addExpense,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text(
                      'Add Operating Expense',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: ShopColors.orange,
                      foregroundColor: Colors.white,
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
  String _category = Urban7.expenseCategories.first;

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Add operating expense',
    icon: Icons.receipt_long_outlined,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String>(
          initialValue: _category,
          isExpanded: true,
          items: Urban7.expenseCategories
              .map(
                (category) =>
                    DropdownMenuItem(value: category, child: Text(category)),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _category = value);
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
        TextField(
          controller: _noteController,
          decoration: shopFieldDecoration('Note (optional)'),
        ),
      ],
    ),
    footer: ShopPopupActions(
      confirmLabel: 'Save expense',
      onCancel: () => Navigator.pop(context),
      onConfirm: () {
        final amount = num.tryParse(_amountController.text.trim());
        if (amount == null || amount <= 0) {
          showShopMessage(context, 'Enter a valid amount.');
          return;
        }
        Navigator.pop(context, {
          'category': _category,
          'amount': _amountController.text.trim(),
          'note': _noteController.text.trim(),
        });
      },
    ),
  );
}
