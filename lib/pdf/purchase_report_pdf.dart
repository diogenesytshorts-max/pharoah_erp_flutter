// FILE: lib/pdf/purchase_report_pdf.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart'; // NAYA SOURCE

class PurchaseReportPdf {
  // NAYA: Ab yeh active shop profile lega
  static Future<void> generate(List<Purchase> purchases, DateTime fDate, DateTime tDate, Party? selectedDist, CompanyProfile shop) async {
    final pdf = pw.Document();
    
    // NAYA: Dukan ka naam registry se
    String shopName = shop.name.toUpperCase();

    // Summary Totals (ORIGINAL LOGIC)
    double totalTaxable = 0; double totalGst = 0; double netTotal = 0;
    int billCount = purchases.length;

    for (var p in purchases) {
      double pTaxable = p.items.fold(0.0, (sum, it) => sum + (it.purchaseRate * it.qty));
      totalTaxable += pTaxable;
      totalGst += (p.totalAmount - pTaxable);
      netTotal += p.totalAmount;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (context) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text("PURCHASE REGISTER (DISTRIBUTOR SUMMARY)", style: const pw.TextStyle(fontSize: 12)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text("Period: ${DateFormat('dd/MM/yy').format(fDate)} to ${DateFormat('dd/MM/yy').format(tDate)}"),
            pw.Text("Distributor: ${selectedDist?.name ?? 'All Suppliers'}"),
          ]),
        ]),
        pw.Divider(thickness: 1),
      ]),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['DATE', 'BILL NO', 'INTERNAL ID', 'SUPPLIER NAME', 'MODE', 'TAXABLE', 'GST (ITC)', 'TOTAL'],
          data: purchases.map((p) {
            double taxable = p.items.fold(0.0, (sum, it) => sum + (it.purchaseRate * it.qty));
            return [
              DateFormat('dd/MM/yy').format(p.date), 
              p.billNo, 
              p.internalNo, 
              p.distributorName, 
              p.paymentMode,
              taxable.toStringAsFixed(2), 
              (p.totalAmount - taxable).toStringAsFixed(2), 
              p.totalAmount.toStringAsFixed(2)
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
           _sumBox("TOTAL BILLS", billCount.toDouble(), isInt: true),
           _sumBox("TAXABLE AMT", totalTaxable),
           _sumBox("INPUT GST (ITC)", totalGst),
           _sumBox("NET PURCHASE", netTotal, isBold: true)
        ]),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), format: PdfPageFormat.a4.landscape);
  }

  static pw.Widget _sumBox(String label, double val, {bool isBold = false, bool isInt = false}) {
    return pw.Column(children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      pw.Text(isInt ? val.toInt().toString() : "Rs. ${val.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ]);
  }
}
