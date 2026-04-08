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
    String cN = prefs.getString('compName') ?? "";
    String cA = prefs.getString('compAddr') ?? "";
    String cG = prefs.getString('compGST') ?? "";
    String cD = prefs.getString('compDL') ?? "";
    String cP = prefs.getString('compPh') ?? "";
    String cE = prefs.getString('compEmail') ?? "";

    double totG = sale.items.fold(0, (s, i) => s + (i.rate * i.qty));
    double totD = sale.items.fold(0, (s, i) => s + ((i.rate * i.qty) * (i.discountPercent / 100)) + i.discountRupees);
    double totT = totG - totD;
    double totGST = sale.items.fold(0, (s, i) => s + (i.cgst + i.sgst));

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(15),
      build: (pw.Context ctx) => pw.Container(
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
        child: pw.Column(children: [
          pw.Row(children: [
            pw.Container(width: 320, height: 95, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(cN, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text(cA, style: const pw.TextStyle(fontSize: 8)),
              pw.Text("GSTIN: $cG | DL: $cD", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text("Ph: $cP | Email: $cE", style: const pw.TextStyle(fontSize: 8)),
            ])),
            pw.Container(width: 160, height: 95, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(children: [
              pw.Container(width: double.infinity, color: PdfColors.blue50, child: pw.Center(child: pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)))),
              pw.SizedBox(height: 5),
              pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text("Inv No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 8)),
              pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 8)),
            ])),
            pw.Container(width: 320, height: 95, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
              pw.Text(party.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
              pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Text("Email: ${party.email}", style: const pw.TextStyle(fontSize: 8)),
            ])),
          ]),
          pw.Container(color: PdfColors.blue50, child: pw.Row(children: [_c("S.N", 30), _c("Product Name", 200, a: pw.Alignment.centerLeft), _c("Pack", 50), _c("Batch", 80), _c("Exp", 50), _c("MRP", 60), _c("Rate", 60), _c("Qty", 50), _c("GST%", 50), _c("Disc", 50), _c("Net Amt", 120)])),
          pw.Expanded(child: pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(children: sale.items.map((i)=>pw.Row(children: [
            _ce("${i.srNo}", 30), _ce(i.name, 200, a: pw.Alignment.centerLeft), _ce(i.packing, 50), _ce(i.batch, 80), _ce(i.exp, 50), _ce("${i.mrp}", 60), _ce("${i.rate}", 60), _ce("${i.qty.toInt()}", 50), _ce("${i.gstRate}%", 50), _ce("${i.discountPercent}%", 50), _ce("${i.total.toStringAsFixed(2)}", 120),
          ])).toList()))),
          pw.Container(height: 80, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Row(children: [
            pw.Container(width: 350, padding: const pw.EdgeInsets.all(5), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text("Total Items: ${sale.items.length}", style: const pw.TextStyle(fontSize: 8)),
              pw.Spacer(),
              pw.Text("Amount in Words: RUPEES ${sale.totalAmount.toInt()} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
            ])),
            pw.Container(width: 250, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text("Terms:\n1. Goods once sold will not be taken back.\n2. All disputes subject to local jurisdiction.", style: const pw.TextStyle(fontSize: 7))),
            pw.Container(width: 200, color: PdfColors.blue50, child: pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
              pw.Text("GRAND TOTAL", style: const pw.TextStyle(fontSize: 10)),
              pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ]))),
          ])),
        ]),
      ),
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Invoice_${sale.billNo}");
  }
  static pw.Widget _c(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, height: 20, alignment: a, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text(t, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _ce(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, alignment: a, padding: const pw.EdgeInsets.all(3), child: pw.Text(t, style: const pw.TextStyle(fontSize: 8)));
}
