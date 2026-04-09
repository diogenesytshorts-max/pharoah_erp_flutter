import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateInvoice(Sale sale, Party party, {bool isPurchase = false}) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    String cAddr = prefs.getString('compAddr') ?? "";
    String cPh = prefs.getString('compPh') ?? "";
    String cGst = prefs.getString('compGST') ?? "";
    String cDl = prefs.getString('compDL') ?? "";
    String cEm = prefs.getString('compEmail') ?? "";
    String cState = prefs.getString('compState') ?? "Rajasthan";

    // --- GST GROUPING & CALCULATION ---
    Map<double, Map<String, double>> gstBuckets = {};
    double grandTotalGross = 0;
    double grandTotalDiscount = 0;
    double grandTotalTax = 0;
    bool hasIGST = false;

    for (var item in sale.items) {
      double rate = item.gstRate;
      double itemGross = item.rate * item.qty;
      double itemDisc = (itemGross * (item.discountPercent / 100)) + item.discountRupees;
      double itemTaxable = itemGross - itemDisc;

      grandTotalGross += itemGross;
      grandTotalDiscount += itemDisc;
      grandTotalTax += (item.cgst + item.sgst + item.igst);
      if (item.igst > 0) hasIGST = true;

      if (!gstBuckets.containsKey(rate)) {
        gstBuckets[rate] = {'taxable': 0, 'cgst': 0, 'sgst': 0, 'igst': 0};
      }
      gstBuckets[rate]!['taxable'] = gstBuckets[rate]!['taxable']! + itemTaxable;
      gstBuckets[rate]!['cgst'] = gstBuckets[rate]!['cgst']! + item.cgst;
      gstBuckets[rate]!['sgst'] = gstBuckets[rate]!['sgst']! + item.sgst;
      gstBuckets[rate]!['igst'] = gstBuckets[rate]!['igst']! + item.igst;
    }

    const int itemsPerPage = 12;
    int totalItems = sale.items.length;
    int totalPages = (totalItems / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
            child: pw.Column(children: [
              // --- HEADER ---
              pw.Row(children: [
                pw.Container(width: 300, height: 100, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(cName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                  pw.Spacer(),
                  pw.Text("State: $cState", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Phone: $cPh | GSTIN: $cGst", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
                pw.Container(width: 180, height: 100, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(children: [
                  pw.Container(width: double.infinity, color: isPurchase ? PdfColors.orange100 : PdfColors.blue100, padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text(isPurchase ? "PURCHASE BILL" : "SALE INVOICE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)))),
                  pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Spacer(),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("Inv No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("Page ${pageIndex + 1} of $totalPages", style: pw.TextStyle(fontSize: 7)),
                  ])),
                ])),
                pw.Container(width: 322, height: 100, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("BILL TO / PARTY DETAILS:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.Text(party.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text(party.address, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                  pw.Spacer(),
                  pw.Text("State: ${party.state} | Phone: ${party.phone}", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
              ]),

              // --- TABLE HEADER ---
              pw.Container(color: PdfColors.blue50, child: pw.Row(children: [
                _c("S.N", 30), _c("Qty", 45), _c("Pack", 45), _c("Product Name", 180, a: pw.Alignment.centerLeft), _c("Batch", 80), _c("Exp", 50), _c("HSN", 50), _c("MRP", 60), _c(isPurchase ? "Pur.Rate" : "Rate", 60), _c("DIS%", 35),
                if (hasIGST) _c("IGST%", 90) else ...[_c("SGST%", 45), _c("CGST%", 45)],
                _c("Net Amt", 77),
              ])),

              // --- TABLE ROWS ---
              pw.Container(height: 260, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Column(children: sale.items.sublist(pageIndex * itemsPerPage, min((pageIndex + 1) * itemsPerPage, totalItems)).map((i)=>pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.2))), child: pw.Row(children: [
                _ce("${i.srNo}", 30), _ce(i.qty.toStringAsFixed(2), 45), _ce(i.packing, 45), _ce(i.name, 180, a: pw.Alignment.centerLeft), _ce(i.batch, 80), _ce(i.exp, 50), _ce(i.hsn, 50), _ce(i.mrp.toStringAsFixed(2), 60), _ce(i.rate.toStringAsFixed(2), 60), _ce(i.discountPercent.toStringAsFixed(1), 35),
                if (hasIGST) _ce("${i.gstRate.toInt()}%", 90) else ...[_ce("${(i.gstRate/2).toStringAsFixed(1)}%", 45), _ce("${(i.gstRate/2).toStringAsFixed(1)}%", 45)],
                _ce(i.total.toStringAsFixed(2), 77),
              ]))).toList())),

              // --- FOOTER ---
              if (pageIndex == totalPages - 1) ...[
                pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(width: 340, child: pw.Column(children: [
                    pw.Container(color: PdfColors.grey200, child: pw.Row(children: [_sH("TAX SLAB", 60), _sH("TAXABLE", 70), if(hasIGST) _sH("IGST", 70) else ...[_sH("SGST", 70), _sH("CGST", 70)], _sH("TOTAL TAX", 70)])),
                    ...gstBuckets.entries.map((entry) => pw.Row(children: [
                      _sC("${entry.key.toInt()}%", 60), _sC(entry.value['taxable']!.toStringAsFixed(2), 70),
                      if(hasIGST) _sC(entry.value['igst']!.toStringAsFixed(2), 70) else ...[_sC(entry.value['sgst']!.toStringAsFixed(2), 70), _sC(entry.value['cgst']!.toStringAsFixed(2), 70)],
                      _sC((entry.value['cgst']! + entry.value['sgst']! + entry.value['igst']!).toStringAsFixed(2), 70)
                    ])),
                    pw.Container(width: 340, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text("Amt in Words: RUPEES ${sale.totalAmount.toInt()} ONLY", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))),
                  ])),
                  pw.Spacer(),
                  pw.Container(width: 200, height: 100, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Column(children: [
                    _fR("GROSS TOTAL", grandTotalGross), _fR("TAX TOTAL", grandTotalTax), _fR("DISCOUNT", grandTotalDiscount, c: PdfColors.red),
                    pw.Spacer(),
                    pw.Container(width: double.infinity, color: PdfColors.blue50, padding: const pw.EdgeInsets.all(5), child: pw.Column(children: [
                      pw.Text("Grand Total", style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    ])),
                  ])),
                ]),
                pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Receiver's Signature", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text("For $cName", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 15),
                    pw.Text("Authorised Signatory", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ]),
                ])),
              ]
            ]),
          );
        },
      ));
    }
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Invoice_${sale.billNo}", format: PdfPageFormat.a4.landscape);
  }

  static pw.Widget _c(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, height: 25, alignment: a, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _ce(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, alignment: a, padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
  static pw.Widget _sH(String t, double w) => pw.Container(width: w, height: 15, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.2)), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _sC(String t, double w) => pw.Container(width: w, height: 15, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.2)), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
  static pw.Widget _fR(String l, double v, {PdfColor c = PdfColors.black}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: c))]));
}
