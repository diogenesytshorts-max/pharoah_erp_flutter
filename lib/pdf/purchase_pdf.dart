import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart'; // NAYA SOURCE

class PurchasePdf {
  static Future<void> generate(Purchase pur, Party supplier, CompanyProfile shop) async {
    final pdf = pw.Document();

    // NAYA: Details from Shop Profile
    String compName = shop.name.toUpperCase();
    String compAddr = shop.address;
    String compPh = shop.phone;
    String compGST = shop.gstin;

    // Calculation (Original Logic)
    double totalTaxable = pur.items.fold(0, (sum, i) => sum + (i.purchaseRate * i.qty));
    double totalGst = pur.totalAmount - totalTaxable;
    int roundedGrandTotal = pur.totalAmount.round();

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
          margin: const pw.EdgeInsets.all(15),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
              child: pw.Column(
                children: [
                  // --- HEADER (Original Layout) ---
                  pw.Row(
                    children: [
                      _headerBox(width: 280, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(compName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(compAddr, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("Phone: $compPh | GSTIN: $compGST", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Type: STOCK INWARD RECORD", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                        ],
                      )),
                      _headerBox(width: 170, child: pw.Column(
                        children: [
                          pw.Text("PURCHASE BILL", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                          pw.Text(pur.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Divider(thickness: 0.5),
                          pw.Text("Bill No: ${pur.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Internal ID: ${pur.internalNo}", style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(pur.date)}", style: pw.TextStyle(fontSize: 9)),
                          pw.Text("Page ${pageNum + 1} of $totalPages", style: const pw.TextStyle(fontSize: 7)),
                        ],
                      )),
                      _headerBox(width: 330, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("SUPPLIER / DISTRIBUTOR DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                          pw.Text(supplier.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(supplier.address, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("GSTIN: ${supplier.gst} | DL: ${supplier.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      )),
                    ],
                  ),

                  // --- TABLE HEADER ---
                  pw.Container(
                    color: PdfColors.grey200,
                    child: pw.Row(
                      children: [
                        _tableCol("S.N", 25), _tableCol("Qty", 40), _tableCol("Free", 30), _tableCol("Pack", 45),
                        _tableCol("Product Name", 190, align: pw.Alignment.centerLeft),
                        _tableCol("Batch", 75), _tableCol("Exp", 45), _tableCol("HSN", 50),
                        _tableCol("MRP", 55), _tableCol("Pur.Rate", 55), _tableCol("GST%", 35), _tableCol("Net Amt", 85),
                      ],
                    ),
                  ),

                  // --- DYNAMIC ROWS ---
                  pw.Expanded(
                    child: pw.Column(
                      children: pageItems.map((i) {
                        return pw.Container(
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))),
                          child: pw.Row(
                            children: [
                              _tableCell("${i.srNo}", 25), _tableCell(i.qty.toStringAsFixed(0), 40),
                              _tableCell(i.freeQty.toStringAsFixed(0), 30), _tableCell(i.packing, 45),
                              _tableCell(i.name, 190, align: pw.Alignment.centerLeft),
                              _tableCell(i.batch, 75), _tableCell(i.exp, 45), _tableCell(i.hsn, 50),
                              _tableCell(i.mrp.toStringAsFixed(2), 55), _tableCell(i.purchaseRate.toStringAsFixed(2), 55),
                              _tableCell("${i.gstRate}%", 35), _tableCell(i.total.toStringAsFixed(2), 85),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // --- FOOTER ---
                  if (isLastPage) _buildFullFooter(compName, pur, totalTaxable, totalGst, roundedGrandTotal)
                  else pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Continued...", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10))),
                ],
              ),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Purchase_${pur.billNo}', format: PdfPageFormat.a4.landscape, dynamicLayout: false);
  }

  // ORIGINAL HELPERS
  static pw.Widget _headerBox({required double width, required pw.Widget child}) => pw.Container(width: width, height: 90, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: child);
  static pw.Widget _tableCol(String text, double width, {pw.Alignment align = pw.Alignment.center}) => pw.Container(width: width, height: 20, alignment: align, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _tableCell(String text, double width, {pw.Alignment align = pw.Alignment.center}) => pw.Container(width: width, padding: const pw.EdgeInsets.symmetric(vertical: 3), alignment: align, child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildFullFooter(String compName, Purchase pur, double taxable, double gst, int total) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(width: 320, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text("Amount in Words:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
            pw.Text("RUPEES ${_numberToWords(total)} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            pw.SizedBox(height: 10),
            pw.Text("Note: This is a system generated purchase record for inventory purpose.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          ],
        )),
        pw.Container(width: 250, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(
          children: [
            _finalRow("TAXABLE AMOUNT", taxable), _finalRow("GST AMOUNT", gst),
            pw.Divider(thickness: 0.5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("TOTAL PURCHASE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
              pw.Text("Rs. $total.00", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ]),
          ],
        )),
        pw.Container(width: 210, height: 62, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            pw.Text("Verified By", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            pw.SizedBox(height: 20),
            pw.Text(compName, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ],
        )),
      ],
    );
  }

  static pw.Widget _finalRow(String l, double v) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 8)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))]);

  static String _numberToWords(int amount) {
    if (amount == 0) return "ZERO";
    var units = ["", "ONE", "TWO", "THREE", "FOUR", "FIVE", "SIX", "SEVEN", "EIGHT", "NINE", "TEN", "ELEVEN", "TWELVE", "THIRTEEN", "FOURTEEN", "FIFTEEN", "SIXTEEN", "SEVENTEEN", "EIGHTEEN", "NINETEEN"];
    var tens = ["", "", "TWENTY", "THIRTY", "FORTY", "FIFTY", "SIXTY", "SEVENTY", "EIGHTY", "NINETY"];
    if (amount < 20) return units[amount];
    if (amount < 100) return tens[(amount / 10).floor()] + (amount % 10 != 0 ? " " + units[amount % 10] : "");
    if (amount < 1000) return units[(amount / 100).floor()] + " HUNDRED" + (amount % 100 != 0 ? " AND " + _numberToWords(amount % 100) : "");
    if (amount < 100000) return _numberToWords((amount / 1000).floor()) + " THOUSAND" + (amount % 1000 != 0 ? " " + _numberToWords(amount % 1000) : "");
    if (amount < 10000000) return _numberToWords((amount / 100000).floor()) + " LAKH" + (amount % 100000 != 0 ? " " + _numberToWords(amount % 100000) : "");
    return amount.toString();
  }
}
