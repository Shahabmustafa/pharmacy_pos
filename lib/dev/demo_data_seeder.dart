import 'dart:math';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import '../data/local/database/app_database.dart';
import '../data/repositories/sale_repository.dart';
import '../core/constants/storage_types.dart';

class _DemoMedicine {
  final String name;
  final String genericName;
  final String category;
  final String unit;
  final String storageType;
  final double purchasePrice;
  final double salePrice;
  final double mrp;
  final int purchaseQty;
  const _DemoMedicine({
    required this.name,
    required this.genericName,
    required this.category,
    required this.unit,
    this.storageType = StorageType.normal,
    required this.purchasePrice,
    required this.salePrice,
    required this.mrp,
    required this.purchaseQty,
  });
}

const _demoMedicines = [
  _DemoMedicine(name: 'Panadol 500mg', genericName: 'Paracetamol', category: 'Tablets', unit: 'Strip', purchasePrice: 25, salePrice: 35, mrp: 40, purchaseQty: 200),
  _DemoMedicine(name: 'Augmentin 625mg', genericName: 'Amoxicillin + Clavulanate', category: 'Tablets', unit: 'Strip', purchasePrice: 180, salePrice: 240, mrp: 260, purchaseQty: 80),
  _DemoMedicine(name: 'Brufen Syrup', genericName: 'Ibuprofen', category: 'Syrups', unit: 'Bottle', purchasePrice: 90, salePrice: 130, mrp: 150, purchaseQty: 60),
  _DemoMedicine(
    name: 'Mixtard Insulin 100IU',
    genericName: 'Insulin',
    category: 'Injections',
    unit: 'Vial',
    storageType: StorageType.refrigerated,
    purchasePrice: 650,
    salePrice: 850,
    mrp: 900,
    purchaseQty: 40,
  ),
  _DemoMedicine(name: 'Panadol Syrup (Kids)', genericName: 'Paracetamol', category: 'Syrups', unit: 'Bottle', purchasePrice: 60, salePrice: 90, mrp: 100, purchaseQty: 70),
  _DemoMedicine(name: 'Disprin', genericName: 'Aspirin', category: 'Tablets', unit: 'Strip', purchasePrice: 15, salePrice: 25, mrp: 30, purchaseQty: 150),
  _DemoMedicine(name: 'Amoxil 250mg', genericName: 'Amoxicillin', category: 'Capsules', unit: 'Strip', purchasePrice: 60, salePrice: 85, mrp: 95, purchaseQty: 100),
  _DemoMedicine(name: 'Eye Relief Drops', genericName: 'Sodium Chloride', category: 'Drops', unit: 'Bottle', purchasePrice: 70, salePrice: 110, mrp: 120, purchaseQty: 50),
];

const _demoSuppliers = ['MediCare Distributors', 'HealthPlus Pharma Supply'];

const _demoCustomers = [
  ('Ahmed Raza', '0300-1234567', 0.0),
  ('Sana Malik', '0321-9876543', 0.0),
  ('Bilal Traders', '0333-5551212', 0.0),
];

const _demoExpenses = [
  ('Rent', 'Shop rent for the month', 25000.0),
  ('Utilities', 'Electricity bill', 6500.0),
  ('Transport', 'Delivery van fuel', 3000.0),
  ('Salaries', 'Staff advance', 10000.0),
];

int? _findByName(List<dynamic> rows, String name) {
  for (final r in rows) {
    if (r.name == name) return r.id as int;
  }
  return null;
}

