import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class SaleInvoicePdf {
  static Future<void> generate(Sale sale, Party party, CompanyProfile shop) async {
    final pdf = pw.Document();

    // Data Mapping from Shop Profile
    String compName = shop.name.toUpperCase();
    String compAddr = shop.address;
    String compPh = shop.phone;
    String compGST = shop.gstin;
    String compDL = shop.dlNo;

    // ORIGINAL LOGIC
    double totalGross = sale.items.fold(0, (sum, i) => sum + (i.qty * i.rate));
    double totalSGST = sale.items.fold(0, (sum, i) => sum + i.sgst);
    double totalCGST = sale.items.fold(0, (sum, i) => sum + i.cgst);
    int roundedGrandTotal = sale.totalAmount.round();

    const int itemsPerPage = 22; 
    int totalPages = (sale.items.length / itemsPerPage).ceil();

    String formatQty(double val) {
      if (val == val.toInt()) return val.toInt().toString();
      return val.toStringAsFixed(1);
    }

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < sale.items.length) ? start + itemsPerPage : sale.items.length;
      List<BillItem> pageItems = sale.items.sublist(start, end);
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
                  // --- HEADER (SAME FORMAT) ---
                  pw.Row(
                    children: [
                      PdfMasterService.headerBox(width: 280, height: 80, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(compName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(compAddr, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("Phone: $compPh | GSTIN: $compGST", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text("D.L.No.: $compDL", style: const pw.TextStyle(fontSize: 7.5)),
                        ],
                      )),
                      PdfMasterService.headerBox(width: 170, height: 80, child: pw.Column(
                        children: [
                          pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                          pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Divider(thickness: 0.5),
                          pw.Text("Inv No: ${sale.billNo}", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: pw.TextStyle(fontSize: 8.5)),
                          pw.Text("Page ${pageNum + 1} of $totalPages", style: const pw.TextStyle(fontSize: 7, color: PdfColors.blue)),
                        ],
                      )),
                      PdfMasterService.headerBox(width: 330, height: 80, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("PARTY DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                          pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      )),
                    ],
                  ),

                  // --- TABLE HEADER (SAME WIDTHS) ---
                  pw.Container(
                    color: PdfColors.grey100,
                    child: pw.Row(
                      children: [
                        PdfMasterService.tableCol("S.N", 25), 
                        PdfMasterService.tableCol("Qty + Free", 50),
                        PdfMasterService.tableCol("Pack", 40),
                        PdfMasterService.tableCol("Product Name", 185, align: pw.Alignment.centerLeft),
                        PdfMasterService.tableCol("Batch", 75), 
                        PdfMasterService.tableCol("Exp", 45), 
                        PdfMasterService.tableCol("HSN", 50),
                        PdfMasterService.tableCol("MRP", 55), 
                        PdfMasterService.tableCol("Rate", 55), 
                        PdfMasterService.tableCol("DIS%", 30),
                        PdfMasterService.tableCol("SGST%", 40), 
                        PdfMasterService.tableCol("CGST%", 40), 
                        PdfMasterService.tableCol("Net Amt", 80),
                      ],
                    ),
                  ),

                  // --- DYNAMIC ROWS ---
                  pw.Expanded(
                    child: pw.Column(
                      children: pageItems.map((i) {
                        String displayQty = i.freeQty > 0 ? "${formatQty(i.qty)} + ${formatQty(i.freeQty)}" : formatQty(i.qty);
                        return pw.Container(
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1, color: PdfColors.grey400))),
                          child: pw.Row(
                            children: [
                              _cell("${i.srNo}", 25), _cell(displayQty, 50), _cell(i.packing, 40), 
                              _cell(i.name, 185, align: pw.Alignment.centerLeft),
                              _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.hsn, 50),
                              _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.rate.toStringAsFixed(2), 55),
                              _cell(i.discountRupees.toStringAsFixed(1), 30),
                              _cell("${(i.gstRate / 2).toStringAsFixed(1)}%", 40), 
                              _cell("${(i.gstRate / 2).toStringAsFixed(1)}%", 40),
                              _cell(i.total.toStringAsFixed(2), 80),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // --- FOOTER (SAME FORMAT) ---
                  if (isLastPage) _buildFooter(compName, sale, totalGross, totalSGST, totalCGST, roundedGrandTotal)
                  else pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Continued to next page...", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10))),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Bill_${sale.billNo}', format: PdfPageFormat.a4.landscape, dynamicLayout: false);
  }

  static pw.Widget _cell(String t, double w, {pw.Alignment align = pw.Alignment.center}) => pw.Container(width: w, padding: const pw.EdgeInsets.symmetric(vertical: 2), alignment: align, child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildFooter(String shopName, Sale sale, CompanyProfile shop) {
    double taxableTotal = sale.items.fold(0, (sum, i) => sum + (i.qty * i.rate));
    double totalGst = sale.items.fold(0, (sum, i) => sum + (i.cgst + i.sgst + i.igst));
    bool isLocal = shop.state.trim().toLowerCase() == sale.partyState.trim().toLowerCase();

    return pw.Container(
      height: 110,
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
      child: pw.Row(children: [
        // Box 1: Words
        pw.Container(width: 320, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("Amount: RUPEES ${PdfMasterService.numberToWords(sale.totalAmount.round())} ONLY", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
          pw.Spacer(),
          pw.Text("Terms: 1. Goods once sold will not be taken back. 2. All disputes subject to local jurisdiction.", style: const pw.TextStyle(fontSize: 6.5)),
        ])),
        // Box 2: NEW PROFESSIONAL TOTALS
        pw.Container(width: 250, padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Column(children: [
          _fRow("TAXABLE AMT", taxableTotal),
          if (isLocal) ...[
            _fRow("CGST TOTAL", totalGst / 2),
            _fRow("SGST TOTAL", totalGst / 2),
          ] else
            _fRow("IGST TOTAL", totalGst),
          if (sale.extraDiscount > 0) _fRow("DISCOUNT (-)", sale.extraDiscount),
          _fRow("ROUND OFF", sale.roundOff),
          pw.Divider(thickness: 0.5),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("GRAND TOTAL", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
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
