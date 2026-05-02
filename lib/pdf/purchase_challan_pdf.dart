// FILE: lib/pdf/purchase_challan_pdf.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class PurchaseChallanPdf {
  static Future<void> generate(PurchaseChallan challan, Party supplier, CompanyProfile shop) async {
    final pdf = pw.Document();

    const double masterWidth = 800;
    const double pageHeightLimit = 550;
    const int itemsPerPage = 18; 
    int totalPages = (challan.items.length / itemsPerPage).ceil();

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < challan.items.length) ? start + itemsPerPage : challan.items.length;
      List<PurchaseItem> pageItems = challan.items.sublist(start, end);
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
              child: pw.Column(children: [
                // --- HEADER ---
                pw.Row(children: [
                  _hBox(280, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("Type: PURCHASE INWARD NOTE", style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  ])),
                  _hBox(170, true, pw.Column(children: [
                    pw.Text("INWARD CHALLAN", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(thickness: 0.5),
                    pw.Text("ID: ${challan.internalNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Ref: ${challan.billNo}", style: const pw.TextStyle(fontSize: 8)),
                    pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(challan.date)}", style: const pw.TextStyle(fontSize: 8.5)),
                  ])),
                  _hBox(330, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("SUPPLIER DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                    pw.Text(supplier.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text("GSTIN: ${supplier.gst} | City: ${supplier.city}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  ])),
                ]),

                // --- TABLE ---
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
                      _cell(i.purchaseRate.toStringAsFixed(2), 100), _cell(i.total.toStringAsFixed(2), 100),
                    ]),
                  );
                }).toList())),

                // --- FOOTER ---
                if (isLastPage) _buildFooter(shop.name, challan.totalAmount, challan.remarks)
                else pw.Container(height: 100, alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.all(10), child: pw.Text("Continued...", style: const pw.TextStyle(fontSize: 10))),
              ]),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Inward_${challan.internalNo}', format: PdfPageFormat.a4.landscape);
  }

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 80, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0), bottom: const pw.BorderSide(width: 0.5))), child: child);
  static pw.Widget _tCol(String t, double w, {bool isLast = false, bool isLeft = false}) => pw.Container(width: w, height: 20, alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, padding: pw.EdgeInsets.only(left: isLeft ? 8 : 0), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: isLast ? 0 : 0.5), bottom: const pw.BorderSide(width: 0.5))), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _cell(String t, double w, {bool isLeft = false}) => pw.Container(width: w, height: 18, padding: const pw.EdgeInsets.symmetric(horizontal: 5), alignment: isLeft ? pw.Alignment.centerLeft : pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.2, color: PdfColors.grey))), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));

  static pw.Widget _buildFooter(String shopName, double total, String remarks) {
    return pw.Container(height: 100, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), child: pw.Row(children: [
      pw.Container(width: 480, padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("REMARKS / NOTES:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        pw.Text(remarks.isEmpty ? "Material received and verified." : remarks, style: const pw.TextStyle(fontSize: 8)),
        pw.Spacer(),
        pw.Text("Note: This is an internal record for stock inward verification.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ])),
      pw.Container(width: 320, padding: const pw.EdgeInsets.all(8), child: pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("TOTAL INWARD VALUE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("Rs. ${total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.Spacer(),
        pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Column(children: [
          pw.Text("Store Verification By", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
          pw.SizedBox(height: 15),
          pw.Text(shopName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        ])),
      ])),
    ]));
  }
}
