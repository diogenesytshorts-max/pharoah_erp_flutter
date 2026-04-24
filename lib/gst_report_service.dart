// FILE: lib/gst_report_service.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'gateway/company_registry_model.dart'; // NAYA SOURCE

class GstReportService {
  
  // --- 1. GSTR-1 (SALES) PDF ---
  static Future<void> generateGstr1Pdf(List<Sale> sales, String periodLabel, CompanyProfile shop) async {
    final pdf = pw.Document();
    String cName = shop.name.toUpperCase();
    
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B" && s.status == "Active").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C" && s.status == "Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => _header(cName, "GSTR-1 (Sales Register)", periodLabel),
      build: (pw.Context context) => [
        _title("B2B SALES (REGISTERED PARTIES)"), 
        _tableB2B(b2b), 
        pw.SizedBox(height: 20),
        _title("B2C SALES (UNREGISTERED / CONSUMERS)"), 
        _tableB2C(b2c), 
        pw.SizedBox(height: 20),
        _title("HSN SUMMARY"), 
        _tableHSN(sales),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR1_$cName");
  }

  // --- 2. GSTR-2 (PURCHASES & ITC) PDF ---
  static Future<void> generateGstr2Pdf(List<Purchase> purchases, List<Voucher> vouchers, List<Party> parties, String periodLabel, CompanyProfile shop) async {
    final pdf = pw.Document();
    String cName = shop.name.toUpperCase();

    // Expense logic for ITC
    List<Voucher> expenseVouchers = vouchers.where((v) {
      final pList = parties.where((pt) => pt.id == v.partyId);
      if (pList.isEmpty) return false;
      return pList.first.group == "Expenses" && pList.first.gst != "N/A";
    }).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => _header(cName, "GSTR-2 (Purchases & Input Tax Credit)", periodLabel),
      build: (pw.Context context) => [
        _title("PURCHASE INWARD REGISTER"), 
        _tablePur(purchases), 
        pw.SizedBox(height: 20),
        _title("ELIGIBLE ITC ON EXPENSES"), 
        _tableExp(expenseVouchers, parties),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR2_$cName");
  }

  // --- 3. GSTR-3B (SUMMARY COMPUTATION) PDF ---
  static Future<void> generateGstr3bPdf(List<Sale> sales, List<Purchase> purchases, String periodLabel, CompanyProfile shop) async {
    final pdf = pw.Document();
    String cName = shop.name.toUpperCase();

    double sTaxVal = 0, sTax = 0, pTaxVal = 0, pTax = 0;
    for (var s in sales.where((s) => s.status == "Active")) {
      for (var it in s.items) { sTaxVal += (it.rate * it.qty); sTax += (it.cgst + it.sgst + it.igst); }
    }
    for (var p in purchases) {
      for (var it in p.items) { pTaxVal += (it.purchaseRate * it.qty); pTax += (it.total - (it.purchaseRate * it.qty)); }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape, 
      build: (pw.Context context) => pw.Column(children: [
        _header(cName, "GSTR-3B MONTHLY SUMMARY", periodLabel),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white), 
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          headers: ['DESCRIPTION', 'TAXABLE VALUE', 'CENTRAL TAX', 'STATE TAX', 'TOTAL TAX'],
          data: [
            ['(A) Outward Supplies (Sales)', sTaxVal.toStringAsFixed(2), (sTax/2).toStringAsFixed(2), (sTax/2).toStringAsFixed(2), sTax.toStringAsFixed(2)],
            ['(B) Eligible ITC (Purchases)', pTaxVal.toStringAsFixed(2), (pTax/2).toStringAsFixed(2), (pTax/2).toStringAsFixed(2), pTax.toStringAsFixed(2)],
            ['NET GST PAYABLE / CREDIT', (sTaxVal - pTaxVal).toStringAsFixed(2), ((sTax - pTax)/2).toStringAsFixed(2), ((sTax - pTax)/2).toStringAsFixed(2), (sTax - pTax).toStringAsFixed(2)],
          ]),
          pw.Spacer(),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Authorized Signatory for $cName", style: const pw.TextStyle(fontSize: 8))),
      ])
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR3B_$cName");
  }

  // --- REPORT HELPERS (ORIGINAL FORMAT) ---
  static pw.Widget _header(String n, String t, String p) => pw.Column(children: [
    pw.Text(n, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), 
    pw.Text(t, style: const pw.TextStyle(fontSize: 14)), 
    pw.Text("Period: $p"), 
    pw.Divider()
  ]);
  
  static pw.Widget _title(String t) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blueGrey)));
  
  static pw.Widget _tableB2B(List<Sale> l) => pw.TableHelper.fromTextArray(headers: ['Date', 'Inv No', 'Party', 'GSTIN', 'Total'], data: l.map((s) => [DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.totalAmount.toStringAsFixed(2)]).toList());
  
  static pw.Widget _tableB2C(List<Sale> l) => pw.TableHelper.fromTextArray(headers: ['State', 'Taxable Val', 'GST', 'Total'], data: l.map((s) => [s.partyState, (s.totalAmount * 0.88).toStringAsFixed(2), (s.totalAmount * 0.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)]).toList());
  
  static pw.Widget _tableHSN(List<Sale> l) => pw.TableHelper.fromTextArray(headers: ['HSN', 'Qty', 'Net Amt'], data: l.expand((s) => s.items).fold<Map<String, List<double>>>({}, (map, it) { map[it.hsn] = [(map[it.hsn]?[0] ?? 0) + it.qty, (map[it.hsn]?[1] ?? 0) + it.total]; return map; }).entries.map((e) => [e.key, e.value[0].toString(), e.value[1].toStringAsFixed(2)]).toList());
  
  static pw.Widget _tablePur(List<Purchase> l) => pw.TableHelper.fromTextArray(headers: ['Date', 'Bill No', 'Supplier', 'Total'], data: l.map((p) => [DateFormat('dd/MM/yy').format(p.date), p.billNo, p.distributorName, p.totalAmount.toStringAsFixed(2)]).toList());
  
  static pw.Widget _tableExp(List<Voucher> v, List<Party> pList) => pw.TableHelper.fromTextArray(headers: ['Date', 'Expense', 'SAC', 'Amount'], data: v.map((e) {
    final party = pList.firstWhere((pt) => pt.id == e.partyId);
    return [DateFormat('dd/MM/yy').format(e.date), e.partyName, party.hsnCode, e.amount.toStringAsFixed(2)];
  }).toList());
}
