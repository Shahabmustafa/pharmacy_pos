import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../local/database/app_database.dart';
import 'settings_repository.dart';

class SaleRepository {
  final AppDatabase _db;
  final SettingsRepository _settings;
  final _uuid = const Uuid();

  SaleRepository(this._db, this._settings);

  Future<String> _nextInvoiceNo() async {
    final prefix = await _settings.get('invoice_prefix') ?? 'INV';
    final count = await _db.sales.count().getSingle();
    final no = (count + 1).toString().padLeft(6, '0');
    final date = DateFormat('yyMMdd').format(DateTime.now());
    return '$prefix-$date-$no';
  }

  Future<Sale> createSale({
    required int userId,
    required List<CartItem> items,
    int? customerId,
    required double discountPercent,
    required double discountAmount,
    required double taxAmount,
    required double totalAmount,
    required double paidAmount,
    required String paymentMethod,
    String? notes,
    String? prescriptionNo,
    DateTime? saleDate,
  }) async {
    final invoiceNo = await _nextInvoiceNo();
    final subtotal = items.fold(0.0, (s, i) => s + (i.quantity * i.unitPrice));
    final change = paidAmount > totalAmount ? paidAmount - totalAmount : 0.0;
    final credit = totalAmount > paidAmount ? totalAmount - paidAmount : 0.0;

    late Sale sale;

    await _db.transaction(() async {
      final saleId = await _db.into(_db.sales).insert(SalesCompanion.insert(
        invoiceNo: invoiceNo,
        userId: userId,
        customerId: Value(customerId),
        saleDate: saleDate != null ? Value(saleDate) : const Value.absent(),
        subtotal: Value(subtotal),
        discountPercent: Value(discountPercent),
        discountAmount: Value(discountAmount),
        taxAmount: Value(taxAmount),
        totalAmount: Value(totalAmount),
        paidAmount: Value(paidAmount),
        changeAmount: Value(change),
        creditAmount: Value(credit),
        paymentMethod: Value(paymentMethod),
        notes: Value(notes),
        prescriptionNo: Value(prescriptionNo),
        serverId: Value(_uuid.v4()),
        needsSync: const Value(true),
      ));

      for (final item in items) {
        await _db.into(_db.saleItems).insert(SaleItemsCompanion.insert(
          saleId: saleId,
          medicineId: item.medicineId,
          batchId: Value(item.batchId),
          medicineName: item.medicineName,
          batchNo: Value(item.batchNo),
          expiryDate: Value(item.expiryDate),
          quantity: item.quantity,
          unitPrice: item.unitPrice,
          discountPercent: Value(item.discountPercent),
          discountAmount: Value(item.discountAmount),
          taxPercent: Value(item.taxPercent),
          taxAmount: Value(item.taxAmount),
          totalPrice: item.total,
          purchasePrice: Value(item.purchasePrice),
          serverId: Value(_uuid.v4()),
          needsSync: const Value(true),
        ));

        // Deduct stock
        await (_db.update(_db.medicines)..where((m) => m.id.equals(item.medicineId)))
            .write(MedicinesCompanion(
          stock: Value(item.currentStock - item.quantity),
          updatedAt: Value(DateTime.now()),
        ));

        // Update batch remaining quantity
        if (item.batchId != null) {
          final batch = await (_db.select(_db.stockBatches)
                ..where((b) => b.id.equals(item.batchId!)))
              .getSingleOrNull();
          if (batch != null) {
            await (_db.update(_db.stockBatches)..where((b) => b.id.equals(item.batchId!)))
                .write(StockBatchesCompanion(
              remainingQty: Value(batch.remainingQty - item.quantity),
            ));
          }
        }
      }

      // Update customer balance if credit sale
      if (credit > 0 && customerId != null) {
        final customer = await (_db.select(_db.customers)
              ..where((c) => c.id.equals(customerId)))
            .getSingleOrNull();
        if (customer != null) {
          await (_db.update(_db.customers)..where((c) => c.id.equals(customerId)))
              .write(CustomersCompanion(balance: Value(customer.balance + credit)));
        }
      }

      sale = await (_db.select(_db.sales)..where((s) => s.invoiceNo.equals(invoiceNo)))
          .getSingle();
    });

    return sale;
  }

