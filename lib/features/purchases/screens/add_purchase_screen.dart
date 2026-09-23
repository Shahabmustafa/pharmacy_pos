import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../../core/widgets/app_icon.dart';

final _purchaseAllMedicinesProvider = StreamProvider<List<Medicine>>((ref) {
  return ref.watch(medicineRepositoryProvider).watchAll();
});

class AddPurchaseScreen extends ConsumerStatefulWidget {
  const AddPurchaseScreen({super.key});

  @override
  ConsumerState<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends ConsumerState<AddPurchaseScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _supplierInvoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime _purchaseDate = DateTime.now();
  int? _selectedSupplierId;
  String? _selectedSupplierName;
  final List<_PurchaseItemData> _items = [];
  bool _isSaving = false;
  String _searchQuery = '';
  final _uuid = const Uuid();

  double get _subtotal => _items.fold(0.0, (s, i) => s + i.totalCost);
  double get _totalDiscount => _items.fold(0.0, (s, i) => i.unitCost * i.quantity * i.discountPercent / 100);
  double get _grandTotal => _subtotal - _totalDiscount;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _supplierInvoiceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.00');
    final medicinesAsync = ref.watch(_purchaseAllMedicinesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left: medicine search + browse grid
          Expanded(
            flex: 3,
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.surface,
                  child: Row(
                    children: [
                      IconButton(icon: const AppIcon(AppIcons.arrowBack), tooltip: 'Back', onPressed: () => context.go('/purchases')),
                      const SizedBox(width: 4),
                      const Text('New Purchase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          decoration: InputDecoration(
                            hintText: 'Search medicine by name, generic, barcode...',
                            prefixIcon: const AppIcon(AppIcons.search),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const AppIcon(AppIcons.clear),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.background,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                          ),
                          onChanged: (v) => setState(() => _searchQuery = v),
                        ),
                      ),
                    ],
                  ),
                ),

                // Medicine grid
                Expanded(
                  child: medicinesAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                    data: (all) {
                      var medicines = all;
                      if (_searchQuery.isNotEmpty) {
                        final q = _searchQuery.toLowerCase();
                        medicines = medicines.where((m) =>
                          m.name.toLowerCase().contains(q) ||
                          (m.genericName?.toLowerCase().contains(q) ?? false) ||
                          (m.barcode?.contains(q) ?? false)
                        ).toList();
                      }

                      if (medicines.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const AppIcon(AppIcons.inventory2Outlined, size: 48, color: AppColors.textHint),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty ? 'No medicine found for "$_searchQuery"' : 'No medicines in inventory yet',
                                style: const TextStyle(color: AppColors.textHint),
                              ),
                            ],
                          ),
                        );
                      }

                      return GridView.builder(
                        padding: const EdgeInsets.all(12),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 210,
                          mainAxisExtent: 156,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: medicines.length,
                        itemBuilder: (_, i) => _PurchaseMedicineTile(
                          medicine: medicines[i],
                          onTap: () => _quickAddItem(context, medicines[i]),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Right: Purchase cart
          Container(
            width: (MediaQuery.of(context).size.width * 0.34).clamp(340.0, 440.0),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              children: [
                // Cart header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: AppColors.primary,
                  child: Row(
                    children: [
                      const AppIcon(AppIcons.shoppingCart, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text('Purchase Items', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      const Spacer(),
                      if (_items.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                          child: Text('${_items.length} items', style: const TextStyle(color: Colors.white, fontSize: 12)),
                        ),
                      if (_items.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const AppIcon(AppIcons.deleteOutline, color: Colors.white70, size: 20),
                          onPressed: _confirmClear,
                          tooltip: 'Clear all',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),

                // Supplier selector
                _SupplierSelector(
                  supplierName: _selectedSupplierName,
                  onTap: () => _selectSupplier(context),
                  onClear: () => setState(() {
                    _selectedSupplierId = null;
                    _selectedSupplierName = null;
                  }),
                ),

                // Items list
                Expanded(
                  child: _items.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIcon(AppIcons.shoppingCartOutlined, size: 48, color: AppColors.textHint),
                              SizedBox(height: 8),
                              Text('No items added yet', style: TextStyle(color: AppColors.textHint)),
                              SizedBox(height: 4),
                              Text('Tap a medicine on the left to add it', style: TextStyle(color: AppColors.textHint, fontSize: 11)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _PurchaseCartRow(
                            item: _items[i],
                            onRemove: () => setState(() => _items.removeAt(i)),
                            onQtyChanged: (q) => setState(() => _items[i] = _items[i].copyWithQuantity(q)),
                          ),
                        ),
                ),

                // Details + summary + save
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.divider))),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(
                          child: TextFormField(
                            controller: _supplierInvoiceCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Supplier Invoice No',
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final d = await showDatePicker(
                                context: context,
                                initialDate: _purchaseDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (d != null) setState(() => _purchaseDate = d);
                            },
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              ),
                              child: Text(DateFormat('dd/MM/yy').format(_purchaseDate), style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _notesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      _SummaryRow('Subtotal', 'Rs. ${nf.format(_subtotal)}'),
                      if (_totalDiscount > 0)
                        _SummaryRow('Discount', '-Rs. ${nf.format(_totalDiscount)}', color: AppColors.error),
                      const Divider(height: 8),
                      _SummaryRow('TOTAL', 'Rs. ${nf.format(_grandTotal)}', isBold: true, fontSize: 18),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isSaving || _items.isEmpty ? null : () => _save(context),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                          child: _isSaving
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const AppIcon(AppIcons.save),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Save Purchase — Rs. ${nf.format(_grandTotal)}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _quickAddItem(BuildContext context, Medicine medicine) async {
    await showDialog(
      context: context,
      builder: (ctx) => _QuickAddItemDialog(
        medicine: medicine,
        onAdd: (item) => setState(() => _items.add(item)),
      ),
    );
  }

  Future<void> _selectSupplier(BuildContext context) async {
    final db = ref.read(databaseProvider);
    final suppliers = await (db.select(db.suppliers)..where((s) => s.isActive.equals(true))).get();
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => _SupplierPickerDialog(
        suppliers: suppliers,
        onSelect: (s) {
          setState(() {
            _selectedSupplierId = s.id;
            _selectedSupplierName = s.name;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Items'),
        content: const Text('Remove all items from this purchase?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok == true) setState(() => _items.clear());
  }

  Future<void> _save(BuildContext context) async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one item'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final db = ref.read(databaseProvider);
      final userId = ref.read(authProvider).user?.id ?? 1;
      final prefix = await ref.read(settingsRepositoryProvider).get('purchase_prefix') ?? 'PUR';
      final countResult = await db.customSelect('SELECT COUNT(*) as cnt FROM purchases', readsFrom: {db.purchases}).getSingle();
      final count = (countResult.data['cnt'] as int?) ?? 0;
      final invoiceNo = '$prefix-${DateFormat('yyMMdd').format(DateTime.now())}-${(count + 1).toString().padLeft(5, '0')}';

      await db.transaction(() async {
        final purchaseId = await db.into(db.purchases).insert(PurchasesCompanion.insert(
          invoiceNo: invoiceNo,
          supplierInvoiceNo: Value(_supplierInvoiceCtrl.text.isEmpty ? null : _supplierInvoiceCtrl.text),
          purchaseDate: Value(_purchaseDate),
          supplierId: Value(_selectedSupplierId),
          userId: userId,
          subtotal: Value(_subtotal),
          discountAmount: Value(_totalDiscount),
          totalAmount: Value(_grandTotal),
          paidAmount: Value(0.0),
          creditAmount: Value(_grandTotal),
          notes: Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
          serverId: Value(_uuid.v4()),
          needsSync: const Value(true),
        ));

        for (final item in _items) {
          await db.into(db.purchaseItems).insert(PurchaseItemsCompanion.insert(
            purchaseId: purchaseId,
            medicineId: item.medicineId,
            medicineName: item.medicineName,
            batchNo: Value(item.batchNo),
            expiryDate: Value(item.expiryDate),
            quantity: item.quantity,
            freeQuantity: Value(item.freeQuantity),
            unitCost: item.unitCost,
            salePrice: Value(item.salePrice),
            discountPercent: Value(item.discountPercent),
            totalCost: item.totalCost,
            serverId: Value(_uuid.v4()),
            needsSync: const Value(true),
          ));

          // Update medicine stock and price
          final medicine = await ref.read(medicineRepositoryProvider).getById(item.medicineId);
          if (medicine != null) {
            await (db.update(db.medicines)..where((m) => m.id.equals(item.medicineId))).write(
              MedicinesCompanion(
                stock: Value(medicine.stock + item.quantity + item.freeQuantity),
                purchasePrice: Value(item.unitCost),
                salePrice: item.salePrice > 0 ? Value(item.salePrice) : const Value.absent(),
                updatedAt: Value(DateTime.now()),
                needsSync: const Value(true),
              ),
            );
          }

          // Create stock batch
          if (item.batchNo != null && item.expiryDate != null) {
            await db.into(db.stockBatches).insert(StockBatchesCompanion.insert(
              medicineId: item.medicineId,
              batchNo: item.batchNo!,
              expiryDate: item.expiryDate!,
              purchasePrice: Value(item.unitCost),
              salePrice: Value(item.salePrice),
              quantity: Value(item.quantity + item.freeQuantity),
              remainingQty: Value(item.quantity + item.freeQuantity),
              serverId: Value(_uuid.v4()),
              needsSync: const Value(true),
            ));
          }
        }

        // Update supplier balance
        if (_selectedSupplierId != null) {
          final supplier = await (db.select(db.suppliers)..where((s) => s.id.equals(_selectedSupplierId!))).getSingleOrNull();
          if (supplier != null) {
            await (db.update(db.suppliers)..where((s) => s.id.equals(_selectedSupplierId!))).write(
              SuppliersCompanion(balance: Value(supplier.balance + _grandTotal)),
            );
          }
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase saved successfully'), backgroundColor: AppColors.success),
        );
        context.go('/purchases');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _PurchaseItemData {
  final int medicineId;
  final String medicineName;
  final String? batchNo;
  final DateTime? expiryDate;
  final double quantity;
  final double freeQuantity;
  final double unitCost;
  final double salePrice;
  final double discountPercent;
  final double totalCost;

  const _PurchaseItemData({
    required this.medicineId,
    required this.medicineName,
    this.batchNo,
    this.expiryDate,
    required this.quantity,
    required this.freeQuantity,
    required this.unitCost,
    required this.salePrice,
    required this.discountPercent,
    required this.totalCost,
  });

  _PurchaseItemData copyWithQuantity(double newQty) {
    final q = newQty < 1 ? 1.0 : newQty;
    final total = (q * unitCost) - (q * unitCost * discountPercent / 100);
    return _PurchaseItemData(
      medicineId: medicineId,
      medicineName: medicineName,
      batchNo: batchNo,
      expiryDate: expiryDate,
      quantity: q,
      freeQuantity: freeQuantity,
      unitCost: unitCost,
      salePrice: salePrice,
      discountPercent: discountPercent,
      totalCost: total,
    );
  }
}

class _PurchaseMedicineTile extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onTap;
  const _PurchaseMedicineTile({required this.medicine, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.00');

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const AppIcon(AppIcons.medication, color: AppColors.primary, size: 18),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.inStock.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('Stock: ${medicine.stock}', style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.inStock)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                medicine.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.2),
              ),
              if (medicine.genericName != null) ...[
                const SizedBox(height: 2),
                Text(
                  medicine.genericName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Cost: Rs. ${nf.format(medicine.purchasePrice)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                    ),
                  ),
                  const AppIcon(AppIcons.addCircle, color: AppColors.primary, size: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseCartRow extends StatelessWidget {
  final _PurchaseItemData item;
  final VoidCallback onRemove;
  final ValueChanged<double> onQtyChanged;
  const _PurchaseCartRow({required this.item, required this.onRemove, required this.onQtyChanged});

  @override
  Widget build(BuildContext context) {
    final nf = NumberFormat('#,##0.00');
    final df = DateFormat('MM/yyyy');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13), overflow: TextOverflow.ellipsis),
              ),
              Text('Rs. ${nf.format(item.totalCost)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
              const SizedBox(width: 4),
              InkWell(onTap: onRemove, child: const AppIcon(AppIcons.close, size: 16, color: AppColors.error)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Batch: ${item.batchNo ?? '-'}  ·  Exp: ${item.expiryDate != null ? df.format(item.expiryDate!) : '-'}'
            '${item.freeQuantity > 0 ? '  ·  +${item.freeQuantity.toStringAsFixed(item.freeQuantity == item.freeQuantity.roundToDouble() ? 0 : 1)} free' : ''}',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        icon: const AppIcon(AppIcons.remove, size: 12),
                        padding: EdgeInsets.zero,
                        onPressed: item.quantity > 1 ? () => onQtyChanged(item.quantity - 1) : null,
                      ),
                    ),
                    SizedBox(
                      width: 36,
                      child: Text(
                        item.quantity.toStringAsFixed(item.quantity == item.quantity.roundToDouble() ? 0 : 1),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        icon: const AppIcon(AppIcons.add, size: 12),
                        padding: EdgeInsets.zero,
                        onPressed: () => onQtyChanged(item.quantity + 1),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('× Rs.${nf.format(item.unitCost)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              if (item.discountPercent > 0)
                Text('-${item.discountPercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: AppColors.error)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SupplierSelector extends StatelessWidget {
  final String? supplierName;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _SupplierSelector({required this.supplierName, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            AppIcon(AppIcons.localShipping, size: 16, color: supplierName != null ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                supplierName ?? 'Select Supplier (optional, tap to choose)',
                style: TextStyle(fontSize: 13, color: supplierName != null ? AppColors.textPrimary : AppColors.textHint),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (supplierName != null)
              InkWell(onTap: onClear, child: const AppIcon(AppIcons.close, size: 16, color: AppColors.textHint)),
          ],
        ),
      ),
    );
  }
}

class _SupplierPickerDialog extends StatefulWidget {
  final List<Supplier> suppliers;
  final void Function(Supplier) onSelect;
  const _SupplierPickerDialog({required this.suppliers, required this.onSelect});

  @override
  State<_SupplierPickerDialog> createState() => _SupplierPickerDialogState();
}

class _SupplierPickerDialogState extends State<_SupplierPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.suppliers
        .where((s) => s.name.toLowerCase().contains(_search.toLowerCase()) || (s.phone?.contains(_search) ?? false))
        .toList();

    return AlertDialog(
      title: const Text('Select Supplier'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(hintText: 'Search by name or phone...', prefixIcon: AppIcon(AppIcons.search)),
              onChanged: (v) => setState(() => _search = v),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No suppliers found', style: TextStyle(color: AppColors.textHint)))
                  : ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (_, i) => ListTile(
                        leading: const CircleAvatar(child: AppIcon(AppIcons.localShipping)),
                        title: Text(filtered[i].name),
                        subtitle: Text(filtered[i].companyName ?? filtered[i].phone ?? ''),
                        onTap: () => widget.onSelect(filtered[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel'))],
    );
  }
}

class _QuickAddItemDialog extends StatefulWidget {
  final Medicine medicine;
  final void Function(_PurchaseItemData) onAdd;
  const _QuickAddItemDialog({required this.medicine, required this.onAdd});

  @override
  State<_QuickAddItemDialog> createState() => _QuickAddItemDialogState();
}

class _QuickAddItemDialogState extends State<_QuickAddItemDialog> {
  final _batchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _freeQtyCtrl = TextEditingController(text: '0');
  late final _costCtrl = TextEditingController(text: widget.medicine.purchasePrice > 0 ? widget.medicine.purchasePrice.toString() : '');
  late final _salePriceCtrl = TextEditingController(text: widget.medicine.salePrice > 0 ? widget.medicine.salePrice.toString() : '');
  final _discountCtrl = TextEditingController(text: '0');
  DateTime? _expiryDate;

  @override
  void dispose() {
    _batchCtrl.dispose();
    _qtyCtrl.dispose();
    _freeQtyCtrl.dispose();
    _costCtrl.dispose();
    _salePriceCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qty = double.tryParse(_qtyCtrl.text) ?? 0;
    final cost = double.tryParse(_costCtrl.text) ?? 0;
    final discount = double.tryParse(_discountCtrl.text) ?? 0;
    final total = (qty * cost) - (qty * cost * discount / 100);

    return AlertDialog(
      title: Row(
        children: [
          const AppIcon(AppIcons.medication, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(widget.medicine.name, overflow: TextOverflow.ellipsis)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _batchCtrl, decoration: const InputDecoration(labelText: 'Batch No'), autofocus: true),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2040),
                  );
                  if (d != null) setState(() => _expiryDate = d);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Expiry Date'),
                  child: Text(_expiryDate != null ? DateFormat('MM/yyyy').format(_expiryDate!) : 'Select date'),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _qtyCtrl, decoration: const InputDecoration(labelText: 'Qty'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _freeQtyCtrl, decoration: const InputDecoration(labelText: 'Free Qty'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: TextFormField(controller: _costCtrl, decoration: const InputDecoration(labelText: 'Unit Cost', prefixText: 'Rs. '), keyboardType: TextInputType.number, onChanged: (_) => setState(() {}))),
                const SizedBox(width: 8),
                Expanded(child: TextFormField(controller: _salePriceCtrl, decoration: const InputDecoration(labelText: 'Sale Price', prefixText: 'Rs. '), keyboardType: TextInputType.number)),
              ]),
              const SizedBox(height: 8),
              TextFormField(controller: _discountCtrl, decoration: const InputDecoration(labelText: 'Discount %', suffixText: '%'), keyboardType: TextInputType.number, onChanged: (_) => setState(() {})),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total:', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text('Rs. ${NumberFormat('#,##0.00').format(total)}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: qty <= 0 || cost <= 0
              ? null
              : () {
                  widget.onAdd(_PurchaseItemData(
                    medicineId: widget.medicine.id,
                    medicineName: widget.medicine.name,
                    batchNo: _batchCtrl.text.isEmpty ? null : _batchCtrl.text,
                    expiryDate: _expiryDate,
                    quantity: qty,
                    freeQuantity: double.tryParse(_freeQtyCtrl.text) ?? 0,
                    unitCost: cost,
                    salePrice: double.tryParse(_salePriceCtrl.text) ?? 0,
                    discountPercent: discount,
                    totalCost: total,
                  ));
                  Navigator.pop(context);
                },
          child: const Text('Add to Purchase'),
        ),
      ],
    );
  }
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
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.normal, color: color ?? AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: fontSize, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500, color: color ?? AppColors.textPrimary)),
        ],
      ),
    );
  }
}
