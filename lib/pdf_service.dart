import 'dart:convert';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateInvoice(Sale sale, Party party) async { /* ... same as before ... */ }
  static Future<void> generatePurchaseInvoice(Purchase pur, Party party) async { /* ... same as before ... */ }
  static Future<void> generateSaleSummaryPdf(List<Sale> sales, DateTime fDate, DateTime tDate, Party? p) async { /* ... same as before ... */ }
  static Future<void> generatePurchaseSummaryPdf(List<Purchase> pur, DateTime fDate, DateTime tDate, Party? p) async { /* ... same as before ... */ }
  
  static Future<void> generateGstReport(String title, List<Sale> allSales, String period) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = prefs.getString('compName') ?? "PHAROAH ERP";
    List<Sale> activeSales = allSales.where((s) => s.status == "Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => pw.Column(children: [ pw.Text(cName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)), pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Text("Period: $period"), pw.Divider() ]),
      build: (pw.Context context) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Date', 'Bill No', 'Party', 'GSTIN', 'POS', 'Taxable', 'Total'],
          data: activeSales.map((s) => [DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.partyState, (s.totalAmount/1.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)]).toList(),
        ),
        pw.SizedBox(height: 30),
        pw.Text("HSN Wise Summary", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildHsnPdfTable(activeSales),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_REPORT_$period", format: PdfPageFormat.a4.landscape);
  }

  static Future<void> generateGstJson(List<Sale> allSales, String monthYear) async { /* ... same as before ... */ }

  static pw.Widget _buildHsnPdfTable(List<Sale> sales) {
    Map<String, Map<String, dynamic>> hsn = {};
    for (var s in sales) { for (var it in s.items) { if (!hsn.containsKey(it.hsn)) hsn[it.hsn] = {'qty': 0.0, 'val': 0.0}; hsn[it.hsn]!['qty'] += it.qty; hsn[it.hsn]!['val'] += (it.rate * it.qty); } }
    return pw.TableHelper.fromTextArray(
      headers: ['HSN', 'Qty', 'Taxable'],
      data: hsn.entries.map((e) => [e.key, e.value['qty'].toString(), e.value['val']!.toStringAsFixed(2)]).toList(),
    );
  }
}
