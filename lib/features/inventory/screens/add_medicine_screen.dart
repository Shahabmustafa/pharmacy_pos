import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' hide Column;
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/constants/storage_types.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/medicine_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/widgets/app_icon.dart';
import 'categories_units_screen.dart';

class AddMedicineScreen extends ConsumerStatefulWidget {
  final int? medicineId;
  const AddMedicineScreen({super.key, this.medicineId});

  @override
  ConsumerState<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends ConsumerState<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _genericCtrl = TextEditingController();
  final _barcodeCtrl = TextEditingController();
  final _salePriceCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _mrpCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _minStockCtrl = TextEditingController(text: '5');
  final _packSizeCtrl = TextEditingController();
  final _rackCtrl = TextEditingController();
  final _taxCtrl = TextEditingController(text: '0');
  int? _selectedCategoryId;
  int? _selectedCompanyId;
  int? _selectedUnitId;
  String _storageType = StorageType.normal;
  bool _requiresPrescription = false;
  bool _isShortage = false;
  bool _isLoading = false;
  Medicine? _existing;

  @override
  void initState() {
    super.initState();
    if (widget.medicineId != null) _loadExisting();
  }

  Future<void> _loadExisting() async {
    final m = await ref.read(medicineRepositoryProvider).getById(widget.medicineId!);
    if (m != null && mounted) {
      setState(() {
        _existing = m;
        _nameCtrl.text = m.name;
        _genericCtrl.text = m.genericName ?? '';
        _barcodeCtrl.text = m.barcode ?? '';
        _salePriceCtrl.text = m.salePrice.toString();
        _purchasePriceCtrl.text = m.purchasePrice.toString();
        _mrpCtrl.text = m.mrp.toString();
        _stockCtrl.text = m.stock.toString();
        _minStockCtrl.text = m.minStockLevel.toString();
        _packSizeCtrl.text = m.packSize ?? '';
        _rackCtrl.text = m.rackLocation ?? '';
        _taxCtrl.text = m.taxPercent.toString();
        _selectedCategoryId = m.categoryId;
        _selectedCompanyId = m.companyId;
        _selectedUnitId = m.unitId;
        _storageType = m.storageType;
        _requiresPrescription = m.requiresPrescription;
        _isShortage = m.isShortage;
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _genericCtrl, _barcodeCtrl, _salePriceCtrl, _purchasePriceCtrl, _mrpCtrl, _stockCtrl, _minStockCtrl, _packSizeCtrl, _rackCtrl, _taxCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final companion = MedicinesCompanion(
        id: _existing != null ? Value(_existing!.id) : const Value.absent(),
        name: Value(_nameCtrl.text.trim()),
        genericName: Value(_genericCtrl.text.trim().isEmpty ? null : _genericCtrl.text.trim()),
        barcode: Value(_barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim()),
        salePrice: Value(double.tryParse(_salePriceCtrl.text) ?? 0),
        purchasePrice: Value(double.tryParse(_purchasePriceCtrl.text) ?? 0),
        mrp: Value(double.tryParse(_mrpCtrl.text) ?? 0),
        stock: Value(double.tryParse(_stockCtrl.text) ?? 0),
        minStockLevel: Value(double.tryParse(_minStockCtrl.text) ?? 5),
        packSize: Value(_packSizeCtrl.text.trim().isEmpty ? null : _packSizeCtrl.text.trim()),
        rackLocation: Value(_rackCtrl.text.trim().isEmpty ? null : _rackCtrl.text.trim()),
        taxPercent: Value(double.tryParse(_taxCtrl.text) ?? 0),
        categoryId: Value(_selectedCategoryId),
        companyId: Value(_selectedCompanyId),
        unitId: Value(_selectedUnitId),
        storageType: Value(_storageType),
        requiresPrescription: Value(_requiresPrescription),
        isShortage: Value(_isShortage),
        needsSync: const Value(true),
        updatedAt: Value(DateTime.now()),
      );

      final repo = ref.read(medicineRepositoryProvider);
      if (_existing != null) {
        await repo.update(companion);
      } else {
        await repo.insert(companion);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicine saved successfully'), backgroundColor: AppColors.success),
        );
        context.go('/inventory');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingLG),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(icon: const AppIcon(AppIcons.arrowBack), onPressed: () => context.go('/inventory')),
                const SizedBox(width: 8),
                Text(
                  widget.medicineId != null ? 'Edit Medicine' : 'Add Medicine',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left column
                  Expanded(
                    flex: 2,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Basic Information', style: Theme.of(context).textTheme.titleMedium),
                                const Divider(),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _nameCtrl,
                                  decoration: const InputDecoration(labelText: 'Medicine Name *'),
                                  validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _genericCtrl,
                                  decoration: const InputDecoration(labelText: 'Generic Name / Salt'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _barcodeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Barcode',
                                    suffixIcon: AppIcon(AppIcons.qrCodeScanner),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _packSizeCtrl,
                                  decoration: const InputDecoration(labelText: 'Pack Size (e.g. 10 Tablets/Strip)'),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _rackCtrl,
                                  decoration: const InputDecoration(labelText: 'Rack / Location'),
                                ),
                                const SizedBox(height: 16),
                                Text('Pricing', style: Theme.of(context).textTheme.titleMedium),
                                const Divider(),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _purchasePriceCtrl,
                                        decoration: const InputDecoration(labelText: 'Purchase Price *', prefixText: 'Rs. '),
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v!.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _salePriceCtrl,
                                        decoration: const InputDecoration(labelText: 'Sale Price *', prefixText: 'Rs. '),
                                        keyboardType: TextInputType.number,
                                        validator: (v) => v!.isEmpty ? 'Required' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _mrpCtrl,
                                        decoration: const InputDecoration(labelText: 'MRP', prefixText: 'Rs. '),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _taxCtrl,
                                        decoration: const InputDecoration(labelText: 'Tax %', suffixText: '%'),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Text('Stock', style: Theme.of(context).textTheme.titleMedium),
                                const Divider(),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _stockCtrl,
                                        decoration: const InputDecoration(labelText: 'Opening Stock'),
                                        keyboardType: TextInputType.number,
                                        enabled: widget.medicineId == null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _minStockCtrl,
                                        decoration: const InputDecoration(labelText: 'Minimum Stock Level'),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Right column
                  Expanded(
                    child: Column(
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Classification', style: Theme.of(context).textTheme.titleMedium),
                                const Divider(),
                                const SizedBox(height: 12),
                                // Category dropdown
                                FutureBuilder<List<MedicineCategory>>(
                                  future: db.select(db.medicineCategories).get(),
                                  builder: (_, snap) {
                                    final cats = snap.data ?? [];
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<int>(
                                            value: _selectedCategoryId,
                                            isExpanded: true,
                                            decoration: const InputDecoration(labelText: 'Category'),
                                            items: cats.map((c) => DropdownMenuItem(
                                              value: c.id,
                                              child: Text(c.name, overflow: TextOverflow.ellipsis),
                                            )).toList(),
                                            onChanged: (v) => setState(() => _selectedCategoryId = v),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const AppIcon(AppIcons.addCircle, size: 20, color: AppColors.primary),
                                          tooltip: 'Add Category',
                                          onPressed: () async {
                                            await showCategoryDialog(context, db);
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<List<MedicineCompany>>(
                                  future: db.select(db.medicineCompanies).get(),
                                  builder: (_, snap) {
                                    final items = snap.data ?? [];
                                    return DropdownButtonFormField<int>(
                                      value: _selectedCompanyId,
                                      isExpanded: true,
                                      decoration: const InputDecoration(labelText: 'Company / Manufacturer'),
                                      items: items.map((c) => DropdownMenuItem(
                                        value: c.id,
                                        child: Text(c.name, overflow: TextOverflow.ellipsis),
                                      )).toList(),
                                      onChanged: (v) => setState(() => _selectedCompanyId = v),
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<List<MedicineUnit>>(
                                  future: db.select(db.medicineUnits).get(),
                                  builder: (_, snap) {
                                    final items = snap.data ?? [];
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: DropdownButtonFormField<int>(
                                            value: _selectedUnitId,
                                            isExpanded: true,
                                            decoration: const InputDecoration(labelText: 'Unit'),
                                            items: items.map((u) => DropdownMenuItem(
                                              value: u.id,
                                              child: Text(u.name, overflow: TextOverflow.ellipsis),
                                            )).toList(),
                                            onChanged: (v) => setState(() => _selectedUnitId = v),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const AppIcon(AppIcons.addCircle, size: 20, color: AppColors.primary),
                                          tooltip: 'Add Unit',
                                          onPressed: () async {
                                            await showUnitDialog(context, db);
                                            setState(() {});
                                          },
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String>(
                                  value: _storageType,
                                  decoration: const InputDecoration(labelText: 'Storage Type'),
                                  items: StorageType.labels.entries
                                      .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _storageType = v ?? StorageType.normal),
                                ),
                                if (StorageType.needsCold(_storageType)) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const AppIcon(AppIcons.acUnit, size: 16, color: AppColors.info),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'This medicine must be kept refrigerated to prevent spoilage.',
                                          style: TextStyle(fontSize: 11.5, color: AppColors.info),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 12),
                                SwitchListTile(
                                  title: const Text('Requires Prescription', style: TextStyle(fontSize: 14)),
                                  value: _requiresPrescription,
                                  onChanged: (v) => setState(() => _requiresPrescription = v),
                                  contentPadding: EdgeInsets.zero,
                                ),
                                SwitchListTile(
                                  title: const Text('Shortage (not available in market)', style: TextStyle(fontSize: 14)),
                                  subtitle: const Text('Discount will be disabled for this medicine at sale', style: TextStyle(fontSize: 11.5)),
                                  value: _isShortage,
                                  activeThumbColor: AppColors.error,
                                  onChanged: (v) => setState(() => _isShortage = v),
                                  contentPadding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _save,
                            icon: _isLoading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const AppIcon(AppIcons.save),
                            label: Text(widget.medicineId != null ? 'Update Medicine' : 'Save Medicine'),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: OutlinedButton(
                            onPressed: () => context.go('/inventory'),
                            child: const Text('Cancel'),
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
      ),
    );
  }
}
