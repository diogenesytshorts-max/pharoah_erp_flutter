// FILE: lib/pdf/purchase_pdf.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class PurchasePdf {
  static Future<void> generate(Purchase pur, Party supplier, CompanyProfile shop) async {
    final bytes = await generateBytes(pur, supplier, shop);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Purchase_${pur.billNo}',
      format: PdfPageFormat.a4.landscape,
    );
  }

  static Future<Uint8List> generateBytes(Purchase pur, Party supplier, CompanyProfile shop) async {
    final pdf = pw.Document();
    const double masterWidth = 800;
    const double pageHeightLimit = 550;
    const int itemsPerPage = 15; 
    int totalPages = (pur.items.length / itemsPerPage).ceil();

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < pur.items.length) ? start + itemsPerPage : pur.items.length;
      List<PurchaseItem> pageItems = pur.items.sublist(start, end);
      bool isLastPage = (pageNum == totalPages - 1);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (context) => pw.Container(
          width: masterWidth, height: pageHeightLimit,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            // Header
            pw.Row(children: [
              _hBox(290, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                pw.Text("Type: STOCK INWARD", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              ])),
              _hBox(175, true, pw.Column(children: [
                pw.Text("PURCHASE BILL", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                pw.Divider(thickness: 0.5),
                pw.Text("Ref: ${pur.billNo}", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy').format(pur.date), style: const pw.TextStyle(fontSize: 8.5)),
              ])),
              _hBox(335, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(supplier.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text("GSTIN: ${supplier.gst} | DL: ${supplier.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ])),
            ]),
            // Table
            pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
              _tCol("S.N", 25), _tCol("Qty", 45), _tCol("Free", 35), _tCol("Pack", 45),
              _tCol("Product Name", 215, isLeft: true), _tCol("Batch", 80), _tCol("Exp", 45),
              _tCol("HSN", 50), _tCol("MRP", 60), _tCol("Rate", 60), _tCol("GST%", 50), _tCol("Net Amt", 90, isLast: true),
            ])),
            // Data
            pw.Container(height: 300, child: pw.Column(children: pageItems.map((i) => pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))), child: pw.Row(children: [
              _cell("${pur.items.indexOf(i) + 1}", 25), _cell(i.qty.toStringAsFixed(0), 45), _cell(i.freeQty.toStringAsFixed(0), 35), _cell(i.packing, 45),
              pw.Container(width: 215, padding: const pw.EdgeInsets.only(left: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(i.name, style: const pw.TextStyle(fontSize: 7.5))),
              _cell(i.batch, 80), _cell(i.exp, 45), _cell(i.hsn, 50), _cell(i.mrp.toStringAsFixed(2), 60), _cell(i.purchaseRate.toStringAsFixed(2), 60), _cell("${i.gstRate}%", 50), _cell(i.total.toStringAsFixed(2), 90),
            ]))).toList())),
            // Footer
            if (isLastPage) _buildFooter(shop.name, pur)
            else pw.Container(height: 120, alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.all(10), child: pw.Text("Continued...", style: const pw.TextStyle(fontSize: 10))),
          ]),
        )
      ));
    }
    return pdf.save();
  }

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 90, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: isLeft ? 8 : 0), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w) => pw.Container(width: w, height: 18, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildFooter(String shopName, Purchase pur) {
    double taxable = pur.items.fold(0, (sum, i) => sum + (i.purchaseRate * i.qty));
    return pw.Container(height: 120, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
      pw.Container(width: 340, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("RUPEES ${PdfMasterService.numberToWords(pur.totalAmount.round())} ONLY", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.Spacer(),
        pw.Text("Note: Internal record for stock inward verification.", style: const pw.TextStyle(fontSize: 7)),
      ])),
      pw.Container(width: 260, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("TAXABLE"), pw.Text(taxable.toStringAsFixed(2))]),
        pw.Divider(thickness: 0.5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("TOTAL", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("Rs. ${pur.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
      ])),
      pw.Container(width: 200, padding: const pw.EdgeInsets.all(5), child: pw.Center(child: pw.Text(shopName, style: const pw.TextStyle(fontWeight: FontWeight.bold)))),
    ]));
  }
}
