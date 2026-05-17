// FILE: lib/pdf/debit_note_pdf.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import '../logic/app_settings_model.dart';
import 'pdf_master_service.dart';

class DebitNotePdf {
  static Future<void> generate(PurchaseReturn ret, Party supplier, CompanyProfile shop, AppConfig config) async {
    if (config.isArchitectMode) {
      await _generateArchitect(ret, supplier, shop, config);
    } else {
      await _generateStandard(ret, supplier, shop, config);
    }
  }

  // ===========================================================================
  // 🏛️ ARCHITECT FORMAT (DEBIT NOTE - PURCHASE SIDE)
  // ===========================================================================
  static Future<void> _generateArchitect(PurchaseReturn ret, Party supplier, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();
    const double masterWidth = 800;
    const int itemsPerPage = 18;

    final sellable = ret.items.where((i) => i.isBreakage == false).toList();
    final breakage = ret.items.where((i) => i.isBreakage == true).toList();

    List<dynamic> combinedList = [];
    if (sellable.isNotEmpty) { combinedList.add(">> PURCHASE RETURN (STOCK OUT)"); combinedList.addAll(sellable); }
    if (breakage.isNotEmpty) { combinedList.add(">> BREAKAGE/EXPIRY RETURN (NON-SELLABLE)"); combinedList.addAll(breakage); }

    int totalPages = (combinedList.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < combinedList.length) ? start + itemsPerPage : combinedList.length;
      List<dynamic> pageContent = combinedList.sublist(start, end);
      bool isLastPage = (pageNum == totalPages - 1);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (context) => pw.Container(
          width: masterWidth,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            pw.Row(children: [
              _hBox(280, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text(shop.address, style: const pw.TextStyle(fontSize: 7), maxLines: 2),
                pw.Text("GSTIN: ${shop.gstin}", style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
              ])),
              _hBox(175, true, pw.Column(children: [
                pw.Text("DEBIT NOTE", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)),
                pw.Divider(thickness: 0.5),
                pw.Text(ret.billNo, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy').format(ret.date), style: const pw.TextStyle(fontSize: 8)),
              ])),
              _hBox(345, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("SEND TO SUPPLIER:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(supplier.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text("GST: ${supplier.gst} | DL: ${supplier.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ])),
            ]),
            pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
              _tCol("S.N", 25), _tCol("Qty+Free", 60), _tCol("Pack", 40), _tCol("Description", 215, isLeft: true), _tCol("Batch", 80), _tCol("Exp", 45), _tCol("MRP", 60), _tCol("Rate", 60), _tCol("GST%", 50), _tCol("Total", 125, isLast: true), 
            ])),
            pw.Expanded(child: pw.Column(children: pageContent.map((row) {
              if (row is String) return _sectionHeaderRow(row, masterWidth);
              PurchaseItem i = row as PurchaseItem;
              int idx = ret.items.indexOf(i);
              bool isShaded = config.useZebraShading && (idx % 2 != 0);
              return pw.Container(color: isShaded ? PdfColors.grey50 : PdfColors.white, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))), child: pw.Row(children: [
                  _cell("${idx + 1}", 25), _cell("${i.qty.toInt()}+${i.freeQty.toInt()}", 60), _cell(i.packing, 40),
                  pw.Container(width: 215, padding: const pw.EdgeInsets.only(left: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(i.name, style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.mrp.toStringAsFixed(2), 60), _cell(i.purchaseRate.toStringAsFixed(2), 60), _cell("${i.gstRate}%", 50), _cell(i.total.toStringAsFixed(2), 125),
              ]));
            }).toList())),
            if (isLastPage) _buildArchitectFooter(shop.name, ret)
          ]),
        )
      ));
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), format: PdfPageFormat.a4.landscape);
  }

  // ===========================================================================
  // 📄 STANDARD PORTRAIT DEBIT NOTE
  // ===========================================================================
  static Future<void> _generateStandard(PurchaseReturn ret, Party supplier, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      build: (context) => [
        pw.Text("DEBIT NOTE - ${shop.name}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 10),
        pw.Text("Supplier: ${supplier.name}"),
        pw.Text("DN No: ${ret.billNo} | Date: ${DateFormat('dd/MM/yy').format(ret.date)}"),
        pw.Divider(),
        pw.TableHelper.fromTextArray(
          headers: ['Product', 'Batch', 'Qty', 'Pur.Rate', 'Total'],
          data: ret.items.map((i) => [i.name, i.batch, i.qty.toString(), i.purchaseRate.toStringAsFixed(2), i.total.toStringAsFixed(2)]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("DEBIT TOTAL: Rs. ${ret.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 100, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 18, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: 5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w) => pw.Container(width: w, height: 18, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));
  static pw.Widget _sectionHeaderRow(String text, double w) => pw.Container(width: w, padding: const pw.EdgeInsets.all(3), color: PdfColors.grey100, child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)));

  static pw.Widget _buildArchitectFooter(String n, PurchaseReturn ret) => pw.Container(height: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
    pw.Container(width: 450, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("RUPEES ${PdfMasterService.numberToWords(ret.totalAmount.round())} ONLY", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Spacer(),
        pw.Text("Return issued to Distributor against provided batch items.", style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700))
    ])),
    pw.Expanded(child: pw.Column(children: [
      pw.Padding(padding: const EdgeInsets.all(8), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("NET DEBIT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("Rs. ${ret.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900))])),
      pw.Spacer(),
      pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Padding(padding: const EdgeInsets.all(8), child: pw.Text("For $n", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))))
    ])),
  ]));
}