/// Populates suppliers, customers, medicines, purchases (with stock batches),
/// a week of sales and a few expenses so every dashboard/report/list has
/// real data to show. Safe to run more than once — existing suppliers,
/// customers and medicines (matched by name) are reused rather than duplicated,
/// while a fresh round of purchases/sales/expenses is added each time.
Future<String> seedDemoData(AppDatabase db, SaleRepository saleRepo, {required int userId}) async {
  const uuid = Uuid();
  final rnd = Random();

  // ── Suppliers ──────────────────────────────────────────────────────────
  final supplierIds = <int>[];
  for (final name in _demoSuppliers) {
    final existing = await (db.select(db.suppliers)..where((s) => s.name.equals(name))).getSingleOrNull();
    if (existing != null) {
      supplierIds.add(existing.id);
      continue;
    }
    final id = await db.into(db.suppliers).insert(SuppliersCompanion.insert(
          name: name,
          serverId: Value(uuid.v4()),
          needsSync: const Value(true),
        ));
    supplierIds.add(id);
  }

  // ── Customers ──────────────────────────────────────────────────────────
  final customerIds = <int>[];
  for (final entry in _demoCustomers) {
    final (name, phone, balance) = entry;
    final existing = await (db.select(db.customers)..where((c) => c.name.equals(name))).getSingleOrNull();
    if (existing != null) {
      customerIds.add(existing.id);
      continue;
    }
    final id = await db.into(db.customers).insert(CustomersCompanion.insert(
          name: name,
          phone: Value(phone),
          balance: Value(balance),
          serverId: Value(uuid.v4()),
          needsSync: const Value(true),
        ));
    customerIds.add(id);
  }

  // ── Medicines + a purchase (stock top-up) for each ───────────────────────
  final cats = await db.select(db.medicineCategories).get();
  final units = await db.select(db.medicineUnits).get();

  final medicineIds = <String, int>{};
  final runningStock = <int, double>{};
  final batchInfo = <int, (int batchId, String batchNo, DateTime expiry)>{};

  final purchaseDate = DateTime.now().subtract(const Duration(days: 12));

  for (final seed in _demoMedicines) {
    final existing = await (db.select(db.medicines)..where((m) => m.name.equals(seed.name))).getSingleOrNull();
    int medId;
    double priorStock;
    if (existing != null) {
      medId = existing.id;
      priorStock = existing.stock;
    } else {
      medId = await db.into(db.medicines).insert(MedicinesCompanion.insert(
            name: seed.name,
            genericName: Value(seed.genericName),
            categoryId: Value(_findByName(cats, seed.category)),
            unitId: Value(_findByName(units, seed.unit)),
            salePrice: Value(seed.salePrice),
            purchasePrice: Value(seed.purchasePrice),
            mrp: Value(seed.mrp),
            storageType: Value(seed.storageType),
            minStockLevel: const Value(15),
            needsSync: const Value(true),
          ));
      priorStock = 0;
    }
    medicineIds[seed.name] = medId;

    final supplierId = supplierIds[rnd.nextInt(supplierIds.length)];
    final batchNo = 'DEMO-${purchaseDate.year}${purchaseDate.month.toString().padLeft(2, '0')}-$medId';
    final expiry = purchaseDate.add(const Duration(days: 540));
    final totalCost = seed.purchaseQty * seed.purchasePrice;

    final purchaseId = await db.into(db.purchases).insert(PurchasesCompanion.insert(
          invoiceNo: 'PUR-DEMO-${uuid.v4().substring(0, 8)}',
          purchaseDate: Value(purchaseDate),
          supplierId: Value(supplierId),
          userId: userId,
          subtotal: Value(totalCost),
          totalAmount: Value(totalCost),
          paidAmount: Value(totalCost),
          creditAmount: const Value(0),
          serverId: Value(uuid.v4()),
          needsSync: const Value(true),
        ));

    await db.into(db.purchaseItems).insert(PurchaseItemsCompanion.insert(
          purchaseId: purchaseId,
          medicineId: medId,
          medicineName: seed.name,
          batchNo: Value(batchNo),
          expiryDate: Value(expiry),
          quantity: seed.purchaseQty.toDouble(),
          unitCost: seed.purchasePrice,
          salePrice: Value(seed.salePrice),
          totalCost: totalCost,
          serverId: Value(uuid.v4()),
          needsSync: const Value(true),
        ));

    final newStock = priorStock + seed.purchaseQty;
    await (db.update(db.medicines)..where((m) => m.id.equals(medId))).write(MedicinesCompanion(
      stock: Value(newStock),
      purchasePrice: Value(seed.purchasePrice),
      salePrice: Value(seed.salePrice),
      updatedAt: Value(DateTime.now()),
      needsSync: const Value(true),
    ));

    final batchId = await db.into(db.stockBatches).insert(StockBatchesCompanion.insert(
          medicineId: medId,
          batchNo: batchNo,
          expiryDate: expiry,
          purchasePrice: Value(seed.purchasePrice),
          salePrice: Value(seed.salePrice),
          quantity: Value(seed.purchaseQty.toDouble()),
          remainingQty: Value(seed.purchaseQty.toDouble()),
          serverId: Value(uuid.v4()),
          needsSync: const Value(true),
        ));

    runningStock[medId] = newStock;
    batchInfo[medId] = (batchId, batchNo, expiry);
  }

  // ── A week of sales, biased so one product is clearly the best-seller ───
  final medNames = _demoMedicines.map((m) => m.name).toList();
  final bestSeller = medNames.first;
  int salesCreated = 0;

  for (int dayOffset = 6; dayOffset >= 0; dayOffset--) {
    final day = DateTime.now().subtract(Duration(days: dayOffset));
    final salesToday = 2 + rnd.nextInt(3);

    for (int s = 0; s < salesToday; s++) {
      final itemCount = 1 + rnd.nextInt(3);
      final pool = List<String>.from(medNames)..shuffle(rnd);
      final useNames = <String>[];
      if (rnd.nextDouble() < 0.7) useNames.add(bestSeller);
      for (final n in pool) {
        if (useNames.length >= itemCount) break;
        if (!useNames.contains(n)) useNames.add(n);
      }

      final items = <CartItem>[];
      double subtotal = 0;
      for (final name in useNames) {
        final medId = medicineIds[name]!;
        final seed = _demoMedicines.firstWhere((m) => m.name == name);
        final qty = (name == bestSeller ? 3 + rnd.nextInt(6) : 1 + rnd.nextInt(4)).toDouble();
        final stock = runningStock[medId] ?? 0;
        if (stock < qty) continue;
        final batch = batchInfo[medId]!;
        final total = qty * seed.salePrice;
        items.add(CartItem(
          medicineId: medId,
          medicineName: name,
          batchId: batch.$1,
          batchNo: batch.$2,
          expiryDate: batch.$3,
          quantity: qty,
          unitPrice: seed.salePrice,
          purchasePrice: seed.purchasePrice,
          currentStock: stock,
          total: total,
        ));
        subtotal += total;
        runningStock[medId] = stock - qty;
      }

      if (items.isEmpty) continue;

      final useCustomer = rnd.nextDouble() < 0.3;
      final customerId = useCustomer ? customerIds[rnd.nextInt(customerIds.length)] : null;
      final paidFull = !useCustomer || rnd.nextDouble() < 0.7;
      final paidAmount = paidFull ? subtotal : subtotal * 0.5;

      await saleRepo.createSale(
        userId: userId,
        items: items,
        customerId: customerId,
        discountPercent: 0,
        discountAmount: 0,
        taxAmount: 0,
        totalAmount: subtotal,
        paidAmount: paidAmount,
        paymentMethod: customerId != null && !paidFull ? 'credit' : 'cash',
        saleDate: DateTime(day.year, day.month, day.day, 10 + rnd.nextInt(8), rnd.nextInt(60)),
      );
      salesCreated++;
    }
  }

  // ── Expenses ──────────────────────────────────────────────────────────
  final expCats = await db.select(db.expenseCategories).get();
  for (int i = 0; i < _demoExpenses.length; i++) {
    final (catName, desc, amount) = _demoExpenses[i];
    await db.into(db.expenses).insert(ExpensesCompanion.insert(
          categoryId: Value(_findByName(expCats, catName)),
          description: desc,
          amount: amount,
          expenseDate: Value(DateTime.now().subtract(Duration(days: i * 2))),
          userId: userId,
          serverId: Value(uuid.v4()),
          needsSync: const Value(true),
        ));
  }

  return '${_demoMedicines.length} medicines, ${supplierIds.length} suppliers, '
      '${customerIds.length} customers, $salesCreated sales (last 7 days), '
      '${_demoExpenses.length} expenses added.';
}
