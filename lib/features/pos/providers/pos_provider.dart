import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/sale_repository.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../auth/providers/auth_provider.dart';

class PosState {
  final List<CartItem> cartItems;
  final int? selectedCustomerId;
  final String? selectedCustomerName;
  final double discountPercent;
  final double discountAmount;
  final bool discountIsPercent;
  final String paymentMethod;
  final double receivedAmount;
  final bool isProcessing;
  final String? error;
  final Sale? lastCompletedSale;

  const PosState({
    this.cartItems = const [],
    this.selectedCustomerId,
    this.selectedCustomerName,
    this.discountPercent = 0,
    this.discountAmount = 0,
    this.discountIsPercent = true,
    this.paymentMethod = 'cash',
    this.receivedAmount = 0,
    this.isProcessing = false,
    this.error,
    this.lastCompletedSale,
  });

  double get subtotal =>
      cartItems.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));

  double get totalDiscount {
    if (discountIsPercent) return cartItems.fold(0.0, (sum, item) => sum + item.discountAmount);
    return discountAmount;
  }

  double get totalTax =>
      cartItems.fold(0.0, (sum, item) => sum + item.taxAmount);

  double get grandTotal => subtotal - totalDiscount + totalTax;

  double get changeAmount =>
      receivedAmount > grandTotal ? receivedAmount - grandTotal : 0;

  double get creditAmount =>
      grandTotal > receivedAmount ? grandTotal - receivedAmount : 0;

  int get itemCount => cartItems.fold(0, (sum, item) => sum + item.quantity.toInt());

  PosState copyWith({
    List<CartItem>? cartItems,
    int? selectedCustomerId,
    String? selectedCustomerName,
    double? discountPercent,
    double? discountAmount,
    bool? discountIsPercent,
    String? paymentMethod,
    double? receivedAmount,
    bool? isProcessing,
    String? error,
    Sale? lastCompletedSale,
    bool clearCustomer = false,
  }) {
    return PosState(
      cartItems: cartItems ?? this.cartItems,
      selectedCustomerId: clearCustomer ? null : (selectedCustomerId ?? this.selectedCustomerId),
      selectedCustomerName: clearCustomer ? null : (selectedCustomerName ?? this.selectedCustomerName),
      discountPercent: discountPercent ?? this.discountPercent,
      discountAmount: discountAmount ?? this.discountAmount,
      discountIsPercent: discountIsPercent ?? this.discountIsPercent,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      receivedAmount: receivedAmount ?? this.receivedAmount,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      lastCompletedSale: lastCompletedSale ?? this.lastCompletedSale,
    );
  }
}

class PosNotifier extends StateNotifier<PosState> {
  final SaleRepository _saleRepo;
  final AppDatabase _db;
  final int _userId;

  PosNotifier(this._saleRepo, this._db, this._userId) : super(const PosState());

  void addItem(Medicine medicine, {double quantity = 1}) {
    final existing = state.cartItems.indexWhere((i) => i.medicineId == medicine.id);
    List<CartItem> newItems;

    if (existing >= 0) {
      final updated = state.cartItems[existing].copyWith(
        quantity: state.cartItems[existing].quantity + quantity,
      );
      newItems = [...state.cartItems];
      newItems[existing] = updated;
    } else {
      final item = CartItem(
        medicineId: medicine.id,
        medicineName: medicine.name,
        quantity: quantity,
        unitPrice: medicine.salePrice,
        purchasePrice: medicine.purchasePrice,
        currentStock: medicine.stock,
        total: medicine.salePrice * quantity,
        isShortage: medicine.isShortage,
      );
      newItems = [...state.cartItems, item];
    }
    state = state.copyWith(cartItems: _applyDiscountToItems(newItems));
  }

  /// Recalculates every item's totals, applying the cart-wide discount % to
  /// each one — except items flagged as "shortage" (short in market), which
  /// are never discounted.
  List<CartItem> _applyDiscountToItems(List<CartItem> items) {
    return items.map((item) {
      final pct = state.discountIsPercent
          ? (item.isShortage ? 0.0 : state.discountPercent)
          : item.discountPercent;
      return _recalcItem(item.copyWith(discountPercent: pct));
    }).toList();
  }

  void removeItem(int medicineId) {
    state = state.copyWith(
      cartItems: state.cartItems.where((i) => i.medicineId != medicineId).toList(),
    );
  }

  void updateQuantity(int medicineId, double quantity) {
    if (quantity <= 0) {
      removeItem(medicineId);
      return;
    }
    final items = state.cartItems.map((item) {
      if (item.medicineId == medicineId) return _recalcItem(item.copyWith(quantity: quantity));
      return item;
    }).toList();
    state = state.copyWith(cartItems: items);
  }

