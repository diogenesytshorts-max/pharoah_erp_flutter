// FILE: lib/pdf/architect_sale_pdf.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import '../logic/app_settings_model.dart';
import 'pdf_master_service.dart';

class ArchitectSalePdf {
  static Future<void> generate(Sale sale, Party party, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();

    // 📐 PRECISION MATH: Total Width 800 points for A4 Landscape
    const double masterWidth = 800;
    const int itemsPerPage = 20; // Safety limit per page
    int totalPages = (sale.items.length / itemsPerPage).ceil();

    // Pre-calculations for Footer
    double totalGross = sale.items.fold(0, (sum, i) => sum + (i.qty * i.rate));
    double totalSGST = sale.items.fold(0, (sum, i) => sum + i.sgst);
    double totalCGST = sale.items.fold(0, (sum, i) => sum + i.cgst);
    int roundedTotal = sale.totalAmount.round();

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < sale.items.length) ? start + itemsPerPage : sale.items.length;
      List<BillItem> pageItems = sale.items.sublist(start, end);
      bool isLastPage = (pageNum == totalPages - 1);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          build: (pw.Context context) {
            return pw.Container(
              width: masterWidth,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
              child: pw.Column(
                children: [
                  // --- HEADER SECTION (Total: 800) ---
                  pw.Row(children: [
                    _hBox(290, true, pw.Row(children: [
                      if (config.showLogo && config.logoPath != null && File(config.logoPath!).existsSync())
                        pw.Container(width: 50, height: 50, margin: const pw.EdgeInsets.only(right: 10), child: pw.Image(pw.MemoryImage(File(config.logoPath!).readAsBytesSync()))),
                      pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                        pw.Text("GST: ${shop.gstin} | DL: ${shop.dlNo}", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Phone: ${shop.phone}", style: const pw.TextStyle(fontSize: 7.5)),
                      ])),
                    ])),
                    _hBox(175, true, pw.Column(children: [
                      pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      pw.Text(sale.paymentMode, style: const pw.TextStyle(fontSize: 8)),
                      pw.Divider(thickness: 0.5),
                      pw.Text(sale.billNo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('dd/MM/yyyy').format(sale.date), style: const pw.TextStyle(fontSize: 8)),
                    ])),
                    _hBox(335, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("PARTY DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text(party.address, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                      pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ])),
                  ]),

                  // --- TABLE HEADER (Total: 800) ---
                  pw.Container(
                    color: PdfColors.grey100,
                    child: pw.Row(children: [
                      _tCol("S.N", 25), _tCol("Qty", 50), _tCol("Pack", 45), _tCol("Product Description", 250, isLeft: true),
                      _tCol("Batch", 70), _tCol("Exp", 40), _tCol("HSN", 40), _tCol("MRP", 50), _tCol("Rate", 50), 
                      _tCol("D%", 30), _tCol("SGST", 45), _tCol("CGST", 45), _tCol("NET", 60, isLast: true),
                    ]),
                  ),

                  // --- ITEMS AREA (Fixed height to prevent collapse) ---
                  pw.Container(
                    height: 320, // Isse items hamesha dikhenge
                    child: pw.Column(children: pageItems.asMap().entries.map((entry) {
                      int idx = entry.key; var i = entry.value;
                      bool isShaded = config.useZebraShading && (idx % 2 != 0);
                      return pw.Container(
                        color: isShaded ? PdfColors.grey50 : PdfColors.white,
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1, color: PdfColors.grey400))),
                        child: pw.Row(children: [
                          _cell("${start + idx + 1}", 25), _cell((i.qty + i.freeQty).toInt().toString(), 50), _cell(i.packing, 45),
                          pw.Container(width: 250, padding: const pw.EdgeInsets.only(left: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(i.name, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                          _cell(i.batch, 70), _cell(i.exp, 40), _cell(i.hsn, 40), _cell(i.mrp.toStringAsFixed(2), 50), _cell(i.rate.toStringAsFixed(2), 50),
                          _cell(i.discountRupees.toStringAsFixed(1), 30), _cell("${(i.gstRate / 2).toStringAsFixed(1)}%", 45), _cell("${(i.gstRate / 2).toStringAsFixed(1)}%", 45),
                          _cell(i.total.toStringAsFixed(2), 60),
                        ]),
                      );
                    }).toList()),
                  ),

                  // --- FOOTER (Only on Last Page) ---
                  if (isLastPage) _buildSmartFooter(shop.name, totalGross, totalSGST, totalCGST, roundedTotal, config)
                  else pw.Container(padding: const pw.EdgeInsets.all(10), alignment: pw.Alignment.centerRight, child: pw.Text("Continued on next page...", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 9))),
                ],
              ),
            );
          },
        ),
      );
    }

    // 🚀 THE FIX: Passing explicit landscape format to the printer
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(), 
      name: 'Bill_${sale.billNo}',
      format: PdfPageFormat.a4.landscape, 
    );
  }

  // --- UI BUILDING BLOCKS ---
  static pw.Widget _hBox(double w, bool border, pw.Widget child) => pw.Container(width: w, height: 90, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: border ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: isLeft ? 8 : 0), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w) => pw.Container(width: w, height: 16, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildSmartFooter(String shopName, double gross, double sgst, double cgst, int total, AppConfig config) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Box 1: Words, Bank & QR
        pw.Container(width: 340, padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("Amount in Words:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.Text("RUPEES ${PdfMasterService.numberToWords(total)} ONLY", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Spacer(),
          pw.Row(children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              if (config.bankAccNumber.isNotEmpty) ...[
                pw.Text("BANK: ${config.bankNameBranch}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.Text("A/C: ${config.bankAccNumber} | IFSC: ${config.bankIfsc}", style: const pw.TextStyle(fontSize: 7)),
              ],
              if (config.showTerms) pw.Text(config.termsAndConditions, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
            ])),
            if (config.showQrCode && config.qrCodePath != null && File(config.qrCodePath!).existsSync())
              pw.Container(width: 50, height: 50, child: pw.Image(pw.MemoryImage(File(config.qrCodePath!).readAsBytesSync()))),
          ])
        ])),
        // Box 2: Calculations
        pw.Container(width: 260, padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5))), child: pw.Column(children: [
          _fRow("GROSS TOTAL", gross), _fRow("TOTAL SGST", sgst), _fRow("TOTAL CGST", cgst),
          pw.Divider(thickness: 0.5),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("NET PAYABLE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text("Rs. $total.00", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ]),
        ])),
        // Box 3: Sign
        pw.Container(width: 200, height: 100, padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("For $shopName", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          if (config.showStaffSign) pw.Text(config.signLabel, style: const pw.TextStyle(fontSize: 7.5)),
        ])),
      ],
    );
  }

  static pw.Widget _fRow(String l, double v) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 7.5)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))]);
}
