import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class GstReportService {
  
  // ==========================================================
  // 1. GSTR-1 MASTER PDF REPORT (Detailed)
  // ==========================================================
  static Future<void> generateGstr1Pdf(List<Sale> sales, String period) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();

    // Filtering Data
    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B" && s.status == "Active").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C" && s.status == "Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => _buildReportHeader(cName, "GSTR-1 (Sales Register)", period),
      build: (pw.Context context) => [
        _sectionTitle("SECTION 1: B2B SALES (REGISTERED PARTIES)"),
        _buildB2bTable(b2b),
        pw.SizedBox(height: 20),
        _sectionTitle("SECTION 2: B2C SALES (CONSUMERS)"),
        _buildB2cTable(b2c),
        pw.SizedBox(height: 20),
        _sectionTitle("SECTION 3: HSN WISE SUMMARY"),
        _buildHsnSummaryTable(sales),
      ],
    ));

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR1_$period");
  }

  // ==========================================================
  // 2. GSTR-3B MASTER PDF REPORT (Sales vs Purchase ITC)
  // ==========================================================
  static Future<void> generateGstr3bPdf(List<Sale> sales, List<Purchase> purchases, String period) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();

    // Calculations
    double saleTaxable = 0, saleGst = 0;
    for (var s in sales.where((s) => s.status == "Active")) {
      saleTaxable += s.totalAmount / 1.12; // Approximation, better to sum item-wise
      for (var it in s.items) saleGst += (it.cgst + it.sgst + it.igst);
    }

    double purchaseTaxable = 0, purchaseGst = 0;
    for (var p in purchases) {
      for (var it in p.items) {
        purchaseTaxable += (it.purchaseRate * it.qty);
        purchaseGst += (it.total - (it.purchaseRate * it.qty));
      }
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (pw.Context context) => pw.Container(
        padding: const pw.EdgeInsets.all(20),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          _buildReportHeader(cName, "GSTR-3B (MONTHLY SUMMARY)", period),
          pw.SizedBox(height: 30),
          
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            headers: ['DESCRIPTION', 'TAXABLE VALUE', 'INTEGRATED TAX', 'CENTRAL TAX', 'STATE TAX', 'TOTAL TAX'],
            data: [
              ['(A) Outward Supplies (Sales)', saleTaxable.toStringAsFixed(2), '0.00', (saleGst/2).toStringAsFixed(2), (saleGst/2).toStringAsFixed(2), saleGst.toStringAsFixed(2)],
              ['(B) Eligible ITC (Purchases)', purchaseTaxable.toStringAsFixed(2), '0.00', (purchaseGst/2).toStringAsFixed(2), (purchaseGst/2).toStringAsFixed(2), purchaseGst.toStringAsFixed(2)],
              ['(C) NET GST PAYABLE (A - B)', (saleTaxable - purchaseTaxable).toStringAsFixed(2), '0.00', ((saleGst - purchaseGst)/2).toStringAsFixed(2), ((saleGst - purchaseGst)/2).toStringAsFixed(2), (saleGst - purchaseGst).toStringAsFixed(2)],
            ],
          ),
          
          pw.Spacer(),
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            color: PdfColors.grey100,
            child: pw.Text("Note: This is a system generated summary for GST filing. Please reconcile with your books before payment.", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
          )
        ]),
      ),
    ));

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR3B_$period");
  }

  // --- UI HELPERS ---

  static pw.Widget _buildReportHeader(String cName, String title, String period) {
    return pw.Column(children: [
      pw.Text(cName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
      pw.Text("Period: $period", style: const pw.TextStyle(fontSize: 11)),
      pw.Divider(thickness: 2),
      pw.SizedBox(height: 10),
    ]);
  }

  static pw.Widget _sectionTitle(String t) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)));

  static pw.Widget _buildB2bTable(List<Sale> list) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['Date', 'Invoice No', 'Party Name', 'GSTIN', 'Taxable Val', 'GST Amt', 'Total'],
      data: list.map((s) => [
        DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, 
        (s.totalAmount/1.12).toStringAsFixed(2), (s.totalAmount - (s.totalAmount/1.12)).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)
      ]).toList(),
    );
  }

  static pw.Widget _buildB2cTable(List<Sale> list) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['Type', 'State (POS)', 'Taxable Value', 'GST Amount', 'Total Amount'],
      data: list.map((s) => [
        'B2C Small', s.partyState, (s.totalAmount/1.12).toStringAsFixed(2), 
        (s.totalAmount - (s.totalAmount/1.12)).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)
      ]).toList(),
    );
  }

  static pw.Widget _buildHsnSummaryTable(List<Sale> sales) {
    Map<String, Map<String, dynamic>> hsnData = {};
    for (var s in sales.where((s) => s.status == "Active")) {
      for (var it in s.items) {
        if (!hsnData.containsKey(it.hsn)) hsnData[it.hsn] = {'qty': 0, 'val': 0.0, 'tax': 0.0};
        hsnData[it.hsn]!['qty'] += it.qty;
        hsnData[it.hsn]!['val'] += (it.rate * it.qty);
        hsnData[it.hsn]!['tax'] += (it.cgst + it.sgst + it.igst);
      }
    }
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['HSN Code', 'Total Quantity', 'Taxable Value', 'Total GST', 'Net Value'],
      data: hsnData.entries.map((e) => [
        e.key, e.value['qty'].toString(), e.value['val'].toStringAsFixed(2), 
        e.value['tax'].toStringAsFixed(2), (e.value['val'] + e.value['tax']).toStringAsFixed(2)
      ]).toList(),
    );
  }
}
