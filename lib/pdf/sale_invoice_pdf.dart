// FILE: lib/pdf/sale_invoice_pdf.dart

import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class SaleInvoicePdf {
  // --- ACTION 1: DIRECT PRINT ---
  static Future<void> generate(Sale sale, Party party, CompanyProfile shop) async {
    final bytes = await generateBytes(sale, party, shop);
    await Printing.layoutPdf(
      onLayout: (format) async => bytes,
      name: 'Invoice_${sale.billNo}',
      format: PdfPageFormat.a4.landscape, // 🚀 FORCED LANDSCAPE
    );
  }

  // --- ACTION 2: GENERATE BYTES (Required for Router & ZIP) ---
  static Future<Uint8List> generateBytes(Sale sale, Party party, CompanyProfile shop) async {
    final pdf = pw.Document();

    // 📐 PRECISION MATH (Total: 800)
    const double masterWidth = 800;
    const double pageHeightLimit = 550;
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
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          build: (pw.Context context) {
            return pw.Container(
              width: masterWidth,
              height: pageHeightLimit,
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1, color: PdfColors.black)),
              child: pw.Column(
                children: [
                  // --- 1. HEADER SECTION (Total: 290 + 175 + 335 = 800) ---
                  pw.Row(children: [
                    _headerBox(290, true, pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                        pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                        pw.Text("GSTIN: ${shop.gstin} | DL: ${shop.dlNo}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Phone: ${shop.phone}", style: const pw.TextStyle(fontSize: 8)),
                      ],
                    )),
                    _headerBox(175, true, pw.Column(children: [
                      pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(thickness: 0.5),
                      pw.Text(sale.billNo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text(DateFormat('dd/MM/yyyy').format(sale.date), style: const pw.TextStyle(fontSize: 8.5)),
                    ])),
                    _headerBox(335, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("PARTY / CONSIGNEE DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                      pw.Text(party.address, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                      pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    ])),
                  ]),

                  // --- 2. TABLE HEADER (Total: 800) ---
                  pw.Container(
                    color: PdfColors.grey100,
                    child: pw.Row(children: [
                      _tCol("S.N", 25), _tCol("Qty+Free", 55), _tCol("Pack", 45),
                      _tCol("PRODUCT NAME", 210, isLeft: true), 
                      _tCol("Batch", 75), _tCol("Exp", 45), _tCol("HSN", 50),
                      _tCol("MRP", 55), _tCol("Rate", 55), _tCol("DIS%", 30),
                      _tCol("SGST", 50), _tCol("CGST", 50), 
                      _tCol("NET AMT", 55, isLast: true), 
                    ]),
                  ),

                  // --- 3. DYNAMIC ROWS (Locked height prevents footer drop) ---
                  pw.Container(
                    height: 330,
                    child: pw.Column(children: pageItems.map((i) {
                      return pw.Container(
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1, color: PdfColors.grey400))),
                        child: pw.Row(children: [
                          _cell("${sale.items.indexOf(i) + 1}", 25), 
                          _cell((i.qty + i.freeQty).toInt().toString(), 55), 
                          _cell(i.packing, 45),
                          pw.Container(width: 210, padding: const pw.EdgeInsets.only(left: 8), alignment: pw.Alignment.centerLeft, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(i.name, style: const pw.TextStyle(fontSize: 7.5))),
                          _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.hsn, 50),
                          _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.rate.toStringAsFixed(2), 55),
                          _cell(i.discountRupees.toStringAsFixed(1), 30),
                          _cell("${(i.gstRate / 2).toStringAsFixed(1)}%", 50), 
                          _cell("${(i.gstRate / 2).toStringAsFixed(1)}%", 50),
                          _cell(i.total.toStringAsFixed(2), 55),
                        ]),
                      );
                    }).toList()),
                  ),

                  // --- 4. SMART FOOTER (Locked Height: 110) ---
                  if (isLastPage) _buildFooter(shop.name, sale, shop)
                  else pw.Container(
                    height: 110, alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.all(10),
                    decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
                    child: pw.Text("Continued to next page...", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10))
                  ),
                ],
              ),
            );
          },
        ),
      );
    }
    return pdf.save();
  }

  // --- UI BUILDING BLOCKS ---
  static pw.Widget _headerBox(double w, bool rBorder, pw.Widget child) => pw.Container(width: w, height: 85, padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: rBorder ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: isLeft ? 8 : 0), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  
  // FIXED: Added vertical borders to cells to align with table headers
  static pw.Widget _cell(String t, double w) => pw.Container(width: w, height: 16, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildFooter(String shopName, Sale sale) {
    double gross = sale.items.fold(0, (sum, i) => sum + (i.qty * i.rate));
    double tax = sale.totalAmount - gross;
    int total = sale.totalAmount.round();

    return pw.Container(
      height: 110,
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
      child: pw.Row(children: [
        // Box 1: Words & Terms
        pw.Container(width: 320, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("Amount: RUPEES ${PdfMasterService.numberToWords(total)} ONLY", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Spacer(),
          pw.Text("Terms: 1. Goods once sold will not be taken back. 2. All disputes subject to local jurisdiction.", style: const pw.TextStyle(fontSize: 6.5)),
        ])),
        // Box 2: Totals
        pw.Container(width: 250, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(children: [
          _fRow("GROSS TOTAL", gross), _fRow("TOTAL GST", tax),
          pw.Divider(thickness: 0.5),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("NET AMOUNT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text("Rs. $total.00", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ]),
        ])),
        // Box 3: Sign
        pw.Container(width: 230, padding: const pw.EdgeInsets.all(5), child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("For $shopName", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 7.5)),
        ])),
      ]),
    );
  }
  static pw.Widget _fRow(String l, double v) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 7.5)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))]);
}
