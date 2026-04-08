import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    String cAddr = prefs.getString('compAddr') ?? "";
    String cPh = prefs.getString('compPh') ?? "";
    String cGst = prefs.getString('compGST') ?? "";
    String cDl = prefs.getString('compDL') ?? "";
    String cEm = prefs.getString('compEmail') ?? "";

    double totalGross = sale.items.fold(0, (sum, i) => sum + (i.rate * i.qty));
    double totalDiscount = sale.items.fold(0, (sum, i) => sum + ((i.rate * i.qty) * (i.discountPercent / 100)) + i.discountRupees);
    double totalGST = sale.items.fold(0, (sum, i) => sum + (i.cgst + i.sgst));
    double totalTaxable = totalGross - totalDiscount;

    const int itemsPerPage = 15;
    int totalItems = sale.items.length;
    int totalPages = (totalItems / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = min(startIndex + itemsPerPage, totalItems);
      final pageItems = sale.items.sublist(startIndex, endIndex);
      final isLastPage = (pageIndex == totalPages - 1);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
            child: pw.Column(children: [
              // --- HEADER (3 BOXES) ---
              pw.Row(children: [
                pw.Container(width: 300, height: 100, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(cName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                  pw.Text("Phone: $cPh | GSTIN: $cGst", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text("D.L.No: $cDl | Email: $cEm", style: const pw.TextStyle(fontSize: 8)),
                ])),
                pw.Container(width: 180, height: 100, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(children: [
                  pw.Container(width: double.infinity, color: PdfColors.blue100, padding: const pw.EdgeInsets.all(4), child: pw.Center(child: pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)))),
                  pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("Inv No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 9)),
                    pw.Text("Page ${pageIndex + 1} of $totalPages", style: pw.TextStyle(fontSize: 8, color: PdfColors.blue800)),
                  ])),
                ])),
                pw.Container(width: 322, height: 100, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("PARTY DETAILS:", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                  pw.Text(party.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                  pw.Text(party.address, style: const pw.TextStyle(fontSize: 9), maxLines: 2),
                  pw.Text("GSTIN: ${party.gst} | Email: ${party.email}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
              ]),
              // --- TABLE HEADER ---
              pw.Container(color: PdfColors.blue50, child: pw.Row(children: [
                _c("S.N", 30), _c("Qty", 45), _c("Pack", 45), _c("Product Name", 180, a: pw.Alignment.centerLeft), _c("Batch", 80), _c("Exp", 50), _c("HSN", 50), _c("MRP", 60), _c("Rate", 60), _c("DIS%", 35), _c("SGST%", 45), _c("CGST%", 45), _c("Net Amt", 77),
              ])),
              // --- TABLE ROWS ---
              pw.Container(height: 280, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Column(children: pageItems.map((i)=>pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.2))), child: pw.Row(children: [
                _ce("${i.srNo}", 30), _ce(i.qty.toStringAsFixed(2), 45), _ce(i.packing, 45), _ce(i.name, 180, a: pw.Alignment.centerLeft), _ce(i.batch, 80), _ce(i.exp, 50), _ce(i.hsn, 50), _ce(i.mrp.toStringAsFixed(2), 60), _ce(i.rate.toStringAsFixed(2), 60), _ce(i.discountPercent.toStringAsFixed(1), 35), _ce("${(i.gstRate/2).toStringAsFixed(2)}%", 45), _ce("${(i.gstRate/2).toStringAsFixed(2)}%", 45), _ce(i.total.toStringAsFixed(2), 77),
              ]))).toList())),
              // --- FOOTER ---
              if (isLastPage) ...[
                pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(width: 340, child: pw.Column(children: [
                    pw.Container(color: PdfColors.grey200, child: pw.Row(children: [_sH("GST CLASS", 70), _sH("TAXABLE", 80), _sH("SGST", 60), _sH("CGST", 60), _sH("TOTAL GST", 70)])),
                    pw.Row(children: [_sC("GST ${sale.items[0].gstRate.toInt()}%", 70), _sC(totalTaxable.toStringAsFixed(2), 80), _sC((totalGST/2).toStringAsFixed(2), 60), _sC((totalGST/2).toStringAsFixed(2), 60), _sC(totalGST.toStringAsFixed(2), 70)]),
                    pw.Container(width: 340, height: 45, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("Amount in Words:", style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.Text("RUPEES ${sale.totalAmount.toInt()} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    ])),
                  ])),
                  pw.Container(width: 262, height: 105, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("Total Items: ${sale.items.length} | Total Qty: ${sale.items.fold(0.0, (s, it)=>s+it.qty)}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(),
                    pw.Text("Terms & Conditions:", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text("• Goods once sold will not be taken back.\n• All disputes subject to local Jurisdiction only.", style: const pw.TextStyle(fontSize: 7)),
                  ])),
                  pw.Container(width: 200, height: 105, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Column(children: [
                    _fR("GROSS TOTAL", totalGross), _fR("DISC AMT.", totalDiscount, c: PdfColors.red), _fR("GST PAYABLE", totalGST),
                    pw.Spacer(),
                    pw.Container(width: double.infinity, color: PdfColors.blue50, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue, width: 2)), child: pw.Column(children: [
                      pw.Text("Grand Total", style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    ])),
                  ])),
                ]),
                pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Receiver's Signature", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text("For $cName", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 15),
                    pw.Text("Authorised Signatory", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  ]),
                ])),
              ] else ...[
                pw.Container(height: 165, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Center(child: pw.Text("Continued to Page ${pageIndex + 2}...", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)))),
              ]
            ]),
          );
        },
      ));
    }
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Bill_${sale.billNo}", format: PdfPageFormat.a4.landscape);
  }

  static pw.Widget _c(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, height: 25, alignment: a, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)));
  static pw.Widget _ce(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, alignment: a, padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
  static pw.Widget _sH(String t, double w) => pw.Container(width: w, height: 15, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.2)), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _sC(String t, double w) => pw.Container(width: w, height: 15, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.2)), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
  static pw.Widget _fR(String l, double v, {PdfColor c = PdfColors.black}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: c))]));
}
