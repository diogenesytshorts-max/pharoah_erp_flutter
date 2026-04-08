import 'dart:typed_data';
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

    // 1. Company Details uthana
    String cName = prefs.getString('compName') ?? "";
    String cAddr = prefs.getString('compAddr') ?? "";
    String cPh = prefs.getString('compPh') ?? "";
    String cGst = prefs.getString('compGST') ?? "";
    String cDl = prefs.getString('compDL') ?? "";

    final int itemsPerPage = 15;
    final int totalPages = (sale.items.length / itemsPerPage).ceil() == 0 ? 1 : (sale.items.length / itemsPerPage).ceil();

    // 2. Pagination Logic (Har page ke liye loop)
    for (int i = 0; i < totalPages; i++) {
      final startIndex = i * itemsPerPage;
      final endIndex = (startIndex + itemsPerPage < sale.items.length) ? startIndex + itemsPerPage : sale.items.length;
      final pageItems = sale.items.sublist(startIndex, endIndex);
      final isLastPage = (i == totalPages - 1);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
              child: pw.Column(
                children: [
                  // --- 1. HEADER SECTION ---
                  pw.Row(
                    children: [
                      // Company Info
                      pw.Container(
                        width: 300, height: 70, padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(cName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                            pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8)),
                            pw.Text("Phone: $cPh | GSTIN: $cGst", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                            pw.Text("D.L.No.: $cDl", style: const pw.TextStyle(fontSize: 8)),
                          ],
                        ),
                      ),
                      // Invoice Title
                      pw.Container(
                        width: 180, height: 70,
                        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                        child: pw.Column(
                          children: [
                            pw.Container(width: double.infinity, color: PdfColors.blue50, child: pw.Center(child: pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)))),
                            pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(2),
                              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                pw.Text("Inv No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 8)),
                                pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 8)),
                                pw.Text("Page ${i + 1} of $totalPages", style: pw.TextStyle(fontSize: 8, color: PdfColors.blue)),
                              ]),
                            ),
                          ],
                        ),
                      ),
                      // Party Details
                      pw.Container(
                        width: 320, height: 70, padding: const pw.EdgeInsets.all(5),
                        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text("PARTY DETAILS:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                            pw.Text(party.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                            pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
                            pw.Text("GSTIN: ${party.gst} | D.L.No: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // --- 2. TABLE HEADER ---
                  pw.Container(
                    color: PdfColors.blue50,
                    child: pw.Row(
                      children: [
                        _col("S.N", 30), _col("Qty", 45), _col("Pack", 45),
                        _col("Product Name", 180, align: pw.Alignment.centerLeft),
                        _col("Batch", 80), _col("Exp", 50), _col("HSN", 50),
                        _col("MRP", 60), _col("Rate", 60), _col("DIS%", 35),
                        _col("SGST%", 45), _col("CGST%", 45), _col("Net Amt", 77),
                      ],
                    ),
                  ),

                  // --- 3. TABLE ROWS ---
                  pw.Expanded(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                      child: pw.Column(
                        children: pageItems.map((item) => pw.Container(
                          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.2))),
                          child: pw.Row(
                            children: [
                              _cell("${item.srNo}", 30), _cell(item.qty.toStringAsFixed(2), 45),
                              _cell(item.packing, 45), _cell(item.name, 180, align: pw.Alignment.centerLeft),
                              _cell(item.batch, 80), _cell(item.exp, 50), _cell(item.hsn, 50),
                              _cell(item.mrp.toStringAsFixed(2), 60), _cell(item.rate.toStringAsFixed(2), 60),
                              _cell(item.discountPercent.toStringAsFixed(1), 35),
                              _cell("${(item.gstRate / 2).toStringAsFixed(2)}%", 45),
                              _cell("${(item.gstRate / 2).toStringAsFixed(2)}%", 45),
                              _cell(item.total.toStringAsFixed(2), 77),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ),

                  // --- 4. FOOTER SECTION ---
                  if (isLastPage) ...[
                    pw.Container(
                      height: 120,
                      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          // GST Summary Table
                          pw.Container(
                            width: 340,
                            child: pw.Column(
                              children: [
                                pw.Container(
                                  color: PdfColors.grey200,
                                  child: pw.Row(children: [
                                    _sumH("GST CLASS", 70), _sumH("TAXABLE", 80), _sumH("SGST", 60), _sumH("CGST", 60), _sumH("TOTAL GST", 70),
                                  ]),
                                ),
                                // Simple GST Summary Logic
                                pw.Row(children: [
                                  _sumC("GST 12%", 70), 
                                  _sumC((sale.totalAmount / 1.12).toStringAsFixed(2), 80),
                                  _sumC((sale.totalAmount * 0.06 / 1.12).toStringAsFixed(2), 60),
                                  _sumC((sale.totalAmount * 0.06 / 1.12).toStringAsFixed(2), 60),
                                  _sumC((sale.totalAmount * 0.12 / 1.12).toStringAsFixed(2), 70),
                                ]),
                                pw.Spacer(),
                                pw.Container(
                                  width: 340, padding: const pw.EdgeInsets.all(5),
                                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                                    pw.Text("Amount in Words:", style: const pw.TextStyle(fontSize: 7)),
                                    pw.Text("${_numberToWords(sale.totalAmount.toInt())} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                          // Terms
                          pw.Container(
                            width: 262, padding: const pw.EdgeInsets.all(5),
                            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                              pw.Text("Total Qty: ${sale.items.fold(0.0, (sum, item) => sum + item.qty)}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                              pw.Divider(),
                              pw.Text("Terms & Conditions", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                              pw.Text("• Goods once sold will not be taken back.\n• All disputes subject to Jurisdiction only.", style: const pw.TextStyle(fontSize: 7)),
                            ]),
                          ),
                          // Grand Total
                          pw.Container(
                            width: 200,
                            decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
                            child: pw.Column(
                              children: [
                                _finalRow("GROSS TOTAL", sale.totalAmount / 1.12),
                                _finalRow("GST PAYABLE", sale.totalAmount - (sale.totalAmount / 1.12)),
                                pw.Spacer(),
                                pw.Container(
                                  width: double.infinity, color: PdfColors.blue50, padding: const pw.EdgeInsets.all(5),
                                  child: pw.Column(children: [
                                    pw.Text("Grand Total", style: const pw.TextStyle(fontSize: 10)),
                                    pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                                  ]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Signatures
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(10),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text("Receiver's Signature", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                            pw.Text("For $cName", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 20),
                            pw.Text("Authorised Signatory", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                          ]),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Continued Message
                    pw.Container(
                      height: 50, width: double.infinity, alignment: pw.Alignment.centerRight, padding: const pw.EdgeInsets.all(10),
                      child: pw.Text("Continued to Page ${i + 2}...", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey)),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      );
    }

    // 3. Print / Save Dialog dikhana
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: "Invoice_${sale.billNo}",
    );
  }

  // --- HELPER UI FUNCTIONS ---
  static pw.Widget _col(String t, double w, {pw.Alignment align = pw.Alignment.center}) => 
    pw.Container(width: w, height: 20, alignment: align, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 2), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))));

  static pw.Widget _cell(String t, double w, {pw.Alignment align = pw.Alignment.center}) => 
    pw.Container(width: w, alignment: align, padding: const pw.EdgeInsets.symmetric(vertical: 2, horizontal: 2), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));

  static pw.Widget _sumH(String t, double w) => 
    pw.Container(width: w, height: 15, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.2)), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));

  static pw.Widget _sumC(String t, double w) => 
    pw.Container(width: w, height: 15, alignment: pw.Alignment.center, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.2)), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));

  static pw.Widget _finalRow(String l, double v) => 
    pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 2), child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(l, style: const pw.TextStyle(fontSize: 8)), pw.Text(v.toStringAsFixed(2), style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))]));

  static String _numberToWords(int amount) {
    if (amount == 0) return "ZERO";
    // Placeholder logic for number to words
    return "RUPEES $amount";
  }
}
