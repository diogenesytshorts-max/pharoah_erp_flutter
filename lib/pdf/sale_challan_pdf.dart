// FILE: lib/pdf/sale_challan_pdf.dart

import 'dart:io'; // NAYA: Signature file read karne ke liye
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

    const double masterWidth = 800;
    const double pageHeightLimit = 550;
    const int itemsPerPage = 18; 
    int totalPages = (challan.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    // --- NAYA: Signature Image taiyar karna (Agar signed hai) ---
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
                
                // --- LAYER 1: BASE CONTENT (Header + Table + Footer) ---
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
                      pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(challan.date)}", style: const pw.TextStyle(fontSize: 8.5)),
                    ])),
                    _hBox(330, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("CONSIGNEE DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                      pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text("GSTIN: ${party.gst} | City: ${party.city}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ])),
                  ]),

                  // Table
                  pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
                    _tCol("S.N", 30), _tCol("Product Description", 300, isLeft: true), _tCol("Packing", 60),
                    _tCol("Batch", 90), _tCol("Expiry", 60), _tCol("Qty", 60), _tCol("Rate", 100), _tCol("Total", 100, isLast: true),
                  ])),

                  pw.Container(height: 320, child: pw.Column(children: pageItems.map((i) {
                    return pw.Container(
                      decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))),
                      child: pw.Row(children: [
                        _cell("${challan.items.indexOf(i) + 1}", 30), _cell(i.name, 300, isLeft: true), _cell(i.packing, 60),
                        _cell(i.batch, 90), _cell(i.exp, 60), _cell(i.qty.toInt().toString(), 60),
                        _cell(i.rate.toStringAsFixed(2), 100), _cell(i.total.toStringAsFixed(2), 100),
                      ]),
                    );
                  }).toList())),

                  // --- NAYA: DYNAMIC FOOTER LOGIC ---
                  if (isLastPage) 
                    _buildFinalFooter(shop.name, challan.totalAmount, challan.remarks, lastSig)
                  else 
                    _buildIntermediateFooter(pageNum + 1, lastSig),
                ]),

                // --- LAYER 2: SECURITY WATERMARK (Har Page Par) ---
                if (lastSig != null)
                  pw.Center(
                    child: pw.Opacity(
                      opacity: 0.1,
                      child: pw.Transform.rotate(
                        angle: -0.5,
                        child: pw.Text(lastSig.verificationCode, style: pw.TextStyle(fontSize: 60, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
                      ),
                    ),
                  ),

                // --- LAYER 3: SIGNATURE INJECTION (Sirf Last Page Par) ---
                if (isLastPage && sigImage != null && lastSig != null)
                  pw.Positioned(
                    // Mapping coordinates from screen % to PDF points
                    left: lastSig.signX * masterWidth - 50, 
                    top: lastSig.signY * pageHeightLimit - 25,
                    child: pw.Image(sigImage, width: 120), // Standard Size signature
                  ),
              ]),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Challan_${challan.billNo}', format: PdfPageFormat.a4.landscape);
  }

  // --- UI ATOMS ---
  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 80, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: isLeft ? 8 : 0), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w, {bool isLeft = false}) => pw.Container(width: w, height: 18, padding: const pw.EdgeInsets.symmetric(horizontal: 5), alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));

  // --- NAYA: INTERMEDIATE FOOTER (Page 1, 2...) ---
  static pw.Widget _buildIntermediateFooter(int pageNum, ChallanSignature? sig) {
    return pw.Container(
      height: 100, 
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        if (sig != null) _buildSecurityMessage(sig.verificationCode),
        pw.Text("Continued to Page ${pageNum + 1}...", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
      ])
    );
  }

  // --- NAYA: FINAL FOOTER (Last Page) ---
  static pw.Widget _buildFinalFooter(String shopName, double total, String remarks, ChallanSignature? sig) {
    return pw.Container(height: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
      pw.Container(width: 480, padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        if (sig != null) _buildSecurityMessage(sig.verificationCode),
        pw.SizedBox(height: 5),
        pw.Text("REMARKS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        pw.Text(remarks.isEmpty ? "Goods delivered as per order." : remarks, style: const pw.TextStyle(fontSize: 8)),
        pw.Spacer(),
        pw.Text("Note: This is a Delivery Challan, not a Tax Invoice.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ])),
      pw.Container(width: 320, padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("TOTAL VALUE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("Rs. ${total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Spacer(),
        pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Column(children: [
          pw.Text("For $shopName", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 7)),
        ])),
      ])),
    ]));
  }

  // --- NAYA: SECURITY MESSAGE (Disclaimer) ---
  static pw.Widget _buildSecurityMessage(String code) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text("DIGITAL SEAL: $code", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
      pw.SizedBox(width: 200, child: pw.Text("SECURITY NOTICE: This document is locked with code $code. Any unauthorized modification to this record will permanently invalidate this digital seal.", style: const pw.TextStyle(fontSize: 5, color: PdfColors.grey700))),
    ]);
  }
}
