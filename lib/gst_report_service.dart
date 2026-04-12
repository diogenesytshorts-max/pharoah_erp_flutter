import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class GstReportService {
  
  // ==========================================================
  // 1. GSTR-1 MASTER PDF REPORT (Sales)
  // ==========================================================
  static Future<void> generateGstr1Pdf(List<Sale> sales, String periodLabel) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();

    List<Sale> b2b = sales.where((s) => s.invoiceType == "B2B" && s.status == "Active").toList();
    List<Sale> b2c = sales.where((s) => s.invoiceType == "B2C" && s.status == "Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => _buildReportHeader(cName, "GSTR-1 (Sales Register Report)", periodLabel),
      build: (pw.Context context) => [
        _sectionTitle("SECTION 1: B2B SALES (REGISTERED PARTIES)"),
        _buildB2bTable(b2b),
        pw.SizedBox(height: 20),
        _sectionTitle("SECTION 2: B2C SALES (CONSUMERS / UNREGISTERED)"),
        _buildB2cTable(b2c),
        pw.SizedBox(height: 20),
        _sectionTitle("SECTION 3: HSN WISE SUMMARY"),
        _buildHsnSummaryTable(sales),
        pw.SizedBox(height: 20),
        _buildFooterNote(),
      ],
    ));

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR1_Report");
  }

  // ==========================================================
  // 2. GSTR-2 MASTER PDF REPORT (Purchase Register / ITC)
  // ==========================================================
  static Future<void> generateGstr2Pdf(List<Purchase> purchases, String periodLabel) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => _buildReportHeader(cName, "GSTR-2 (Purchase Register / ITC Summary)", periodLabel),
      footer: (context) => pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Page ${context.pageNumber}", style: const pw.TextStyle(fontSize: 8))),
      build: (pw.Context context) => [
        _sectionTitle("INWARD SUPPLIES RECEIVED (PURCHASES)"),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Date', 'Bill No', 'Internal ID', 'Supplier Name', 'Mode', 'Taxable Val', 'GST (ITC)', 'Total'],
          data: purchases.map((p) {
            double pTaxable = p.items.fold(0.0, (sum, it) => sum + (it.purchaseRate * it.qty));
            return [
              DateFormat('dd/MM/yy').format(p.date),
              p.billNo,
              p.internalNo,
              p.distributorName,
              p.paymentMode,
              pTaxable.toStringAsFixed(2),
              (p.totalAmount - pTaxable).toStringAsFixed(2),
              p.totalAmount.toStringAsFixed(2)
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("Total Purchase Bills: ${purchases.length}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text("Total ITC Available: Rs. ${purchases.fold(0.0, (sum, p) {
                double tx = p.items.fold(0.0, (s, it) => s + (it.purchaseRate * it.qty));
                return sum + (p.totalAmount - tx);
              }).toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
            ])
          )
        ]),
        pw.SizedBox(height: 15),
        _buildFooterNote(),
      ],
    ));

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR2_Report");
  }

  // ==========================================================
  // 3. GSTR-3B MASTER PDF REPORT (Monthly / Custom Summary)
  // ==========================================================
  static Future<void> generateGstr3bPdf(List<Sale> sales, List<Purchase> purchases, String periodLabel) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();

    double saleTaxable = 0, saleGst = 0;
    for (var s in sales.where((s) => s.status == "Active")) {
      for (var it in s.items) {
        saleTaxable += (it.rate * it.qty);
        saleGst += (it.cgst + it.sgst + it.igst);
      }
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
          _buildReportHeader(cName, "GSTR-3B (TAX COMPUTATION SUMMARY)", periodLabel),
          pw.SizedBox(height: 30),
          
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 10),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headers: ['DESCRIPTION', 'TAXABLE VALUE', 'INTEGRATED TAX', 'CENTRAL TAX', 'STATE TAX', 'TOTAL TAX'],
            data: [
              ['(A) Outward Supplies (Sales)', saleTaxable.toStringAsFixed(2), '0.00', (saleGst/2).toStringAsFixed(2), (saleGst/2).toStringAsFixed(2), saleGst.toStringAsFixed(2)],
              ['(B) Eligible ITC (Purchases)', purchaseTaxable.toStringAsFixed(2), '0.00', (purchaseGst/2).toStringAsFixed(2), (purchaseGst/2).toStringAsFixed(2), purchaseGst.toStringAsFixed(2)],
              ['(C) NET GST PAYABLE (A - B)', (saleTaxable - purchaseTaxable).toStringAsFixed(2), '0.00', ((saleGst - purchaseGst)/2).toStringAsFixed(2), ((saleGst - purchaseGst)/2).toStringAsFixed(2), (saleGst - purchaseGst).toStringAsFixed(2)],
            ],
          ),
          
          pw.Spacer(),
          _buildFooterNote(),
        ]),
      ),
    ));

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR3B_Summary");
  }

  // ==========================================================
  // UI HELPERS
  // ==========================================================
  
  static pw.Widget _buildReportHeader(String cName, String title, String range) {
    return pw.Column(children: [
      pw.Text(cName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
      pw.Text("Report Period: $range", style: const pw.TextStyle(fontSize: 11)),
      pw.Divider(thickness: 2),
      pw.SizedBox(height: 10),
    ]);
  }

  static pw.Widget _sectionTitle(String t) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)));

  static pw.Widget _buildB2bTable(List<Sale> list) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['Date', 'Invoice No', 'Party Name', 'GSTIN', 'Taxable Val', 'GST Amt', 'Total'],
      data: list.map((s) {
        double tax = s.items.fold(0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
        return [DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, (s.totalAmount - tax).toStringAsFixed(2), tax.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)];
      }).toList(),
    );
  }

  static pw.Widget _buildB2cTable(List<Sale> list) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['Type', 'State (POS)', 'Taxable Value', 'GST Amount', 'Total Amount'],
      data: list.map((s) {
        double tax = s.items.fold(0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
        return ['B2C Small', s.partyState, (s.totalAmount - tax).toStringAsFixed(2), tax.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)];
      }).toList(),
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

  static pw.Widget _buildFooterNote() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      color: PdfColors.grey100,
      child: pw.Text(
        "Disclaimer: This is a computer-generated summary for GST filing assistance. Please reconcile with your actual books of accounts before filing on the GST portal.",
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
      ),
    );
  }
}
