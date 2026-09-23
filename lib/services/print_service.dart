import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../data/repositories/settings_repository.dart';

class ReceiptData {
  final String shopName;
  final String shopAddress;
  final String shopPhone;
  final String invoiceNo;
  final DateTime saleDate;
  final String? customerName;
  final String? cashierName;
  final List<ReceiptItem> items;
  final double subtotal;
  final double discountAmount;
  final double taxAmount;
  final double totalAmount;
  final double paidAmount;
  final double changeAmount;
  final String paymentMethod;
  final String headerText;
  final String footerText;
  final bool showBatch;
  final bool showMrp;

  const ReceiptData({
    required this.shopName,
    required this.shopAddress,
    required this.shopPhone,
    required this.invoiceNo,
    required this.saleDate,
    this.customerName,
    this.cashierName,
    required this.items,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.totalAmount,
    required this.paidAmount,
    required this.changeAmount,
    required this.paymentMethod,
    this.headerText = 'Thank you for your visit!',
    this.footerText = 'Get well soon!',
    this.showBatch = true,
    this.showMrp = false,
  });
}

class ReceiptItem {
  final String name;
  final String? batchNo;
  final String? expiryDate;
  final double quantity;
  final double unitPrice;
  final double discount;
  final double total;

  const ReceiptItem({
    required this.name,
    this.batchNo,
    this.expiryDate,
    required this.quantity,
    required this.unitPrice,
    required this.discount,
    required this.total,
  });
}

class PrintService {
  final SettingsRepository _settings;

  PrintService(this._settings);

  Future<void> printReceipt(BuildContext context, ReceiptData data) async {
    final printerType = await _settings.get('printer_type') ?? 'pdf';

    switch (printerType) {
      case 'usb':
      case 'network':
      case 'bluetooth':
        await _printEscPos(data, printerType);
        break;
      case 'pdf':
      default:
        await _printPdf(context, data);
    }
  }

