import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/widgets/app_icon.dart';

final _reportCustomerNamesProvider = StreamProvider<Map<int, String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.customers).watch().map(
        (rows) => {for (final c in rows) c.id: c.name},
      );
});

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Widget _reportTab(String icon, String label) {
    return Tab(
      height: 42,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: AppSizes.iconSM),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Reports', style: Theme.of(context).textTheme.headlineMedium),
                OutlinedButton.icon(
                  icon: const AppIcon(AppIcons.calendarToday, size: 16),
                  label: Text(
                    '${DateFormat('dd/MM/yyyy').format(_dateRange.start)} – ${DateFormat('dd/MM/yyyy').format(_dateRange.end)}',
                  ),
                  onPressed: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _dateRange,
                    );
                    if (range != null) setState(() => _dateRange = range);
                  },
                ),
                _QuickDateBtn(label: 'Today', onTap: () => setState(() => _dateRange = DateTimeRange(start: DateTime.now(), end: DateTime.now()))),
                _QuickDateBtn(label: 'This Month', onTap: () => setState(() => _dateRange = DateTimeRange(
                  start: DateTime(DateTime.now().year, DateTime.now().month, 1),
                  end: DateTime.now(),
                ))),
                _QuickDateBtn(label: 'This Year', onTap: () => setState(() => _dateRange = DateTimeRange(
                  start: DateTime(DateTime.now().year, 1, 1),
                  end: DateTime.now(),
                ))),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius + 4),
                border: Border.all(color: AppColors.divider),
              ),
              child: TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                splashBorderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.25), blurRadius: 6, offset: const Offset(0, 2)),
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: AppSizes.fontSM),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: AppSizes.fontSM),
                tabs: [
                  _reportTab(AppIcons.receiptLong, 'Sales'),
                  _reportTab(AppIcons.trendingUp, 'Profit & Loss'),
                  _reportTab(AppIcons.inventory, 'Stock'),
                  _reportTab(AppIcons.eventBusy, 'Expiry'),
                  _reportTab(AppIcons.accountBalanceWallet, 'Customer Ledger'),
                  _reportTab(AppIcons.today, 'Day Closing'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _SalesReport(dateRange: _dateRange),
                  _ProfitLossReport(dateRange: _dateRange),
                  _StockReport(),
                  _ExpiryReport(),
                  _CustomerLedgerReport(),
                  _DayClosingReport(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickDateBtn extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickDateBtn({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

class _SalesReport extends ConsumerWidget {
  final DateTimeRange dateRange;
  const _SalesReport({required this.dateRange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final nf = NumberFormat('#,##0.00');
    final df = DateFormat('dd/MM/yyyy');
    final customerNames = ref.watch(_reportCustomerNamesProvider).value ?? {};

    return FutureBuilder<List<Sale>>(
      future: (db.select(db.sales)
            ..where((s) =>
                s.saleDate.isBiggerOrEqualValue(dateRange.start) &
                s.saleDate.isSmallerOrEqualValue(dateRange.end.add(const Duration(days: 1))))
            ..orderBy([(s) => OrderingTerm.desc(s.saleDate)]))
          .get(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final sales = snap.data!;
        final totalRevenue = sales.fold(0.0, (s, x) => s + x.totalAmount);
        final totalDiscount = sales.fold(0.0, (s, x) => s + x.discountAmount);

        return Column(
          children: [
            // Summary cards
            LayoutBuilder(builder: (context, constraints) {
              final cards = [
                _ReportCard(title: 'Total Sales', value: '${sales.length}', icon: AppIcons.receiptLong, color: AppColors.primary),
                _ReportCard(title: 'Total Revenue', value: 'Rs. ${nf.format(totalRevenue)}', icon: AppIcons.payments, color: AppColors.success),
                _ReportCard(title: 'Total Discount', value: 'Rs. ${nf.format(totalDiscount)}', icon: AppIcons.discount, color: AppColors.warning),
                _ReportCard(title: 'Avg Sale Value', value: 'Rs. ${nf.format(sales.isEmpty ? 0 : totalRevenue / sales.length)}', icon: AppIcons.analytics, color: AppColors.accent),
              ];
              if (constraints.maxWidth < 800) {
                return Column(children: [
                  Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
                  const SizedBox(height: 10),
                  Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
                ]);
              }
              return Row(children: [
                Expanded(child: cards[0]), const SizedBox(width: 12),
                Expanded(child: cards[1]), const SizedBox(width: 12),
                Expanded(child: cards[2]), const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ]);
            }),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.background),
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('Invoice')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Total'), numeric: true),
                      DataColumn(label: Text('Discount'), numeric: true),
                      DataColumn(label: Text('Paid'), numeric: true),
                      DataColumn(label: Text('Payment')),
                      DataColumn(label: Text('Status')),
                      DataColumn(label: Text('')),
                    ],
                    rows: sales.asMap().entries.map((e) {
                      final s = e.value;
                      return DataRow(cells: [
                        DataCell(Text('${e.key + 1}', style: const TextStyle(color: AppColors.textHint))),
                        DataCell(Text(s.invoiceNo, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500))),
                        DataCell(Text(df.format(s.saleDate))),
                        DataCell(Text(s.customerId != null ? (customerNames[s.customerId] ?? 'Walk-in') : 'Walk-in')),
                        DataCell(Text('Rs. ${nf.format(s.totalAmount)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text('Rs. ${nf.format(s.discountAmount)}', style: const TextStyle(color: AppColors.error))),
                        DataCell(Text('Rs. ${nf.format(s.paidAmount)}')),
                        DataCell(Text(s.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 12))),
                        DataCell(_StatusBadge(status: s.status)),
                        DataCell(IconButton(
                          icon: const AppIcon(AppIcons.receipt, size: 18, color: AppColors.primary),
                          tooltip: 'View Invoice',
                          onPressed: () => showInvoiceDetailDialog(context, db, s, customerNames[s.customerId]),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

Future<void> showInvoiceDetailDialog(BuildContext context, AppDatabase db, Sale sale, String? customerName) async {
  final nf = NumberFormat('#,##0.00');
  final df = DateFormat('dd/MM/yyyy hh:mm a');

  await showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          const AppIcon(AppIcons.receipt, color: AppColors.primary, size: 22),
          const SizedBox(width: 8),
          Expanded(child: Text(sale.invoiceNo, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: FutureBuilder<List<SaleItem>>(
          future: (db.select(db.saleItems)..where((i) => i.saleId.equals(sale.id))).get(),
          builder: (_, snap) {
            if (!snap.hasData) {
              return const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
            }
            final items = snap.data!;
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(df.format(sale.saleDate), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                Text('Customer: ${customerName ?? 'Walk-in'}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                const SizedBox(height: 12),
                if (items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No items found for this invoice', style: TextStyle(color: AppColors.textHint)),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxHeight: 260),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final item = items[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.medicineName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                                    Text(
                                      '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} x Rs. ${nf.format(item.unitPrice)}'
                                      '${item.batchNo != null ? ' · Batch ${item.batchNo}' : ''}',
                                      style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text('Rs. ${nf.format(item.totalPrice)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                const Divider(),
                _SummaryRow('Subtotal', 'Rs. ${nf.format(sale.subtotal)}'),
                if (sale.discountAmount > 0) _SummaryRow('Discount', '-Rs. ${nf.format(sale.discountAmount)}', color: AppColors.error),
                if (sale.taxAmount > 0) _SummaryRow('Tax', 'Rs. ${nf.format(sale.taxAmount)}'),
                _SummaryRow('Total', 'Rs. ${nf.format(sale.totalAmount)}', isBold: true, fontSize: 16),
                _SummaryRow('Paid', 'Rs. ${nf.format(sale.paidAmount)}'),
                if (sale.creditAmount > 0) _SummaryRow('Balance Due', 'Rs. ${nf.format(sale.creditAmount)}', color: AppColors.error),
              ],
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
      ],
    ),
  );
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final double fontSize;
  final Color? color;
  const _SummaryRow(this.label, this.value, {this.isBold = false, this.fontSize = 13, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize - 2, color: AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: color ?? AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'completed' => AppColors.success,
      'returned' => AppColors.error,
      'hold' => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
    );
  }
}

class _ProfitLossReport extends ConsumerWidget {
  final DateTimeRange dateRange;
  const _ProfitLossReport({required this.dateRange});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nf = NumberFormat('#,##0.00');

    Future<Map<String, double>> loadData() async {
        final db = ref.read(databaseProvider);
        final result = await db.customSelect(
          '''SELECT
            COALESCE(SUM(s.total_amount), 0) as revenue,
            COALESCE(SUM(si.purchase_price * si.quantity), 0) as cogs,
            COALESCE(SUM(s.discount_amount), 0) as discount,
            COALESCE(SUM(s.tax_amount), 0) as tax
          FROM sales s
          JOIN sale_items si ON si.sale_id = s.id
          WHERE s.sale_date >= ? AND s.sale_date <= ? AND s.status = 'completed'
          ''',
          variables: [Variable(dateRange.start), Variable(dateRange.end.add(const Duration(days: 1)))],
          readsFrom: {db.sales, db.saleItems},
        ).getSingleOrNull();

        if (result == null) return {};
        final revenue = (result.data['revenue'] as num).toDouble();
        final cogs = (result.data['cogs'] as num).toDouble();
        final discount = (result.data['discount'] as num).toDouble();
        final tax = (result.data['tax'] as num).toDouble();

        // Get expenses
        final expenses = await db.customSelect(
          'SELECT COALESCE(SUM(amount), 0) as total FROM expenses WHERE expense_date >= ? AND expense_date <= ?',
          variables: [Variable(dateRange.start), Variable(dateRange.end)],
          readsFrom: {db.expenses},
        ).getSingleOrNull();
        final totalExpenses = (expenses?.data['total'] as num?)?.toDouble() ?? 0;

        final grossProfit = revenue - cogs - discount;
        final netProfit = grossProfit - totalExpenses + tax;

        return {
          'revenue': revenue,
          'cogs': cogs,
          'discount': discount,
          'tax': tax,
          'expenses': totalExpenses,
          'grossProfit': grossProfit,
          'netProfit': netProfit,
        };
    }
    return FutureBuilder<Map<String, double>>(
      future: loadData(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final d = snap.data!;

        Widget plStatement = Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Profit & Loss Statement', style: Theme.of(context).textTheme.titleLarge),
                Text(
                  '${DateFormat('dd/MM/yyyy').format(dateRange.start)} to ${DateFormat('dd/MM/yyyy').format(dateRange.end)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                _PLRow('Revenue', d['revenue'] ?? 0, nf, isBold: true),
                _PLRow('Cost of Goods Sold (COGS)', -(d['cogs'] ?? 0), nf),
                _PLRow('Discount Given', -(d['discount'] ?? 0), nf),
                const Divider(),
                _PLRow('GROSS PROFIT', d['grossProfit'] ?? 0, nf, isBold: true, isHighlight: true),
                const SizedBox(height: 12),
                Text('Operating Expenses', style: Theme.of(context).textTheme.titleSmall),
                _PLRow('Total Expenses', -(d['expenses'] ?? 0), nf),
                _PLRow('Tax Collected', d['tax'] ?? 0, nf),
                const Divider(),
                _PLRow('NET PROFIT', d['netProfit'] ?? 0, nf, isBold: true, isHighlight: true, large: true),
              ],
            ),
          ),
        );
        Widget pieCard = Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text('Breakdown', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: PieChart(PieChartData(sections: [
                    PieChartSectionData(value: (d['netProfit'] ?? 0).clamp(0, double.infinity), title: 'Profit\n${nf.format(d['netProfit'] ?? 0)}', color: AppColors.success, radius: 80, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    PieChartSectionData(value: d['cogs'] ?? 0, title: 'COGS\n${nf.format(d['cogs'] ?? 0)}', color: AppColors.primary, radius: 80, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    PieChartSectionData(value: d['expenses'] ?? 0, title: 'Exp\n${nf.format(d['expenses'] ?? 0)}', color: AppColors.error, radius: 80, titleStyle: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                  ])),
                ),
              ],
            ),
          ),
        );
        return Column(
          children: [
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth < 800) {
                return Column(children: [plStatement, const SizedBox(height: 16), pieCard]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: plStatement),
                const SizedBox(width: 16),
                SizedBox(width: (constraints.maxWidth * 0.28).clamp(240.0, 320.0), child: pieCard),
              ]);
            }),
          ],
        );
      },
    );
  }
}

class _PLRow extends StatelessWidget {
  final String label;
  final double value;
  final NumberFormat nf;
  final bool isBold;
  final bool isHighlight;
  final bool large;

  const _PLRow(this.label, this.value, this.nf, {this.isBold = false, this.isHighlight = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    final isNegative = value < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.normal,
              fontSize: large ? 16 : 14,
              color: isHighlight ? (value >= 0 ? AppColors.success : AppColors.error) : null,
            ),
          ),
          Text(
            '${isNegative ? '-' : ''}Rs. ${nf.format(value.abs())}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              fontSize: large ? 18 : 14,
              color: isHighlight
                  ? (value >= 0 ? AppColors.success : AppColors.error)
                  : isNegative
                      ? AppColors.error
                      : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockReport extends ConsumerWidget {
  const _StockReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final nf = NumberFormat('#,##0.00');

    return FutureBuilder<List<Medicine>>(
      future: (db.select(db.medicines)..where((m) => m.isActive.equals(true))..orderBy([(m) => OrderingTerm.asc(m.name)])).get(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final medicines = snap.data!;
        final totalValue = medicines.fold(0.0, (s, m) => s + m.stock * m.purchasePrice);
        final totalRetailValue = medicines.fold(0.0, (s, m) => s + m.stock * m.salePrice);

        return Column(
          children: [
            LayoutBuilder(builder: (context, constraints) {
              final cards = [
                _ReportCard(title: 'Total SKUs', value: '${medicines.length}', icon: AppIcons.medication, color: AppColors.primary),
                _ReportCard(title: 'Stock Value (Cost)', value: 'Rs. ${nf.format(totalValue)}', icon: AppIcons.inventory, color: AppColors.success),
                _ReportCard(title: 'Stock Value (Retail)', value: 'Rs. ${nf.format(totalRetailValue)}', icon: AppIcons.priceCheck, color: AppColors.accent),
                _ReportCard(title: 'Low/Out of Stock', value: '${medicines.where((m) => m.stock <= m.minStockLevel).length}', icon: AppIcons.warning, color: AppColors.warning),
              ];
              if (constraints.maxWidth < 800) {
                return Column(children: [
                  Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
                  const SizedBox(height: 10),
                  Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
                ]);
              }
              return Row(children: [
                Expanded(child: cards[0]), const SizedBox(width: 12),
                Expanded(child: cards[1]), const SizedBox(width: 12),
                Expanded(child: cards[2]), const SizedBox(width: 12),
                Expanded(child: cards[3]),
              ]);
            }),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.background),
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('Medicine')),
                      DataColumn(label: Text('Generic')),
                      DataColumn(label: Text('Stock'), numeric: true),
                      DataColumn(label: Text('Purchase Price'), numeric: true),
                      DataColumn(label: Text('Sale Price'), numeric: true),
                      DataColumn(label: Text('Stock Value'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: medicines.asMap().entries.map((e) {
                      final m = e.value;
                      final isLow = m.stock <= m.minStockLevel && m.stock > 0;
                      final isOut = m.stock <= 0;
                      return DataRow(cells: [
                        DataCell(Text('${e.key + 1}', style: const TextStyle(color: AppColors.textHint))),
                        DataCell(Text(m.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(m.genericName ?? '-')),
                        DataCell(Text('${m.stock}', style: TextStyle(fontWeight: FontWeight.w600, color: isOut ? AppColors.outOfStock : isLow ? AppColors.lowStock : AppColors.inStock))),
                        DataCell(Text('Rs. ${nf.format(m.purchasePrice)}')),
                        DataCell(Text('Rs. ${nf.format(m.salePrice)}')),
                        DataCell(Text('Rs. ${nf.format(m.stock * m.purchasePrice)}', style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (isOut ? AppColors.outOfStock : isLow ? AppColors.lowStock : AppColors.inStock).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            isOut ? 'Out' : isLow ? 'Low' : 'OK',
                            style: TextStyle(fontSize: 11, color: isOut ? AppColors.outOfStock : isLow ? AppColors.lowStock : AppColors.inStock, fontWeight: FontWeight.w600),
                          ),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ExpiryReport extends ConsumerWidget {
  const _ExpiryReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final df = DateFormat('dd/MM/yyyy');

    return FutureBuilder<List<StockBatche>>(
      future: (db.select(db.stockBatches)
            ..where((b) => b.remainingQty.isBiggerThanValue(0))
            ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
          .get(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final batches = snap.data!;

        return Card(
          child: SingleChildScrollView(
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Medicine ID')),
                DataColumn(label: Text('Batch No')),
                DataColumn(label: Text('Expiry Date')),
                DataColumn(label: Text('Days Left'), numeric: true),
                DataColumn(label: Text('Qty'), numeric: true),
                DataColumn(label: Text('Status')),
              ],
              rows: batches.asMap().entries.map((e) {
                final b = e.value;
                final daysLeft = b.expiryDate.difference(DateTime.now()).inDays;
                final isExpired = daysLeft < 0;
                final isCritical = daysLeft >= 0 && daysLeft <= 30;
                final isWarning = daysLeft > 30 && daysLeft <= 90;
                final color = isExpired ? AppColors.expired : isCritical ? AppColors.error : isWarning ? AppColors.warning : AppColors.success;

                return DataRow(cells: [
                  DataCell(Text('${e.key + 1}', style: const TextStyle(color: AppColors.textHint))),
                  DataCell(Text('${b.medicineId}')),
                  DataCell(Text(b.batchNo, style: const TextStyle(fontWeight: FontWeight.w500))),
                  DataCell(Text(df.format(b.expiryDate))),
                  DataCell(Text(
                    isExpired ? 'Expired' : '$daysLeft',
                    style: TextStyle(fontWeight: FontWeight.w600, color: color),
                  )),
                  DataCell(Text('${b.remainingQty}')),
                  DataCell(Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      isExpired ? 'EXPIRED' : isCritical ? 'CRITICAL' : isWarning ? 'WARNING' : 'GOOD',
                      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w700),
                    ),
                  )),
                ]);
              }).toList(),
            ),
          ),
        );
      },
    );
  }
}

class _CustomerLedgerReport extends ConsumerWidget {
  const _CustomerLedgerReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    final nf = NumberFormat('#,##0.00');

    return FutureBuilder<List<Customer>>(
      future: (db.select(db.customers)..where((c) => c.balance.isBiggerThanValue(0) & c.isActive.equals(true))..orderBy([(c) => OrderingTerm.desc(c.balance)])).get(),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final customers = snap.data!;
        final totalDue = customers.fold(0.0, (s, c) => s + c.balance);

        return Column(
          children: [
            Row(children: [
              Expanded(child: _ReportCard(title: 'Customers with Balance', value: '${customers.length}', icon: AppIcons.people, color: AppColors.primary)),
              const SizedBox(width: 12),
              Expanded(child: _ReportCard(title: 'Total Receivable', value: 'Rs. ${nf.format(totalDue)}', icon: AppIcons.accountBalanceWallet, color: AppColors.error)),
            ]),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: SingleChildScrollView(
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(AppColors.background),
                    columns: const [
                      DataColumn(label: Text('#')),
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Phone')),
                      DataColumn(label: Text('Balance'), numeric: true),
                      DataColumn(label: Text('Credit Limit'), numeric: true),
                    ],
                    rows: customers.asMap().entries.map((e) {
                      final c = e.value;
                      return DataRow(cells: [
                        DataCell(Text('${e.key + 1}')),
                        DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                        DataCell(Text(c.phone ?? '-')),
                        DataCell(Text('Rs. ${nf.format(c.balance)}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.error))),
                        DataCell(Text('Rs. ${nf.format(c.creditLimit)}')),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _DayClosingReport extends ConsumerWidget {
  const _DayClosingReport();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saleRepo = ref.watch(saleRepositoryProvider);
    final nf = NumberFormat('#,##0.00');

    return FutureBuilder<DailySummary>(
      future: saleRepo.getDailySummary(DateTime.now()),
      builder: (_, snap) {
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final s = snap.data!;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const AppIcon(AppIcons.today, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text('Day Closing Report — ${DateFormat('dd MMMM yyyy').format(DateTime.now())}', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  ElevatedButton.icon(icon: const AppIcon(AppIcons.print, size: 18), label: const Text('Print'), onPressed: () {}),
                ]),
                const SizedBox(height: 24),
                LayoutBuilder(builder: (context, constraints) {
                  Widget dayRows = Column(children: [
                    _DayRow('Total Invoices', '${s.totalSales}'),
                    _DayRow('Total Revenue', 'Rs. ${nf.format(s.totalRevenue)}', highlight: true),
                    _DayRow('Total Discount', 'Rs. ${nf.format(s.totalDiscount)}', isNeg: true),
                    _DayRow('Tax Collected', 'Rs. ${nf.format(s.totalTax)}'),
                    const Divider(),
                    _DayRow('Cash Received', 'Rs. ${nf.format(s.totalCash)}', highlight: true),
                    _DayRow('Credit Sales', 'Rs. ${nf.format(s.totalCredit)}', isNeg: true),
                    const Divider(),
                    _DayRow('GROSS PROFIT', 'Rs. ${nf.format(s.totalProfit)}', highlight: true, large: true),
                  ]);
                  Widget pie = SizedBox(
                    height: 180,
                    child: PieChart(PieChartData(sections: [
                      PieChartSectionData(value: s.totalProfit.clamp(0, double.infinity), color: AppColors.success, title: 'Profit', titleStyle: const TextStyle(color: Colors.white, fontSize: 11)),
                      PieChartSectionData(value: (s.totalRevenue - s.totalProfit).clamp(0, double.infinity), color: AppColors.primary, title: 'Cost', titleStyle: const TextStyle(color: Colors.white, fontSize: 11)),
                    ])),
                  );
                  if (constraints.maxWidth < 600) {
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [dayRows, const SizedBox(height: 24), pie]);
                  }
                  return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: dayRows),
                    const SizedBox(width: 32),
                    SizedBox(width: (constraints.maxWidth * 0.28).clamp(160.0, 220.0), height: 180, child: pie),
                  ]);
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;
  final bool isNeg;
  final bool large;
  const _DayRow(this.label, this.value, {this.highlight = false, this.isNeg = false, this.large = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: large ? 16 : 14, fontWeight: large ? FontWeight.w700 : FontWeight.normal)),
          Text(
            value,
            style: TextStyle(
              fontSize: large ? 18 : 14,
              fontWeight: FontWeight.w600,
              color: highlight ? AppColors.success : isNeg ? AppColors.error : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String value;
  final String icon;
  final Color color;
  const _ReportCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: AppIcon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
