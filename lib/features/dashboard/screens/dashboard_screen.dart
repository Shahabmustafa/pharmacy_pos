import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:fl_chart/fl_chart.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/local/database/app_database.dart';
import '../../../core/widgets/app_icon.dart';

final _todaySummaryProvider = FutureProvider<DailySummary>((ref) async {
  return ref.watch(saleRepositoryProvider).getDailySummary(DateTime.now());
});

final _lowStockProvider = FutureProvider<List<Medicine>>((ref) async {
  return ref.watch(medicineRepositoryProvider).getLowStock();
});

final _weeklySalesProvider = FutureProvider<List<DailyRevenue>>((ref) async {
  return ref.watch(saleRepositoryProvider).getWeeklySales();
});

final _topProductsProvider = FutureProvider<List<TopProduct>>((ref) async {
  return ref.watch(saleRepositoryProvider).getTopSellingProducts();
});

final _expiryAlertProvider = FutureProvider<List<StockBatche>>((ref) async {
  final db = ref.watch(databaseProvider);
  final warningDays = int.tryParse(
        await ref.watch(settingsRepositoryProvider).get('expiry_warning_days') ?? '90',
      ) ?? 90;
  final cutoff = DateTime.now().add(Duration(days: warningDays));
  return (db.select(db.stockBatches)
        ..where((b) => b.expiryDate.isSmallerOrEqualValue(cutoff) & b.remainingQty.isBiggerOrEqualValue(0))
        ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)])
        ..limit(20))
      .get();
});

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(_todaySummaryProvider);
    final lowStock = ref.watch(_lowStockProvider);
    final expiryAlerts = ref.watch(_expiryAlertProvider);
    final weeklySales = ref.watch(_weeklySalesProvider);
    final topProducts = ref.watch(_topProductsProvider);
    final nf = NumberFormat('#,##0', 'en_PK');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dashboard', style: Theme.of(context).textTheme.headlineMedium),
                    Text(
                      DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now()),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/pos'),
                  icon: const AppIcon(AppIcons.pointOfSale),
                  label: const Text('New Sale'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Summary cards
            summary.when(
              loading: () => const _SummaryCardsSkeleton(),
              error: (_, __) => const Text('Error loading summary'),
              data: (s) {
                final cards = [
                  _SummaryCard(title: "Today's Sales", value: 'Rs. ${nf.format(s.totalRevenue)}', subtitle: '${s.totalSales} invoices', icon: AppIcons.receiptLong, color: AppColors.primary, onTap: () => context.go('/reports')),
                  _SummaryCard(title: "Today's Profit", value: 'Rs. ${nf.format(s.totalProfit)}', subtitle: s.totalRevenue > 0 ? '${(s.totalProfit / s.totalRevenue * 100).toStringAsFixed(1)}% margin' : '0% margin', icon: AppIcons.trendingUp, color: AppColors.success, onTap: () => context.go('/reports')),
                  _SummaryCard(title: 'Cash Received', value: 'Rs. ${nf.format(s.totalCash)}', subtitle: 'Rs. ${nf.format(s.totalCredit)} on credit', icon: AppIcons.payments, color: AppColors.accent, onTap: () => context.go('/reports')),
                  _SummaryCard(title: 'Total Discount', value: 'Rs. ${nf.format(s.totalDiscount)}', subtitle: 'Given today', icon: AppIcons.discount, color: AppColors.warning, onTap: () => context.go('/reports')),
                ];
                return LayoutBuilder(builder: (context, constraints) {
                  if (constraints.maxWidth < 900) {
                    return Column(children: [
                      Row(children: [Expanded(child: cards[0]), const SizedBox(width: 12), Expanded(child: cards[1])]),
                      const SizedBox(height: 12),
                      Row(children: [Expanded(child: cards[2]), const SizedBox(width: 12), Expanded(child: cards[3])]),
                    ]);
                  }
                  return Row(children: [
                    Expanded(child: cards[0]), const SizedBox(width: 16),
                    Expanded(child: cards[1]), const SizedBox(width: 16),
                    Expanded(child: cards[2]), const SizedBox(width: 16),
                    Expanded(child: cards[3]),
                  ]);
                });
              },
            ),
            const SizedBox(height: 24),

            // Alerts row
            LayoutBuilder(builder: (context, constraints) {
              final lowStockCard = _AlertCard(
                title: 'Low Stock Alerts', icon: AppIcons.warningAmber, color: AppColors.warning,
                child: lowStock.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Error'),
                  data: (items) => items.isEmpty
                      ? const _EmptyAlert(message: 'All medicines are well stocked')
                      : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length.clamp(0, 8), itemBuilder: (_, i) => _StockAlertRow(medicine: items[i])),
                ),
                actionLabel: 'View All', onAction: () => context.go('/inventory'),
              );
              final expiryCard = _AlertCard(
                title: 'Expiry Alerts', icon: AppIcons.eventBusy, color: AppColors.error,
                child: expiryAlerts.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, __) => const Text('Error'),
                  data: (batches) => batches.isEmpty
                      ? const _EmptyAlert(message: 'No medicines expiring soon')
                      : ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: batches.length.clamp(0, 8), itemBuilder: (_, i) => _ExpiryAlertRow(batch: batches[i])),
                ),
                actionLabel: 'View Report', onAction: () => context.go('/reports'),
              );
              if (constraints.maxWidth < 700) {
                return Column(children: [lowStockCard, const SizedBox(height: 16), expiryCard]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: lowStockCard), const SizedBox(width: 16), Expanded(child: expiryCard),
              ]);
            }),
            const SizedBox(height: 24),

            // Sales trend & top selling products
            LayoutBuilder(builder: (context, constraints) {
              final chartCard = _WeeklySalesChart(data: weeklySales);
              final topCard = _TopProductsCard(data: topProducts);
              if (constraints.maxWidth < 900) {
                return Column(children: [chartCard, const SizedBox(height: 16), topCard]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 2, child: chartCard),
                const SizedBox(width: 16),
                Expanded(child: topCard),
              ]);
            }),
            const SizedBox(height: 24),

            // Quick actions
            Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _QuickAction(icon: AppIcons.pointOfSale, label: 'New Sale', color: AppColors.primary, onTap: () => context.go('/pos')),
                _QuickAction(icon: AppIcons.shoppingCart, label: 'New Purchase', color: AppColors.accent, onTap: () => context.go('/purchases/add')),
                _QuickAction(icon: AppIcons.personAdd, label: 'Add Customer', color: AppColors.success, onTap: () => context.go('/customers')),
                _QuickAction(icon: AppIcons.medication, label: 'Add Medicine', color: AppColors.warning, onTap: () => context.go('/inventory/add')),
                _QuickAction(icon: AppIcons.barChart, label: 'Day Report', color: AppColors.info, onTap: () => context.go('/reports')),
                _QuickAction(icon: AppIcons.receiptLong, label: 'Add Expense', color: AppColors.error, onTap: () => context.go('/expenses')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final String icon;
  final Color color;
  final VoidCallback? onTap;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.cardRadius),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: AppIcon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, fontFamily: 'Poppins'),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final String title;
  final String icon;
  final Color color;
  final Widget child;
  final String actionLabel;
  final VoidCallback? onAction;

  const _AlertCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
    required this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(onPressed: onAction, child: Text(actionLabel)),
              ],
            ),
            const Divider(),
            child,
          ],
        ),
      ),
    );
  }
}