  Future<void> _printPdf(BuildContext context, ReceiptData data) async {
    final pdf = pw.Document();
    final receiptWidth = 80.0; // 80mm paper

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat(
          receiptWidth * PdfPageFormat.mm,
          double.infinity,
          marginAll: 4 * PdfPageFormat.mm,
        ),
        build: (context) => _buildPdfReceipt(data),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Receipt_${data.invoiceNo}',
    );
  }

  pw.Widget _buildPdfReceipt(ReceiptData data) {
    final df = DateFormat('dd/MM/yyyy hh:mm a');
    final nf = NumberFormat('#,##0.00');
    final bold = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final small = pw.TextStyle(fontSize: 8);
    final normal = pw.TextStyle(fontSize: 9);
    final largeBold = pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Header
        pw.Text(data.shopName, style: largeBold, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 2),
        pw.Text(data.shopAddress, style: small, textAlign: pw.TextAlign.center),
        pw.Text('Ph: ${data.shopPhone}', style: small, textAlign: pw.TextAlign.center),
        pw.Divider(thickness: 0.5),
        pw.Text(data.headerText, style: small, textAlign: pw.TextAlign.center),
        pw.Divider(thickness: 0.5),

        // Invoice info
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('Invoice: ${data.invoiceNo}', style: bold.copyWith(fontSize: 8)),
          pw.Text(df.format(data.saleDate), style: small),
        ]),
        if (data.customerName != null)
          pw.Row(children: [pw.Text('Customer: ${data.customerName}', style: small)]),
        if (data.cashierName != null)
          pw.Row(children: [pw.Text('Cashier: ${data.cashierName}', style: small)]),
        pw.Divider(thickness: 0.5),

        // Items header
        pw.Row(children: [
          pw.Expanded(flex: 4, child: pw.Text('Item', style: bold.copyWith(fontSize: 8))),
          pw.Expanded(flex: 1, child: pw.Text('Qty', style: bold.copyWith(fontSize: 8), textAlign: pw.TextAlign.center)),
          pw.Expanded(flex: 2, child: pw.Text('Price', style: bold.copyWith(fontSize: 8), textAlign: pw.TextAlign.right)),
          pw.Expanded(flex: 2, child: pw.Text('Total', style: bold.copyWith(fontSize: 8), textAlign: pw.TextAlign.right)),
        ]),
        pw.Divider(thickness: 0.5),

        // Items
        ...data.items.map((item) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(children: [
              pw.Expanded(flex: 4, child: pw.Text(item.name, style: normal)),
              pw.Expanded(flex: 1, child: pw.Text('${item.quantity}', style: normal, textAlign: pw.TextAlign.center)),
              pw.Expanded(flex: 2, child: pw.Text('Rs.${nf.format(item.unitPrice)}', style: normal, textAlign: pw.TextAlign.right)),
              pw.Expanded(flex: 2, child: pw.Text('Rs.${nf.format(item.total)}', style: normal, textAlign: pw.TextAlign.right)),
            ]),
            if (data.showBatch && item.batchNo != null)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Text(
                  'Batch: ${item.batchNo}  Exp: ${item.expiryDate ?? '-'}',
                  style: small.copyWith(color: PdfColors.grey600),
                ),
              ),
            if (item.discount > 0)
              pw.Padding(
                padding: const pw.EdgeInsets.only(left: 4),
                child: pw.Text('Discount: Rs.${nf.format(item.discount)}', style: small),
              ),
          ],
        )),

        pw.Divider(thickness: 0.5),

        // Totals
        if (data.discountAmount > 0)
          _pdfTotalRow('Subtotal:', 'Rs.${nf.format(data.subtotal)}', small),
        if (data.discountAmount > 0)
          _pdfTotalRow('Discount:', '-Rs.${nf.format(data.discountAmount)}', small),
        if (data.taxAmount > 0)
          _pdfTotalRow('Tax:', 'Rs.${nf.format(data.taxAmount)}', small),
        _pdfTotalRow('TOTAL:', 'Rs.${nf.format(data.totalAmount)}', largeBold),
        _pdfTotalRow('Paid (${data.paymentMethod.toUpperCase()}):', 'Rs.${nf.format(data.paidAmount)}', small),
        if (data.changeAmount > 0)
          _pdfTotalRow('Change:', 'Rs.${nf.format(data.changeAmount)}', small),

        pw.Divider(thickness: 0.5),
        pw.Text(data.footerText, style: small, textAlign: pw.TextAlign.center),
        pw.SizedBox(height: 4),
      ],
    );
  }

  pw.Widget _pdfTotalRow(String label, String value, pw.TextStyle style) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: style),
      pw.Text(value, style: style),
    ]);
  }

  Future<void> _printEscPos(ReceiptData data, String printerType) async {
    final widthSetting = await _settings.get('receipt_width') ?? '80';
    final paperSize = widthSetting == '58' ? PaperSize.mm58 : PaperSize.mm80;
    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final nf = NumberFormat('#,##0.00');
    final df = DateFormat('dd/MM/yyyy hh:mm a');

    List<int> bytes = [];

    bytes += generator.text(
      data.shopName,
      styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2),
    );
    bytes += generator.text(data.shopAddress, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Ph: ${data.shopPhone}', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    bytes += generator.text(data.headerText, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Invoice: ${data.invoiceNo}', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: df.format(data.saleDate), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (data.customerName != null) {
      bytes += generator.text('Customer: ${data.customerName}');
    }
    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'Item', width: 5, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 2, styles: const PosStyles(bold: true, align: PosAlign.center)),
      PosColumn(text: 'Price', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: 'Total', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    for (final item in data.items) {
      bytes += generator.row([
        PosColumn(text: item.name, width: 5),
        PosColumn(text: '${item.quantity}', width: 2, styles: const PosStyles(align: PosAlign.center)),
        PosColumn(text: nf.format(item.unitPrice), width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: nf.format(item.total), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      if (data.showBatch && item.batchNo != null) {
        bytes += generator.text('  Batch: ${item.batchNo}  Exp: ${item.expiryDate ?? '-'}');
      }
    }

    bytes += generator.hr();
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 8, styles: const PosStyles(bold: true, height: PosTextSize.size2, width: PosTextSize.size2)),
      PosColumn(
        text: 'Rs.${nf.format(data.totalAmount)}',
        width: 4,
        styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2, width: PosTextSize.size2),
      ),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Paid (${data.paymentMethod.toUpperCase()})', width: 8),
      PosColumn(text: 'Rs.${nf.format(data.paidAmount)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
    ]);
    if (data.changeAmount > 0) {
      bytes += generator.row([
        PosColumn(text: 'Change', width: 8),
        PosColumn(text: 'Rs.${nf.format(data.changeAmount)}', width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }
    bytes += generator.hr();
    bytes += generator.text(data.footerText, styles: const PosStyles(align: PosAlign.center));
    bytes += generator.feed(3);
    bytes += generator.cut();

    await _sendEscPosBytes(bytes, printerType);
  }

  Future<void> _sendEscPosBytes(List<int> bytes, String printerType) async {
    switch (printerType) {
      case 'network':
        final ip = await _settings.get('printer_ip') ?? '';
        final port = int.tryParse(await _settings.get('printer_port') ?? '9100') ?? 9100;
        if (ip.isEmpty) throw Exception('Printer IP not set. Go to Settings → Receipt → Printer IP.');
        final socket = await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
        socket.add(bytes);
        await socket.flush();
        await socket.close();
        break;

      case 'usb':
        final path = await _settings.get('printer_usb_path') ?? '/dev/usb/lp0';
        final file = File(path);
        await file.writeAsBytes(bytes, mode: FileMode.write);
        break;

      case 'bluetooth':
        throw UnsupportedError(
          'Bluetooth printing is not supported on desktop. '
          'Connect your Bluetooth printer via network (TCP) mode instead.',
        );
    }
  }
}

final printServiceProvider = Provider<PrintService>((ref) {
  final settings = ref.watch(settingsRepositoryProvider);
  return PrintService(settings);
});
