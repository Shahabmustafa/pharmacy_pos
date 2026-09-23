import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/storage_types.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../services/print_service.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/pos_provider.dart';
import '../../../core/widgets/app_icon.dart';

final _medicineSearchProvider = FutureProvider.family<List<Medicine>, String>((ref, query) async {
  if (query.isEmpty) return [];
  return ref.watch(medicineRepositoryProvider).search(query);
});

final _allMedicinesProvider = StreamProvider<List<Medicine>>((ref) {
  return ref.watch(medicineRepositoryProvider).watchAll();
});

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _receivedCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    _receivedCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pos = ref.watch(posProvider);
    final nf = NumberFormat('#,##0.00');
    final allShortage = pos.cartItems.isNotEmpty && pos.cartItems.every((i) => i.isShortage);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left: medicine search + list
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
                      // Search box
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          autofocus: true,
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
                          onSubmitted: (v) async {
                            if (v.isEmpty) return;
                            // Try barcode lookup first
                            final medicine = await ref.read(medicineRepositoryProvider).getByBarcode(v);
                            if (medicine != null && mounted) {
                              ref.read(posProvider.notifier).addItem(medicine);
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                              _searchFocus.requestFocus();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Hold bill button
                      OutlinedButton.icon(
                        icon: const AppIcon(AppIcons.pauseCircleOutline, size: 18),
                        label: const Text('Hold'),
                        onPressed: pos.cartItems.isEmpty ? null : () => _holdBill(context),
                      ),
                      const SizedBox(width: 8),
                      // Restore held bills
                      OutlinedButton.icon(
                        icon: const AppIcon(AppIcons.restore, size: 18),
                        label: const Text('Bills'),
                        onPressed: () => _showHeldBills(context),
                      ),
                    ],
                  ),
                ),

                // Search results / full medicine list
                if (_searchQuery.isNotEmpty)
                  Expanded(child: _SearchResults(query: _searchQuery, onClear: () {
                    _searchCtrl.clear();
                    setState(() => _searchQuery = '');
                    _searchFocus.requestFocus();
                  }))
                else
                  Expanded(child: _AllMedicinesList(onAdd: () => _searchFocus.requestFocus())),
              ],
            ),
          ),

          // Right: Cart
          Container(
            width: (MediaQuery.of(context).size.width * 0.32).clamp(300.0, 420.0),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: AppColors.divider)),
            ),
            child: Column(
              children: [
                // Cart header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.zero,
                  ),
                  child: Row(
                    children: [
                      const AppIcon(AppIcons.shoppingCart, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Text('Cart', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                      const Spacer(),
                      if (pos.cartItems.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pos.itemCount} items',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      if (pos.cartItems.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const AppIcon(AppIcons.deleteOutline, color: Colors.white70, size: 20),
                          onPressed: () => _confirmClear(context),
                          tooltip: 'Clear cart',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),

                // Customer selector
                _CustomerSelector(),

                // Cart items
                Expanded(
                  child: pos.cartItems.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AppIcon(AppIcons.shoppingCartOutlined, size: 48, color: AppColors.textHint),
                              SizedBox(height: 8),
                              Text('Cart is empty', style: TextStyle(color: AppColors.textHint)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          itemCount: pos.cartItems.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => _CartItemRow(item: pos.cartItems[i]),
                        ),
                ),

                // Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.divider)),
                  ),
                  child: Column(
                    children: [
                      // Discount row
                      Row(
                        children: [
                          const Text('Discount:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          const Spacer(),
                          SizedBox(
                            width: 80,
                            height: 32,
                            child: TextField(
                              enabled: !allShortage,
                              decoration: const InputDecoration(
                                suffixText: '%',
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              style: const TextStyle(fontSize: 13),
                              onChanged: (v) {
                                final pct = double.tryParse(v) ?? 0;
                                ref.read(posProvider.notifier).setDiscount(percent: pct);
                              },
                            ),
                          ),
                        ],
                      ),
                      if (allShortage)
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'All items are shortage — discount disabled',
                              style: TextStyle(fontSize: 10.5, color: AppColors.warning),
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      _SummaryRow('Subtotal', 'Rs. ${nf.format(pos.subtotal)}'),
                      if (pos.totalDiscount > 0)
                        _SummaryRow('Discount', '-Rs. ${nf.format(pos.totalDiscount)}', color: AppColors.error),
                      if (pos.totalTax > 0)
                        _SummaryRow('Tax', 'Rs. ${nf.format(pos.totalTax)}'),
                      const Divider(height: 8),
                      _SummaryRow(
                        'TOTAL',
                        'Rs. ${nf.format(pos.grandTotal)}',
                        isBold: true,
                        fontSize: 18,
                      ),

                      const SizedBox(height: 8),

                      // Payment method
                      Row(
                        children: [
                          _PaymentChip(label: 'Cash', method: 'cash', current: pos.paymentMethod),
                          const SizedBox(width: 6),
                          _PaymentChip(label: 'Card', method: 'card', current: pos.paymentMethod),
                          const SizedBox(width: 6),
                          _PaymentChip(label: 'Credit', method: 'credit', current: pos.paymentMethod),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Received amount
                      if (pos.paymentMethod == 'cash') ...[
                        TextField(
                          controller: _receivedCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Received Amount',
                            prefixText: 'Rs. ',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final amt = double.tryParse(v) ?? 0;
                            ref.read(posProvider.notifier).setReceivedAmount(amt);
                          },
                        ),
                        if (pos.changeAmount > 0) ...[
                          const SizedBox(height: 4),
                          _SummaryRow('Change', 'Rs. ${nf.format(pos.changeAmount)}', color: AppColors.success),
                        ],
                        if (pos.creditAmount > 0) ...[
                          const SizedBox(height: 4),
                          _SummaryRow('Balance Due', 'Rs. ${nf.format(pos.creditAmount)}', color: AppColors.error),
                        ],
                      ],

                      const SizedBox(height: 12),

                      // Pay button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: pos.cartItems.isEmpty || pos.isProcessing
                              ? null
                              : () => _completeSale(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                          ),
                          child: pos.isProcessing
                              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const AppIcon(AppIcons.checkCircleOutline),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Complete Sale — Rs. ${nf.format(pos.grandTotal)}',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

  Future<void> _completeSale(BuildContext context) async {
    final pos = ref.read(posProvider);
    if (pos.paymentMethod == 'cash' && pos.receivedAmount == 0) {
      ref.read(posProvider.notifier).setReceivedAmount(pos.grandTotal);
    }

    final sale = await ref.read(posProvider.notifier).completeSale();
    if (!mounted) return;

    if (sale != null) {
      await _showReceiptDialog(context, sale);
      ref.read(posProvider.notifier).clearCart();
      _receivedCtrl.clear();
    } else {
      final err = ref.read(posProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err ?? 'Sale failed'), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _showReceiptDialog(BuildContext context, Sale sale) async {
    await showDialog(
      context: context,
      builder: (ctx) => _ReceiptDialog(sale: sale),
    );
  }

  Future<void> _holdBill(BuildContext context) async {
    final ctrl = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hold Bill'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: 'Label (optional, e.g. Table 3)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Hold')),
        ],
      ),
    );
    if (label != null) {
      await ref.read(posProvider.notifier).holdBill(label.isEmpty ? null : label);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bill held successfully'), backgroundColor: AppColors.success),
        );
      }
    }
  }

  Future<void> _showHeldBills(BuildContext context) async {
    final bills = await ref.read(posProvider.notifier).getHeldBills();
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Held Bills'),
        content: bills.isEmpty
            ? const Text('No held bills')
            : SizedBox(
                width: 300,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: bills.length,
                  itemBuilder: (_, i) => ListTile(
                    leading: const AppIcon(AppIcons.receipt),
                    title: Text(bills[i].label ?? 'Bill ${i + 1}'),
                    subtitle: Text(DateFormat('dd/MM hh:mm a').format(bills[i].createdAt)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref.read(posProvider.notifier).restoreHeldBill(bills[i]);
                    },
                  ),
                ),
              ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from cart?'),
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
    if (ok == true) ref.read(posProvider.notifier).clearCart();
  }
}

class _SearchResults extends ConsumerWidget {
  final String query;
  final VoidCallback onClear;
  const _SearchResults({required this.query, required this.onClear});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = ref.watch(_medicineSearchProvider(query));

    return results.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (medicines) => medicines.isEmpty
          ? Center(
              child: Text('No medicine found for "$query"', style: const TextStyle(color: AppColors.textHint)),
            )
          : _MedicineGrid(medicines: medicines, onAdd: onClear),
    );
  }
}

class _AllMedicinesList extends ConsumerWidget {
  final VoidCallback onAdd;
  const _AllMedicinesList({required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final medicinesAsync = ref.watch(_allMedicinesProvider);

    return medicinesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (medicines) => medicines.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AppIcon(AppIcons.search, size: 64, color: AppColors.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'No medicines in inventory yet',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add medicines from the Inventory page first',
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
                  ),
                ],
              ),
            )
          : _MedicineGrid(medicines: medicines, onAdd: onAdd),
    );
  }
}

