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

    // 📐 PRECISION MATH: 800 points total width (A4 Landscape)
    const double masterWidth = 800;

    // Totals for calculation
    double totalGross = sale.items.fold(0, (sum, i) => sum + (i.qty * i.rate));
    double totalSGST = sale.items.fold(0, (sum, i) => sum + i.sgst);
    double totalCGST = sale.items.fold(0, (sum, i) => sum + i.cgst);
    int roundedTotal = sale.totalAmount.round();

    const int itemsPerPage = 20; 
    int totalPages = (sale.items.length / itemsPerPage).ceil();

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < sale.items.length) ? start + itemsPerPage : sale.items.length;
      List<BillItem> pageItems = sale.items.sublist(start, end);
      bool isLastPage = (pageNum == totalPages - 1);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.symmetric(horizontal: 21, vertical: 15),
          build: (pw.Context context) {
            return pw.Container(
              width: masterWidth,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.2, color: PdfColors.black)),
              child: pw.Column(
                children: [
                  // --- 1. PREMIUM HEADER (Total: 800) ---
                  pw.Row(children: [
                    // SHOP & LOGO BOX (290 pts)
                    _headerBox(290, true, pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (config.showLogo && config.logoPath != null && File(config.logoPath!).existsSync())
                          pw.Container(
                            width: 50, height: 50, margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(pw.MemoryImage(File(config.logoPath!).readAsBytesSync())),
                          ),
                        pw.Expanded(child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                            pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                            pw.Text("GST: ${shop.gstin} | DL: ${shop.dlNo}", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                            pw.Text("Phone: ${shop.phone}", style: const pw.TextStyle(fontSize: 7.5)),
                          ],
                        )),
                      ],
                    )),
                    // INV INFO BOX (175 pts)
                    _headerBox(175, true, pw.Column(children: [
                      pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(thickness: 0.5),
                      pw.Text(sale.billNo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 8)),
                      pw.Text("Page ${pageNum + 1} of $totalPages", style: const pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey)),
                    ])),
                    // PARTY BOX (335 pts)
                    _headerBox(335, false, pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text("PARTY DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
                        pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ],
                    )),
                  ]),

                  // --- 2. PRECISION TABLE HEADER (Total: 800) ---
                  pw.Container(
                    color: PdfColors.grey100,
                    child: pw.Row(children: [
                      _tCol("S.N", 25), _tCol("Qty", 55), _tCol("Pack", 45),
                      _tCol("PRODUCT DESCRIPTION", 205, isLeft: true), 
                      _tCol("Batch", 75), _tCol("Exp", 45), _tCol("HSN", 45),
                      _tCol("MRP", 55), _tCol("Rate", 55), _tCol("D%", 30),
                      _tCol("SGST%", 50), _tCol("CGST%", 50), 
                      _tCol("NET AMT", 65, isLast: true), 
                    ]),
                  ),

                  // --- 3. DYNAMIC DATA ROWS (With Zebra Shading) ---
                  pw.Expanded(
                    child: pw.Column(children: pageItems.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var i = entry.value;
                      bool isShaded = config.useZebraShading && (idx % 2 != 0);
                      return pw.Container(
                        color: isShaded ? PdfColors.grey50 : PdfColors.white,
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1, color: PdfColors.grey400))),
                        child: pw.Row(children: [
                          _cell("${start + idx + 1}", 25), 
                          _cell((i.qty + i.freeQty).toInt().toString(), 55), 
                          _cell(i.packing, 45),
                          pw.Container(width: 205, padding: const pw.EdgeInsets.only(left: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(i.name, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                          _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.hsn, 45),
                          _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.rate.toStringAsFixed(2), 55),
                          _cell(i.discountRupees.toStringAsFixed(1), 30),
                          _cell("${(i.gstRate / 2).toStringAsFixed(1)}%", 50), 
                          _cell("${(i.gstRate / 2).toStringAsFixed(1)}%", 50),
                          _cell(i.total.toStringAsFixed(2), 65),
                        ]),
                      );
                    }).toList()),
                  ),

                  // --- 4. SMART CONNECTED FOOTER ---
                  if (isLastPage) _buildSmartFooter(shop.name, sale, totalGross, totalSGST, totalCGST, roundedTotal, config)
                  else pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Continued...", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 8))),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Bill_Architect_${sale.billNo}');
  }

  // --- UI ATOMS ---
  static pw.Widget _headerBox(double w, bool rBorder, pw.Widget child) => pw.Container(width: w, height: 100, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: rBorder ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 25, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: isLeft ? 8 : 0), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w) => pw.Container(width: w, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  // --- THE SMART FOOTER ---
  static pw.Widget _buildSmartFooter(String shopName, Sale sale, double gross, double sgst, double cgst, int total, AppConfig config) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // BOX 1: Words, Bank & QR (340 pts)
        pw.Container(
          width: 340, padding: const pw.EdgeInsets.all(8), 
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5))), 
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
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
          ]),
        ),
        // BOX 2: Calculations (260 pts)
        pw.Container(
          width: 260, padding: const pw.EdgeInsets.all(8), 
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5))), 
          child: pw.Column(children: [
            _fRow("GROSS TOTAL", gross), _fRow("TOTAL SGST", sgst), _fRow("TOTAL CGST", cgst),
            pw.Divider(thickness: 0.5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("NET AMOUNT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text("Rs. $total.00", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ]),
          ]),
        ),
        // BOX 3: Signature (200 pts)
        pw.Container(
          width: 200, height: 100, padding: const pw.EdgeInsets.all(8), 
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), 
          child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("For $shopName", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            if (config.showStaffSign) pw.Text(config.signLabel, style: const pw.TextStyle(fontSize: 7.5)),
          ]),
        ),
      ],
    );
  }

  static pw.Widget _fRow(String l, double v) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 7.5)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))]);
}
