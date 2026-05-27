// FILE: lib/gst_report_service.dart (FIXED FOR EMAIL BYTES)

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'gateway/company_registry_model.dart';

class GstReportService {
  
  // ===========================================================================
  // 1. GSTR-1 (SALES)
  // ===========================================================================
  static Future<void> generateGstr1Pdf(List<Sale> sales, String period, CompanyProfile shop) async {
    final bytes = await generateGstr1Bytes(sales, shop);
    await Printing.layoutPdf(onLayout: (format) async => bytes, name: "GSTR1_${shop.name}");
  }

  // --- NEW: Generate Bytes for Email ---
  static Future<Uint8List> generateGstr1Bytes(List<Sale> sales, CompanyProfile shop) async {
    final pdf = pw.Document();
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B" && s.status == "Active").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C" && s.status == "Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _header(shop.name, "GSTR-1 (Sales Register)", "Audit Report"),
      build: (context) => [
        _title("B2B SALES"), _tableB2B(b2b),
        pw.SizedBox(height: 20),
        _title("B2C SALES"), _tableB2C(b2c),
      ],
    ));
    return pdf.save();
  }

  // ===========================================================================
  // 2. GSTR-2 (PURCHASES & ITC)
  // ===========================================================================
  static Future<void> generateGstr2Pdf(List<Purchase> pur, List<Voucher> vouc, List<Party> parties, String period, CompanyProfile shop) async {
    final bytes = await generateGstr2Bytes(pur, vouc, parties, shop);
    await Printing.layoutPdf(onLayout: (format) async => bytes, name: "GSTR2_${shop.name}");
  }

  static Future<Uint8List> generateGstr2Bytes(List<Purchase> pur, List<Voucher> vouc, List<Party> parties, CompanyProfile shop) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      header: (context) => _header(shop.name, "GSTR-2 (Inward & ITC)", "Audit Report"),
      build: (context) => [_title("PURCHASE INWARD REGISTER"), _tablePur(pur)],
    ));
    return pdf.save();
  }

  // ===========================================================================
  // 3. GSTR-3B (SUMMARY)
  // ===========================================================================
  static Future<void> generateGstr3bPdf(List<Sale> sales, List<Purchase> purchases, String period, CompanyProfile shop) async {
    final bytes = await generateGstr3bBytes(sales, purchases, shop);
    await Printing.layoutPdf(onLayout: (format) async => bytes, name: "GSTR3B_${shop.name}");
  }

  static Future<Uint8List> generateGstr3bBytes(List<Sale> sales, List<Purchase> purchases, CompanyProfile shop) async {
    final pdf = pw.Document();
    double sTaxVal = 0, sTax = 0, pTaxVal = 0, pTax = 0;
    for (var s in sales.where((s) => s.status == "Active")) {
      for (var it in s.items) { sTaxVal += (it.rate * it.qty); sTax += (it.cgst + it.sgst + it.igst); }
    }
    for (var p in purchases) {
      for (var it in p.items) { pTaxVal += (it.purchaseRate * it.qty); pTax += (it.total - (it.purchaseRate * it.qty)); }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape, 
      build: (context) => pw.Column(children: [
        _header(shop.name, "GSTR-3B MONTHLY SUMMARY", "Final Computation"),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), 
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          headers: ['DESCRIPTION', 'TAXABLE VALUE', 'CENTRAL TAX', 'STATE TAX', 'TOTAL TAX'],
          data: [
            ['(A) Outward Supplies', sTaxVal.toStringAsFixed(2), (sTax/2).toStringAsFixed(2), (sTax/2).toStringAsFixed(2), sTax.toStringAsFixed(2)],
            ['(B) Eligible ITC', pTaxVal.toStringAsFixed(2), (pTax/2).toStringAsFixed(2), (pTax/2).toStringAsFixed(2), pTax.toStringAsFixed(2)],
            ['NET GST PAYABLE', (sTaxVal - pTaxVal).toStringAsFixed(2), ((sTax - pTax)/2).toStringAsFixed(2), ((sTax - pTax)/2).toStringAsFixed(2), (sTax - pTax).toStringAsFixed(2)],
          ]),
      ])
    ));
    return pdf.save();
  }

  // --- HELPERS ---
  static pw.Widget _header(String n, String t, String p) => pw.Column(children: [
    pw.Text(n.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
    pw.Text(t, style: const pw.TextStyle(fontSize: 12)),
    pw.Divider()
  ]);

  static pw.Widget _title(String t) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey)));

  static pw.Widget _tableB2B(List<Sale> l) => pw.TableHelper.fromTextArray(headers: ['Date', 'Inv No', 'Party', 'GSTIN', 'Total'], data: l.map((s) => [DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.totalAmount.toStringAsFixed(2)]).toList());
  static pw.Widget _tableB2C(List<Sale> l) => pw.TableHelper.fromTextArray(headers: ['State', 'Taxable Val', 'GST', 'Total'], data: l.map((s) => [s.partyState, (s.totalAmount * 0.88).toStringAsFixed(2), (s.totalAmount * 0.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)]).toList());
  static pw.Widget _tablePur(List<Purchase> l) => pw.TableHelper.fromTextArray(headers: ['Date', 'Bill No', 'Supplier', 'Total'], data: l.map((p) => [DateFormat('dd/MM/yy').format(p.date), p.billNo, p.distributorName, p.totalAmount.toStringAsFixed(2)]).toList());
}