class _MedicineGrid extends StatelessWidget {
  final List<Medicine> medicines;
  final VoidCallback onAdd;
  const _MedicineGrid({required this.medicines, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 210,
        mainAxisExtent: 172,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: medicines.length,
      itemBuilder: (_, i) => _MedicineTile(medicine: medicines[i], onAdd: onAdd),
    );
  }
}

class _MedicineTile extends ConsumerWidget {
  final Medicine medicine;
  final VoidCallback onAdd;
  const _MedicineTile({required this.medicine, required this.onAdd});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nf = NumberFormat('#,##0.00');
    final isLowStock = medicine.stock <= medicine.minStockLevel && medicine.stock > 0;
    final isOutOfStock = medicine.stock <= 0;
    final statusColor = isOutOfStock ? AppColors.outOfStock : isLowStock ? AppColors.lowStock : AppColors.inStock;
    final needsCold = StorageType.needsCold(medicine.storageType);

    void add() {
      ref.read(posProvider.notifier).addItem(medicine);
      onAdd();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: needsCold ? AppColors.error.withValues(alpha: 0.06) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        side: BorderSide(color: needsCold ? AppColors.error.withValues(alpha: 0.35) : AppColors.divider),
      ),
      child: InkWell(
        onTap: isOutOfStock ? null : add,
        child: Opacity(
          opacity: isOutOfStock ? 0.55 : 1,
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
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AppIcon(AppIcons.medication, color: statusColor, size: 18),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isOutOfStock ? 'Out' : isLowStock ? 'Low: ${medicine.stock}' : '${medicine.stock} left',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        medicine.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, height: 1.2),
                      ),
                    ),
                    if (needsCold) ...[
                      const SizedBox(width: 4),
                      const AppIcon(AppIcons.acUnit, size: 14, color: AppColors.error),
                    ],
                  ],
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
                if (medicine.isShortage) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Shortage · No discount',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: AppColors.warning),
                    ),
                  ),
                ],
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Rs. ${nf.format(medicine.salePrice)}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                      ),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: isOutOfStock ? null : add,
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: AppIcon(AppIcons.addCircle, color: AppColors.primary, size: 26),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CartItemRow extends ConsumerWidget {
  final CartItem item;
  const _CartItemRow({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nf = NumberFormat('#,##0.00');

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
              Text('Rs. ${nf.format(item.total)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.primary)),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => ref.read(posProvider.notifier).removeItem(item.medicineId),
                child: const AppIcon(AppIcons.close, size: 16, color: AppColors.error),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              // Qty controls
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
                        onPressed: () => ref.read(posProvider.notifier).updateQuantity(item.medicineId, item.quantity - 1),
                        padding: EdgeInsets.zero,
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
                        onPressed: () => ref.read(posProvider.notifier).updateQuantity(item.medicineId, item.quantity + 1),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('× Rs.${nf.format(item.unitPrice)}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              if (item.isShortage)
                const Text('No discount (shortage)', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.warning))
              else if (item.discountPercent > 0)
                Text('-${item.discountPercent.toStringAsFixed(0)}%', style: const TextStyle(fontSize: 11, color: AppColors.error)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pos = ref.watch(posProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: InkWell(
        onTap: () => _selectCustomer(context, ref),
        child: Row(
          children: [
            AppIcon(AppIcons.personOutline, size: 16, color: pos.selectedCustomerId != null ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                pos.selectedCustomerName ?? 'Walk-in Customer (tap to select)',
                style: TextStyle(
                  fontSize: 13,
                  color: pos.selectedCustomerId != null ? AppColors.textPrimary : AppColors.textHint,
                ),
              ),
            ),
            if (pos.selectedCustomerId != null)
              InkWell(
                onTap: () => ref.read(posProvider.notifier).setCustomer(null, null),
                child: const AppIcon(AppIcons.close, size: 16, color: AppColors.textHint),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectCustomer(BuildContext context, WidgetRef ref) async {
    final db = ref.read(databaseProvider);
    final customers = await db.select(db.customers).get();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => _CustomerPickerDialog(
        customers: customers,
        onSelect: (c) {
          ref.read(posProvider.notifier).setCustomer(c.id, c.name);
          Navigator.pop(ctx);
        },
      ),
    );
  }
}

class _CustomerPickerDialog extends StatefulWidget {
  final List<Customer> customers;
  final void Function(Customer) onSelect;

  const _CustomerPickerDialog({required this.customers, required this.onSelect});

  @override
  State<_CustomerPickerDialog> createState() => _CustomerPickerDialogState();
}

class _CustomerPickerDialogState extends State<_CustomerPickerDialog> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.customers
        .where((c) => c.name.toLowerCase().contains(_search.toLowerCase()) || (c.phone?.contains(_search) ?? false))
        .toList();

    return AlertDialog(
      title: const Text('Select Customer'),
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
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) => ListTile(
                  leading: const CircleAvatar(child: AppIcon(AppIcons.person)),
                  title: Text(filtered[i].name),
                  subtitle: Text(filtered[i].phone ?? ''),
                  trailing: filtered[i].balance > 0
                      ? Text('Rs. ${filtered[i].balance.toStringAsFixed(0)} due', style: const TextStyle(color: AppColors.error, fontSize: 12))
                      : null,
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

class _PaymentChip extends ConsumerWidget {
  final String label;
  final String method;
  final String current;

  const _PaymentChip({required this.label, required this.method, required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = method == current;
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(posProvider.notifier).setPaymentMethod(method),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.background,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: selected ? AppColors.primary : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
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

class _ReceiptDialog extends ConsumerWidget {
  final Sale sale;
  const _ReceiptDialog({required this.sale});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nf = NumberFormat('#,##0.00');
    final posState = ref.watch(posProvider);

    return AlertDialog(
      title: Row(
        children: [
          const AppIcon(AppIcons.checkCircle, color: AppColors.success, size: 24),
          const SizedBox(width: 8),
          const Text('Sale Complete!'),
          const Spacer(),
          Text('${sale.invoiceNo}', style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
        ],
      ),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (posState.cartItems.isNotEmpty) ...[
              const Text('Items', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: posState.cartItems.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = posState.cartItems[i];
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
                                  '${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)} x Rs. ${nf.format(item.unitPrice)}',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text('Rs. ${nf.format(item.total)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
            _SummaryRow('Total', 'Rs. ${nf.format(sale.totalAmount)}', isBold: true, fontSize: 18),
            _SummaryRow('Paid', 'Rs. ${nf.format(sale.paidAmount)}'),
            if (sale.changeAmount > 0) _SummaryRow('Change', 'Rs. ${nf.format(sale.changeAmount)}', color: AppColors.success),
            if (sale.creditAmount > 0) _SummaryRow('Balance Due', 'Rs. ${nf.format(sale.creditAmount)}', color: AppColors.error),
          ],
        ),
      ),
      actions: [
        OutlinedButton.icon(
          icon: const AppIcon(AppIcons.print),
          label: const Text('Print Receipt'),
          onPressed: () async {
            final settings = await ref.read(settingsRepositoryProvider).getAll();
            final posState = ref.read(posProvider);
            final user = ref.read(authProvider).user;
            final df = DateFormat('dd/MM/yyyy');

            final receiptData = ReceiptData(
              shopName: settings['shop_name'] ?? 'Pharmacy',
              shopAddress: settings['shop_address'] ?? '',
              shopPhone: settings['shop_phone'] ?? '',
              invoiceNo: sale.invoiceNo,
              saleDate: sale.saleDate,
              customerName: posState.selectedCustomerName,
              cashierName: user?.name,
              items: posState.cartItems.map((item) => ReceiptItem(
                name: item.medicineName,
                batchNo: item.batchNo,
                expiryDate: item.expiryDate != null ? df.format(item.expiryDate!) : null,
                quantity: item.quantity,
                unitPrice: item.unitPrice,
                discount: item.discountAmount,
                total: item.total,
              )).toList(),
              subtotal: sale.subtotal,
              discountAmount: sale.discountAmount,
              taxAmount: sale.taxAmount,
              totalAmount: sale.totalAmount,
              paidAmount: sale.paidAmount,
              changeAmount: sale.changeAmount,
              paymentMethod: sale.paymentMethod,
              headerText: settings['receipt_header'] ?? 'Thank you for your visit!',
              footerText: settings['receipt_footer'] ?? 'Get well soon!',
              showBatch: settings['show_batch_on_receipt'] != 'false',
              showMrp: settings['show_mrp_on_receipt'] == 'true',
            );

            if (!context.mounted) return;
            try {
              await ref.read(printServiceProvider).printReceipt(context, receiptData);
              if (context.mounted) Navigator.pop(context);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Print failed: $e'),
                    backgroundColor: AppColors.error,
                    duration: const Duration(seconds: 6),
                  ),
                );
              }
            }
          },
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('New Sale'),
        ),
      ],
    );
  }
}