  void updateItemDiscount(int medicineId, double discountPercent) {
    final items = state.cartItems.map((item) {
      if (item.medicineId == medicineId) {
        final pct = item.isShortage ? 0.0 : discountPercent;
        return _recalcItem(item.copyWith(discountPercent: pct));
      }
      return item;
    }).toList();
    state = state.copyWith(cartItems: items);
  }

  void updateItemPrice(int medicineId, double price) {
    final items = state.cartItems.map((item) {
      if (item.medicineId == medicineId) return _recalcItem(item.copyWith(unitPrice: price));
      return item;
    }).toList();
    state = state.copyWith(cartItems: items);
  }

  CartItem _recalcItem(CartItem item) {
    final discountAmt = item.unitPrice * item.quantity * item.discountPercent / 100;
    final taxableAmount = (item.unitPrice * item.quantity) - discountAmt;
    final taxAmt = taxableAmount * item.taxPercent / 100;
    final total = taxableAmount + taxAmt;
    return item.copyWith(discountAmount: discountAmt, taxAmount: taxAmt, total: total);
  }

  void setDiscount({double? percent, double? amount}) {
    if (percent != null) {
      state = state.copyWith(discountPercent: percent, discountIsPercent: true);
      state = state.copyWith(cartItems: _applyDiscountToItems(state.cartItems));
    } else if (amount != null) {
      state = state.copyWith(discountAmount: amount, discountIsPercent: false);
    }
  }

  void setPaymentMethod(String method) => state = state.copyWith(paymentMethod: method);
  void setReceivedAmount(double amount) => state = state.copyWith(receivedAmount: amount);

  void setCustomer(int? id, String? name) {
    if (id == null) {
      state = state.copyWith(clearCustomer: true);
    } else {
      state = state.copyWith(selectedCustomerId: id, selectedCustomerName: name);
    }
  }

  void clearCart() => state = const PosState();

  Future<Sale?> completeSale() async {
    if (state.cartItems.isEmpty) return null;
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final sale = await _saleRepo.createSale(
        userId: _userId,
        items: state.cartItems,
        customerId: state.selectedCustomerId,
        discountPercent: state.discountIsPercent ? state.discountPercent : 0,
        discountAmount: state.totalDiscount,
        taxAmount: state.totalTax,
        totalAmount: state.grandTotal,
        paidAmount: state.receivedAmount > 0 ? state.receivedAmount : state.grandTotal,
        paymentMethod: state.paymentMethod,
      );
      state = state.copyWith(isProcessing: false, lastCompletedSale: sale);
      return sale;
    } catch (e) {
      state = state.copyWith(isProcessing: false, error: e.toString());
      return null;
    }
  }

  Future<void> holdBill(String? label) async {
    if (state.cartItems.isEmpty) return;
    final cartJson = jsonEncode(state.cartItems.map((i) => {
      'medicineId': i.medicineId,
      'medicineName': i.medicineName,
      'quantity': i.quantity,
      'unitPrice': i.unitPrice,
      'purchasePrice': i.purchasePrice,
      'currentStock': i.currentStock,
      'discountPercent': i.discountPercent,
      'total': i.total,
      'isShortage': i.isShortage,
    }).toList());

    await _db.into(_db.heldBills).insert(HeldBillsCompanion.insert(
      label: Value(label),
      cartData: cartJson,
      customerId: Value(state.selectedCustomerId),
    ));
    clearCart();
  }

  Future<List<HeldBill>> getHeldBills() => _db.select(_db.heldBills).get();

  Future<void> restoreHeldBill(HeldBill bill) async {
    final items = (jsonDecode(bill.cartData) as List).map((d) => CartItem(
      medicineId: d['medicineId'],
      medicineName: d['medicineName'],
      quantity: (d['quantity'] as num).toDouble(),
      unitPrice: (d['unitPrice'] as num).toDouble(),
      purchasePrice: (d['purchasePrice'] as num).toDouble(),
      currentStock: (d['currentStock'] as num).toDouble(),
      discountPercent: (d['discountPercent'] as num?)?.toDouble() ?? 0,
      total: (d['total'] as num).toDouble(),
      isShortage: (d['isShortage'] as bool?) ?? false,
    )).toList();

    state = state.copyWith(cartItems: items, selectedCustomerId: bill.customerId);
    await (_db.delete(_db.heldBills)..where((b) => b.id.equals(bill.id))).go();
  }
}

final posProvider = StateNotifierProvider<PosNotifier, PosState>((ref) {
  return PosNotifier(
    ref.watch(saleRepositoryProvider),
    ref.watch(databaseProvider),
    ref.watch(authProvider).user?.id ?? 1,
  );
});
