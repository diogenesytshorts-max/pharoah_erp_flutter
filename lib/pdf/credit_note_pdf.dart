// FILE: lib/pdf/credit_note_pdf.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import '../logic/app_settings_model.dart';
import 'pdf_master_service.dart';

class CreditNotePdf {
  static Future<void> generate(SaleReturn ret, Party party, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();
    const double masterWidth = 800; 
    const int itemsPerPage = 20;

    // Formatting Helper: Removes unnecessary .0 decimals
    String fmt(double v) => v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1);
    bool isLocal = shop.state.trim().toLowerCase() == party.state.trim().toLowerCase();

    // Logic: Categorize for Display
    final sellable = ret.items.where((i) => i.isBreakage == false).toList();
    final breakage = ret.items.where((i) => i.isBreakage == true).toList();

    List<dynamic> layoutList = [];
    if (sellable.isNotEmpty) {
      layoutList.add(">> SALES RETURN (SELLABLE STOCK)");
      layoutList.addAll(sellable);
    }
    if (breakage.isNotEmpty) {
      layoutList.add(">> BREAKAGE & EXPIRY (NON-SELLABLE)");
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
            // --- BOX HEADER (800pt FIXED GRID) ---
            pw.Row(children: [
              _hBox(280, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text(shop.address, style: const pw.TextStyle(fontSize: 7.5), maxLines: 2),
                pw.Text("GSTIN: ${shop.gstin} | DL: ${shop.dlNo}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text("Mob: ${shop.phone} | Email: ${shop.email}", style: const pw.TextStyle(fontSize: 7)),
              ])),
              _hBox(175, true, pw.Column(children: [
                pw.Text("CREDIT NOTE", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                pw.Divider(thickness: 0.5),
                pw.Text("No: ${ret.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy').format(ret.date), style: const pw.TextStyle(fontSize: 8)),
              ])),
              _hBox(345, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("CONSIGNEE:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(party.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text("${party.address}, ${party.city}", style: const pw.TextStyle(fontSize: 7.5), maxLines: 2),
                pw.Text("GST: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text("Mob: ${party.phone}", style: const pw.TextStyle(fontSize: 7.5)),
              ])),
            ]),

            // --- TABLE HEADER ---
            pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
              _tCol("S.N", 25), _tCol("Qty+Free", 60), _tCol("Pack", 40), 
              _tCol("Description", 220, isLeft: true), 
              _tCol("Batch", 75), _tCol("Exp", 45), _tCol("HSN", 45),
              _tCol("MRP", 55), _tCol("Rate", 55), 
              _tCol("CGST", 40), _tCol("SGST", 40),
              _tCol("Net Amt", 100, isLast: true), 
            ])),

            // --- DATA ROWS ---
            pw.Expanded(child: pw.Column(children: pageItems.map((entry) {
              if (row is String) {
                 return pw.Container(width: masterWidth, padding: const pw.EdgeInsets.all(3), color: PdfColors.grey100, 
                 child: pw.Text(entry, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: entry.contains("BREAKAGE") ? PdfColors.red900 : PdfColors.blue900)));
              }
              BillItem i = entry as BillItem;
              int sNo = ret.items.indexOf(i) + 1;
              bool isShaded = config.useZebraShading && (sNo % 2 != 0);

              return pw.Container(
                color: isShaded ? PdfColors.grey50 : PdfColors.white,
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1, color: PdfColors.grey400))),
                child: pw.Row(children: [
                  _cell("$sNo", 25), _cell("${fmt(i.qty)} + ${fmt(i.freeQty)}", 60), _cell(i.packing, 40),
                  pw.Container(width: 220, padding: const pw.EdgeInsets.only(left: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(i.name, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.hsn, 45),
                  _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.rate.toStringAsFixed(2), 55),
                  _cell("${(i.gstRate / 2)}%", 40), _cell("${(i.gstRate / 2)}%", 40),
                  _cell(i.total.toStringAsFixed(2), 100),
                ]),
              );
            }).toList())),

            if (isLastPage) _buildFooter(shop.name, ret, isLocal)
            else pw.Container(height: 30, alignment: pw.Alignment.centerRight, child: pw.Text("Next Page...", style: const pw.TextStyle(fontSize: 8))),
          ]),
        )
      ));
    }
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "CN_${ret.billNo}", format: PdfPageFormat.a4.landscape);
  }

  // Same Private Helpers as Sale Invoice
  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 105, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: 5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w) => pw.Container(width: w, height: 18, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildFooter(String name, SaleReturn ret, bool isLocal) {
    double taxableTotal = ret.items.fold(0, (sum, i) => sum + (i.rate * i.qty));
    double tax = ret.totalAmount - taxableTotal;
    return pw.Container(height: 110, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
      pw.Container(width: 330, padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("Amount in Words:", style: const pw.TextStyle(fontSize: 7)),
        pw.Text("RUPEES ${PdfMasterService.numberToWords(ret.totalAmount.round())} ONLY", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        pw.Spacer(),
        pw.Text("Credit Account Updated Successfully.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ])),
      pw.Container(width: 250, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(children: [
        _fRow("TAXABLE VAL", taxableTotal),
        if (isLocal) ...[_fRow("CGST TOTAL", tax / 2), _fRow("SGST TOTAL", tax / 2)] else _fRow("IGST TOTAL", tax),
        pw.Divider(thickness: 0.5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("NET CREDIT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("Rs. ${ret.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ]),
      ])),
      pw.Container(width: 220, padding: const pw.EdgeInsets.all(8), child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text("For $name", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 7)),
      ])),
    ]));
  }
  static pw.Widget _fRow(String l, double v) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 7.5)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))]);
}
