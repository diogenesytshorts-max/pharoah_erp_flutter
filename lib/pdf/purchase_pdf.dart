import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class PurchasePdf {
  static Future<void> generate(Purchase pur, Party supplier, CompanyProfile shop) async {
    final pdf = pw.Document();

    // 📐 CONFIGURATION: Master Width for A4 Landscape (800pts fills the page perfectly)
    const double masterWidth = 800;

    // Data Mapping from Shop Profile
    String compName = shop.name.toUpperCase();
    String compAddr = shop.address;
    String compPh = shop.phone;
    String compGST = shop.gstin;

    // CALCULATION LOGIC
    double totalTaxable = pur.items.fold(0, (sum, i) => sum + (i.purchaseRate * i.qty));
    double totalGst = pur.totalAmount - totalTaxable;
    int roundedGrandTotal = pur.totalAmount.round();

    // Pagination: 12 items per page for cleaner look
    const int itemsPerPage = 12;
    int totalPages = (pur.items.length / itemsPerPage).ceil();

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < pur.items.length) ? start + itemsPerPage : pur.items.length;
      List<PurchaseItem> pageItems = pur.items.sublist(start, end);
      bool isLastPage = (pageNum == totalPages - 1);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.symmetric(horizontal: 21, vertical: 15),
          build: (pw.Context context) {
            return pw.Container(
              width: masterWidth,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 1, color: PdfColors.black), // MAIN OUTER FRAME
              ),
              child: pw.Column(
                children: [
                  // --- 1. HEADER SECTION (Total: 290 + 175 + 335 = 800) ---
                  pw.Row(
                    children: [
                      PdfMasterService.headerBox(width: 290, height: 90, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(compName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(compAddr, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("Phone: $compPh | GSTIN: $compGST", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Type: STOCK INWARD RECORD", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        ],
                      )),
                      PdfMasterService.headerBox(width: 175, height: 90, child: pw.Column(
                        children: [
                          pw.Text("PURCHASE BILL", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                          pw.Text(pur.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Divider(thickness: 0.5),
                          pw.Text("Bill No: ${pur.billNo}", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Internal ID: ${pur.internalNo}", style: const pw.TextStyle(fontSize: 7.5)),
                          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(pur.date)}", style: const pw.TextStyle(fontSize: 8.5)),
                        ],
                      )),
                      PdfMasterService.headerBox(width: 335, height: 90, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("SUPPLIER / DISTRIBUTOR DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                          pw.Text(supplier.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(supplier.address, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("GSTIN: ${supplier.gst} | DL: ${supplier.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      )),
                    ],
                  ),

                  // --- 2. TABLE HEADER (Total: 25+45+35+45+215+80+45+50+60+60+50+90 = 800) ---
                  pw.Container(
                    color: PdfColors.grey200,
                    child: pw.Row(
                      children: [
                        PdfMasterService.tableCol("S.N", 25), 
                        PdfMasterService.tableCol("Qty", 45), 
                        PdfMasterService.tableCol("Free", 35), 
                        PdfMasterService.tableCol("Pack", 45),
                        PdfMasterService.tableCol("Product Name", 215, align: pw.Alignment.centerLeft),
                        PdfMasterService.tableCol("Batch", 80), 
                        PdfMasterService.tableCol("Exp", 45), 
                        PdfMasterService.tableCol("HSN", 50),
                        PdfMasterService.tableCol("MRP", 60), 
                        PdfMasterService.tableCol("Pur.Rate", 60), 
                        PdfMasterService.tableCol("GST%", 50), 
                        PdfMasterService.tableCol("Net Amt", 90),
                      ],
                    ),
                  ),

                  // --- 3. DYNAMIC ROWS ---
                  pw.Expanded(
                    child: pw.Column(
                      children: pageItems.map((i) {
                        return pw.Container(
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))),
                          child: pw.Row(
                            children: [
                              _tCell("${i.srNo}", 25), 
                              _tCell(i.qty.toStringAsFixed(0), 45),
                              _tCell(i.freeQty.toStringAsFixed(0), 35), 
                              _tCell(i.packing, 45),
                              // 💡 Padding Fix for Product Name
                              pw.Container(
                                width: 215,
                                padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                                alignment: pw.Alignment.centerLeft,
                                child: pw.Text(i.name, style: const pw.TextStyle(fontSize: 7.5)),
                              ),
                              _tCell(i.batch, 80), 
                              _tCell(i.exp, 45), 
                              _tCell(i.hsn, 50),
                              _tCell(i.mrp.toStringAsFixed(2), 60), 
                              _tCell(i.purchaseRate.toStringAsFixed(2), 60),
                              _tCell("${i.gstRate}%", 50), 
                              _tCell(i.total.toStringAsFixed(2), 90),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // --- 4. FOOTER SECTION (Total: 340 + 260 + 200 = 800) ---
                  if (isLastPage) _buildFullFooter(compName, pur, totalTaxable, totalGst, roundedGrandTotal)
                  else pw.Padding(
                    padding: const pw.EdgeInsets.all(5), 
                    child: pw.Text("Continued...", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10))
                  ),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(), 
      name: 'Purchase_${pur.billNo}',
      format: PdfPageFormat.a4.landscape,
      dynamicLayout: false,
    );
  }

  static pw.Widget _tCell(String text, double width, {pw.Alignment align = pw.Alignment.center}) => 
    pw.Container(
      width: width, 
      padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2), 
      alignment: align, 
      child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5))
    );

  static pw.Widget _buildFullFooter(String compName, Purchase pur, double taxable, double gst, int total) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // BOX 1: Words & Note
        pw.Container(
          width: 340, 
          padding: const pw.EdgeInsets.all(5), 
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5))), 
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Amount in Words:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              pw.Text("RUPEES ${PdfMasterService.numberToWords(total)} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.SizedBox(height: 10),
              pw.Text("Note: This is a system generated purchase record for inventory purposes.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
            ],
          ),
        ),
        // BOX 2: Totals
        pw.Container(
          width: 260, 
          padding: const pw.EdgeInsets.all(5), 
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), right: pw.BorderSide(width: 0.5))), 
          child: pw.Column(
            children: [
              _fRow("TAXABLE AMOUNT", taxable), 
              _fRow("GST AMOUNT", gst),
              pw.Divider(thickness: 0.5),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                children: [
                  pw.Text("TOTAL PURCHASE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Rs. $total.00", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
        // BOX 3: Verification
        pw.Container(
          width: 200, 
          height: 65, 
          padding: const pw.EdgeInsets.all(5), 
          decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))), 
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text("Verified By", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.SizedBox(height: 15),
              pw.Text(compName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _fRow(String l, double v) => 
    pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
      children: [
        pw.Text(l, style: const pw.TextStyle(fontSize: 8)), 
        pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))
      ],
    );
}
