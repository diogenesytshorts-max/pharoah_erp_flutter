import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class GstReportService {
  
  // 1. GSTR-1 (Sales)
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
        _sectionTitle("SECTION 2: B2C SALES (CONSUMERS)"),
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

  // 2. GSTR-2 (Purchases + Expense ITC)
  static Future<void> generateGstr2Pdf(List<Purchase> purchases, List<Voucher> vouchers, List<Party> parties, String periodLabel) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();

    // Filter Expense vouchers that might have GST (SAC codes)
    List<Voucher> expenseVouchers = vouchers.where((v) {
      Party p = parties.firstWhere((pt) => pt.id == v.partyId, orElse: () => Party(id: '0', name: 'N/A'));
      return p.accountGroup == "Expenses" && p.gst != "N/A";
    }).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => _buildReportHeader(cName, "GSTR-2 (ITC & Expense Summary)", periodLabel),
      build: (pw.Context context) => [
        _sectionTitle("INWARD SUPPLIES (PURCHASES)"),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.orange900),
          headers: ['Date', 'Bill No', 'Supplier Name', 'Taxable Val', 'GST (ITC)', 'Total'],
          data: purchases.map((p) {
            double pTaxable = p.items.fold(0.0, (sum, it) => sum + (it.purchaseRate * it.qty));
            return [DateFormat('dd/MM/yy').format(p.date), p.billNo, p.distributorName, pTaxable.toStringAsFixed(2), (p.totalAmount - pTaxable).toStringAsFixed(2), p.totalAmount.toStringAsFixed(2)];
          }).toList(),
        ),
        pw.SizedBox(height: 20),
        _sectionTitle("ITC ON EXPENSES (SAC CODE ENTRIES)"),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
          headers: ['Date', 'Expense Name', 'GSTIN', 'SAC Code', 'Amount'],
          data: expenseVouchers.map((v) {
            Party p = parties.firstWhere((pt) => pt.id == v.partyId);
            return [DateFormat('dd/MM/yy').format(v.date), v.partyName, p.gst, p.hsnCode, v.amount.toStringAsFixed(2)];
          }).toList(),
        ),
        pw.SizedBox(height: 15),
        _buildFooterNote(),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR2_Report");
  }

  // 3. GSTR-3B (Summary)
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
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
            headers: ['DESCRIPTION', 'TAXABLE VALUE', 'CENTRAL TAX', 'STATE TAX', 'TOTAL TAX'],
            data: [
              ['Outward Supplies (Sales)', saleTaxable.toStringAsFixed(2), (saleGst/2).toStringAsFixed(2), (saleGst/2).toStringAsFixed(2), saleGst.toStringAsFixed(2)],
              ['Eligible ITC (Purchases)', purchaseTaxable.toStringAsFixed(2), (purchaseGst/2).toStringAsFixed(2), (purchaseGst/2).toStringAsFixed(2), purchaseGst.toStringAsFixed(2)],
              ['NET GST PAYABLE', (saleTaxable - purchaseTaxable).toStringAsFixed(2), ((saleGst - purchaseGst)/2).toStringAsFixed(2), ((saleGst - purchaseGst)/2).toStringAsFixed(2), (saleGst - purchaseGst).toStringAsFixed(2)],
            ],
          ),
          pw.Spacer(),
          _buildFooterNote(),
        ]),
      ),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GSTR3B_Summary");
  }

  // --- UI HELPERS ---
  static pw.Widget _buildReportHeader(String cName, String title, String range) {
    return pw.Column(children: [
      pw.Text(cName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Text(title, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo700)),
      pw.Text("Period: $range", style: const pw.TextStyle(fontSize: 11)),
      pw.Divider(thickness: 2),
      pw.SizedBox(height: 10),
    ]);
  }
  static pw.Widget _sectionTitle(String t) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 8), child: pw.Text(t, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.indigo900)));
  static pw.Widget _buildB2bTable(List<Sale> list) {
    return pw.TableHelper.fromTextArray(headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 8), headers: ['Date', 'Invoice No', 'Party Name', 'GSTIN', 'Taxable Val', 'GST Amt', 'Total'], data: list.map((s) {
        double tax = s.items.fold(0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
        return [DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, (s.totalAmount - tax).toStringAsFixed(2), tax.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)];
      }).toList(),
    );
  }
  static pw.Widget _buildB2cTable(List<Sale> list) {
    return pw.TableHelper.fromTextArray(headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), headers: ['Type', 'State', 'Taxable Value', 'GST Amount', 'Total Amount'], data: list.map((s) {
        double tax = s.items.fold(0, (sum, it) => sum + (it.cgst + it.sgst + it.igst));
        return ['B2C Small', s.partyState, (s.totalAmount - tax).toStringAsFixed(2), tax.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)];
      }).toList(),
    );
  }
  static pw.Widget _buildHsnSummaryTable(List<Sale> sales) {
    Map<String, Map<String, dynamic>> hsnData = {};
    for (var s in sales.where((s) => s.status == "Active")) {
      for (var it in s.items) {
        if (!hsnData.containsKey(it.hsn)) hsnData[it.hsn] = {'qty': 0.0, 'val': 0.0, 'tax': 0.0};
        hsnData[it.hsn]!['qty'] += it.qty;
        hsnData[it.hsn]!['val'] += (it.rate * it.qty);
        hsnData[it.hsn]!['tax'] += (it.cgst + it.sgst + it.igst);
      }
    }
    return pw.TableHelper.fromTextArray(headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold), headers: ['HSN Code', 'Qty', 'Taxable Val', 'Total GST', 'Net Val'], data: hsnData.entries.map((e) => [e.key, e.value['qty'].toString(), e.value['val'].toStringAsFixed(2), e.value['tax'].toStringAsFixed(2), (e.value['val'] + e.value['tax']).toStringAsFixed(2)]).toList());
  }
  static pw.Widget _buildFooterNote() => pw.Container(padding: const pw.EdgeInsets.all(8), color: PdfColors.grey100, child: pw.Text("Disclaimer: System generated summary for GST filing assistance. Please reconcile before filing.", style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)));
}
