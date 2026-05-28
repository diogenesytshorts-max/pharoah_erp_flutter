// FILE: lib/gst_report_service.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'gateway/company_registry_model.dart';

class GstReportService {
  
  // ===========================================================================
  // 1. GSTR-1 (SALES) - GENERATE BYTES
  // ===========================================================================
  static Future<void> generateGstr1Pdf(List<Sale> sales, String period, CompanyProfile shop) async {
    final bytes = await generateGstr1Bytes(sales, shop);
    await Printing.layoutPdf(onLayout: (format) async => bytes, name: "GSTR1_${shop.name}");
  }

  // Strictly expects List<Sale>
  static Future<Uint8List> generateGstr1Bytes(List<Sale> sales, CompanyProfile shop) async {
    final pdf = pw.Document();
    
    // Filtering Active records
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B" && s.status == "Active").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C" && s.status == "Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _header(shop.name, "GSTR-1 (Sales Register)", "Audit Summary"),
      build: (context) => [
        _title("B2B SALES SUMMARY"), 
        _tableB2B(b2b),
        pw.SizedBox(height: 25),
        _title("B2C SALES SUMMARY"), 
        _tableB2C(b2c),
      ],
    ));
    return pdf.save();
  }

  // ===========================================================================
  // 2. GSTR-3B (MONTHLY SUMMARY) - GENERATE BYTES
  // ===========================================================================
  static Future<void> generateGstr3bPdf(List<Sale> sales, List<Purchase> purchases, String period, CompanyProfile shop) async {
    final bytes = await generateGstr3bBytes(sales, purchases, shop);
    await Printing.layoutPdf(onLayout: (format) async => bytes, name: "GSTR3B_${shop.name}");
  }

  // Strictly expects List<Sale> and List<Purchase>
  static Future<Uint8List> generateGstr3bBytes(List<Sale> sales, List<Purchase> purchases, CompanyProfile shop) async {
    final pdf = pw.Document();
    double sTaxVal = 0, sTax = 0, pTaxVal = 0, pTax = 0;

    // Outward (Sales) Computation
    for (var s in sales.where((s) => s.status == "Active")) {
      for (var it in s.items) { 
        sTaxVal += (it.rate * it.qty); 
        sTax += (it.cgst + it.sgst + it.igst); 
      }
    }

    // Inward (Purchases) Computation
    for (var p in purchases) {
      for (var it in p.items) { 
        pTaxVal += (it.purchaseRate * it.qty); 
        pTax += (it.total - (it.purchaseRate * it.qty)); 
      }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape, 
      build: (context) => pw.Column(children: [
        _header(shop.name, "GSTR-3B MONTHLY RETURN", "Computation for Filing"),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), 
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          headers: ['DESCRIPTION', 'TAXABLE VALUE', 'CENTRAL TAX', 'STATE TAX', 'TOTAL TAX'],
          data: [
            ['(A) Outward Supplies (Sales)', sTaxVal.toStringAsFixed(2), (sTax/2).toStringAsFixed(2), (sTax/2).toStringAsFixed(2), sTax.toStringAsFixed(2)],
            ['(B) Eligible ITC (Purchases)', pTaxVal.toStringAsFixed(2), (pTax/2).toStringAsFixed(2), (pTax/2).toStringAsFixed(2), pTax.toStringAsFixed(2)],
            ['NET GST PAYABLE / REFUND', (sTaxVal - pTaxVal).toStringAsFixed(2), ((sTax - pTax)/2).toStringAsFixed(2), ((sTax - pTax)/2).toStringAsFixed(2), (sTax - pTax).toStringAsFixed(2)],
          ]),
      ])
    ));
    return pdf.save();
  }

  // ===========================================================================
  // 3. INTERNAL HELPERS
  // ===========================================================================
  static pw.Widget _header(String n, String t, String p) => pw.Column(children: [
    pw.Text(n.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
    pw.Text(t, style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
    pw.Text(p, style: const pw.TextStyle(fontSize: 9)),
    pw.Divider(thickness: 1, color: PdfColors.indigo900)
  ]);

  static pw.Widget _title(String t) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5), 
    child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey900))
  );

  static pw.Widget _tableB2B(List<Sale> l) => pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
    headers: ['Date', 'Inv No', 'Party Name', 'GSTIN', 'Total Amt'], 
    data: l.map((s) => [DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.totalAmount.toStringAsFixed(2)]).toList()
  );

  static pw.Widget _tableB2C(List<Sale> l) => pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.black),
    headers: ['State', 'Taxable Val', 'GST Amt', 'Total Amt'], 
    data: l.map((s) => [s.partyState, (s.totalAmount * 0.88).toStringAsFixed(2), (s.totalAmount * 0.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)]).toList()
  );
}
