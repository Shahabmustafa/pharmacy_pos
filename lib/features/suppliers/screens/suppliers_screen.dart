import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/widgets/app_icon.dart';

class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    final nf = NumberFormat('#,##0.00');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Suppliers', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const AppIcon(AppIcons.add),
                  label: const Text('Add Supplier'),
                  onPressed: () => _showAddDialog(context, db),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(hintText: 'Search suppliers...', prefixIcon: AppIcon(AppIcons.search)),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: StreamBuilder<List<Supplier>>(
                  stream: (db.select(db.suppliers)
                        ..where((s) => s.isActive.equals(true))
                        ..orderBy([(s) => OrderingTerm.asc(s.name)]))
                      .watch(),
                  builder: (_, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    var list = snap.data!;
                    if (_search.isNotEmpty) {
                      final q = _search.toLowerCase();
                      list = list.where((s) =>
                        s.name.toLowerCase().contains(q) ||
                        (s.companyName?.toLowerCase().contains(q) ?? false) ||
                        (s.phone?.contains(q) ?? false)
                      ).toList();
                    }

                    if (list.isEmpty) {
                      return const Center(child: Text('No suppliers found', style: TextStyle(color: AppColors.textHint)));
                    }

                    return SingleChildScrollView(
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(AppColors.background),
                        headingRowHeight: 56,
                        dataRowMinHeight: 60,
                        dataRowMaxHeight: 68,
                        columnSpacing: 72,
                        horizontalMargin: 28,
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        dataTextStyle: const TextStyle(fontSize: 15),
                        columns: const [
                          DataColumn(label: Text('#')),
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Company')),
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('Balance'), numeric: true),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: list.asMap().entries.map((e) {
                          final s = e.value;
                          return DataRow(cells: [
                            DataCell(Text('${e.key + 1}', style: const TextStyle(color: AppColors.textHint))),
                            DataCell(Text(s.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(s.companyName ?? '-')),
                            DataCell(Text(s.phone ?? '-')),
                            DataCell(Text(
                              'Rs. ${nf.format(s.balance)}',
                              style: TextStyle(fontWeight: FontWeight.w600, color: s.balance > 0 ? AppColors.error : AppColors.success),
                            )),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const AppIcon(AppIcons.editOutlined, size: 18), onPressed: () => _showAddDialog(context, db, supplier: s)),
                                IconButton(
                                  icon: const AppIcon(AppIcons.deleteOutline, size: 18, color: AppColors.error),
                                  onPressed: () async {
                                    await (db.update(db.suppliers)..where((x) => x.id.equals(s.id)))
                                        .write(const SuppliersCompanion(isActive: Value(false)));
                                  },
                                ),
                              ],
                            )),
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

  Future<void> _showAddDialog(BuildContext context, AppDatabase db, {Supplier? supplier}) async {
    final nameCtrl = TextEditingController(text: supplier?.name ?? '');
    final companyCtrl = TextEditingController(text: supplier?.companyName ?? '');
    final phoneCtrl = TextEditingController(text: supplier?.phone ?? '');
    final mobileCtrl = TextEditingController(text: supplier?.mobile ?? '');
    final emailCtrl = TextEditingController(text: supplier?.email ?? '');
    final addressCtrl = TextEditingController(text: supplier?.address ?? '');
    final ntnCtrl = TextEditingController(text: supplier?.ntn ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(supplier != null ? 'Edit Supplier' : 'Add Supplier'),
        content: SizedBox(
          width: 500,
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Supplier Name *'), validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 12),
                  TextFormField(controller: companyCtrl, decoration: const InputDecoration(labelText: 'Company Name')),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextFormField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile'))),
                  ]),
                  const SizedBox(height: 12),
                  TextFormField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email')),
                  const SizedBox(height: 12),
                  TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address'), maxLines: 2),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: TextFormField(controller: ntnCtrl, decoration: const InputDecoration(labelText: 'NTN'))),
                  ]),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (supplier != null) {
                await (db.update(db.suppliers)..where((s) => s.id.equals(supplier.id))).write(
                  SuppliersCompanion(
                    name: Value(nameCtrl.text),
                    companyName: Value(companyCtrl.text.isEmpty ? null : companyCtrl.text),
                    phone: Value(phoneCtrl.text.isEmpty ? null : phoneCtrl.text),
                    mobile: Value(mobileCtrl.text.isEmpty ? null : mobileCtrl.text),
                    email: Value(emailCtrl.text.isEmpty ? null : emailCtrl.text),
                    address: Value(addressCtrl.text.isEmpty ? null : addressCtrl.text),
                    ntn: Value(ntnCtrl.text.isEmpty ? null : ntnCtrl.text),
                    needsSync: const Value(true),
                  ),
                );
              } else {
                await db.into(db.suppliers).insert(SuppliersCompanion.insert(
                  name: nameCtrl.text,
                  companyName: Value(companyCtrl.text.isEmpty ? null : companyCtrl.text),
                  phone: Value(phoneCtrl.text.isEmpty ? null : phoneCtrl.text),
                  mobile: Value(mobileCtrl.text.isEmpty ? null : mobileCtrl.text),
                  email: Value(emailCtrl.text.isEmpty ? null : emailCtrl.text),
                  address: Value(addressCtrl.text.isEmpty ? null : addressCtrl.text),
                  ntn: Value(ntnCtrl.text.isEmpty ? null : ntnCtrl.text),
                  needsSync: const Value(true),
                ));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
