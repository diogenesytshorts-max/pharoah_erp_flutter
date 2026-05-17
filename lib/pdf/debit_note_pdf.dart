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
    final pdf = pw.Document();
    const double masterWidth = 800;
    const int itemsPerPage = 18;

    String fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);

    final sellable = ret.items.where((i) => i.isBreakage == false).toList();
    final breakage = ret.items.where((i) => i.isBreakage == true).toList();

    List<dynamic> layoutList = [];
    if (sellable.isNotEmpty) {
      layoutList.add(">> PURCHASE RETURN (STOCK OUT)");
      layoutList.addAll(sellable);
    }
    if (breakage.isNotEmpty) {
      layoutList.add(">> BREAKAGE/EXPIRY RETURN (NON-SELLABLE)");
      layoutList.addAll(breakage);
    }

    int totalPages = (layoutList.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < layoutList.length) ? start + itemsPerPage : layoutList.length;
      List<dynamic> pageItems = layoutList.sublist(start, end);
      bool isLastPage = (pageNum == totalPages - 1);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (pw.Context context) => pw.Container(
          width: masterWidth,
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            // --- HEADER ---
            pw.Row(children: [
              _hBox(280, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text(shop.address, style: const pw.TextStyle(fontSize: 7.5), maxLines: 2),
                pw.Text("GSTIN: ${shop.gstin} | Mob: ${shop.phone}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text("DL: ${shop.dlNo} | Email: ${shop.email}", style: const pw.TextStyle(fontSize: 7)),
              ])),
              _hBox(175, true, pw.Column(children: [
                pw.Text("DEBIT NOTE", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)),
                pw.Divider(thickness: 0.5),
                pw.Text("Ref: ${ret.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy').format(ret.date), style: const pw.TextStyle(fontSize: 8)),
              ])),
              _hBox(345, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("SUPPLIER:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(supplier.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text("${supplier.address}, ${supplier.city}", style: const pw.TextStyle(fontSize: 7.5), maxLines: 2),
                pw.Text("GST: ${supplier.gst} | DL: ${supplier.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ])),
            ]),

            // --- TABLE (Rate = Purchase Rate Mapping) ---
            pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
              _tCol("S.N", 25), _tCol("Qty+Free", 60), _tCol("Pack", 40), 
              _tCol("Product Name", 220, isLeft: true), 
              _tCol("Batch", 75), _tCol("Exp", 45), _tCol("HSN", 45),
              _tCol("MRP", 55), _tCol("Pur.Rate", 55), 
              _tCol("GST%", 35),
              _tCol("Total", 145, isLast: true), 
            ])),

            pw.Expanded(child: pw.Column(children: pageItems.map((entry) {
              if (entry is String) {
                return pw.Container(width: masterWidth, padding: const pw.EdgeInsets.all(3), color: PdfColors.grey100, 
                child: pw.Text(entry, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)));
              }
              PurchaseItem i = entry as PurchaseItem;
              int idx = ret.items.indexOf(i) + 1;
              bool isShaded = config.useZebraShading && (idx % 2 != 0);

              return pw.Container(
                color: isShaded ? PdfColors.grey50 : PdfColors.white,
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))),
                child: pw.Row(children: [
                  _cell("$idx", 25), _cell("${fmt(i.qty)} + ${fmt(i.freeQty)}", 60), _cell(i.packing, 40),
                  pw.Container(width: 220, padding: const pw.EdgeInsets.only(left: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(i.name, style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.hsn, 45),
                  _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.purchaseRate.toStringAsFixed(2), 55),
                  _cell("${i.gstRate}%", 35),
                  _cell(i.total.toStringAsFixed(2), 145),
                ]),
              );
            }).toList())),

            if (isLastPage) _buildFooter(shop.name, ret)
          ]),
        )
      ));
    }
    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), format: PdfPageFormat.a4.landscape);
  }

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 105, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: 5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w) => pw.Container(width: w, height: 18, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildFooter(String shop, PurchaseReturn ret) {
    return pw.Container(height: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
      pw.Container(width: 480, padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("Amount In Words:", style: const pw.TextStyle(fontSize: 7)),
        pw.Text("RUPEES ${PdfMasterService.numberToWords(ret.totalAmount.round())} ONLY", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Spacer(),
        pw.Text("Supplier record updated. Physical stock removed.", style: const pw.TextStyle(fontSize: 6)),
      ])),
      pw.Expanded(child: pw.Column(children: [
        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("NET DEBIT AMT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("Rs. ${ret.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)),
        ])),
        pw.Spacer(),
        pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Text("For $shop", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)))),
      ])),
    ]));
  }
}