class _WeeklySalesChart extends StatelessWidget {
  final AsyncValue<List<DailyRevenue>> data;
  const _WeeklySalesChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat.compact();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIcon(AppIcons.trendingUp, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Weekly Sales', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const Divider(),
            SizedBox(
              height: 220,
              child: data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Error loading sales trend')),
                data: (days) {
                  if (days.every((d) => d.revenue == 0)) {
                    return const _EmptyAlert(message: 'No sales recorded in the last 7 days');
                  }
                  final maxRevenue = days.map((d) => d.revenue).reduce((a, b) => a > b ? a : b);
                  final maxY = maxRevenue <= 0 ? 100.0 : maxRevenue * 1.2;

                  return LineChart(
                    LineChartData(
                      minY: 0,
                      maxY: maxY,
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 4,
                        getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1),
                      ),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 42,
                            interval: maxY / 4,
                            getTitlesWidget: (v, meta) => Text(
                              nf.format(v),
                              style: const TextStyle(fontSize: 10, color: AppColors.textHint),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 24,
                            getTitlesWidget: (v, meta) {
                              final i = v.toInt();
                              if (i < 0 || i >= days.length) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  DateFormat('EEE').format(days[i].date),
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipItems: (spots) => spots.map((s) {
                            final i = s.x.toInt();
                            final label = i >= 0 && i < days.length ? DateFormat('EEE, d MMM').format(days[i].date) : '';
                            return LineTooltipItem(
                              '$label\nRs. ${NumberFormat('#,##0').format(s.y)}',
                              const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            );
                          }).toList(),
                        ),
                      ),
                      lineBarsData: [
                        LineChartBarData(
                          spots: [for (var i = 0; i < days.length; i++) FlSpot(i.toDouble(), days[i].revenue)],
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [AppColors.primary.withValues(alpha: 0.22), AppColors.primary.withValues(alpha: 0.0)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopProductsCard extends StatelessWidget {
  final AsyncValue<List<TopProduct>> data;
  const _TopProductsCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const AppIcon(AppIcons.medication, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Top Selling (7 Days)', style: Theme.of(context).textTheme.titleMedium, overflow: TextOverflow.ellipsis)),
              ],
            ),
            const Divider(),
            data.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Text('Error loading top products'),
              data: (items) {
                if (items.isEmpty) {
                  return const _EmptyAlert(message: 'No sales recorded in the last 7 days');
                }
                final best = items.first;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                        border: Border.all(color: AppColors.success.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Text('🏆', style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(best.medicineName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                                Text('${best.totalQty.toStringAsFixed(0)} units sold', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: items.length.clamp(0, 5),
                      separatorBuilder: (_, __) => const Divider(height: 12),
                      itemBuilder: (_, i) {
                        final p = items[i];
                        return Row(
                          children: [
                            SizedBox(
                              width: 18,
                              child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: AppColors.textHint, fontWeight: FontWeight.w600)),
                            ),
                            Expanded(
                              child: Text(p.medicineName, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                            ),
                            Text(p.totalQty.toStringAsFixed(0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                          ],
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StockAlertRow extends StatelessWidget {
  final Medicine medicine;
  const _StockAlertRow({required this.medicine});

  @override
  Widget build(BuildContext context) {
    final isOut = medicine.stock <= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isOut ? AppColors.outOfStock : AppColors.lowStock,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(medicine.name, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
          Text(
            '${medicine.stock}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isOut ? AppColors.outOfStock : AppColors.lowStock,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpiryAlertRow extends StatelessWidget {
  final StockBatche batch;
  const _ExpiryAlertRow({required this.batch});

  @override
  Widget build(BuildContext context) {
    final daysLeft = batch.expiryDate.difference(DateTime.now()).inDays;
    final isExpired = daysLeft < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isExpired ? AppColors.expired : AppColors.expiringSoon,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Batch: ${batch.batchNo}', style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis),
          ),
          Text(
            isExpired ? 'Expired' : '$daysLeft days',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isExpired ? AppColors.expired : AppColors.expiringSoon,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppIcon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _EmptyAlert extends StatelessWidget {
  final String message;
  const _EmptyAlert({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const AppIcon(AppIcons.checkCircle, color: AppColors.success, size: 16),
          const SizedBox(width: 8),
          Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}

class _SummaryCardsSkeleton extends StatelessWidget {
  const _SummaryCardsSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cols = constraints.maxWidth < 900 ? 2 : 4;
      final children = List.generate(cols, (_) => Expanded(
        child: Card(child: Container(height: 80, color: Colors.grey.shade100)),
      ));
      if (cols == 2) {
        return Column(children: [
          Row(children: [...children.sublist(0, 2).expand((w) => [w, const SizedBox(width: 12)]).toList()..removeLast()]),
          const SizedBox(height: 12),
          Row(children: [...List.generate(2, (_) => Expanded(child: Card(child: Container(height: 80, color: Colors.grey.shade100)))).expand((w) => [w, const SizedBox(width: 12)]).toList()..removeLast()]),
        ]);
      }
      return Row(children: [...children.expand((w) => [w, const SizedBox(width: 16)]).toList()..removeLast()]);
    });
  }
}
