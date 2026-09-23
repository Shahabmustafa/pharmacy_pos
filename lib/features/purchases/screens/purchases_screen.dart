import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/widgets/app_icon.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final nf = NumberFormat('#,##0.00');
    final df = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Purchases', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const AppIcon(AppIcons.add),
                  label: const Text('New Purchase'),
                  onPressed: () => context.go('/purchases/add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(hintText: 'Search by invoice no or supplier...', prefixIcon: AppIcon(AppIcons.search)),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: StreamBuilder<List<Purchase>>(
                  stream: (db.select(db.purchases)..orderBy([(p) => OrderingTerm.desc(p.purchaseDate)])).watch(),
                  builder: (_, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    var list = snap.data!;
                    if (_search.isNotEmpty) {
                      final q = _search.toLowerCase();
                      list = list.where((p) => p.invoiceNo.toLowerCase().contains(q)).toList();
                    }

                    if (list.isEmpty) {
                      return const Center(child: Text('No purchases found', style: TextStyle(color: AppColors.textHint)));
                    }

                    return SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.background),
                        columns: const [
                          DataColumn(label: Text('#')),
                          DataColumn(label: Text('Invoice')),
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Supplier')),
                          DataColumn(label: Text('Total'), numeric: true),
                          DataColumn(label: Text('Paid'), numeric: true),
                          DataColumn(label: Text('Balance'), numeric: true),
                          DataColumn(label: Text('Status')),
                        ],
                        rows: list.asMap().entries.map((e) {
                          final p = e.value;
                          final balance = p.totalAmount - p.paidAmount;
                          return DataRow(cells: [
                            DataCell(Text('${e.key + 1}', style: const TextStyle(color: AppColors.textHint))),
                            DataCell(Text(p.invoiceNo, style: const TextStyle(fontWeight: FontWeight.w500, color: AppColors.primary))),
                            DataCell(Text(df.format(p.purchaseDate))),
                            DataCell(Text(p.supplierId?.toString() ?? 'Cash')),
                            DataCell(Text('Rs. ${nf.format(p.totalAmount)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                            DataCell(Text('Rs. ${nf.format(p.paidAmount)}')),
                            DataCell(Text(
                              'Rs. ${nf.format(balance)}',
                              style: TextStyle(color: balance > 0 ? AppColors.error : AppColors.success, fontWeight: FontWeight.w500),
                            )),
                            DataCell(_StatusBadge(status: p.status)),
                          ]);
                        }).toList(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
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
      'received' => AppColors.success,
      'pending' => AppColors.warning,
      'returned' => AppColors.error,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
    );
  }
}
