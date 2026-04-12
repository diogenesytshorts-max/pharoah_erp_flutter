import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models.dart';

class SaleInvoicePdf {
  static Future<void> generate(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    // Settings load kar rahe hain
    String compName = (prefs.getString('compName') ?? "").toUpperCase();
    String compAddr = prefs.getString('compAddr') ?? "";
    String compPh = prefs.getString('compPh') ?? "";
    String compGST = prefs.getString('compGST') ?? "";
    String compDL = prefs.getString('compDL') ?? "";

    // Data calculations
    double totalGross = sale.items.fold(0, (sum, i) => sum + (i.qty * i.rate));
    double totalSGST = sale.items.fold(0, (sum, i) => sum + i.sgst);
    double totalCGST = sale.items.fold(0, (sum, i) => sum + i.cgst);
    double totalQty = sale.items.fold(0, (sum, i) => sum + i.qty);
    int roundedGrandTotal = sale.totalAmount.round();

    // Items limit per page
    const int itemsPerPage = 12; // 12 items safe rehte hain landscape mein
    int totalPages = (sale.items.length / itemsPerPage).ceil();

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < sale.items.length) ? start + itemsPerPage : sale.items.length;
      List<BillItem> pageItems = sale.items.sublist(start, end);
      bool isLastPage = (pageNum == totalPages - 1);

      pdf.addPage(
        pw.Page(
          // YAHAN LANDSCAPE FIX KIYA GAYA HAI
          pageFormat: PdfPageFormat.a4.landscape, 
          margin: const pw.EdgeInsets.all(15),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
              child: pw.Column(
                children: [
                  // --- 1. HEADER ---
                  pw.Row(
                    children: [
                      _headerBox(width: 280, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(compName, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(compAddr, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("Phone: $compPh | GSTIN: $compGST", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text("D.L.No.: $compDL", style: const pw.TextStyle(fontSize: 8)),
                        ],
                      )),
                      _headerBox(width: 170, child: pw.Column(
                        children: [
                          pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                          pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Divider(thickness: 0.5),
                          pw.Text("Inv No: ${sale.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: pw.TextStyle(fontSize: 9)),
                          pw.Text("Page ${pageNum + 1} of $totalPages", style: const pw.TextStyle(fontSize: 7, color: PdfColors.blue)),
                        ],
                      )),
                      _headerBox(width: 330, child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text("PARTY DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey)),
                          pw.Text(party.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                          pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
                          pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ],
                      )),
                    ],
                  ),

                  // --- 2. TABLE HEADER ---
                  pw.Container(
                    color: PdfColors.grey100,
                    child: pw.Row(
                      children: [
                        _tableCol("S.N", 25), _tableCol("Qty", 40), _tableCol("Pack", 45),
                        _tableCol("Product Name", 190, align: pw.Alignment.centerLeft),
                        _tableCol("Batch", 75), _tableCol("Exp", 45), _tableCol("HSN", 50),
                        _tableCol("MRP", 55), _tableCol("Rate", 55), _tableCol("DIS%", 35),
                        _tableCol("SGST", 40), _tableCol("CGST", 40), _tableCol("Net Amt", 85),
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
                              _tableCell("${i.srNo}", 25), _tableCell(i.qty.toStringAsFixed(2), 40),
                              _tableCell(i.packing, 45), _tableCell(i.name, 190, align: pw.Alignment.centerLeft),
                              _tableCell(i.batch, 75), _tableCell(i.exp, 45), _tableCell(i.hsn, 50),
                              _tableCell(i.mrp.toStringAsFixed(2), 55), _tableCell(i.rate.toStringAsFixed(2), 55),
                              _tableCell(i.discountRupees.toStringAsFixed(1), 35),
                              _tableCell(i.sgst.toStringAsFixed(2), 40), _tableCell(i.cgst.toStringAsFixed(2), 40),
                              _tableCell(i.total.toStringAsFixed(2), 85),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  // --- 4. FOOTER ---
                  if (isLastPage) _buildFullFooter(compName, sale, totalGross, totalSGST, totalCGST, totalQty, roundedGrandTotal)
                  else pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Continued...", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10))),
                ],
              ),
            );
          },
        ),
      );
    }

    // YAHAN PRINTING KO LANDSCAPE FORCE KIYA HAI
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(), 
      name: 'Bill_${sale.billNo}',
      format: PdfPageFormat.a4.landscape, // Force Landscape in Printer
      dynamicLayout: false, // Prevent re-calculating for portrait
    );
  }

  // --- HELPERS ---
  static pw.Widget _headerBox({required double width, required pw.Widget child}) {
    return pw.Container(width: width, height: 90, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: child);
  }

  static pw.Widget _tableCol(String text, double width, {pw.Alignment align = pw.Alignment.center}) {
    return pw.Container(width: width, height: 20, alignment: align, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  }

  static pw.Widget _tableCell(String text, double width, {pw.Alignment align = pw.Alignment.center}) {
    return pw.Container(width: width, padding: const pw.EdgeInsets.symmetric(vertical: 3), alignment: align, child: pw.Text(text, style: const pw.TextStyle(fontSize: 7.5)));
  }

  static pw.Widget _buildFullFooter(String compName, Sale sale, double gross, double sgst, double cgst, double qty, int total) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(width: 320, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text("Amount in Words:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.Text("RUPEES ${_numberToWords(total)} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.SizedBox(height: 5),
                pw.Text("Terms & Conditions:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.Text("1. Goods once sold will not be taken back.\n2. All disputes subject to Jurisdiction only.", style: const pw.TextStyle(fontSize: 6.5)),
              ],
            )),
            pw.Container(width: 250, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(
              children: [
                _finalRow("GROSS TOTAL", gross),
                _finalRow("TOTAL SGST", sgst),
                _finalRow("TOTAL CGST", cgst),
                pw.Divider(thickness: 0.5),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("NET AMOUNT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Rs. $total.00", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ]),
              ],
            )),
            pw.Container(width: 210, height: 62, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("For $compName", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 8)),
              ],
            )),
          ],
        ),
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
