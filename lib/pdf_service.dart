import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  
  // ==========================================================
  // 1. SALES INVOICE GENERATOR (Blue Theme)
  // ==========================================================
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();
    String cAddr = prefs.getString('compAddr') ?? "Address Not Set";
    String cGst = prefs.getString('compGST') ?? "N/A";
    String cDl = prefs.getString('compDL') ?? "N/A";
    String cState = prefs.getString('compState') ?? "Rajasthan";

    bool isInterstate = sale.partyState.trim().toLowerCase() != cState.trim().toLowerCase();

    double grossTotal = 0; double totalDiscount = 0; double totalTax = 0;
    for (var it in sale.items) { grossTotal += (it.rate * it.qty); totalDiscount += it.discountRupees; totalTax += (it.cgst + it.sgst + it.igst); }

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
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            _buildHeader(cName, cAddr, cGst, cDl, "TAX INVOICE", sale.billNo, sale.date, party, PdfColors.blue900),
            pw.Expanded(child: _buildTable(pItems, isInterstate, true)),
            if (isLast) _buildFooter(grossTotal, totalDiscount, totalTax, sale.totalAmount) else _buildPageIndicator(i + 1, totalPages),
          ]),
        ),
      ));
    }
    await _printPdf(pdf, "Sale_${sale.billNo}");
  }

  // ==========================================================
  // 2. PURCHASE INVOICE GENERATOR (Orange Theme)
  // ==========================================================
  static Future<void> generatePurchaseInvoice(Purchase pur, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();
    String cAddr = prefs.getString('compAddr') ?? "Address Not Set";
    String cGst = prefs.getString('compGST') ?? "N/A";
    String cState = prefs.getString('compState') ?? "Rajasthan";

    bool isInterstate = party.state.trim().toLowerCase() != cState.trim().toLowerCase();

    double grossTotal = 0; double totalTax = 0;
    for (var it in pur.items) { grossTotal += (it.purchaseRate * it.qty); totalTax += (it.total - (it.purchaseRate * it.qty)); }

    const int itemsPerPage = 12; int totalPages = (pur.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int i = 0; i < totalPages; i++) {
      int start = i * itemsPerPage; int end = min(start + itemsPerPage, pur.items.length);
      List<PurchaseItem> pItems = pur.items.sublist(start, end); bool isLast = (i == totalPages - 1);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            _buildHeader(cName, cAddr, cGst, "", "PURCHASE VOUCHER", pur.billNo, pur.date, party, PdfColors.deepOrange900),
            pw.Expanded(child: _buildTable(pItems, isInterstate, false)),
            if (isLast) _buildFooter(grossTotal, 0, totalTax, pur.totalAmount) else _buildPageIndicator(i + 1, totalPages),
          ]),
        ),
      ));
    }
    await _printPdf(pdf, "Purchase_${pur.billNo}");
  }

  // ==========================================================
  // 3. SALES SUMMARY REPORT (NEW)
  // ==========================================================
  static Future<void> generateSaleSummaryPdf(List<Sale> sales, DateTime fDate, DateTime tDate, Party? p) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();
    String pStr = "${DateFormat('dd/MM/yy').format(fDate)} to ${DateFormat('dd/MM/yy').format(tDate)}";
    String pFilter = p == null ? "All Parties" : p.name;

    double gTaxable = 0; double gTax = 0; double gTotal = 0;
    for(var s in sales) {
      double t=0; for(var it in s.items) t += (it.cgst+it.sgst+it.igst);
      gTax += t; gTaxable += (s.totalAmount-t); gTotal += s.totalAmount;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => pw.Column(children: [
        pw.Text(cName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.Text("SALES REGISTER / SUMMARY", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text("Period: $pStr | Filter: $pFilter", style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(thickness: 1.5),
      ]),
      build: (pw.Context context) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Date', 'Invoice No', 'Party Name', 'Taxable Amt', 'GST Amt', 'Net Total'],
          data: sales.map((s) {
            double tax = 0; for(var it in s.items) tax += (it.cgst+it.sgst+it.igst);
            return [DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, (s.totalAmount-tax).toStringAsFixed(2), tax.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)];
          }).toList(),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10), color: PdfColors.grey200,
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            pw.Text("TOTAL TAXABLE: Rs. ${gTaxable.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text("TOTAL GST: Rs. ${gTax.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text("NET SALES: Rs. ${gTotal.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.blue900)),
          ])
        )
      ],
    ));
    await _printPdf(pdf, "Sale_Summary");
  }

  // ==========================================================
  // 4. PURCHASE SUMMARY REPORT (NEW)
  // ==========================================================
  static Future<void> generatePurchaseSummaryPdf(List<Purchase> pur, DateTime fDate, DateTime tDate, Party? p) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();
    String pStr = "${DateFormat('dd/MM/yy').format(fDate)} to ${DateFormat('dd/MM/yy').format(tDate)}";
    String pFilter = p == null ? "All Suppliers" : p.name;

    double gTaxable = 0; double gTax = 0; double gTotal = 0;
    for(var pr in pur) {
      double taxb=0; for(var it in pr.items) taxb += (it.purchaseRate * it.qty);
      gTaxable += taxb; gTax += (pr.totalAmount-taxb); gTotal += pr.totalAmount;
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => pw.Column(children: [
        pw.Text(cName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.deepOrange900)),
        pw.Text("PURCHASE REGISTER / SUMMARY", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.Text("Period: $pStr | Filter: $pFilter", style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(thickness: 1.5),
      ]),
      build: (pw.Context context) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.deepOrange900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Date', 'Bill No', 'Supplier Name', 'Taxable Amt', 'GST (ITC)', 'Net Total'],
          data: pur.map((pr) {
            double taxb = 0; for(var it in pr.items) taxb += (it.purchaseRate * it.qty);
            return [DateFormat('dd/MM/yy').format(pr.date), pr.billNo, pr.distributorName, taxb.toStringAsFixed(2), (pr.totalAmount-taxb).toStringAsFixed(2), pr.totalAmount.toStringAsFixed(2)];
          }).toList(),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10), color: PdfColors.grey200,
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
            pw.Text("TOTAL TAXABLE: Rs. ${gTaxable.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text("TOTAL ITC: Rs. ${gTax.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
            pw.Text("NET PURCHASE: Rs. ${gTotal.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12, color: PdfColors.deepOrange900)),
          ])
        )
      ],
    ));
    await _printPdf(pdf, "Purchase_Summary");
  }

  // --- INTERNAL HELPER WIDGETS ---
  static pw.Widget _buildHeader(String cN, String cA, String cG, String cD, String title, String bNo, DateTime date, Party p, PdfColor themeColor) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(cN, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: themeColor)),
          pw.Text(cA, style: const pw.TextStyle(fontSize: 8)),
          pw.Text("GSTIN: $cG ${cD != "" ? "| DL: $cD" : ""}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ])),
        pw.Container(padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(color: PdfColors.grey100), child: pw.Column(children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text("No: $bNo", style: const pw.TextStyle(fontSize: 9)),
          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(date)}", style: const pw.TextStyle(fontSize: 9)),
        ])),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text("BILL TO:", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Text(p.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("${p.city}, ${p.state}", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
          pw.Text("GSTIN: ${p.gst}", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text("DL No: ${p.dl} | Mob: ${p.phone}", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ])),
      ])
    );
  }

  static pw.Widget _buildTable(List<dynamic> items, bool isInterstate, bool isSale) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), cellStyle: const pw.TextStyle(fontSize: 7), headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
      columnWidths: {0: const pw.FixedColumnWidth(25), 1: const pw.FixedColumnWidth(30), 2: const pw.FixedColumnWidth(35), 3: const pw.FlexColumnWidth(3), 4: const pw.FixedColumnWidth(55), 5: const pw.FixedColumnWidth(40), 6: const pw.FixedColumnWidth(50), 7: const pw.FixedColumnWidth(40), 8: const pw.FixedColumnWidth(40), 9: const pw.FixedColumnWidth(35), 10: const pw.FixedColumnWidth(45), 11: const pw.FixedColumnWidth(45), 12: const pw.FixedColumnWidth(55)},
      headers: ['S.N', 'Qty', 'Pack', 'Product Name', 'Batch', 'Exp', 'HSN', 'MRP', isSale ? 'Rate' : 'P.Rate', 'Dis%', if (!isInterstate) ...['SGST', 'CGST'] else 'IGST', 'Net Amt'],
      data: items.map((it) {
        double rate = isSale ? it.rate : it.purchaseRate; double discAmt = isSale ? it.discountRupees : 0; double discP = (rate * it.qty) > 0 ? (discAmt / (rate * it.qty)) * 100 : 0;
        return [it.srNo, it.qty.toInt(), it.packing, it.name, it.batch, it.exp, it.hsn, it.mrp.toStringAsFixed(2), rate.toStringAsFixed(2), discP > 0 ? "${discP.toStringAsFixed(1)}%" : "0", if (!isInterstate) ...[isSale ? it.sgst.toStringAsFixed(2) : ((it.total - (rate * it.qty))/2).toStringAsFixed(2), isSale ? it.cgst.toStringAsFixed(2) : ((it.total - (rate * it.qty))/2).toStringAsFixed(2)] else (it.total - (rate * it.qty)).toStringAsFixed(2), it.total.toStringAsFixed(2)];
      }).toList(),
    );
  }

  static pw.Widget _buildFooter(double gross, double disc, double tax, double grand) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text("Amount in Words: Rupees ${grand.toInt()} Only", style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)), pw.SizedBox(height: 10), pw.Text("Terms: Goods once sold cannot be returned. E. & O. E.", style: const pw.TextStyle(fontSize: 7))])),
        pw.Container(width: 200, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), color: PdfColors.grey50), child: pw.Column(children: [_fRow("Gross Total:", gross), _fRow("(-) Discount:", disc), _fRow("(+) GST Tax:", tax), pw.Divider(thickness: 0.5), pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("GRAND TOTAL:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)), pw.Text("Rs. ${grand.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11))])]))
      ])
    );
  }

  static pw.Widget _fRow(String l, double v) { return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 8)), pw.Text(v.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8))]); }
  static pw.Widget _buildPageIndicator(int cur, int tot) { return pw.Container(padding: const pw.EdgeInsets.all(5), alignment: pw.Alignment.centerRight, child: pw.Text("Page $cur of $tot - Continued...", style: const pw.TextStyle(fontSize: 8))); }
  static Future<void> _printPdf(pw.Document pdf, String fileName) async { await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: fileName, format: PdfPageFormat.a4.landscape); }
}