  Future<List<SaleWithItems>> getSalesWithItems({
    DateTime? from,
    DateTime? to,
    int? customerId,
    String? status,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _db.select(_db.sales);
    if (from != null) query.where((s) => s.saleDate.isBiggerOrEqualValue(from));
    if (to != null) query.where((s) => s.saleDate.isSmallerOrEqualValue(to));
    if (customerId != null) query.where((s) => s.customerId.equals(customerId));
    if (status != null) query.where((s) => s.status.equals(status));
    query
      ..orderBy([(s) => OrderingTerm.desc(s.saleDate)])
      ..limit(limit, offset: offset);

    final sales = await query.get();
    final result = <SaleWithItems>[];

    for (final sale in sales) {
      final items = await (_db.select(_db.saleItems)
            ..where((i) => i.saleId.equals(sale.id)))
          .get();
      Customer? customer;
      if (sale.customerId != null) {
        customer = await (_db.select(_db.customers)
              ..where((c) => c.id.equals(sale.customerId!)))
            .getSingleOrNull();
      }
      result.add(SaleWithItems(sale: sale, items: items, customer: customer));
    }
    return result;
  }

  Future<Sale?> getByInvoiceNo(String invoiceNo) {
    return (_db.select(_db.sales)..where((s) => s.invoiceNo.equals(invoiceNo)))
        .getSingleOrNull();
  }

  Future<DailySummary> getDailySummary(DateTime date) async {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final result = await _db.customSelect(
      '''SELECT
          COUNT(*) as total_sales,
          COALESCE(SUM(total_amount), 0) as total_revenue,
          COALESCE(SUM(discount_amount), 0) as total_discount,
          COALESCE(SUM(tax_amount), 0) as total_tax,
          COALESCE(SUM(paid_amount), 0) as total_cash,
          COALESCE(SUM(credit_amount), 0) as total_credit
        FROM sales
        WHERE sale_date >= ? AND sale_date < ? AND status != 'returned'
      ''',
      variables: [Variable(start), Variable(end)],
      readsFrom: {_db.sales},
    ).getSingleOrNull();

    if (result == null) return DailySummary.empty();

    final profitResult = await _db.customSelect(
      '''SELECT COALESCE(SUM((si.unit_price - si.purchase_price) * si.quantity), 0) as profit
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        WHERE s.sale_date >= ? AND s.sale_date < ? AND s.status != 'returned' AND si.is_returned = 0
      ''',
      variables: [Variable(start), Variable(end)],
      readsFrom: {_db.saleItems, _db.sales},
    ).getSingleOrNull();

    return DailySummary(
      totalSales: result.data['total_sales'] as int,
      totalRevenue: (result.data['total_revenue'] as num).toDouble(),
      totalDiscount: (result.data['total_discount'] as num).toDouble(),
      totalTax: (result.data['total_tax'] as num).toDouble(),
      totalCash: (result.data['total_cash'] as num).toDouble(),
      totalCredit: (result.data['total_credit'] as num).toDouble(),
      totalProfit: profitResult != null
          ? (profitResult.data['profit'] as num).toDouble()
          : 0.0,
    );
  }

  Stream<List<Sale>> watchRecentSales({int limit = 10}) {
    return (_db.select(_db.sales)
          ..orderBy([(s) => OrderingTerm.desc(s.saleDate)])
          ..limit(limit))
        .watch();
  }

  /// Total revenue per day for the last [days] days (including today), oldest first.
  /// Days with no sales are filled in with 0 so the series has no gaps.
  Future<List<DailyRevenue>> getWeeklySales({int days = 7}) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));

    final rows = await _db.customSelect(
      '''SELECT strftime('%Y-%m-%d', sale_date, 'unixepoch') as day,
                COALESCE(SUM(total_amount), 0) as revenue
         FROM sales
         WHERE sale_date >= ? AND status != 'returned'
         GROUP BY day''',
      variables: [Variable(start)],
      readsFrom: {_db.sales},
    ).get();

    final byDay = {
      for (final r in rows) r.data['day'] as String: (r.data['revenue'] as num).toDouble(),
    };

    return List.generate(days, (i) {
      final date = start.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      return DailyRevenue(date: date, revenue: byDay[key] ?? 0);
    });
  }

  /// Best-selling medicines (by quantity sold) in the last [days] days.
  Future<List<TopProduct>> getTopSellingProducts({int days = 7, int limit = 5}) async {
    final start = DateTime.now().subtract(Duration(days: days));

    final rows = await _db.customSelect(
      '''SELECT si.medicine_id as medicine_id, si.medicine_name as medicine_name,
                SUM(si.quantity) as total_qty, SUM(si.total_price) as total_revenue
         FROM sale_items si
         JOIN sales s ON s.id = si.sale_id
         WHERE s.sale_date >= ? AND s.status != 'returned' AND si.is_returned = 0
         GROUP BY si.medicine_id
         ORDER BY total_qty DESC
         LIMIT ?''',
      variables: [Variable(start), Variable(limit)],
      readsFrom: {_db.saleItems, _db.sales},
    ).get();

    return rows
        .map((r) => TopProduct(
              medicineId: r.data['medicine_id'] as int,
              medicineName: r.data['medicine_name'] as String,
              totalQty: (r.data['total_qty'] as num).toDouble(),
              totalRevenue: (r.data['total_revenue'] as num).toDouble(),
            ))
        .toList();
  }
}

