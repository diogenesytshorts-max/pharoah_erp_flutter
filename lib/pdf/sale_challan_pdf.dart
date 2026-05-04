// FILE: lib/pdf/sale_challan_pdf.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class SaleChallanPdf {
  static Future<void> generate(SaleChallan challan, Party party, CompanyProfile shop) async {
    final pdf = pw.Document();

    const double masterWidth = 800; // Fixed Width to fill page
    const double pageHeightLimit = 550;
    const int itemsPerPage = 20; 
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

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.all(15),
          build: (pw.Context context) {
            return pw.Container(
              width: masterWidth,
              height: pageHeightLimit,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
              child: pw.Stack(children: [
                
                pw.Column(children: [
                  // --- HEADER (Exact 800 Width) ---
                  pw.Row(children: [
                    _hBox(290, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                      pw.Text("GST: ${shop.gstin} | DL: ${shop.dlNo}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ])),
                    _hBox(175, true, pw.Column(children: [
                      pw.Text("DELIVERY CHALLAN", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      pw.Divider(thickness: 0.5),
                      pw.Text("No: ${challan.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(challan.date)}", style: const pw.TextStyle(fontSize: 8.5)),
                    ])),
                    _hBox(335, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("CONSIGNEE DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text("GSTIN: ${party.gst} | City: ${party.city}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ])),
                  ]),

                  // --- TABLE HEADER (11 COLUMNS - Total 800) ---
                  pw.Container(
                    color: PdfColors.grey200,
                    child: pw.Row(children: [
                      _tCol("S.N", 25), _tCol("Qty+Free", 55), _tCol("Pack", 45),
                      _tCol("Product Description", 210, isLeft: true), 
                      _tCol("Batch", 75), _tCol("Exp", 45), _tCol("HSN", 50),
                      _tCol("MRP", 55), _tCol("Rate", 55), _tCol("GST%", 30),
                      _tCol("Net Amount", 155, isLast: true), 
                    ]),
                  ),

                  // --- ROWS ---
                  pw.Expanded(
                    child: pw.Column(children: pageItems.map((i) {
                      return pw.Container(
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1, color: PdfColors.grey400))),
                        child: pw.Row(children: [
                          _cell("${challan.items.indexOf(i) + 1}", 25), 
                          _cell("${i.qty.toInt()} + ${i.freeQty.toInt()}", 55), 
                          _cell(i.packing, 45),
                          _cell(i.name, 210, isLeft: true),
                          _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.hsn, 50),
                          _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.rate.toStringAsFixed(2), 55),
                          _cell("${i.gstRate.toInt()}%", 30),
                          _cell(i.total.toStringAsFixed(2), 155),
                        ]),
                      );
                    }).toList()),
                  ),

                  if (isLastPage) 
                    _buildFinalFooter(shop.name, challan.totalAmount, challan.remarks, lastSig)
                  else 
                    _buildIntermediateFooter(pageNum + 1, lastSig),
                ]),

                if (lastSig != null)
                  pw.Center(child: pw.Opacity(opacity: 0.1, child: pw.Transform.rotate(angle: -0.5, child: pw.Text(lastSig.verificationCode, style: pw.TextStyle(fontSize: 70, fontWeight: pw.FontWeight.bold, color: PdfColors.red900))))),

                if (isLastPage && sigImage != null && lastSig != null)
                  pw.Positioned(
                    left: (lastSig.signX * masterWidth) - 60, 
                    top: (lastSig.signY * pageHeightLimit) - 30,
                    child: pw.Image(sigImage, width: 120),
                  ),
              ]),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Challan_${challan.billNo}', format: PdfPageFormat.a4.landscape);
  }

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 85, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: 5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w, {bool isLeft = false}) => pw.Container(width: w, height: 18, padding: const pw.EdgeInsets.symmetric(horizontal: 4), alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));
  static pw.Widget _buildIntermediateFooter(int pageNum, ChallanSignature? sig) => pw.Container(height: 60, padding: const pw.EdgeInsets.symmetric(horizontal: 10), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [if (sig != null) _buildSecurityMessage(sig.verificationCode), pw.Text("Continued to Page ${pageNum + 1}...", style: pw.TextStyle(fontSize: 9, fontStyle: pw.FontStyle.italic))]));
  static pw.Widget _buildFinalFooter(String shopName, double total, String remarks, ChallanSignature? sig) => pw.Container(height: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
      pw.Container(width: 480, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [if (sig != null) _buildSecurityMessage(sig.verificationCode), pw.SizedBox(height: 5), pw.Text("REMARKS: ${remarks.isEmpty ? 'Condition verified.' : remarks}", style: const pw.TextStyle(fontSize: 7.5)), pw.Spacer(), pw.Text("Note: This is a digitally verified delivery challan.", style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700))])),
      pw.Container(width: 320, padding: const pw.EdgeInsets.all(5), child: pw.Column(children: [pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("GRAND TOTAL VALUE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text("Rs. ${total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold))]), pw.Spacer(), pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Column(children: [pw.Text("For $shopName", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.SizedBox(height: 10), pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 7))]))]))]));
  static pw.Widget _buildSecurityMessage(String code) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text("DIGITAL SEAL: $code", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)), pw.SizedBox(width: 320, child: pw.Text("SECURITY NOTICE: This document is locked with code $code. Any unauthorized modification will permanently invalidate this digital seal.", style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700)))]);
}
