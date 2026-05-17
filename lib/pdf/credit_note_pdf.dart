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
    if (config.isArchitectMode) {
      await _generateArchitect(ret, party, shop, config);
    } else {
      await _generateStandard(ret, party, shop, config);
    }
  }

  // ===========================================================================
  // 🏛️ ARCHITECT FORMAT (LANDSCAPE 800PT) - THE EJECT MIRROR
  // ===========================================================================
  static Future<void> _generateArchitect(SaleReturn ret, Party party, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();
    const double masterWidth = 800;
    const int itemsPerPage = 18;
    bool isLocal = shop.state.trim().toLowerCase() == party.state.trim().toLowerCase();

    // Grouping Logic
    final sellable = ret.items.where((i) => i.isBreakage == false).toList();
    final breakage = ret.items.where((i) => i.isBreakage == true).toList();

    List<dynamic> combinedList = [];
    if (sellable.isNotEmpty) { combinedList.add(">> SALES RETURN (SELLABLE STOCK)"); combinedList.addAll(sellable); }
    if (breakage.isNotEmpty) { combinedList.add(">> BREAKAGE & EXPIRY (NON-SELLABLE)"); combinedList.addAll(breakage); }

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
            // --- HEADER ---
            pw.Row(children: [
              _hBox(280, true, pw.Row(children: [
                if (config.showLogo && config.logoPath != null && File(config.logoPath!).existsSync())
                  pw.Container(width: 40, height: 40, margin: const pw.EdgeInsets.only(right: 5), child: pw.Image(pw.MemoryImage(File(config.logoPath!).readAsBytesSync()))),
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(shop.address, style: const pw.TextStyle(fontSize: 7), maxLines: 2),
                  pw.Text("GSTIN: ${shop.gstin}", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                ])),
              ])),
              _hBox(175, true, pw.Column(children: [
                pw.Text("CREDIT NOTE", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                pw.Divider(thickness: 0.5),
                pw.Text(ret.billNo, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy').format(ret.date), style: const pw.TextStyle(fontSize: 8)),
              ])),
              _hBox(345, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("CONSIGNEE DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                pw.Text(party.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text("GST: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ])),
            ]),
            // --- TABLE ---
            pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
              _tCol("S.N", 25), _tCol("Qty+Free", 50), _tCol("Pack", 40), _tCol("Description", 210, isLeft: true), _tCol("Batch", 70), _tCol("Exp", 45), _tCol("MRP", 55), _tCol("Rate", 55), _tCol("CGST", 40), _tCol("SGST", 40), _tCol("Net Total", 125, isLast: true), 
            ])),
            pw.Expanded(child: pw.Column(children: pageContent.map((row) {
              if (row is String) return _sectionHeaderRow(row, masterWidth);
              BillItem i = row as BillItem;
              int idx = ret.items.indexOf(i);
              bool isShaded = config.useZebraShading && (idx % 2 != 0);
              return pw.Container(color: isShaded ? PdfColors.grey50 : PdfColors.white, child: pw.Row(children: [
                  _cell("${idx+1}", 25), _cell("${i.qty.toInt()}+${i.freeQty.toInt()}", 50), _cell(i.packing, 40),
                  pw.Container(width: 210, padding: const pw.EdgeInsets.only(left: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(i.name, style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  _cell(i.batch, 70), _cell(i.exp, 45), _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.rate.toStringAsFixed(2), 55), _cell("${(i.gstRate/2)}%", 40), _cell("${(i.gstRate/2)}%", 40), _cell(i.total.toStringAsFixed(2), 125),
              ]));
            }).toList())),
            if (isLastPage) _buildArchitectFooter(shop.name, ret, isLocal)
          ]),
        )
      ));
    }
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), format: PdfPageFormat.a4.landscape);
  }

  // ===========================================================================
  // 📄 STANDARD FORMAT (PORTAL PORTRAIT)
  // ===========================================================================
  static Future<void> _generateStandard(SaleReturn ret, Party party, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      header: (context) => pw.Header(child: pw.Text("CREDIT NOTE - ${shop.name}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))),
      build: (context) => [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text("Return No: ${ret.billNo}"), pw.Text("Date: ${DateFormat('dd/MM/yy').format(ret.date)}")]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [pw.Text("Party: ${party.name}"), pw.Text("GST: ${party.gst}")]),
        ]),
        pw.SizedBox(height: 20),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headers: ['S.N', 'Item Name', 'Batch', 'Qty', 'Rate', 'Total'],
          data: ret.items.asMap().entries.map((e) => ["${e.key+1}", e.value.name, e.value.batch, e.value.qty.toInt().toString(), e.value.rate.toStringAsFixed(2), e.value.total.toStringAsFixed(2)]).toList(),
        ),
        pw.Divider(),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("GRAND TOTAL: Rs. ${ret.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save());
  }

  // --- HELPERS ---
  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 105, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 18, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: 5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w) => pw.Container(width: w, height: 18, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));
  static pw.Widget _sectionHeaderRow(String text, double w) => pw.Container(width: w, padding: const pw.EdgeInsets.all(3), color: PdfColors.grey100, child: pw.Text(text, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: text.contains("BREAKAGE") ? PdfColors.red900 : PdfColors.blue900)));

  static pw.Widget _buildArchitectFooter(String n, SaleReturn ret, bool isLocal) {
    double taxable = ret.items.fold(0, (sum, i) => sum + (i.rate * i.qty));
    double tax = ret.totalAmount - taxable;
    return pw.Container(height: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
      pw.Container(width: 320, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("RUPEES ${PdfMasterService.numberToWords(ret.totalAmount.round())} ONLY", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        pw.Spacer(),
        pw.Text("Document: System Generated Sales Credit Note.", style: const pw.TextStyle(fontSize: 6)),
      ])),
      pw.Container(width: 250, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(children: [
        _fRow("TAXABLE", taxable),
        if(isLocal) ...[ _fRow("CGST", tax/2), _fRow("SGST", tax/2) ] else _fRow("IGST", tax),
        pw.Divider(thickness: 0.5),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("NET CREDIT", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text("Rs. ${ret.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900))]),
      ])),
      pw.Container(width: 230, padding: const pw.EdgeInsets.all(10), child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("For $n", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 7))])),
    ]));
  }
  static pw.Widget _fRow(String l, double v) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 7.5)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))]);
}
