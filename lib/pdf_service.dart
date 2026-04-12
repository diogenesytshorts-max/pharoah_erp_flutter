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
  // ===================================================
  // 1. PROFESSIONAL SALE INVOICE
  // ===================================================
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();
    String cAddr = prefs.getString('compAddr') ?? "Address Not Set";
    String cGst = prefs.getString('compGST') ?? "N/A";
    String cDl = prefs.getString('compDL') ?? "N/A";
    String cPh = prefs.getString('compPh') ?? "0000000000";
    String cEm = prefs.getString('compEmail') ?? "N/A";

    const int itemsPerPage = 12;
    int totalPages = (sale.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int i = 0; i < totalPages; i++) {
      int start = i * itemsPerPage;
      int end = min(start + itemsPerPage, sale.items.length);
      List<BillItem> pItems = sale.items.sublist(start, end);
      bool isLast = (i == totalPages - 1);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
          child: pw.Column(children: [
            pw.Row(children: [
              pw.Expanded(child: pw.Container(height: 110, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(cName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                pw.Spacer(),
                pw.Text("GSTIN: $cGst", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text("D.L. No: $cDl", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text("Ph: $cPh | Email: $cEm", style: const pw.TextStyle(fontSize: 7)),
              ]))),
              pw.Expanded(child: pw.Container(height: 110, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), color: PdfColors.grey100), child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text("Invoice No: ${sale.billNo}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("Page ${i+1} of $totalPages", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ]))),
              pw.Expanded(child: pw.Container(height: 110, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("BILL TO / BUYER:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(sale.partyName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(sale.partyAddress, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                pw.Spacer(),
                pw.Text("GSTIN: ${sale.partyGstin}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text("D.L. No: ${sale.partyDl} | Mob: ${party.phone}", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ]))),
            ]),
            pw.Expanded(child: pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white), headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              columnWidths: {0: const pw.FixedColumnWidth(25), 1: const pw.FlexColumnWidth(3), 7: const pw.FixedColumnWidth(40)},
              headers: ['S.N', 'Product Description', 'Batch', 'Exp', 'Qty', 'MRP', 'Rate', 'GST%', 'Total'],
              data: pItems.map((it)=>[it.srNo, it.name, it.batch, it.exp, it.qty.toInt(), it.mrp.toStringAsFixed(2), it.rate.toStringAsFixed(2), "${it.gstRate.toInt()}%", it.total.toStringAsFixed(2)]).toList(),
            )),
            if (isLast) pw.Container(padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))), child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Spacer(), pw.Container(width: 250, padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(width: 1), color: PdfColors.grey200), child: pw.Column(children: [pw.Text("GRAND TOTAL", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)), pw.Divider(thickness: 1), pw.Text("Rupees ${sale.totalAmount.toInt()} Only", style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic))]))]))
            else pw.Container(padding: const pw.EdgeInsets.all(8), alignment: pw.Alignment.centerRight, child: pw.Text("Continued...", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)))
          ]),
        ),
      ));
    }
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Invoice_${sale.billNo}", format: PdfPageFormat.a4.landscape);
  }

  // ===================================================
  // 2. SALE & PURCHASE SUMMARY PDF (Naya Function)
  // ===================================================
  static Future<void> generateSaleSummaryPdf(List<Sale> sales, DateTime fDate, DateTime tDate, Party? p) async { /* ... Same logic as before ... */ }
  static Future<void> generatePurchaseSummaryPdf(List<Purchase> pur, DateTime fDate, DateTime tDate, Party? p) async { /* ... Same logic as before ... */ }

  // ===================================================
  // 3. GST REPORTS & JSON (Aapka original code)
  // ===================================================
  static Future<void> generateGstReport(String title, List<Sale> allSales, String period) async { /* ... Aapka purana code yahan aayega ... */ }
  static Future<void> generateGstJson(List<Sale> allSales, String monthYear) async { /* ... Aapka purana code yahan aayega ... */ }
  static pw.Widget _buildHsnPdfTable(List<Sale> sales) { /* ... Aapka purana code yahan aayega ... */ }
}
