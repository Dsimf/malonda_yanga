import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/api_client.dart';
import '../widgets/shop_ui.dart';
import 'inventory_page.dart' show routeObserver;

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  /// Notify any mounted ReportsPage that report data may have changed.
  static void notifyRefresh() => _ReportsPageState.notifyRefresh();

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> with RouteAware {
  String _period = 'Daily';
  String _selectedCategory = 'All Categories';
  DateTimeRange _dateRange = DateTimeRange(
    start: DateUtils.dateOnly(DateTime.now()),
    end: DateTime.now(),
  );
  Map<String, dynamic>? _report;
  String? _errorMessage;
  bool _loading = true;

  /// Real categories from the shop's sold products, not a hardcoded list.
  List<String> get _categories => [
    'All Categories',
    for (final product in _topProducts)
      if ((product['category'] as String? ?? '').trim().isNotEmpty)
        (product['category'] as String).trim(),
  ].toSet().toList();

  /// Callback registered by a mounted ReportsPage so that a sale completion
  /// elsewhere in the app can trigger a refresh of the report data.
  static VoidCallback? _onRefresh;

  /// Register a callback to refresh this page's report data.
  /// Returns an unregister function.
  static VoidCallback registerRefresh(VoidCallback callback) {
    _onRefresh = callback;
    return () {
      if (_onRefresh == callback) _onRefresh = null;
    };
  }

  /// Notify any mounted ReportsPage that report data may have changed.
  static void notifyRefresh() {
    _onRefresh?.call();
  }

  @override
  void initState() {
    super.initState();
    registerRefresh(() => _loadReport());
    _loadReport();
  }

  List<Map<String, dynamic>> get _topProducts {
    final products = _report?['top_products'];
    if (products is! List) return const [];
    return products.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> get _expenseBreakdown {
    final breakdown = _report?['expense_breakdown'];
    return breakdown is Map<String, dynamic> ? breakdown : const {};
  }

  Map<String, dynamic> get _paymentTotals {
    final totals = _report?['payment_totals'];
    return totals is Map<String, dynamic> ? totals : const {};
  }

  List<(String, int)> get _dailySales {
    final daily = _report?['daily_totals'];
    if (daily is! List) return const [];
    return daily.whereType<Map<String, dynamic>>().map((entry) {
      final date = DateTime.parse(entry['date'] as String);
      const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return (weekdays[date.weekday - 1], (entry['total'] as num).round());
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  /// Called when this page is revealed again after a route is popped off it
  /// (e.g. user returns from the sale-success page).
  @override
  void didPopNext() => _loadReport();

  Future<void> _loadReport() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final report = await ApiClient.reports(
        start: _dateRange.start,
        end: _dateRange.end,
      );
      if (mounted) {
        setState(() {
          _report = report;
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

  void _selectPeriod(String period) {
    // Employees only see the daily sales view.
    if (ApiClient.role == 'employee') period = 'Daily';
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _period = period;
      switch (period) {
        case 'Daily':
          _dateRange = DateTimeRange(start: today, end: today);
        case 'Weekly':
          _dateRange = DateTimeRange(
            start: today.subtract(const Duration(days: 6)),
            end: today,
          );
        case 'Monthly':
          _dateRange = DateTimeRange(
            start: DateTime(today.year, today.month),
            end: today,
          );
        case 'Yearly':
          _dateRange = DateTimeRange(start: DateTime(today.year), end: today);
        case 'Custom':
          break;
      }
    });
    _loadReport();
  }

  Future<void> _selectDateRange() async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      helpText: 'Select report date range',
    );
    if (selected != null && mounted) {
      setState(() {
        _dateRange = selected;
        _period = 'Custom';
      });
      _loadReport();
    }
  }

  void _selectPreset(String preset) {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _period = 'Custom';
      switch (preset) {
        case 'Last 7 Days':
          _dateRange = DateTimeRange(
            start: today.subtract(const Duration(days: 6)),
            end: today,
          );
        case 'Last 30 Days':
          _dateRange = DateTimeRange(
            start: today.subtract(const Duration(days: 29)),
            end: today,
          );
        case 'This Month':
          _dateRange = DateTimeRange(
            start: DateTime(today.year, today.month),
            end: today,
          );
        default:
          break;
      }
    });
    _loadReport();
  }

  void _resetDateRange() {
    final today = DateUtils.dateOnly(DateTime.now());
    setState(() {
      _period = 'Custom';
      _dateRange = DateTimeRange(
        start: today.subtract(const Duration(days: 13)),
        end: today,
      );
    });
    _loadReport();
  }

  Future<void> _exportReport() async {
    final report = _report;
    if (report == null) {
      showShopMessage(context, 'Load a report before exporting.');
      return;
    }
    final rows = <List<Object?>>[
      ['Malonda Yanga sales report'],
      ['From', _dateRange.start.toIso8601String().substring(0, 10)],
      ['To', _dateRange.end.toIso8601String().substring(0, 10)],
      [],
      ['Metric', 'Value'],
      ['Total sales', report['total_sales']],
      ['Total cost (cost of goods sold)', report['total_cost']],
      ['Gross profit', report['gross_profit']],
      for (final entry in _expenseBreakdown.entries)
        ['Expense - ${entry.key}', entry.value],
      ['Total operating expenses', report['total_expenses']],
      ['Net profit', report['net_profit']],
      ['Number of sales', report['sale_count']],
      [],
      ['Payment method', 'Total'],
      for (final entry in _paymentTotals.entries) [entry.key, entry.value],
      [],
      ['Product', 'Category', 'Quantity sold', 'Revenue'],
      for (final product in _topProducts)
        [
          product['name'],
          product['category'],
          product['quantity'],
          product['revenue'],
        ],
    ];
    final csv = rows.map((row) => row.map(_csvCell).join(',')).join('\r\n');
    final filename =
        'sales-report-${_dateRange.start.toIso8601String().substring(0, 10)}-'
        '${_dateRange.end.toIso8601String().substring(0, 10)}.csv';
    try {
      await SharePlus.instance.share(
        ShareParams(
          title: 'Export sales report',
          files: [
            XFile.fromData(
              utf8.encode(csv),
              name: filename,
              mimeType: 'text/csv',
            ),
          ],
          fileNameOverrides: [filename],
        ),
      );
    } on PlatformException catch (error) {
      if (mounted) {
        showShopMessage(context, error.message ?? 'Could not export report.');
      }
    } on MissingPluginException {
      if (mounted) showShopMessage(context, 'Report sharing is not available.');
    }
  }

  String _csvCell(Object? value) {
    final text = value?.toString() ?? '';
    return '"${text.replaceAll('"', '""')}"';
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ShopColors.surface,
    body: SafeArea(
      child: Column(
        children: [
          _ReportsHeader(role: ApiClient.role),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
              children: [
                _PeriodSelector(
                  selected: _period,
                  onSelected: _selectPeriod,
                  role: ApiClient.role,
                ),
                if (_period == 'Custom') ...[
                  const SizedBox(height: 8),
                  _CustomDateRangeCard(
                    dateRange: _dateRange,
                    onSelectRange: _selectDateRange,
                    onPresetSelected: _selectPreset,
                    onReset: _resetDateRange,
                  ),
                ],
                const SizedBox(height: 10),
                if (_errorMessage != null)
                  Text(
                    'Could not load reports: $_errorMessage',
                    style: const TextStyle(color: ShopColors.red, fontSize: 12),
                  ),
                if (_loading) const LinearProgressIndicator(),
                _SummaryCard(
                  period: _period,
                  report: _report ?? const {},
                  role: ApiClient.role,
                ),
                const SizedBox(height: 11),
                _ProfitLossCard(report: _report ?? const {}),
                const SizedBox(height: 11),

                _SalesChartCard(days: _dailySales),
                const SizedBox(height: 11),
                _SalesLogCard(
                  sales: _report?['sales'] is List
                      ? (_report!['sales'] as List)
                            .whereType<Map<String, dynamic>>()
                            .toList()
                      : const <Map<String, dynamic>>[],
                  onDeleted: _loadReport,
                ),
                const SizedBox(height: 11),
                _ProductsSoldCard(
                  selectedCategory: _selectedCategory,
                  categories: _categories,
                  reportProducts: _topProducts,
                  onCategorySelected: (category) =>
                      setState(() => _selectedCategory = category),
                  onViewInventory: () =>
                      Navigator.pushNamed(context, '/inventory'),
                ),
                const SizedBox(height: 11),
                _PaymentDistributionCard(totals: _paymentTotals),
                const SizedBox(height: 14),
                if (ApiClient.role != 'employee') ...[
                  SizedBox(
                    height: 53,
                    child: FilledButton.icon(
                      onPressed: _exportReport,
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Export Report (CSV / Excel)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: ShopColors.orange,
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: ShopColors.orange.withValues(alpha: .25),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Center(
                    child: Text(
                      'Exported CSV files open in spreadsheet apps.',
                      style: TextStyle(color: ShopColors.muted, fontSize: 10),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
    bottomNavigationBar: _ReportsBottomNavigation(role: ApiClient.role),
  );
}

class _ReportsHeader extends StatelessWidget {
  const _ReportsHeader({this.role});

  final String? role;

  @override
  Widget build(BuildContext context) => Container(
    height: 67,
    padding: const EdgeInsets.symmetric(horizontal: 16),
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
        const Expanded(
          child: ShopHeaderBrand(
            title: 'Reports',
            logoSize: 36,
            nameStyle: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
            titleStyle: TextStyle(
              color: Colors.white,
              fontSize: 17,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (role != 'employee')
          _HeaderAction(
            icon: Icons.search_rounded,
            onPressed: () => Navigator.pushNamed(context, '/inventory'),
          ),
        _HeaderAction(
          icon: Icons.shopping_bag_outlined,
          onPressed: () => Navigator.pushNamed(context, '/sales'),
        ),
        const SizedBox(width: 4),
        if (role != 'employee')
          CircleAvatar(
            radius: 17,
            backgroundColor: ShopColors.primary,
            child: IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              icon: const Icon(
                Icons.person_outline_rounded,
                color: Colors.white,
                size: 19,
              ),
            ),
          ),
      ],
    ),
  );
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    onPressed: onPressed,
    visualDensity: VisualDensity.compact,
    icon: Icon(icon, color: Colors.white, size: 21),
  );
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.selected,
    required this.onSelected,
    this.role,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final String? role;

  @override
  Widget build(BuildContext context) => Container(
    height: 39,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: ShopColors.pale,
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children:
          (role == 'employee'
                  ? ['Daily']
                  : ['Daily', 'Weekly', 'Monthly', 'Yearly', 'Custom'])
              .map((period) {
                final isSelected = selected == period;
                return Expanded(
                  child: GestureDetector(
                    key: Key('reportPeriod$period'),
                    onTap: () => onSelected(period),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? ShopColors.primary
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: isSelected
                            ? const [
                                BoxShadow(
                                  color: Color(0x1A002E7B),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (period == 'Custom') ...[
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : ShopColors.text,
                                ),
                                const SizedBox(width: 2),
                              ],
                              Text(
                                period,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : ShopColors.text,
                                  fontSize: 10,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              })
              .toList(),
    ),
  );
}

class _CustomDateRangeCard extends StatelessWidget {
  const _CustomDateRangeCard({
    required this.dateRange,
    required this.onSelectRange,
    required this.onPresetSelected,
    required this.onReset,
  });

  final DateTimeRange dateRange;
  final VoidCallback onSelectRange;
  final ValueChanged<String> onPresetSelected;
  final VoidCallback onReset;

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) => _ReportCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.date_range_rounded,
              color: ShopColors.primary,
              size: 18,
            ),
            const SizedBox(width: 7),
            const Expanded(
              child: Text(
                'Active Filter Range',
                style: TextStyle(
                  color: ShopColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('reportResetDateRange'),
              onPressed: onReset,
              icon: const Icon(Icons.restart_alt_rounded, size: 15),
              label: const Text('Reset'),
              style: TextButton.styleFrom(
                foregroundColor: ShopColors.muted,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
              ),
            ),
          ],
        ),
        InkWell(
          key: const Key('reportSelectDateRange'),
          onTap: onSelectRange,
          borderRadius: BorderRadius.circular(9),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: ShopColors.pale,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_rounded,
                  color: ShopColors.primary,
                  size: 17,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    '${_formatDate(dateRange.start)} – ${_formatDate(dateRange.end)}',
                    key: const Key('reportActiveDateRange'),
                    style: const TextStyle(
                      color: ShopColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Icons.edit_calendar_rounded,
                  color: ShopColors.muted,
                  size: 17,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final preset in [
              'Last 7 Days',
              'Last 30 Days',
              'This Month',
              'Custom Range',
            ])
              ActionChip(
                key: Key('reportPreset$preset'),
                label: Text(preset),
                onPressed: preset == 'Custom Range'
                    ? onSelectRange
                    : () => onPresetSelected(preset),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                labelStyle: const TextStyle(
                  color: ShopColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: ShopColors.pale,
                side: BorderSide.none,
              ),
          ],
        ),
      ],
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.period, required this.report, this.role});

  final String period;
  final Map<String, dynamic> report;
  final String? role;

  String get _title => switch (period) {
    'Daily' => 'Today’s Summary',
    'Weekly' => 'This Week’s Summary',
    'Monthly' => 'This Month’s Summary',
    'Yearly' => 'Annual Summary',
    _ => 'Custom Range Summary',
  };

  @override
  Widget build(BuildContext context) {
    final sales = (report['total_sales'] as num?)?.toDouble() ?? 0;
    final cost = (report['total_cost'] as num?)?.toDouble() ?? 0;
    final discounts = (report['total_discounts'] as num?)?.toDouble() ?? 0;
    final grossProfit =
        (report['gross_profit'] as num?)?.toDouble() ?? (sales - cost);
    final expenses = (report['total_expenses'] as num?)?.toDouble() ?? 0;
    final netProfit =
        (report['net_profit'] as num?)?.toDouble() ?? (grossProfit - expenses);
    final invoices = (report['sale_count'] as num?)?.toInt() ?? 0;
    return _ReportCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _title,
                  style: const TextStyle(
                    color: ShopColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF0F3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: Color(0xFF45D9A2), size: 7),
                    SizedBox(width: 4),
                    Text(
                      'Live Sync',
                      style: TextStyle(
                        color: ShopColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryMetric(
            icon: Icons.shopping_cart_outlined,
            iconColor: ShopColors.primary,
            iconBackground: ShopColors.paleBlue,
            label: 'Total Sales (Revenue)',
            detail: '$invoices Invoices',
            value: 'K${sales.toStringAsFixed(0)}',
            note: 'For selected period',
            valueColor: ShopColors.primary,
            noteColor: ShopColors.green,
          ),
          if (role != 'employee') ...[
            const SizedBox(height: 8),
            _SummaryMetric(
              icon: Icons.local_offer_outlined,
              iconColor: const Color(0xFFB63F00),
              iconBackground: const Color(0xFFFFECD9),
              label: 'Total Discounts',
              detail: 'Amounts given as discounts',
              value: 'K${discounts.toStringAsFixed(0)}',
              note: 'For selected period',
              valueColor: ShopColors.text,
              noteColor: ShopColors.text,
            ),
            const SizedBox(height: 8),
            _SummaryMetric(
              icon: Icons.inventory_2_outlined,
              iconColor: const Color(0xFFB63F00),
              iconBackground: const Color(0xFFFFDBCC),
              label: 'Cost of Goods Sold',
              detail: 'Product purchase cost',
              value: 'K${cost.toStringAsFixed(0)}',
              note: 'For selected period',
              valueColor: ShopColors.text,
              noteColor: ShopColors.text,
            ),
            const SizedBox(height: 8),
            _SummaryMetric(
              icon: Icons.trending_up_rounded,
              iconColor: ShopColors.green,
              iconBackground: const Color(0xFF6FFBBE),
              label: 'Gross Profit',
              detail: 'Revenue minus cost of goods',
              value: 'K${grossProfit.toStringAsFixed(0)}',
              note: 'For selected period',
              valueColor: ShopColors.green,
              noteColor: ShopColors.green,
            ),
            const SizedBox(height: 8),
            _SummaryMetric(
              icon: Icons.account_balance_outlined,
              iconColor: const Color(0xFF7C4DFF),
              iconBackground: const Color(0xFFEDE7FF),
              label: 'Net Profit',
              detail: 'Gross profit minus expenses',
              value: 'K${netProfit.toStringAsFixed(0)}',
              note: 'After operating expenses',
              valueColor: const Color(0xFF7C4DFF),
              noteColor: const Color(0xFF7C4DFF),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfitLossCard extends StatelessWidget {
  const _ProfitLossCard({required this.report});

  final Map<String, dynamic> report;

  @override
  Widget build(BuildContext context) {
    final sales = (report['total_sales'] as num?)?.toDouble() ?? 0;
    final cost = (report['total_cost'] as num?)?.toDouble() ?? 0;
    final expenses = (report['total_expenses'] as num?)?.toDouble() ?? 0;
    final grossProfit = sales - cost;
    final netProfit =
        (report['net_profit'] as num?)?.toDouble() ?? grossProfit - expenses;
    final grossMargin = sales > 0 ? grossProfit / sales * 100 : 0.0;
    final netMargin = sales > 0 ? netProfit / sales * 100 : 0.0;
    final invoiceCount = (report['sale_count'] as num?)?.toInt() ?? 0;

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Financial Summary',
                  style: TextStyle(
                    color: ShopColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Profit & Loss (Income Statement)',
                style: const TextStyle(color: ShopColors.muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Step 1: Gross Profit
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ShopColors.pale,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E3E9)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calculate_rounded,
                      color: ShopColors.primary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'STEP 1: GROSS PROFIT',
                      style: TextStyle(
                        color: ShopColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Revenue − COGS',
                      style: TextStyle(color: ShopColors.muted, fontSize: 9),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Sales Revenue',
                              style: TextStyle(
                                color: ShopColors.muted,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'K${sales.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: ShopColors.primary,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              '$invoiceCount Invoices',
                              style: const TextStyle(
                                color: ShopColors.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text(
                        '−',
                        style: TextStyle(
                          color: ShopColors.muted,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'COGS (Cost)',
                              style: TextStyle(
                                color: ShopColors.muted,
                                fontSize: 9,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'K${cost.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: ShopColors.red,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const Text(
                              'Direct Items',
                              style: TextStyle(
                                color: ShopColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    const Text(
                      '  =  Gross Profit',
                      style: TextStyle(
                        color: ShopColors.text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'K${grossProfit.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: ShopColors.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: ShopColors.paleBlue,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${grossMargin.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          color: ShopColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          // Step 2: Operating Expenses
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: ShopColors.pale,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE0E3E9)),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFDBCC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_long_rounded,
                    color: ShopColors.orange,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OPERATING EXPENSES (OPEX)',
                        style: TextStyle(
                          color: ShopColors.muted,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '-K${expenses.toStringAsFixed(0)}',
                        key: Key('reportValExpenses'),
                        style: TextStyle(
                          color: ShopColors.red,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/expenses'),
                  icon: const Text(
                    'Manage Expenses',
                    style: TextStyle(
                      color: ShopColors.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  label: const Icon(
                    Icons.arrow_forward_rounded,
                    color: ShopColors.primary,
                    size: 14,
                  ),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: ShopColors.primary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: const BorderSide(color: Color(0xFFE0E3E9)),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 9),
          // Final Net Profit tile
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6FFBBE).withValues(alpha: .4),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF6FFBBE)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: ShopColors.green,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Net Profit',
                            style: TextStyle(
                              color: ShopColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6FFBBE),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Safe Target',
                              style: TextStyle(
                                color: ShopColors.green,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Gross Profit (K${grossProfit.toStringAsFixed(0)}) − OPEX (K${expenses.toStringAsFixed(0)})',
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'K${netProfit.toStringAsFixed(0)}',
                      key: const Key('reportValNetProfit'),
                      style: TextStyle(
                        color: netProfit >= 0
                            ? ShopColors.green
                            : ShopColors.red,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Margin: ${netMargin.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: ShopColors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.label,
    required this.detail,
    required this.value,
    required this.note,
    required this.valueColor,
    required this.noteColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String label;
  final String detail;
  final String value;
  final String note;
  final Color valueColor;
  final Color noteColor;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: ShopColors.pale,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Container(
          width: 39,
          height: 39,
          decoration: BoxDecoration(
            color: iconBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(color: ShopColors.muted, fontSize: 10),
              ),
              Text(
                detail,
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 18,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              note,
              style: TextStyle(
                color: noteColor,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _SalesLogCard extends StatefulWidget {
  const _SalesLogCard({required this.sales, required this.onDeleted});

  final List<Map<String, dynamic>> sales;
  final VoidCallback onDeleted;

  @override
  State<_SalesLogCard> createState() => _SalesLogCardState();
}

class _SalesLogCardState extends State<_SalesLogCard> {
  bool _deleting = false;

  Future<void> _deleteSale(Map<String, dynamic> sale) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete sale?'),
        content: Text(
          'This removes the K${(sale['total'] as num?)?.toStringAsFixed(2) ?? '0'} '
          'record permanently. Sold stock will be returned to inventory.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: ShopColors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ApiClient.deleteSale(sale['id'] as String);
      if (!mounted) return;
      showShopMessage(context, 'Sale deleted.');
      widget.onDeleted();
    } on ApiException catch (error) {
      if (mounted) showShopMessage(context, error.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sales = widget.sales;
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Sales Log',
            style: TextStyle(
              color: ShopColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap the bin to void a mistaken sale',
            style: TextStyle(color: ShopColors.muted, fontSize: 10),
          ),
          const SizedBox(height: 8),
          if (_deleting) const LinearProgressIndicator(),
          if (sales.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: Text(
                  'No sales recorded in this period.',
                  style: TextStyle(color: ShopColors.muted, fontSize: 11),
                ),
              ),
            ),
          for (final sale in sales)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: ShopColors.pale)),
              ),
              child: Builder(
                builder: (context) {
                  final items = (sale['items'] as List<dynamic>?)
                          ?.whereType<Map<String, dynamic>>()
                          .toList() ??
                      const <Map<String, dynamic>>[];
                  String itemLine(Map<String, dynamic> item) {
                    final categoryName = '${item['category'] ?? ''}'.trim();
                    final subCategoryName = '${item['sub_category'] ?? ''}'
                        .trim();
                    final categoryLine = subCategoryName.isEmpty
                        ? categoryName
                        : '$categoryName › $subCategoryName';
                    final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
                    final name = '${item['product_name'] ?? ''}'.trim();
                    return [
                      if (categoryLine.isNotEmpty) categoryLine,
                      if (name.isNotEmpty) name,
                      'x$quantity',
                    ].join(' • ');
                  }
                  return Row(
                    children: [
                  Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: ShopColors.orange.withValues(alpha: .1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      (sale['sale_type'] ?? '').toString().toLowerCase() ==
                              'layby'
                          ? Icons.shopping_bag_outlined
                          : Icons.point_of_sale_outlined,
                      color: ShopColors.orange,
                      size: 20,
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${sale['payment_method'] ?? 'Sale'} • '
                          '${sale['sale_type'] ?? 'Walk-in'}',
                          style: const TextStyle(
                            color: ShopColors.text,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          sale['sold_at']?.toString().substring(0, 16) ?? '',
                          style: const TextStyle(
                            color: ShopColors.muted,
                            fontSize: 9,
                          ),
                        ),
                        // What was sold: category › sub category • name • qty.
                        for (final item in items)
                          Text(
                            itemLine(item),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ShopColors.primaryContainer,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    'K${(sale['total'] as num?)?.toStringAsFixed(2) ?? '0'}',
                    style: const TextStyle(
                      color: ShopColors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    key: Key('deleteSale${sale['id']}'),
                    tooltip: 'Delete sale',
                    onPressed: _deleting ? null : () => _deleteSale(sale),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      color: ShopColors.red,
                      size: 19,
                    ),
                  ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _SalesChartCard extends StatefulWidget {
  const _SalesChartCard({required this.days});

  final List<(String, int)> days;

  @override
  State<_SalesChartCard> createState() => _SalesChartCardState();
}

class _SalesChartCardState extends State<_SalesChartCard> {
  int _selectedDay = 0;

  @override
  Widget build(BuildContext context) {
    final days = widget.days;
    if (days.isEmpty) {
      return const _ReportCard(
        child: Center(child: Text('No sales recorded in this period.')),
      );
    }
    final selectedIndex = _selectedDay.clamp(0, days.length - 1);
    final selected = days[selectedIndex];
    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sales Chart',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Daily Revenue Flow (ZMW)',
                      style: TextStyle(color: ShopColors.muted, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: ShopColors.pale,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.circle, color: ShopColors.primary, size: 8),
                    SizedBox(width: 5),
                    Text(
                      'Target: K1,000',
                      style: TextStyle(
                        color: ShopColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 184,
            child: _SalesChart(
              days: days,
              selectedIndex: selectedIndex,
              onSelected: (index) => setState(() => _selectedDay = index),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${selected.$1} Revenue: K${selected.$2}',
              key: const Key('reportChartSelection'),
              style: const TextStyle(
                color: ShopColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  const _SalesChart({
    required this.days,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<(String, int)> days;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, _) {
      const top = 14.0;
      const bottom = 168.0;
      final maxValue = days.fold<int>(
        1,
        (maximum, day) => day.$2 > maximum ? day.$2 : maximum,
      );
      double y(double value) =>
          (bottom - value / maxValue * (bottom - top)).clamp(top, bottom);

      return Stack(
        children: [
          for (final value in [maxValue.toDouble(), maxValue / 2, 0.0])
            Positioned(
              left: 39,
              right: 0,
              top: y(value),
              child: const Divider(
                height: 1,
                thickness: 1,
                color: Color(0xFFE0E3E9),
              ),
            ),
          Positioned(
            left: 47,
            right: 4,
            top: 0,
            bottom: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var index = 0; index < days.length; index++)
                  Expanded(
                    child: _ChartDay(
                      label: days[index].$1,
                      value: days[index].$2,
                      maxValue: maxValue,
                      selected: index == selectedIndex,
                      onTap: () => onSelected(index),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _ChartDay extends StatelessWidget {
  const _ChartDay({
    required this.label,
    required this.value,
    required this.maxValue,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int value;
  final int maxValue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '$value',
          style: TextStyle(
            color: selected ? ShopColors.primary : ShopColors.muted,
            fontSize: 9,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 3),
        SizedBox(
          height: 145,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: 22,
              height: 145 * (value / maxValue),
              decoration: BoxDecoration(
                color: ShopColors.primaryContainer,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(5),
                ),
                boxShadow: selected
                    ? const [
                        BoxShadow(
                          color: Color(0x1A002E7B),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: selected
                  ? const Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: EdgeInsets.only(top: 3),
                        child: Icon(
                          Icons.circle,
                          color: ShopColors.orange,
                          size: 7,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(
          height: 18,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? ShopColors.primary : ShopColors.text,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProductSale {
  const _ProductSale({
    required this.name,
    required this.category,
    required this.stock,
    required this.quantity,
    required this.revenue,
    required this.performance,
    required this.icon,
    required this.color,
  });

  final String name;
  final String category;
  final int stock;
  final int quantity;
  final String revenue;
  final String performance;
  final IconData icon;
  final Color color;

  factory _ProductSale.fromJson(Map<String, dynamic> json, int rank) {
    final category = (json['category'] as String? ?? '').trim();
    final icon = category.toLowerCase().contains('shoe') ||
            category.toLowerCase().contains('footwear')
        ? Icons.directions_run_rounded
        : category.toLowerCase().contains('jean') ||
              category.toLowerCase().contains('trouser')
        ? Icons.straighten_rounded
        : category.toLowerCase().contains('hoodie') ||
              category.toLowerCase().contains('jacket')
        ? Icons.hiking_rounded
        : Icons.checkroom_rounded;
    return _ProductSale(
      name: json['name'] as String,
      category: category.isEmpty ? 'Uncategorized' : category,
      stock: (json['stock'] as num).toInt(),
      quantity: (json['quantity'] as num).toInt(),
      revenue: 'K${(json['revenue'] as num).toStringAsFixed(0)}',
      performance: rank == 1 ? 'Top Seller' : 'Steady',
      icon: icon,
      color: rank == 1 ? ShopColors.green : ShopColors.primary,
    );
  }
}

class _ProductsSoldCard extends StatelessWidget {
  const _ProductsSoldCard({
    required this.selectedCategory,
    required this.categories,
    required this.onCategorySelected,
    required this.onViewInventory,
    required this.reportProducts,
  });

  final String selectedCategory;
  final List<String> categories;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onViewInventory;
  final List<Map<String, dynamic>> reportProducts;

  @override
  Widget build(BuildContext context) {
    final products = reportProducts
        .asMap()
        .entries
        .map((entry) => _ProductSale.fromJson(entry.value, entry.key + 1))
        .where(
          (product) =>
              selectedCategory == 'All Categories' ||
              product.category == selectedCategory,
        )
        .toList();

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Products Sold',
                  style: TextStyle(
                    color: ShopColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFDBCC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      color: ShopColors.orange,
                      size: 14,
                    ),
                    SizedBox(width: 3),
                    Text(
                      'Ranked by Sales',
                      style: TextStyle(
                        color: ShopColors.orange,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('reportProductCount'),
              onPressed: onViewInventory,
              style: TextButton.styleFrom(
                foregroundColor: ShopColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 3),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Showing ${products.length} items'),
            ),
          ),
          const SizedBox(height: 3),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      key: Key('reportCategory$category'),
                      label: Text(category),
                      selected: category == selectedCategory,
                      onSelected: (_) => onCategorySelected(category),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      labelStyle: TextStyle(
                        color: category == selectedCategory
                            ? Colors.white
                            : ShopColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                      backgroundColor: ShopColors.pale,
                      selectedColor: ShopColors.primary,
                      side: BorderSide.none,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 510,
              child: Column(
                children: [
                  const _ProductTableHeader(),
                  for (var index = 0; index < products.length; index++)
                    _ProductTableRow(rank: index + 1, product: products[index]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductTableHeader extends StatelessWidget {
  const _ProductTableHeader();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 5),
    color: ShopColors.pale,
    child: const Row(
      children: [
        SizedBox(width: 30, child: Text('#', textAlign: TextAlign.center)),
        SizedBox(width: 190, child: Text('Product')),
        SizedBox(width: 65, child: Text('Qty Sold', textAlign: TextAlign.end)),
        SizedBox(width: 90, child: Text('Revenue', textAlign: TextAlign.end)),
        SizedBox(
          width: 110,
          child: Text('Performance', textAlign: TextAlign.end),
        ),
      ],
    ),
  );
}

class _ProductTableRow extends StatelessWidget {
  const _ProductTableRow({required this.rank, required this.product});

  final int rank;
  final _ProductSale product;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 55),
    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 5),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: ShopColors.pale)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 30,
          child: Center(
            child: CircleAvatar(
              radius: 10,
              backgroundColor: rank == 1 ? ShopColors.orange : ShopColors.pale,
              child: Text(
                '$rank',
                style: TextStyle(
                  color: rank == 1 ? Colors.white : ShopColors.muted,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 190,
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ShopColors.pale,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(product.icon, color: product.color, size: 21),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShopColors.text,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Stock: ${product.stock} left',
                      style: const TextStyle(
                        color: ShopColors.muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 65,
          child: Text(
            '${product.quantity}',
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 11),
          ),
        ),
        SizedBox(
          width: 90,
          child: Text(
            product.revenue,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: ShopColors.text,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          width: 110,
          child: Text(
            product.performance,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: product.color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PaymentDistributionCard extends StatelessWidget {
  const _PaymentDistributionCard({required this.totals});

  final Map<String, dynamic> totals;

  @override
  Widget build(BuildContext context) {
    const methods = [
      ('Cash', ShopColors.primary),
      ('Airtel / MTN', ShopColors.orange),
      ('Card POS', ShopColors.green),
    ];
    final total = totals.values.fold<double>(
      0,
      (sum, value) => sum + (value as num).toDouble(),
    );
    final visibleMethods = methods
        .where((method) => (totals[method.$1] as num? ?? 0) > 0)
        .toList();
    return _ReportCard(
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Payment Distribution',
                  style: TextStyle(
                    color: ShopColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                'Lusaka Shop POS',
                style: TextStyle(
                  color: ShopColors.text,
                  fontSize: 9,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final method in visibleMethods)
                    Expanded(
                      flex: ((totals[method.$1] as num) / total * 100)
                          .round()
                          .clamp(1, 100)
                          .toInt(),
                      child: ColoredBox(color: method.$2),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final method in visibleMethods)
                SizedBox(
                  width: 92,
                  child: _PaymentTile(
                    label: method.$1,
                    percent:
                        '${((totals[method.$1] as num) / total * 100).round()}%',
                    value: 'K${(totals[method.$1] as num).toStringAsFixed(0)}',
                    color: method.$2,
                  ),
                ),
              if (visibleMethods.isEmpty)
                const Text('No completed sales in this period.'),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.label,
    required this.percent,
    required this.value,
    required this.color,
  });

  final String label;
  final String percent;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
    decoration: BoxDecoration(
      color: ShopColors.pale,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.circle, color: color, size: 8),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          percent,
          style: const TextStyle(
            color: ShopColors.text,
            fontSize: 15,
            height: 1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(color: ShopColors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0A192033),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _ReportsBottomNavigation extends StatelessWidget {
  const _ReportsBottomNavigation({this.role});

  final String? role;

  @override
  Widget build(BuildContext context) {
    final routes = <_NavInfo>[
      _NavInfo(
        icon: Icons.point_of_sale_outlined,
        label: 'Sales',
        route: '/sales',
      ),
      _NavInfo(
        icon: Icons.bar_chart_rounded,
        label: 'Reports',
        route: '/reports',
      ),
    ];
    if (role != 'employee') {
      routes.insertAll(0, [
        _NavInfo(icon: Icons.home_outlined, label: 'Home', route: '/home'),
        _NavInfo(
          icon: Icons.inventory_2_outlined,
          label: 'Inventory',
          route: '/inventory',
        ),
      ]);
      routes.add(
        _NavInfo(
          icon: Icons.settings_outlined,
          label: 'Settings',
          route: '/settings',
        ),
      );
    }
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
          height: 58,
          child: Row(
            children: routes
                .map(
                  (info) => _ReportsNavItem(
                    icon: info.icon,
                    label: info.label,
                    route: info.route,
                    selected: info.route == '/reports',
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NavInfo {
  const _NavInfo({
    required this.icon,
    required this.label,
    required this.route,
  });
  final IconData icon;
  final String label;
  final String route;
}

class _ReportsNavItem extends StatelessWidget {
  const _ReportsNavItem({
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
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 1),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: color,
                fontSize: 9,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inventory overview shown on the main Reports page. Loads the live product
/// list and summarises stock levels and stock value. Tapping "View inventory"
/// opens the full inventory page.
class _InventorySummaryCard extends StatefulWidget {
  const _InventorySummaryCard();

  @override
  State<_InventorySummaryCard> createState() => _InventorySummaryCardState();
}

class _InventorySummaryCardState extends State<_InventorySummaryCard> {
  List<Map<String, dynamic>> _products = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final products = await ApiClient.products();
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.message;
          _loading = false;
        });
      }
    }
  }

  int _qty(Map<String, dynamic> p) => (p['quantity'] as num?)?.toInt() ?? 0;
  double _price(Map<String, dynamic> p) =>
      (p['price'] as num?)?.toDouble() ?? 0;
  double _cost(Map<String, dynamic> p) =>
      (p['cost'] as num?)?.toDouble() ?? 0;

  @override
  Widget build(BuildContext context) {
    final totalUnits = _products.fold<int>(0, (s, p) => s + _qty(p));
    final lowStock = _products.where((p) => _qty(p) <= 5).length;
    final outOfStock = _products.where((p) => _qty(p) <= 0).length;
    final costValue = _products.fold<double>(
      0,
      (s, p) => s + _cost(p) * _qty(p),
    );
    final retailValue = _products.fold<double>(
      0,
      (s, p) => s + _price(p) * _qty(p),
    );

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Inventory Summary',
                  style: TextStyle(
                    color: ShopColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/inventory'),
                icon: const Text(
                  'View inventory',
                  style: TextStyle(
                    color: ShopColors.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                label: const Icon(
                  Icons.arrow_forward_rounded,
                  color: ShopColors.primary,
                  size: 14,
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (_loading)
            const LinearProgressIndicator()
          else if (_errorMessage != null)
            Text(
              'Could not load inventory: $_errorMessage',
              style: const TextStyle(color: ShopColors.red, fontSize: 11),
            )
          else ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InventoryStat(
                  label: 'Products',
                  value: '${_products.length}',
                  color: ShopColors.primary,
                ),
                _InventoryStat(
                  label: 'Units in stock',
                  value: '$totalUnits',
                  color: ShopColors.green,
                ),
                _InventoryStat(
                  label: 'Low stock',
                  value: '$lowStock',
                  color: ShopColors.orange,
                ),
                _InventoryStat(
                  label: 'Out of stock',
                  value: '$outOfStock',
                  color: ShopColors.red,
                ),
                _InventoryStat(
                  label: 'Value at cost',
                  value: 'K${costValue.toStringAsFixed(0)}',
                  color: ShopColors.text,
                ),
                _InventoryStat(
                  label: 'Value at retail',
                  value: 'K${retailValue.toStringAsFixed(0)}',
                  color: ShopColors.primary,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InventoryStat extends StatelessWidget {
  const _InventoryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 100,
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: ShopColors.pale,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ShopColors.muted, fontSize: 9),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    ),
  );
}
