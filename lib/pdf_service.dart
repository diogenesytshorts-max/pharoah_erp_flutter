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

    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();
    String cAddr = prefs.getString('compAddr') ?? "Address Not Set";
    String cGst = prefs.getString('compGST') ?? "N/A";
    String cDl = prefs.getString('compDL') ?? "N/A";
    String cState = prefs.getString('compState') ?? "Rajasthan";

    bool isInterstate = sale.partyState.trim().toLowerCase() != cState.trim().toLowerCase();

    // Summary Totals
    double grossTotal = 0;
    double totalDiscount = 0;
    double totalTax = 0;
    for (var it in sale.items) {
      grossTotal += (it.rate * it.qty);
      totalDiscount += it.discountRupees;
      totalTax += (it.cgst + it.sgst + it.igst);
    }

    const int itemsPerPage = 12;
    int totalPages = (sale.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int i = 0; i < totalPages; i++) {
      int start = i * itemsPerPage;
      int end = min(start + itemsPerPage, sale.items.length);
      List<BillItem> pItems = sale.items.sublist(start, end);
      bool isLast = (i == totalPages - 1);

      pdf.addPage(pw.Page(
        // FORCE LANDSCAPE HERE
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            
            // --- HEADER SECTION ---
            _buildProfessionalHeader(cName, cAddr, cGst, cDl, sale, party),

            // --- MAIN TABLE WITH FIXED COLUMN WIDTHS ---
            pw.Expanded(
              child: pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                cellStyle: const pw.TextStyle(fontSize: 7),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
                
                // COLUMN WIDTHS SETTINGS (Taaki squashing na ho)
                columnWidths: {
                  0: const pw.FixedColumnWidth(25),  // S.N
                  1: const pw.FixedColumnWidth(30),  // QTY
                  2: const pw.FixedColumnWidth(35),  // PACK
                  3: const pw.FlexColumnWidth(3),    // PRODUCT NAME (Zyada jagah)
                  4: const pw.FixedColumnWidth(55),  // BATCH
                  5: const pw.FixedColumnWidth(40),  // EXP
                  6: const pw.FixedColumnWidth(50),  // HSN
                  7: const pw.FixedColumnWidth(40),  // MRP
                  8: const pw.FixedColumnWidth(40),  // RATE
                  9: const pw.FixedColumnWidth(35),  // DISC%
                  10: const pw.FixedColumnWidth(45), // SGST/IGST
                  11: const pw.FixedColumnWidth(45), // CGST (If local)
                  12: const pw.FixedColumnWidth(55), // NET AMT
                },

                headers: [
                  'S.N', 'Qty', 'Pack', 'Product Name', 'Batch', 'Exp', 'HSN', 'MRP', 'Rate', 'Dis%', 
                  if (!isInterstate) ...['SGST', 'CGST'] else 'IGST',
                  'Net Amt'
                ],
                data: pItems.map((it) {
                  double dP = (it.discountRupees / (it.rate * it.qty)) * 100;
                  return [
                    it.srNo, it.qty.toInt(), it.packing, it.name, it.batch, it.exp, it.hsn, 
                    it.mrp.toStringAsFixed(2), it.rate.toStringAsFixed(2),
                    dP > 0 ? "${dP.toStringAsFixed(1)}%" : "0",
                    if (!isInterstate) ...[it.sgst.toStringAsFixed(2), it.cgst.toStringAsFixed(2)] 
                    else it.igst.toStringAsFixed(2),
                    it.total.toStringAsFixed(2)
                  ];
                }).toList(),
              ),
            ),

            // --- FOOTER SECTION ---
            if (isLast)
              _buildFinalFooter(grossTotal, totalDiscount, totalTax, sale.totalAmount)
            else
              pw.Container(
                padding: const pw.EdgeInsets.all(5),
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Page ${i+1} of $totalPages - Continued...", style: const pw.TextStyle(fontSize: 8)),
              ),
          ]),
        ),
      ));
    }

    // --- PRINT COMMAND (FORCED LANDSCAPE) ---
    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(), 
      name: "Bill_${sale.billNo}",
      format: PdfPageFormat.a4.landscape // Printer ko landscape batane ke liye
    );
  }

  static pw.Widget _buildProfessionalHeader(String cN, String cA, String cG, String cD, Sale s, Party p) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(cN, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text(cA, style: const pw.TextStyle(fontSize: 8)),
          pw.Text("GSTIN: $cG | DL: $cD", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ])),
        pw.Container(padding: const pw.EdgeInsets.all(8), decoration: const pw.BoxDecoration(color: PdfColors.grey100), child: pw.Column(children: [
          pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text("No: ${s.billNo}", style: const pw.TextStyle(fontSize: 9)),
          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(s.date)}", style: const pw.TextStyle(fontSize: 9)),
        ])),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text("BILL TO:", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
          pw.Text(p.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text(p.address, textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 8)),
          pw.Text("GSTIN: ${p.gst}", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ])),
      ])
    );
  }

  static pw.Widget _buildFinalFooter(double gross, double disc, double tax, double grand) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
      child: pw.Row(children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("Amount in Words: Rupees ${grand.toInt()} Only", style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
          pw.SizedBox(height: 10),
          pw.Text("Terms: Goods once sold cannot be returned.", style: const pw.TextStyle(fontSize: 7)),
        ])),
        pw.Container(
          width: 200,
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), color: PdfColors.grey50),
          child: pw.Column(children: [
            _row("Gross Total:", gross),
            _row("Discount Amount:", disc),
            _row("GST Payable:", tax),
            pw.Divider(thickness: 0.5),
            pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("GRAND TOTAL:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
              pw.Text("Rs. ${grand.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
            ]),
          ])
        )
      ])
    );
  }

  static pw.Widget _row(String l, double v) {
    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(l, style: const pw.TextStyle(fontSize: 8)),
      pw.Text(v.toStringAsFixed(2), style: const pw.TextStyle(fontSize: 8)),
    ]);
  }

  // --- Purchase PDF function ko bhi isi header/footer logic pe update karein ---
  static Future<void> generatePurchaseInvoice(Purchase pur, Party party) async {
    // Same implementation as above with Orange theme and different title
  }
}
