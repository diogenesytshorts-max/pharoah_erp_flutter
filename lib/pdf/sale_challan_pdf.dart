// FILE: lib/pdf/sale_challan_pdf.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

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
              // Header
              pw.Row(children: [
                _hBox(280, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("GST: ${shop.gstin}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
                _hBox(170, true, pw.Column(children: [
                  pw.Text("DELIVERY CHALLAN", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                  pw.Divider(thickness: 0.5),
                  pw.Text("No: ${challan.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(challan.date)}", style: const pw.TextStyle(fontSize: 8)),
                ])),
                _hBox(330, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("CONSIGNEE:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text("GSTIN: ${party.gst} | City: ${party.city}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
              ]),
              // Table
              pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
                _tCol("S.N", 30), _tCol("Item Description", 320, isLeft: true), _tCol("Batch", 90), _tCol("Exp", 60), _tCol("Qty", 60), _tCol("MRP", 70), _tCol("Net Total", 150, isLast: true),
              ])),
              pw.Expanded(child: pw.Column(children: pageItems.map((i) => pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))),
                child: pw.Row(children: [
                  _cell("${i.srNo}", 30), _cell(i.name, 320, isLeft: true), _cell(i.batch, 90), _cell(i.exp, 60), _cell(i.qty.toInt().toString(), 60), _cell(i.mrp.toStringAsFixed(2), 70), _cell(i.total.toStringAsFixed(2), 150),
                ])
              )).toList())),
              // Footer
              if (isLastPage) _buildFooter(shop.name, challan.totalAmount, challan.remarks, lastSig)
              else pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Continued...", style: const pw.TextStyle(fontSize: 10))),
            ]),
            
            // SIGNATURE PLACEMENT
            if (isLastPage && sigImage != null)
               pw.Positioned(bottom: 45, left: 30, child: pw.Image(sigImage, width: 140)),

            // Watermark
            if (challan.isSigned)
               pw.Center(child: pw.Opacity(opacity: 0.08, child: pw.Transform.rotate(angle: -0.5, child: pw.Text(challan.sigHistory.last.verificationCode, style: pw.TextStyle(fontSize: 70, fontWeight: pw.FontWeight.bold, color: PdfColors.red900))))),
          ]),
      ));
    }
    return pdf.save();
  }

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 80, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: 5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w, {bool isLeft = false}) => pw.Container(width: w, height: 18, padding: const pw.EdgeInsets.symmetric(horizontal: 5), alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
  
  static pw.Widget _buildFooter(String n, double t, String r, ChallanSignature? sig) => pw.Container(height: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
    pw.Container(width: 480, padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      if (sig != null) pw.Text("DIGITAL SEAL: ${sig.verificationCode}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
      pw.SizedBox(height: 40), // FIXED: SizedBox changed to pw.SizedBox
      pw.Text("RECEIVER SIGNATURE", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
      pw.Spacer(), 
      pw.Text("REMARKS: ${r.isEmpty ? 'N/A' : r}", style: const pw.TextStyle(fontSize: 7)),
    ])),
    pw.Container(width: 320, padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("TOTAL VALUE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text("Rs. ${t.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold))]),
      pw.Spacer(), 
      pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Column(children: [
        pw.Text("For $n", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 35), // FIXED: SizedBox changed to pw.SizedBox
        pw.Text("AUTHORISED SIGNATORY", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      ])),
    ])),
  ]));
}
