import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/storage_types.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/widgets/app_icon.dart';

final _inventorySearchProvider = StateProvider<String>((ref) => '');
final _inventoryFilterProvider = StateProvider<String>((ref) => 'all'); // all, low, out

final _categoryNamesProvider = StreamProvider<Map<int, String>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.select(db.medicineCategories).watch().map(
        (cats) => {for (final c in cats) c.id: c.name},
      );
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.watch(_inventorySearchProvider);
    final filter = ref.watch(_inventoryFilterProvider);
    final nf = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text('Inventory', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const AppIcon(AppIcons.straighten, size: 18),
                  label: const Text('Categories & Units'),
                  onPressed: () => context.go('/inventory/categories'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const AppIcon(AppIcons.fileDownload, size: 18),
                  label: const Text('Export'),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const AppIcon(AppIcons.add),
                  label: const Text('Add Medicine'),
                  onPressed: () => context.go('/inventory/add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _LowStockBanner(),

            // Filters row
            LayoutBuilder(builder: (context, constraints) {
              final searchField = TextField(
                decoration: const InputDecoration(
                  hintText: 'Search medicines...',
                  prefixIcon: AppIcon(AppIcons.search, size: 20),
                  contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                ),
                onChanged: (v) => ref.read(_inventorySearchProvider.notifier).state = v,
              );
              final segmented = SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'low', label: Text('Low')),
                  ButtonSegment(value: 'out', label: Text('Out')),
                ],
                selected: {filter},
                onSelectionChanged: (s) => ref.read(_inventoryFilterProvider.notifier).state = s.first,
              );
              if (constraints.maxWidth < 700) {
                return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  searchField,
                  const SizedBox(height: 8),
                  segmented,
                ]);
              }
              return Row(children: [
                Expanded(flex: 2, child: searchField),
                const SizedBox(width: 12),
                segmented,
              ]);
            }),
            const SizedBox(height: 16),

            // Table
            Expanded(
              child: Card(
                child: _MedicineTable(search: search, filter: filter),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockBanner extends ConsumerWidget {
  const _LowStockBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(medicineRepositoryProvider.select((r) => r.watchAll()));

    return StreamBuilder<List<Medicine>>(
      stream: medicinesAsync,
      builder: (context, snap) {
        final medicines = snap.data ?? const <Medicine>[];
        final lowCount = medicines.where((m) => m.stock <= m.minStockLevel && m.stock > 0).length;
        final outCount = medicines.where((m) => m.stock <= 0).length;
        final alertCount = lowCount + outCount;
        if (alertCount == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            onTap: () => ref.read(_inventoryFilterProvider.notifier).state = outCount > 0 && lowCount == 0 ? 'out' : 'low',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const AppIcon(AppIcons.warningAmber, color: AppColors.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      [
                        if (lowCount > 0) '$lowCount medicine${lowCount == 1 ? '' : 's'} low on stock',
                        if (outCount > 0) '$outCount out of stock',
                      ].join(' · '),
                      style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: AppSizes.fontSM),
                    ),
                  ),
                  const Text('View', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600, fontSize: AppSizes.fontSM)),
                  const AppIcon(AppIcons.chevronRight, color: AppColors.warning, size: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MedicineTable extends ConsumerWidget {
  final String search;
  final String filter;
  const _MedicineTable({required this.search, required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesStream = ref.watch(medicineRepositoryProvider.select((r) => r.watchAll()));
    final categoryNames = ref.watch(_categoryNamesProvider).value ?? {};

    return StreamBuilder<List<Medicine>>(
      stream: medicinesStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        var medicines = snapshot.data!;

        if (search.isNotEmpty) {
          final q = search.toLowerCase();
          medicines = medicines.where((m) =>
            m.name.toLowerCase().contains(q) ||
            (m.genericName?.toLowerCase().contains(q) ?? false) ||
            (m.barcode?.contains(q) ?? false)
          ).toList();
        }

        if (filter == 'low') medicines = medicines.where((m) => m.stock <= m.minStockLevel && m.stock > 0).toList();
        if (filter == 'out') medicines = medicines.where((m) => m.stock <= 0).toList();

        if (medicines.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(AppIcons.inventory2Outlined, size: 48, color: AppColors.textHint),
                SizedBox(height: 12),
                Text('No medicines found', style: TextStyle(color: AppColors.textHint)),
              ],
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
          child: DataTable(
            columnSpacing: 40,
            horizontalMargin: 28,
            headingRowHeight: 56,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 72,
            headingRowColor: WidgetStateProperty.all(AppColors.background),
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            dataTextStyle: const TextStyle(fontSize: 15),
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Medicine Name')),
              DataColumn(label: Text('Generic')),
              DataColumn(label: Text('Category')),
              DataColumn(label: Text('Sale Price'), numeric: true),
              DataColumn(label: Text('Purchase Price'), numeric: true),
              DataColumn(label: Text('Stock'), numeric: true),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Actions')),
            ],
            rows: medicines.asMap().entries.map((e) {
              final i = e.key;
              final m = e.value;
              final isLow = m.stock <= m.minStockLevel && m.stock > 0;
              final isOut = m.stock <= 0;
              final nf = NumberFormat('#,##0.00');

              return DataRow(cells: [
                DataCell(Text('${i + 1}', style: const TextStyle(color: AppColors.textHint))),
                DataCell(Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        if (StorageType.needsCold(m.storageType)) ...[
                          const SizedBox(width: 6),
                          Tooltip(
                            message: StorageType.labelFor(m.storageType),
                            child: const AppIcon(AppIcons.acUnit, size: 14, color: AppColors.info),
                          ),
                        ],
                        if (m.isShortage) ...[
                          const SizedBox(width: 6),
                          const Tooltip(
                            message: 'Shortage — discount disabled at sale',
                            child: AppIcon(AppIcons.warningAmber, size: 14, color: AppColors.warning),
                          ),
                        ],
                      ],
                    ),
                    if (m.packSize != null) Text(m.packSize!, style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                  ],
                )),
                DataCell(Text(m.genericName ?? '-', style: const TextStyle(color: AppColors.textSecondary))),
                DataCell(Text(categoryNames[m.categoryId] ?? '-', style: const TextStyle(color: AppColors.textSecondary))),
                DataCell(Text('Rs. ${nf.format(m.salePrice)}', style: const TextStyle(fontWeight: FontWeight.w500))),
                DataCell(Text('Rs. ${nf.format(m.purchasePrice)}', style: const TextStyle(color: AppColors.textSecondary))),
                DataCell(Text(
                  '${m.stock}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isOut ? AppColors.outOfStock : isLow ? AppColors.lowStock : AppColors.inStock,
                  ),
                )),
                DataCell(_StatusChip(isOut: isOut, isLow: isLow)),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const AppIcon(AppIcons.editOutlined, size: 18),
                      tooltip: 'Edit',
                      onPressed: () => context.go('/inventory/add?id=${m.id}'),
                    ),
                    IconButton(
                      icon: const AppIcon(AppIcons.deleteOutline, size: 18, color: AppColors.error),
                      tooltip: 'Delete',
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete Medicine'),
                            content: Text('Delete "${m.name}"?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await ref.read(medicineRepositoryProvider).delete(m.id);
                        }
                      },
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ));
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOut;
  final bool isLow;
  const _StatusChip({required this.isOut, required this.isLow});

  @override
  Widget build(BuildContext context) {
    final color = isOut ? AppColors.outOfStock : isLow ? AppColors.lowStock : AppColors.inStock;
    final label = isOut ? 'Out of Stock' : isLow ? 'Low Stock' : 'In Stock';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
    );
  }
}
