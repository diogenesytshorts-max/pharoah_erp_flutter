// FILE: lib/pdf/sale_report_pdf.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart'; // NAYA SOURCE

class SaleReportPdf {
  // NAYA: Ab yeh active shop profile lega
  static Future<void> generate(List<Sale> sales, DateTime fDate, DateTime tDate, Party? selectedParty, CompanyProfile shop) async {
    final pdf = pw.Document();
    
    // NAYA: Dukan ka naam registry se
    String shopName = shop.name.toUpperCase();

    // Summary Calculations (ORIGINAL LOGIC)
    double totalTaxable = 0; double totalGst = 0; double netTotal = 0;
    double cashTotal = 0; double creditTotal = 0;

    for (var s in sales) {
      double sTax = s.items.fold(0.0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
      totalTaxable += (s.totalAmount - sTax);
      totalGst += sTax;
      netTotal += s.totalAmount;
      if (s.paymentMode.toUpperCase() == 'CASH') cashTotal += s.totalAmount;
      else creditTotal += s.totalAmount;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (context) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(shopName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
            pw.Text("Sales Register Report", style: const pw.TextStyle(fontSize: 12)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text("Period: ${DateFormat('dd/MM/yy').format(fDate)} to ${DateFormat('dd/MM/yy').format(tDate)}"),
            pw.Text("Filter: ${selectedParty?.name ?? 'All Parties'}"),
          ]),
        ]),
        pw.Divider(thickness: 1),
      ]),
      build: (context) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['DATE', 'BILL NO', 'PARTY NAME', 'GSTIN', 'MODE', 'TAXABLE', 'GST', 'TOTAL'],
          data: sales.map((s) {
            double tax = s.items.fold(0.0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
            return [
              DateFormat('dd/MM/yy').format(s.date), 
              s.billNo, 
              s.partyName, 
              s.partyGstin, 
              s.paymentMode,
              (s.totalAmount - tax).toStringAsFixed(2), 
              tax.toStringAsFixed(2), 
              s.totalAmount.toStringAsFixed(2)
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
           _sumBox("CASH SALE", cashTotal), 
           _sumBox("CREDIT SALE", creditTotal), 
           _sumBox("NET TOTAL", netTotal, isBold: true)
        ]),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), format: PdfPageFormat.a4.landscape);
  }

  static pw.Widget _sumBox(String label, double val, {bool isBold = false}) {
    return pw.Column(children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      pw.Text("Rs. ${val.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    ]);
  }
}
