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

class ExpensesScreen extends ConsumerStatefulWidget {
  const ExpensesScreen({super.key});

  @override
  ConsumerState<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends ConsumerState<ExpensesScreen> {
  DateTimeRange _range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 29)),
    end: DateTime.now(),
  );

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
                Text('Expenses', style: Theme.of(context).textTheme.headlineMedium),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const AppIcon(AppIcons.calendarToday, size: 16),
                  label: Text('${df.format(_range.start)} - ${df.format(_range.end)}'),
                  onPressed: () async {
                    final r = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      initialDateRange: _range,
                    );
                    if (r != null) setState(() => _range = r);
                  },
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  icon: const AppIcon(AppIcons.add),
                  label: const Text('Add Expense'),
                  onPressed: () => _showAddDialog(context, db),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Expense>>(
                future: (db.select(db.expenses)
                      ..where((e) =>
                          e.expenseDate.isBiggerOrEqualValue(_range.start) &
                          e.expenseDate.isSmallerOrEqualValue(_range.end.add(const Duration(days: 1))))
                      ..orderBy([(e) => OrderingTerm.desc(e.expenseDate)]))
                    .get(),
                builder: (_, snap) {
                  if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                  final expenses = snap.data!;
                  final total = expenses.fold(0.0, (s, e) => s + e.amount);

                  return Column(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              const AppIcon(AppIcons.receiptLong, color: AppColors.error, size: 24),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Total Expenses', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                                  Text('Rs. ${nf.format(total)}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.error)),
                                ],
                              ),
                              const Spacer(),
                              Text('${expenses.length} entries', style: const TextStyle(color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: Card(
                          child: expenses.isEmpty
                              ? const Center(child: Text('No expenses found', style: TextStyle(color: AppColors.textHint)))
                              : SingleChildScrollView(
                                  child: DataTable(
                                    headingRowColor: WidgetStateProperty.all(AppColors.background),
                                    headingRowHeight: 56,
                                    dataRowMinHeight: 60,
                                    dataRowMaxHeight: 68,
                                    columnSpacing: 56,
                                    horizontalMargin: 28,
                                    headingTextStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    dataTextStyle: const TextStyle(fontSize: 15),
                                    columns: const [
                                      DataColumn(label: Text('#')),
                                      DataColumn(label: Text('Date')),
                                      DataColumn(label: Text('Category')),
                                      DataColumn(label: Text('Description')),
                                      DataColumn(label: Text('Amount'), numeric: true),
                                      DataColumn(label: Text('Payment')),
                                      DataColumn(label: Text('Actions')),
                                    ],
                                    rows: expenses.asMap().entries.map((e) {
                                      final exp = e.value;
                                      return DataRow(cells: [
                                        DataCell(Text('${e.key + 1}', style: const TextStyle(color: AppColors.textHint))),
                                        DataCell(Text(df.format(exp.expenseDate))),
                                        DataCell(Text('${exp.categoryId ?? '-'}')),
                                        DataCell(Text(exp.description, overflow: TextOverflow.ellipsis)),
                                        DataCell(Text('Rs. ${nf.format(exp.amount)}', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.error))),
                                        DataCell(Text(exp.paymentMethod.toUpperCase(), style: const TextStyle(fontSize: 12))),
                                        DataCell(IconButton(
                                          icon: const AppIcon(AppIcons.deleteOutline, size: 18, color: AppColors.error),
                                          onPressed: () async {
                                            await (db.delete(db.expenses)..where((x) => x.id.equals(exp.id))).go();
                                            setState(() {});
                                          },
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, AppDatabase db) async {
    final descCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    int? categoryId;
    String paymentMethod = 'cash';
    DateTime date = DateTime.now();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Add Expense'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<List<ExpenseCategory>>(
                    future: db.select(db.expenseCategories).get(),
                    builder: (_, snap) => DropdownButtonFormField<int>(
                      value: categoryId,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: (snap.data ?? []).map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                      )).toList(),
                      onChanged: (v) => setS(() => categoryId = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description *'),
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: amtCtrl,
                    decoration: const InputDecoration(labelText: 'Amount *', prefixText: 'Rs. '),
                    keyboardType: TextInputType.number,
                    validator: (v) => v!.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: paymentMethod,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'bank', child: Text('Bank Transfer')),
                      DropdownMenuItem(value: 'card', child: Text('Card')),
                    ],
                    onChanged: (v) => setS(() => paymentMethod = v ?? 'cash'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(controller: notesCtrl, decoration: const InputDecoration(labelText: 'Notes')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final userId = ref.read(authProvider).user?.id ?? 1;
                await db.into(db.expenses).insert(ExpensesCompanion.insert(
                  categoryId: Value(categoryId),
                  description: descCtrl.text,
                  amount: double.tryParse(amtCtrl.text) ?? 0,
                  userId: userId,
                  paymentMethod: Value(paymentMethod),
                  notes: Value(notesCtrl.text.isEmpty ? null : notesCtrl.text),
                  needsSync: const Value(true),
                ));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  setState(() {});
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
