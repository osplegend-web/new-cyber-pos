import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../core/utils/formatters.dart';
import '../core/utils/constants.dart';
import '../models/sale.dart';
import '../models/expense.dart';

class PdfService {
  /// Builds a printable A5-ish receipt document for the given sale.
  Future<pw.Document> buildInvoice({
    required Sale sale,
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String gstin,
    required String currencySymbol,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // works well for thermal printers too
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(shopName,
                    style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              ),
              if (shopAddress.isNotEmpty)
                pw.Center(child: pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 9))),
              if (shopPhone.isNotEmpty)
                pw.Center(child: pw.Text('Ph: $shopPhone', style: const pw.TextStyle(fontSize: 9))),
              if (gstin.isNotEmpty)
                pw.Center(child: pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 9))),
              pw.SizedBox(height: 6),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice: ${sale.invoiceNumber}', style: const pw.TextStyle(fontSize: 9)),
                ],
              ),
              pw.Text(AppFormatters.dateTime(sale.createdAt), style: const pw.TextStyle(fontSize: 9)),
              if (sale.customerName != null)
                pw.Text('Customer: ${sale.customerName}', style: const pw.TextStyle(fontSize: 9)),
              pw.Divider(),
              pw.Row(children: [
                pw.Expanded(flex: 4, child: pw.Text('Item', style: _headStyle)),
                pw.Expanded(flex: 1, child: pw.Text('Qty', style: _headStyle)),
                pw.Expanded(flex: 2, child: pw.Text('Price', style: _headStyle)),
                pw.Expanded(flex: 2, child: pw.Text('Total', style: _headStyle)),
              ]),
              pw.Divider(),
              ...sale.items.map((item) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Row(children: [
                      pw.Expanded(flex: 4, child: pw.Text(item.itemName, style: _rowStyle)),
                      pw.Expanded(flex: 1, child: pw.Text(_qty(item.quantity), style: _rowStyle)),
                      pw.Expanded(
                          flex: 2,
                          child: pw.Text(item.unitPrice.toStringAsFixed(2), style: _rowStyle)),
                      pw.Expanded(
                          flex: 2, child: pw.Text(item.totalPrice.toStringAsFixed(2), style: _rowStyle)),
                    ]),
                  )),
              pw.Divider(),
              _totalsRow('Subtotal', sale.subtotal, currencySymbol),
              if (sale.discount > 0) _totalsRow('Discount', -sale.discount, currencySymbol),
              pw.Divider(),
              _totalsRow('Grand Total', sale.grandTotal, currencySymbol, bold: true),
              _totalsRow('Paid (${sale.paymentMethod.label})', sale.amountPaid, currencySymbol),
              _totalsRow('Change', sale.changeAmount, currencySymbol),
              pw.SizedBox(height: 10),
              pw.Center(child: pw.Text('Thank you for your visit!', style: const pw.TextStyle(fontSize: 9))),
            ],
          );
        },
      ),
    );

    return doc;
  }

  String _qty(double q) => q == q.roundToDouble() ? q.toInt().toString() : q.toString();

  static final _headStyle = pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);
  static const _rowStyle = pw.TextStyle(fontSize: 8);

  pw.Widget _totalsRow(String label, double value, String symbol, {bool bold = false}) {
    final style = pw.TextStyle(fontSize: bold ? 11 : 9, fontWeight: bold ? pw.FontWeight.bold : null);
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text('$symbol ${value.toStringAsFixed(2)}', style: style),
      ],
    );
  }


  /// Builds a complete monthly statement with sales, expenses and profit summary.
  /// This report is intended for Admin use because it contains financial figures.
  Future<pw.Document> buildMonthlyStatement({
    required String shopName,
    required String shopAddress,
    required String shopPhone,
    required String gstin,
    required String currencySymbol,
    required DateTime month,
    required List<Sale> sales,
    required List<Expense> expenses,
  }) async {
    final doc = pw.Document();
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
    final activeSales = sales.where((s) => !s.isVoided).toList();
    final totalSales = activeSales.fold<double>(0, (sum, s) => sum + s.grandTotal);
    final grossProfit = activeSales.fold<double>(0, (sum, s) => sum + s.totalProfit);
    final totalExpenses = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final netProfit = grossProfit - totalExpenses;

    String money(double value) => '$currencySymbol ${value.toStringAsFixed(2)}';

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                shopName,
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (shopAddress.isNotEmpty)
              pw.Center(child: pw.Text(shopAddress, style: const pw.TextStyle(fontSize: 9))),
            if (shopPhone.isNotEmpty)
              pw.Center(child: pw.Text('Ph: $shopPhone', style: const pw.TextStyle(fontSize: 9))),
            if (gstin.isNotEmpty)
              pw.Center(child: pw.Text('GSTIN: $gstin', style: const pw.TextStyle(fontSize: 9))),
            pw.SizedBox(height: 8),
            pw.Divider(),
            pw.Center(
              child: pw.Text(
                'MONTHLY STATEMENT — ${DateFormat('MMMM yyyy').format(month)}',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber}', style: const pw.TextStyle(fontSize: 8)),
        ),
        build: (context) => [
          pw.Text('Statement Period', style: _sectionStyle),
          pw.Text('${AppFormatters.date(from)} to ${AppFormatters.date(to)}'),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(2),
              1: pw.FlexColumnWidth(2),
            },
            children: [
              _statementRow('Total Bills', '${activeSales.length}'),
              _statementRow('Total Sales', money(totalSales)),
              _statementRow('Gross Profit', money(grossProfit)),
              _statementRow('Total Expenses', money(totalExpenses)),
              _statementRow('Net Profit', money(netProfit), bold: true),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Sales Transactions', style: _sectionStyle),
          pw.SizedBox(height: 6),
          if (sales.isEmpty)
            pw.Text('No sales recorded for this month.')
          else
            pw.Table.fromTextArray(
              headers: const ['Date', 'Invoice', 'Customer', 'Payment', 'Amount', 'Status'],
              data: sales.map((sale) => [
                AppFormatters.date(sale.createdAt),
                sale.invoiceNumber,
                sale.customerName ?? '-',
                sale.paymentMethod.label,
                money(sale.grandTotal),
                sale.isVoided ? 'VOID' : 'Paid',
              ]).toList(),
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),
          pw.SizedBox(height: 18),
          pw.Text('Expenses', style: _sectionStyle),
          pw.SizedBox(height: 6),
          if (expenses.isEmpty)
            pw.Text('No expenses recorded for this month.')
          else
            pw.Table.fromTextArray(
              headers: const ['Date', 'Category', 'Note', 'Amount'],
              data: expenses.map((expense) => [
                AppFormatters.date(expense.date),
                expense.category,
                expense.note ?? '-',
                money(expense.amount),
              ]).toList(),
              headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 7),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignment: pw.Alignment.centerLeft,
              cellPadding: const pw.EdgeInsets.all(4),
              border: pw.TableBorder.all(color: PdfColors.grey400),
            ),
          pw.SizedBox(height: 18),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Net Profit: ${money(netProfit)}',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  Future<File> saveMonthlyStatement({
    required pw.Document doc,
    required DateTime month,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final monthName = DateFormat('yyyy_MM').format(month);
    final file = File('${dir.path}/monthly_statement_$monthName.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  pw.TableRow _statementRow(String label, String value, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );
    return pw.TableRow(children: [
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(label, style: style)),
      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(value, style: style)),
    ]);
  }

  static final _sectionStyle = pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold);

  /// Sends the document to the system print dialog - works with any
  /// Windows-installed printer (including thermal printers via their driver)
  /// and Android's print service.
  Future<void> printInvoice(pw.Document doc) async {
    await Printing.layoutPdf(onLayout: (format) async => doc.save());
  }

  /// Saves the invoice to a PDF file in app documents and returns the path.
  Future<File> saveAsPdf(pw.Document doc, String invoiceNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/invoice_$invoiceNumber.pdf');
    await file.writeAsBytes(await doc.save());
    return file;
  }

  /// Shares the invoice PDF (Android share sheet / Windows share).
  Future<void> shareInvoice(pw.Document doc, String invoiceNumber) async {
    final file = await saveAsPdf(doc, invoiceNumber);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: 'Invoice $invoiceNumber'),
    );
  }
}