class DailyRevenue {
  final DateTime date;
  final double revenue;
  const DailyRevenue({required this.date, required this.revenue});
}

class TopProduct {
  final int medicineId;
  final String medicineName;
  final double totalQty;
  final double totalRevenue;
  const TopProduct({
    required this.medicineId,
    required this.medicineName,
    required this.totalQty,
    required this.totalRevenue,
  });
}

class CartItem {
  final int medicineId;
  final String medicineName;
  final int? batchId;
  final String? batchNo;
  final DateTime? expiryDate;
  final double quantity;
  final double unitPrice;
  final double purchasePrice;
  final double currentStock;
  final double discountPercent;
  final double discountAmount;
  final double taxPercent;
  final double taxAmount;
  final double total;
  final bool isShortage;

  const CartItem({
    required this.medicineId,
    required this.medicineName,
    this.batchId,
    this.batchNo,
    this.expiryDate,
    required this.quantity,
    required this.unitPrice,
    required this.purchasePrice,
    required this.currentStock,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.taxPercent = 0,
    this.taxAmount = 0,
    required this.total,
    this.isShortage = false,
  });

  CartItem copyWith({
    double? quantity,
    double? unitPrice,
    double? discountPercent,
    double? discountAmount,
    double? taxPercent,
    double? taxAmount,
    double? total,
  }) {
    return CartItem(
      medicineId: medicineId,
      medicineName: medicineName,
      batchId: batchId,
      batchNo: batchNo,
      expiryDate: expiryDate,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      purchasePrice: purchasePrice,
      currentStock: currentStock,
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      taxPercent: taxPercent ?? this.taxPercent,
      taxAmount: taxAmount ?? this.taxAmount,
      total: total ?? this.total,
      isShortage: isShortage,
    );
  }
}

class SaleWithItems {
  final Sale sale;
  final List<SaleItem> items;
  final Customer? customer;

  const SaleWithItems({required this.sale, required this.items, this.customer});
}

class DailySummary {
  final int totalSales;
  final double totalRevenue;
  final double totalDiscount;
  final double totalTax;
  final double totalCash;
  final double totalCredit;
  final double totalProfit;

  const DailySummary({
    required this.totalSales,
    required this.totalRevenue,
    required this.totalDiscount,
    required this.totalTax,
    required this.totalCash,
    required this.totalCredit,
    required this.totalProfit,
  });

  factory DailySummary.empty() => const DailySummary(
        totalSales: 0,
        totalRevenue: 0,
        totalDiscount: 0,
        totalTax: 0,
        totalCash: 0,
        totalCredit: 0,
        totalProfit: 0,
      );
}

final saleRepositoryProvider = Provider<SaleRepository>((ref) {
  return SaleRepository(
    ref.watch(databaseProvider),
    ref.watch(settingsRepositoryProvider),
  );
});
