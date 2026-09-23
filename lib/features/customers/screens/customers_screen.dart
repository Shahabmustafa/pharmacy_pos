import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/widgets/app_icon.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
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
                Text('Customers', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                ElevatedButton.icon(
                  icon: const AppIcon(AppIcons.personAdd),
                  label: const Text('Add Customer'),
                  onPressed: () => _showAddDialog(context, db),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(hintText: 'Search by name or phone...', prefixIcon: AppIcon(AppIcons.search)),
              onChanged: (v) => setState(() => _search = v),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Card(
                child: StreamBuilder<List<Customer>>(
                  stream: (db.select(db.customers)
                        ..where((c) => c.isActive.equals(true))
                        ..orderBy([(c) => OrderingTerm.asc(c.name)]))
                      .watch(),
                  builder: (_, snap) {
                    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                    var list = snap.data!;
                    if (_search.isNotEmpty) {
                      final q = _search.toLowerCase();
                      list = list.where((c) =>
                        c.name.toLowerCase().contains(q) ||
                        (c.phone?.contains(q) ?? false)
                      ).toList();
                    }

                    if (list.isEmpty) {
                      return const Center(child: Text('No customers found', style: TextStyle(color: AppColors.textHint)));
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
                          DataColumn(label: Text('Phone')),
                          DataColumn(label: Text('CNIC')),
                          DataColumn(label: Text('Balance'), numeric: true),
                          DataColumn(label: Text('Credit Limit'), numeric: true),
                          DataColumn(label: Text('Actions')),
                        ],
                        rows: list.asMap().entries.map((e) {
                          final c = e.value;
                          final hasDue = c.balance > 0;
                          return DataRow(cells: [
                            DataCell(Text('${e.key + 1}', style: const TextStyle(color: AppColors.textHint))),
                            DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                            DataCell(Text(c.phone ?? '-')),
                            DataCell(Text(c.cnic ?? '-')),
                            DataCell(Text(
                              'Rs. ${nf.format(c.balance)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: hasDue ? AppColors.error : AppColors.success,
                              ),
                            )),
                            DataCell(Text('Rs. ${nf.format(c.creditLimit)}')),
                            DataCell(Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(icon: const AppIcon(AppIcons.editOutlined, size: 18), onPressed: () => _showAddDialog(context, db, customer: c)),
                                if (hasDue)
                                  IconButton(
                                    icon: const AppIcon(AppIcons.payment, size: 18, color: AppColors.success),
                                    tooltip: 'Receive Payment',
                                    onPressed: () => _showPaymentDialog(context, db, c),
                                  ),
                                IconButton(
                                  icon: const AppIcon(AppIcons.deleteOutline, size: 18, color: AppColors.error),
                                  onPressed: () async {
                                    await (db.update(db.customers)..where((x) => x.id.equals(c.id)))
                                        .write(const CustomersCompanion(isActive: Value(false)));
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

  Future<void> _showAddDialog(BuildContext context, AppDatabase db, {Customer? customer}) async {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final cnicCtrl = TextEditingController(text: customer?.cnic ?? '');
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final creditCtrl = TextEditingController(text: customer?.creditLimit.toString() ?? '0');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(customer != null ? 'Edit Customer' : 'Add Customer'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name *'), validator: (v) => v!.isEmpty ? 'Required' : null),
                const SizedBox(height: 12),
                TextFormField(controller: phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
                const SizedBox(height: 12),
                TextFormField(controller: cnicCtrl, decoration: const InputDecoration(labelText: 'CNIC')),
                const SizedBox(height: 12),
                TextFormField(controller: addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
                const SizedBox(height: 12),
                TextFormField(controller: creditCtrl, decoration: const InputDecoration(labelText: 'Credit Limit', prefixText: 'Rs. '), keyboardType: TextInputType.number),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              if (customer != null) {
                await (db.update(db.customers)..where((c) => c.id.equals(customer.id))).write(
                  CustomersCompanion(
                    name: Value(nameCtrl.text),
                    phone: Value(phoneCtrl.text.isEmpty ? null : phoneCtrl.text),
                    cnic: Value(cnicCtrl.text.isEmpty ? null : cnicCtrl.text),
                    address: Value(addressCtrl.text.isEmpty ? null : addressCtrl.text),
                    creditLimit: Value(double.tryParse(creditCtrl.text) ?? 0),
                    needsSync: const Value(true),
                  ),
                );
              } else {
                await db.into(db.customers).insert(CustomersCompanion.insert(
                  name: nameCtrl.text,
                  phone: Value(phoneCtrl.text.isEmpty ? null : phoneCtrl.text),
                  cnic: Value(cnicCtrl.text.isEmpty ? null : cnicCtrl.text),
                  address: Value(addressCtrl.text.isEmpty ? null : addressCtrl.text),
                  creditLimit: Value(double.tryParse(creditCtrl.text) ?? 0),
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

  Future<void> _showPaymentDialog(BuildContext context, AppDatabase db, Customer customer) async {
    final amtCtrl = TextEditingController(text: customer.balance.toStringAsFixed(2));
    final notesCtrl = TextEditingController();
    final userId = ref.read(authProvider).user?.id ?? 1;

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Receive Payment from ${customer.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Balance Due: Rs. ${customer.balance.toStringAsFixed(2)}', style: const TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextFormField(controller: amtCtrl, decoration: const InputDecoration(labelText: 'Amount', prefixText: 'Rs. '), keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            TextFormField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () async {
              final amt = double.tryParse(amtCtrl.text) ?? 0;
              if (amt <= 0) return;

              await db.transaction(() async {
                await db.into(db.customerPayments).insert(CustomerPaymentsCompanion.insert(
                  customerId: customer.id,
                  amount: amt,
                  type: 'received',
                  userId: userId,
                  notes: Value(notesCtrl.text.isEmpty ? null : notesCtrl.text),
                  needsSync: const Value(true),
                ));
                await (db.update(db.customers)..where((c) => c.id.equals(customer.id)))
                    .write(CustomersCompanion(balance: Value(customer.balance - amt)));
              });
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Receive'),
          ),
        ],
      ),
    );
  }
}

