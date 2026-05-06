// FILE: lib/pdf/sale_challan_pdf.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';

class SaleChallanPdf {
  static const int itemsPerPage = 15;

  static Future<void> generate(SaleChallan challan, Party party, CompanyProfile shop) async {
    final bytes = await generateBytes(challan, party, shop);
    await Printing.layoutPdf(onLayout: (format) async => bytes, name: 'Challan_${challan.billNo}', format: PdfPageFormat.a4.landscape);
  }

  static Future<Uint8List> generateBytes(SaleChallan challan, Party party, CompanyProfile shop) async {
    final pdf = pw.Document();
    int totalPages = (challan.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    pw.MemoryImage? sigImage;
    ChallanSignature? lastSig;
    if (challan.isSigned && challan.sigHistory.isNotEmpty) {
      lastSig = challan.sigHistory.last;
      if (File(lastSig.imagePath).existsSync()) {
        sigImage = pw.MemoryImage(File(lastSig.imagePath).readAsBytesSync());
      }
    }

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < challan.items.length) ? start + itemsPerPage : challan.items.length;
      List<BillItem> pageItems = challan.items.sublist(start, end);
      bool isLastPage = (pageNum == totalPages - 1);

      pdf.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.all(20),
          build: (context) => pw.Stack(children: [
            pw.Column(children: [
              // --- HEADER SECTION ---
              pw.Row(children: [
                _hBox(280, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("GSTIN: ${shop.gstin}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
                _hBox(170, true, pw.Column(children: [
                  pw.Text("DELIVERY CHALLAN", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  pw.Divider(thickness: 0.5),
                  pw.Text("Challan No: ${challan.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(challan.date)}", style: const pw.TextStyle(fontSize: 8)),
                ])),
                _hBox(330, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("CONSIGNEE DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text("${party.city} | GSTIN: ${party.gst}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
              ]),

              // --- 11 COLUMNS TABLE HEADER ---
              pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
                _tCol("S.N", 25), _tCol("Qty+Free", 50), _tCol("Pack", 40), _tCol("Product Description", 200, isLeft: true), 
                _tCol("Batch", 75), _tCol("Exp", 45), _tCol("HSN", 45), _tCol("MRP", 55), 
                _tCol("Rate", 55), _tCol("GST%", 35), _tCol("Net Total", 155, isLast: true), 
              ])),

              // --- DYNAMIC ITEM ROWS ---
              pw.Expanded(child: pw.Column(children: pageItems.asMap().entries.map((entry) {
                int idx = entry.key; var i = entry.value;
                int sn = start + idx + 1;
                return pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1, color: PdfColors.grey400))), child: pw.Row(children: [
                  _cell("$sn", 25), _cell("${i.qty.toInt()} + ${i.freeQty.toInt()}", 50), _cell(i.packing, 40), 
                  _cell(i.name, 200, isLeft: true), _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.hsn, 45), 
                  _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.rate.toStringAsFixed(2), 55), _cell("${i.gstRate.toInt()}%", 35), 
                  _cell(i.total.toStringAsFixed(2), 155),
                ]));
              }).toList())),

              // --- FOOTER SECTION ---
              if (isLastPage) _buildFinalFooter(shop.name, challan.totalAmount, challan.remarks, lastSig)
              else pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Continued on next page...", style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))),
            ]),
            
            // SIGNATURE PLACEMENT (Scaling the full screen sign to the box)
            if (isLastPage && sigImage != null)
               pw.Positioned(bottom: 30, left: 25, child: pw.Image(sigImage, width: 220, height: 80)),

            // Watermark
            if (challan.isSigned)
               pw.Center(child: pw.Opacity(opacity: 0.05, child: pw.Transform.rotate(angle: -0.5, child: pw.Text(challan.sigHistory.last.verificationCode, style: pw.TextStyle(fontSize: 100, fontWeight: pw.FontWeight.bold, color: PdfColors.red900))))),
          ]),
      ));
    }
    return pdf.save();
  }

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 80, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: 5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w, {bool isLeft = false}) => pw.Container(width: w, height: 18, padding: const pw.EdgeInsets.symmetric(horizontal: 4), alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildFinalFooter(String n, double t, String r, ChallanSignature? s) => pw.Container(height: 110, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
      // BOX 1: RECEIVER AREA
      pw.Container(width: 480, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (s != null) ...[
          pw.Text("DIGITAL SEAL: ${s.verificationCode}", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
          pw.SizedBox(height: 50), // Gap for actual signature image
          pw.Text("RECEIVER SIGNATURE & STAMP", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Spacer(),
          pw.Text("SECURE DOCUMENT NOTICE: The unique Digital Seal above is tied to the quantities listed. Post-signing modifications by the issuer will invalidate this seal.", style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic)),
        ],
      ])),
      // BOX 2: TOTALS & AUTH AREA
      pw.Container(width: 320, padding: const pw.EdgeInsets.all(5), child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("GRAND TOTAL VALUE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("Rs. ${t.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))
        ]),
        pw.SizedBox(height: 10),
        pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text("REMARKS: ${r.isEmpty ? 'N/A' : r}", style: const pw.TextStyle(fontSize: 7))),
        pw.Spacer(), 
        pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text("For $n", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 25),
          pw.Text("AUTHORISED SIGNATORY", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700))
        ]))
      ])),
  ]));
}
