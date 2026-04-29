// FILE: lib/pdf/sale_challan_pdf.dart

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

    String compName = shop.name.toUpperCase();
    String compAddr = shop.address;
    String compPh = shop.phone;
    String compGST = shop.gstin;

    const int itemsPerPage = 20; 
    int totalPages = (challan.items.length / itemsPerPage).ceil();

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
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
              child: pw.Column(
                children: [
                  // --- HEADER ---
                  pw.Row(
                    children: [
                      PdfMasterService.headerBox(width: 280, height: 80, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(compName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(compAddr, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("Phone: $compPh | GSTIN: $compGST", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      )),
                      PdfMasterService.headerBox(width: 170, height: 80, child: pw.Column(
                        children: [
                          pw.Text("SALE CHALLAN", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
                          pw.Divider(thickness: 0.5),
                          pw.Text("Challan No: ${challan.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(challan.date)}", style: const pw.TextStyle(fontSize: 8.5)),
                          pw.Text("Page ${pageNum + 1} of $totalPages", style: const pw.TextStyle(fontSize: 7)),
                        ],
                      )),
                      PdfMasterService.headerBox(width: 330, height: 80, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("CONSIGNEE / PARTY DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                          pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("GSTIN: ${party.gst} | City: ${party.city}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      )),
                    ],
                  ),

                  // --- TABLE HEADER ---
                  pw.Container(
                    color: PdfColors.grey200,
                    child: pw.Row(
                      children: [
                        PdfMasterService.tableCol("S.N", 30), 
                        PdfMasterService.tableCol("Product Description", 300, align: pw.Alignment.centerLeft),
                        PdfMasterService.tableCol("Packing", 60),
                        PdfMasterService.tableCol("Batch", 90), 
                        PdfMasterService.tableCol("Expiry", 60), 
                        PdfMasterService.tableCol("Qty", 60), 
                        PdfMasterService.tableCol("Rate", 80), 
                        PdfMasterService.tableCol("Total", 100),
                      ],
                    ),
                  ),

                  // --- ITEMS ---
                  pw.Expanded(
                    child: pw.Column(
                      children: pageItems.map((i) {
                        return pw.Container(
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))),
                          child: pw.Row(
                            children: [
                              _cell("${i.srNo}", 30),
                              _cell(i.name, 300, align: pw.Alignment.centerLeft),
                              _cell(i.packing, 60),
                              _cell(i.batch, 90),
                              _cell(i.exp, 60),
                              _cell(i.qty.toInt().toString(), 60),
                              _cell(i.rate.toStringAsFixed(2), 80),
                              _cell(i.total.toStringAsFixed(2), 100),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // --- FOOTER ---
                  if (isLastPage) _buildFooter(compName, challan)
                  else pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Continued...", style: const pw.TextStyle(fontSize: 8))),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Challan_${challan.billNo}');
  }

  static pw.Widget _cell(String t, double w, {pw.Alignment align = pw.Alignment.center}) => 
    pw.Container(width: w, padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4), alignment: align, child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));

  static pw.Widget _buildFooter(String shopName, SaleChallan challan) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 470, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("REMARKS / NOTES:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.Text(challan.remarks.isEmpty ? "No specific instructions." : challan.remarks, style: const pw.TextStyle(fontSize: 8)),
            pw.SizedBox(height: 10),
            pw.Text("Terms: This is a delivery challan, not a tax invoice. Goods are sent for approval/processing.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ],
        )),
        pw.Container(width: 310, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(
          children: [
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("TOTAL CHALLAN VALUE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text("Rs. ${challan.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ]),
            pw.SizedBox(height: 20),
            pw.Align(alignment: pw.Alignment.bottomRight, child: pw.Column(
              children: [
                pw.Text("For $shopName", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 15),
                pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 7)),
              ]
            )),
          ],
        )),
      ],
    );
  }
}
