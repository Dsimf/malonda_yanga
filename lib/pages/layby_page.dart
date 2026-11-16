import 'package:flutter/material.dart';

import '../services/api_client.dart';
import '../widgets/shop_dialogs.dart';
import '../widgets/shop_ui.dart';

class LaybyPage extends StatefulWidget {
  const LaybyPage({super.key});

  @override
  State<LaybyPage> createState() => _LaybyPageState();
}

class _LaybyPageState extends State<LaybyPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  late Future<List<Map<String, dynamic>>> _laybys;
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _laybys = ApiClient.laybys();
    _history = ApiClient.laybyHistory();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) return;
      // Refresh whichever tab was just opened so the data is never stale.
      if (_tabs.index == 0) {
        _reload();
      } else {
        _reloadHistory();
      }
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _reload() {
    final future = ApiClient.laybys();
    setState(() {
      _laybys = future;
    });
  }

  void _reloadHistory() {
    final future = ApiClient.laybyHistory();
    setState(() {
      _history = future;
    });
  }

  void _reloadAll() {
    _reload();
    _reloadHistory();
  }

  Future<void> _recordPayment(Map<String, dynamic> layby) async {
    final balance = (layby['layby_balance'] as num).round();
    final amount = await showDialog<num>(
      context: context,
      builder: (dialogContext) => _LaybyPaymentDialog(balance: balance),
    );
    if (amount == null || !mounted) return;
    try {
      final updated = await ApiClient.payLayby(layby['id'] as String, amount);
      if (!mounted) return;
      await _showPaymentReceipt(
        sale: updated,
        paidNow: amount,
        payments: const [],
        fallbackCustomer: layby['customer_name'] as String?,
      );
      _reloadAll();
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    }
  }

  Future<void> _showPaymentReceipt({
    required Map<String, dynamic> sale,
    required num paidNow,
    required List<Map<String, dynamic>> payments,
    String? fallbackCustomer,
  }) async {
    final total = (sale['total'] as num?)?.round() ?? 0;
    final deposit = (sale['layby_deposit'] as num?)?.round() ?? 0;
    final balance = (sale['layby_balance'] as num?)?.round() ?? 0;
    final settled = sale['layby_settled'] == true || balance <= 0;
    final customer =
        (sale['customer_name'] as String?) ?? fallbackCustomer ?? 'Customer';
    final history = payments.isNotEmpty
        ? payments
              .map(
                (payment) => (
                  amount: (payment['amount'] as num?)?.round() ?? 0,
                  paidAt: DateTime.tryParse(payment['paid_at'] as String? ?? ''),
                ),
              )
              .toList()
        : <({int amount, DateTime? paidAt})>[
            (amount: deposit, paidAt: null),
          ];

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => ShopPopup(
        title: settled ? 'Layby fully paid! 🎉' : 'Payment receipt',
        icon: settled ? Icons.celebration_rounded : Icons.receipt_long_rounded,
        accent: settled ? ShopColors.green : ShopColors.primary,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(customer, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _receiptRow('Sale total', 'K$total'),
            _receiptRow('Paid this time', 'K${paidNow.round()}'),
            _receiptRow('Total paid so far', 'K$deposit'),
            _receiptRow('Remaining balance', 'K$balance'),
            const SizedBox(height: 12),
            const Text(
              'Payments on this layby',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            ...history.map(
              (entry) => Text(
                '• K${entry.amount}${entry.paidAt == null ? '' : ' — ${_shortDate(entry.paidAt!)}'}',
                style: const TextStyle(fontSize: 12, color: ShopColors.muted),
              ),
            ),
            const SizedBox(height: 12),
            if (settled)
              const Text(
                'This layby is now fully paid. A paid-in-full receipt has '
                'been generated.',
                style: TextStyle(
                  color: ShopColors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              Text(
                'Balance of K$balance still remains on this layby.',
                style: const TextStyle(
                  color: ShopColors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        footer: ShopPopupSingleAction(
          label: 'Done',
          accent: settled ? ShopColors.green : ShopColors.primary,
          onPressed: () => Navigator.pop(dialogContext),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 13)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ],
    ),
  );

  String _shortDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    appBar: AppBar(
      backgroundColor: ShopColors.primary,
      foregroundColor: Colors.white,
      title: const Text('Layby Sales'),
      bottom: TabBar(
        controller: _tabs,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(text: 'Open'),
          Tab(text: 'History'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _tabs,
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _laybys,
          builder: (context, snapshot) =>
              _OpenLaybysView(snapshot: snapshot, onReload: _reload, onPay: _recordPayment),
        ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _history,
          builder: (context, snapshot) =>
              _HistoryView(snapshot: snapshot, onReload: _reloadHistory),
        ),
      ],
    ),
  );
}

class _OpenLaybysView extends StatelessWidget {
  const _OpenLaybysView({
    required this.snapshot,
    required this.onReload,
    required this.onPay,
  });

  final AsyncSnapshot<List<Map<String, dynamic>>> snapshot;
  final VoidCallback onReload;
  final void Function(Map<String, dynamic> layby) onPay;

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load laybys: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ShopColors.red, fontSize: 12),
            ),
            TextButton(onPressed: onReload, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final laybys = snapshot.data!;
    if (laybys.isEmpty) {
      return const Center(
        child: Text(
          'No open laybys.\nSales recorded as Layby will appear here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ShopColors.muted),
        ),
      );
    }
    final totalOwed = laybys.fold<int>(
      0,
      (sum, layby) => sum + (layby['layby_balance'] as num).round(),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, color: ShopColors.orange),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'Total owed on open laybys',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'K$totalOwed',
                style: const TextStyle(
                  color: ShopColors.orange,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ...laybys.map((layby) {
          final balance = (layby['layby_balance'] as num).round();
          final deposit = (layby['layby_deposit'] as num).round();
          final total = (layby['total'] as num).round();
          final paidPercent = total == 0 ? 0 : (deposit / total).clamp(0, 1);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          layby['customer_name'] as String? ?? 'Customer',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Text(
                        'K$balance left',
                        style: const TextStyle(
                          color: ShopColors.red,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  if ((layby['customer_phone'] as String? ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        layby['customer_phone'] as String,
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: paidPercent.toDouble(),
                      minHeight: 6,
                      backgroundColor: const Color(0xFFEFF0F3),
                      color: ShopColors.green,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Paid K$deposit of K$total · ${layby['payment_method']}',
                    style: const TextStyle(
                      color: ShopColors.muted,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 9),
                  SizedBox(
                    height: 38,
                    child: FilledButton.icon(
                      onPressed: () => onPay(layby),
                      icon: const Icon(Icons.payments_rounded, size: 18),
                      label: const Text(
                        'Record Payment',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.snapshot, required this.onReload});

  final AsyncSnapshot<List<Map<String, dynamic>>> snapshot;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (snapshot.hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Could not load history: ${snapshot.error}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: ShopColors.red, fontSize: 12),
            ),
            TextButton(onPressed: onReload, child: const Text('Try again')),
          ],
        ),
      );
    }
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }
    final sales = snapshot.data!;
    if (sales.isEmpty) {
      return const Center(
        child: Text(
          'No layby sales yet.\nEvery layby — open or fully paid — will be listed here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: ShopColors.muted),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        for (final sale in sales) _HistoryCard(sale: sale),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.sale});

  final Map<String, dynamic> sale;

  String _shortDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final total = (sale['total'] as num?)?.round() ?? 0;
    final deposit = (sale['layby_deposit'] as num?)?.round() ?? 0;
    final balance = (sale['layby_balance'] as num?)?.round() ?? 0;
    final settled = sale['layby_settled'] == true || balance <= 0;
    final customer = sale['customer_name'] as String? ?? 'Customer';
    final phone = sale['customer_phone'] as String? ?? '';
    final soldAt = DateTime.tryParse(sale['sold_at'] as String? ?? '');
    final payments = (sale['payments'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: settled
                        ? const Color(0xFFE4F6E9)
                        : const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    settled ? 'PAID IN FULL' : 'OPEN · K$balance',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: settled ? ShopColors.green : ShopColors.orange,
                    ),
                  ),
                ),
              ],
            ),
            if (phone.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  phone,
                  style: const TextStyle(
                    color: ShopColors.muted,
                    fontSize: 12,
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text(
              'Sale total K$total · sold ${soldAt == null ? '—' : _shortDate(soldAt)}',
              style: const TextStyle(color: ShopColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              'Paid K$deposit of K$total',
              style: const TextStyle(
                color: ShopColors.green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (payments.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Payment history',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              ...payments.map(
                (payment) => Text(
                  '• K${(payment['amount'] as num?)?.round() ?? 0}'
                  '${payment['paid_at'] == null ? '' : ' — ${_shortDate(DateTime.parse(payment['paid_at'] as String))}'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: ShopColors.muted,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Payment dialog for recording a layby payment.
///
/// Owns its text controller and disposes it in `dispose()` only after the
/// dialog route has fully left the screen. The previous inline version
/// disposed the controller the instant `showDialog` returned — while the
/// pop animation was still rebuilding the TextField — which threw
/// "used after being disposed" on both Cancel and Record and froze the page
/// behind the stuck modal barrier.
class _LaybyPaymentDialog extends StatefulWidget {
  const _LaybyPaymentDialog({required this.balance});

  final int balance;

  @override
  State<_LaybyPaymentDialog> createState() => _LaybyPaymentDialogState();
}

class _LaybyPaymentDialogState extends State<_LaybyPaymentDialog> {
  late final _controller = TextEditingController(text: '${widget.balance}');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ShopPopup(
    title: 'Record payment',
    icon: Icons.payments_rounded,
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: ShopColors.paleBlue.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: ShopColors.primary,
                size: 18,
              ),
              const SizedBox(width: 9),
              const Text(
                'Balance owed',
                style: TextStyle(fontSize: 12, color: ShopColors.muted),
              ),
              const Spacer(),
              Text(
                'K${widget.balance}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: ShopColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: shopFieldDecoration(
            'Amount paid (K)',
            icon: Icons.payments_outlined,
          ).copyWith(prefixText: 'K'),
        ),
      ],
    ),
    footer: ShopPopupActions(
      confirmLabel: 'Record payment',
      onCancel: () => Navigator.pop(context),
      onConfirm: () {
        final parsed = num.tryParse(_controller.text.trim());
        if (parsed == null || parsed <= 0) {
          showShopMessage(context, 'Enter a valid amount.');
          return;
        }
        Navigator.pop(context, parsed);
      },
    ),
  );
}
