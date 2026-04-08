import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    // Company Profile
    String cName = prefs.getString('compName') ?? "Ok";
    String cAddr = prefs.getString('compAddr') ?? "";
    String cPh = prefs.getString('compPh') ?? "";
    String cGst = prefs.getString('compGST') ?? "";
    String cDl = prefs.getString('compDL') ?? "";

    // Calculations for Footer
    double totalGross = sale.items.fold(0, (sum, i) => sum + (i.rate * i.qty));
    double totalDiscount = sale.items.fold(0, (sum, i) => sum + ((i.rate * i.qty) * (i.discountPercent / 100)) + i.discountRupees);
    double totalTaxable = totalGross - totalDiscount;
    double totalGST = sale.items.fold(0, (sum, i) => sum + (i.cgst + i.sgst));

    const int itemsPerPage = 15;
    int totalItems = sale.items.length;
    int totalPages = (totalItems / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * itemsPerPage;
      final endIndex = min(startIndex + itemsPerPage, totalItems);
      final pageItems = sale.items.sublist(startIndex, endIndex);
      final isLastPage = (pageIndex == totalPages - 1);

      pdf.addPage(
        pw.Page(
          // YAHAN FIX HAI: Force true Landscape A4
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20), 
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
              child: pw.Column(
                children: [
                  // --- 1. HEADER (Exactly 3 Boxes) ---
                  pw.Row(children: [
                    // Company Box
                    pw.Container(
                      width: 300, height: 100, padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(cName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text(cAddr, style: const pw.TextStyle(fontSize: 9), maxLines: 2),
                        pw.Text("Phone: $cPh | GSTIN: $cGst", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        pw.Text("D.L.No.: $cDl", style: const pw.TextStyle(fontSize: 8)),
                      ]),
                    ),
                    // Invoice Box
                    pw.Container(
                      width: 180, height: 100, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                      child: pw.Column(children: [
                        pw.Container(width: double.infinity, color: PdfColors.blue50, padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Center(child: pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)))),
                        pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Text("Inv No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 9)),
                          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 9)),
                          pw.Text("Page ${pageIndex + 1} of $totalPages", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                        ])),
                      ]),
                    ),
                    // Party Box
                    pw.Container(
                      width: 322, height: 100, padding: const pw.EdgeInsets.all(8),
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text("PARTY DETAILS:", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                        pw.Text(party.name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                        pw.Text(party.address, style: const pw.TextStyle(fontSize: 9), maxLines: 2),
                        pw.Text("GSTIN: ${party.gst} | D.L.No: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      ]),
                    ),
                  ]),

                  // --- 2. TABLE HEADER ---
                  pw.Container(
                    color: PdfColors.blue50,
                    child: pw.Row(children: [
                      _col("S.N", 30), _col("Qty", 45), _col("Pack", 45), _col("Product Name", 180, a: pw.Alignment.centerLeft),
                      _col("Batch", 80), _col("Exp", 50), _col("HSN", 50), _col("MRP", 60), _col("Rate", 60),
                      _col("DIS%", 35), _col("SGST%", 45), _col("CGST%", 45), _col("Net Amt", 77),
                    ]),
                  ),

                  // --- 3. DYNAMIC TABLE ROWS (Fixed Height 280) ---
                  pw.Container(
                    height: 280,
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                    child: pw.Column(children: [
                      ...pageItems.map((item) => pw.Container(
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.2, color: PdfColors.grey))),
                        child: pw.Row(children: [
                          _cell("${item.srNo}", 30), _cell(item.qty.toStringAsFixed(2), 45), _cell(item.packing, 45), _cell(item.name, 180, a: pw.Alignment.centerLeft),
                          _cell(item.batch, 80), _cell(item.exp, 50), _cell(item.hsn, 50), _cell(item.mrp.toStringAsFixed(2), 60), _cell(item.rate.toStringAsFixed(2), 60),
                          _cell(item.discountPercent.toStringAsFixed(1), 35), _cell("${(item.gstRate / 2).toStringAsFixed(2)}%", 45), _cell("${(item.gstRate / 2).toStringAsFixed(2)}%", 45), _cell(item.total.toStringAsFixed(2), 77),
                        ]),
                      )).toList(),
                    ]),
                  ),

                  // --- 4. FOOTER (Exactly like 1st Image) ---
                  if (isLastPage) ...[
                    pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      // Tax Summary Box
                      pw.Container(
                        width: 340,
                        child: pw.Column(children: [
                          pw.Container(color: PdfColors.grey200, child: pw.Row(children: [_sumH("GST CLASS", 70), _sumH("TAXABLE", 80), _sumH("SGST", 60), _sumH("CGST", 60), _sumH("TOTAL GST", 70)])),
                          pw.Row(children: [_sumC("GST ${sale.items[0].gstRate.toInt()}%", 70), _sumC(totalTaxable.toStringAsFixed(2), 80), _sumC((totalGST/2).toStringAsFixed(2), 60), _sumC((totalGST/2).toStringAsFixed(2), 60), _sumC(totalGST.toStringAsFixed(2), 70)]),
                          pw.Container(width: 340, height: 45, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                            pw.Text("Amount in Words:", style: const pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                            pw.Text("${_numberToWords(sale.totalAmount.toInt())} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                          ])),
                        ]),
                      ),
                      // Terms Box
                      pw.Container(
                        width: 262, height: 105, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                          pw.Text("Total Items: ${sale.items.length} | Total Qty: ${sale.items.fold(0.0, (sum, it) => sum + it.qty)}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Divider(),
                          pw.Text("Terms & Conditions", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Text("• Goods once sold will not be taken back.\n• All disputes subject to local Jurisdiction only.", style: const pw.TextStyle(fontSize: 7)),
                        ]),
                      ),
                      // Final Grand Total Box
                      pw.Container(
                        width: 200, height: 105, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
                        child: pw.Column(children: [
                          _fR("GROSS TOTAL", totalGross),
                          _fR("DISC AMT.", totalDiscount, color: PdfColors.red), 
                          _fR("GST PAYABLE", totalGST),
                          pw.Spacer(),
                          pw.Container(width: double.infinity, color: PdfColors.blue50, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.blue, width: 2)), child: pw.Column(children: [
                            pw.Text("Grand Total", style: const pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            // Large Grand Total Text like Image 1
                            pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(0)}", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                          ])),
                        ]),
                      ),
                    ]),
                    // Signatures Area
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                        pw.Text("Receiver's Signature", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                          pw.Text("For $cName", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.SizedBox(height: 15),
                          pw.Text("Authorised Signatory", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                        ]),
                      ]),
                    ),
                  ] else ...[
                    // Continued Footer
                    pw.Container(height: 165, decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)), child: pw.Row(children: [
                      pw.Spacer(),
                      pw.Padding(padding: const pw.EdgeInsets.all(10), child: pw.Text("Continued to Page ${pageIndex + 2}...", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700))),
                    ])),
                  ],
                ],
              ),
            );
          },
        ),
      );
    }

    // PDF ko Landscape name ke saath layout karna
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(), 
      name: "Bill_${sale.billNo}",
      format: PdfPageFormat.a4.landscape, // Force printer to see landscape
    );
  }

  // --- UI HELPER METHODS ---
  static pw.Widget _col(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, height: 25, alignment: a, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 2), child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))));
  static pw.Widget _cell(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, alignment: a, padding: const pw.EdgeInsets.symmetric(vertical: 3, horizontal: 2), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
  static pw.Widget _sumH(String t, double w) => pw.Container(width: w, height: 15, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.2)), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _sumC(String t, double w) => pw.Container(width: w, height: 15, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.2)), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
  static pw.Widget _fR(String l, double v, {PdfColor color = PdfColors.black}) => pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 1), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color))]));

  static String _numberToWords(int amount) {
    if (amount == 0) return "ZERO";
    return "RUPEES $amount";
  }
}
