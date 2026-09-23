import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

// ─── Tables ──────────────────────────────────────────────────────────────────

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get username => text().withLength(min: 1, max: 50).unique()();
  TextColumn get passwordHash => text()();
  TextColumn get role => text().withDefault(const Constant('cashier'))(); // admin, manager, cashier, pharmacist
  TextColumn get phone => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()(); // Supabase UUID
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class MedicineCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get nameUrdu => text().nullable()();
  TextColumn get description => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class MedicineCompanies extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class MedicineSalts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get description => text().nullable()();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class MedicineUnits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)(); // Strip, Bottle, Box, Tube
  TextColumn get abbreviation => text().withLength(min: 1, max: 10)(); // Str, Btl, Bx
  TextColumn get serverId => text().nullable()();
}

class Medicines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 300)();
  TextColumn get genericName => text().nullable()();
  IntColumn get categoryId => integer().nullable().references(MedicineCategories, #id)();
  IntColumn get companyId => integer().nullable().references(MedicineCompanies, #id)();
  IntColumn get saltId => integer().nullable().references(MedicineSalts, #id)();
  IntColumn get unitId => integer().nullable().references(MedicineUnits, #id)();
  TextColumn get barcode => text().nullable().unique()();
  RealColumn get salePrice => real().withDefault(const Constant(0.0))();
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  RealColumn get mrp => real().withDefault(const Constant(0.0))(); // Max Retail Price
  RealColumn get stock => real().withDefault(const Constant(0.0))();
  RealColumn get minStockLevel => real().withDefault(const Constant(5.0))();
  TextColumn get packSize => text().nullable()(); // e.g. "10 Tablets/Strip"
  TextColumn get description => text().nullable()();
  TextColumn get sideEffects => text().nullable()();
  TextColumn get schedule => text().nullable()(); // Schedule H, Schedule G, etc.
  BoolColumn get requiresPrescription => boolean().withDefault(const Constant(false))();
  RealColumn get taxPercent => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get rackLocation => text().nullable()();
  TextColumn get storageType => text().withDefault(const Constant('normal'))(); // normal, refrigerated, frozen
  BoolColumn get isShortage => boolean().withDefault(const Constant(false))(); // short in market / unavailable from suppliers — discount disabled at sale
  TextColumn get imagePath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class StockBatches extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  TextColumn get batchNo => text().withLength(min: 1, max: 100)();
  DateTimeColumn get expiryDate => dateTime()();
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))();
  RealColumn get salePrice => real().withDefault(const Constant(0.0))();
  RealColumn get quantity => real().withDefault(const Constant(0.0))();
  RealColumn get remainingQty => real().withDefault(const Constant(0.0))();
  IntColumn get purchaseItemId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get phone => text().nullable()();
  TextColumn get cnic => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get email => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))(); // positive = customer owes, negative = advance
  RealColumn get creditLimit => real().withDefault(const Constant(0.0))();
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  TextColumn get companyName => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get mobile => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get ntn => text().nullable()();
  TextColumn get strn => text().nullable()();
  RealColumn get balance => real().withDefault(const Constant(0.0))(); // positive = we owe supplier
  TextColumn get notes => text().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNo => text().unique()();
  DateTimeColumn get saleDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get changeAmount => real().withDefault(const Constant(0.0))();
  RealColumn get creditAmount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))(); // cash, card, credit, mixed
  TextColumn get status => text().withDefault(const Constant('completed'))(); // completed, returned, partial_return, hold
  TextColumn get notes => text().nullable()();
  TextColumn get prescriptionNo => text().nullable()();
  BoolColumn get isPrinted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  IntColumn get batchId => integer().nullable().references(StockBatches, #id)();
  TextColumn get medicineName => text()(); // snapshot
  TextColumn get batchNo => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get quantity => real()();
  RealColumn get unitPrice => real()();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalPrice => real()();
  RealColumn get purchasePrice => real().withDefault(const Constant(0.0))(); // for profit calc
  BoolColumn get isReturned => boolean().withDefault(const Constant(false))();
  RealColumn get returnedQty => real().withDefault(const Constant(0.0))();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get invoiceNo => text()();
  TextColumn get supplierInvoiceNo => text().nullable()();
  DateTimeColumn get purchaseDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  RealColumn get subtotal => real().withDefault(const Constant(0.0))();
  RealColumn get discountAmount => real().withDefault(const Constant(0.0))();
  RealColumn get taxAmount => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real().withDefault(const Constant(0.0))();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  RealColumn get creditAmount => real().withDefault(const Constant(0.0))();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get status => text().withDefault(const Constant('received'))(); // pending, received, partial, returned
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseId => integer().references(Purchases, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  TextColumn get medicineName => text()();
  TextColumn get batchNo => text().nullable()();
  DateTimeColumn get expiryDate => dateTime().nullable()();
  RealColumn get quantity => real()();
  RealColumn get freeQuantity => real().withDefault(const Constant(0.0))();
  RealColumn get unitCost => real()();
  RealColumn get salePrice => real().withDefault(const Constant(0.0))();
  RealColumn get mrp => real().withDefault(const Constant(0.0))();
  RealColumn get discountPercent => real().withDefault(const Constant(0.0))();
  RealColumn get taxPercent => real().withDefault(const Constant(0.0))();
  RealColumn get totalCost => real()();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class SaleReturns extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer().references(Sales, #id)();
  TextColumn get returnNo => text().unique()();
  DateTimeColumn get returnDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();
  RealColumn get totalReturnAmount => real()();
  TextColumn get reason => text().nullable()();
  TextColumn get refundMethod => text().withDefault(const Constant('cash'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class SaleReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(SaleReturns, #id)();
  IntColumn get saleItemId => integer().references(SaleItems, #id)();
  IntColumn get medicineId => integer().references(Medicines, #id)();
  RealColumn get returnedQty => real()();
  RealColumn get unitPrice => real()();
  RealColumn get totalAmount => real()();
  TextColumn get serverId => text().nullable()();
}

class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get description => text().nullable()();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId => integer().nullable().references(ExpenseCategories, #id)();
  TextColumn get description => text()();
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime().withDefault(currentDateAndTime)();
  IntColumn get userId => integer().references(Users, #id)();
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  TextColumn get notes => text().nullable()();
  TextColumn get receiptPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class CustomerPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get customerId => integer().references(Customers, #id)();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // received, refund
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  IntColumn get saleId => integer().nullable().references(Sales, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class SupplierPayments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get supplierId => integer().references(Suppliers, #id)();
  RealColumn get amount => real()();
  TextColumn get type => text()(); // paid, received
  TextColumn get paymentMethod => text().withDefault(const Constant('cash'))();
  DateTimeColumn get paymentDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get notes => text().nullable()();
  IntColumn get purchaseId => integer().nullable().references(Purchases, #id)();
  IntColumn get userId => integer().references(Users, #id)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get serverId => text().nullable()();
  BoolColumn get needsSync => boolean().withDefault(const Constant(false))();
}

class HeldBills extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get label => text().nullable()();
  TextColumn get cartData => text()(); // JSON encoded cart
  IntColumn get customerId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().unique()();
  TextColumn get value => text()();
  TextColumn get type => text().withDefault(const Constant('string'))(); // string, int, double, bool, json
}

class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get targetTable => text()();
  TextColumn get operation => text()(); // insert, update, delete
  IntColumn get recordId => integer()();
  TextColumn get data => text()(); // JSON
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

// ─── Database Class ───────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Users,
  MedicineCategories,
  MedicineCompanies,
  MedicineSalts,
  MedicineUnits,
  Medicines,
  StockBatches,
  Customers,
  Suppliers,
  Sales,
  SaleItems,
  Purchases,
  PurchaseItems,
  SaleReturns,
  SaleReturnItems,
  ExpenseCategories,
  Expenses,
  CustomerPayments,
  SupplierPayments,
  HeldBills,
  AppSettings,
  SyncQueue,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        await _seedInitialData();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(medicines, medicines.storageType);
        }
        if (from < 3) {
          await m.addColumn(medicines, medicines.isShortage);
        }
      },
    );
  }

  Future<void> _seedInitialData() async {
    // Default admin user (password: admin123 - hashed)
    await into(users).insert(UsersCompanion.insert(
      name: 'Administrator',
      username: 'admin',
      passwordHash: 'admin123', // In production, use bcrypt hash
      role: const Value('admin'),
      isActive: const Value(true),
    ));

    // Default medicine categories
    final categories = [
      'Tablets', 'Capsules', 'Syrups', 'Injections', 'Drops',
      'Creams & Ointments', 'Suppositories', 'Inhalers', 'Patches',
      'Surgical', 'Baby Care', 'Vitamins & Supplements', 'Herbal',
    ];
    for (final cat in categories) {
      await into(medicineCategories).insert(
        MedicineCategoriesCompanion.insert(name: cat),
      );
    }

    // Default units
    final units = [
      ('Strip', 'Str'), ('Bottle', 'Btl'), ('Box', 'Bx'), ('Tube', 'Tub'),
      ('Sachet', 'Sct'), ('Ampoule', 'Amp'), ('Vial', 'Vil'), ('Pcs', 'Pcs'),
    ];
    for (final u in units) {
      await into(medicineUnits).insert(
        MedicineUnitsCompanion.insert(name: u.$1, abbreviation: u.$2),
      );
    }

    // Default expense categories
    final expCats = ['Rent', 'Salaries', 'Utilities', 'Maintenance', 'Transport', 'Other'];
    for (final cat in expCats) {
      await into(expenseCategories).insert(
        ExpenseCategoriesCompanion.insert(name: cat),
      );
    }

    // Default settings
    final defaultSettings = {
      'shop_name': 'Al-Shifa Medical Store',
      'shop_address': 'Main Market, City',
      'shop_phone': '0300-0000000',
      'shop_email': '',
      'invoice_prefix': 'INV',
      'purchase_prefix': 'PUR',
      'return_prefix': 'RET',
      'tax_percent': '0',
      'currency_symbol': 'Rs.',
      'receipt_header': 'Thank you for your visit!',
      'receipt_footer': 'Get well soon!',
      'low_stock_days': '30',
      'expiry_warning_days': '90',
      'printer_type': 'pdf',
      'printer_name': '',
      'receipt_width': '80',
      'show_mrp_on_receipt': 'true',
      'show_batch_on_receipt': 'true',
      'supabase_url': '',
      'supabase_anon_key': '',
      'auto_sync': 'true',
      'language': 'en',
    };

    for (final entry in defaultSettings.entries) {
      await into(appSettings).insert(
        AppSettingsCompanion.insert(key: entry.key, value: entry.value),
      );
    }
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'pharma_pos.db'));
    return NativeDatabase.createInBackground(file);
  });
}
