import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/database/app_database.dart';
import 'settings_repository.dart';

class MedicineRepository {
  final AppDatabase _db;

  MedicineRepository(this._db);

  Stream<List<Medicine>> watchAll({bool activeOnly = true}) {
    final query = _db.select(_db.medicines);
    if (activeOnly) query.where((m) => m.isActive.equals(true));
    query.orderBy([(m) => OrderingTerm.asc(m.name)]);
    return query.watch();
  }

  Future<List<Medicine>> search(String query) async {
    final q = '%${query.toLowerCase()}%';
    return (_db.select(_db.medicines)
          ..where((m) =>
              m.name.lower().like(q) |
              m.genericName.lower().like(q) |
              m.barcode.like(q))
          ..where((m) => m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.name)])
          ..limit(50))
        .get();
  }

  Future<Medicine?> getById(int id) {
    return (_db.select(_db.medicines)..where((m) => m.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Medicine?> getByBarcode(String barcode) {
    return (_db.select(_db.medicines)..where((m) => m.barcode.equals(barcode)))
        .getSingleOrNull();
  }

  Future<int> insert(MedicinesCompanion entry) {
    return _db.into(_db.medicines).insert(entry);
  }

  Future<bool> update(MedicinesCompanion entry) {
    return _db.update(_db.medicines).replace(entry);
  }

  Future<void> delete(int id) async {
    await (_db.update(_db.medicines)..where((m) => m.id.equals(id)))
        .write(const MedicinesCompanion(isActive: Value(false)));
  }

  Future<List<Medicine>> getLowStock() async {
    return _db.customSelect(
      'SELECT * FROM medicines WHERE stock <= min_stock_level AND is_active = 1 ORDER BY stock ASC',
      readsFrom: {_db.medicines},
    ).map((row) => _db.medicines.map(row.data)).get();
  }

  Future<List<Medicine>> getOutOfStock() async {
    return (_db.select(_db.medicines)
          ..where((m) => m.stock.isSmallerOrEqualValue(0) & m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .get();
  }

  Future<void> updateStock(int medicineId, double newStock) async {
    await (_db.update(_db.medicines)..where((m) => m.id.equals(medicineId)))
        .write(MedicinesCompanion(stock: Value(newStock)));
  }

  Future<void> adjustStock(int medicineId, double delta) async {
    final medicine = await getById(medicineId);
    if (medicine == null) return;
    await updateStock(medicineId, medicine.stock + delta);
  }

  // With category info
  Future<List<MedicineWithDetails>> getAllWithDetails() async {
    final medicines = await (_db.select(_db.medicines)
          ..where((m) => m.isActive.equals(true))
          ..orderBy([(m) => OrderingTerm.asc(m.name)]))
        .get();
    final result = <MedicineWithDetails>[];

    for (final m in medicines) {
      MedicineCategory? cat;
      MedicineCompany? comp;

      if (m.categoryId != null) {
        cat = await (_db.select(_db.medicineCategories)
              ..where((c) => c.id.equals(m.categoryId!)))
            .getSingleOrNull();
      }
      if (m.companyId != null) {
        comp = await (_db.select(_db.medicineCompanies)
              ..where((c) => c.id.equals(m.companyId!)))
            .getSingleOrNull();
      }

      result.add(MedicineWithDetails(medicine: m, category: cat, company: comp));
    }
    return result;
  }
}

class MedicineWithDetails {
  final Medicine medicine;
  final MedicineCategory? category;
  final MedicineCompany? company;

  const MedicineWithDetails({
    required this.medicine,
    this.category,
    this.company,
  });
}

final medicineRepositoryProvider = Provider<MedicineRepository>((ref) {
  return MedicineRepository(ref.watch(databaseProvider));
});
