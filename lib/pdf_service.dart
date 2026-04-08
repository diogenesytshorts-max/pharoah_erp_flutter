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
    String cName = prefs.getString('compName') ?? "";
    String cAddr = prefs.getString('compAddr') ?? "";
    String cGst = prefs.getString('compGST') ?? "";
    String cDl = prefs.getString('compDL') ?? "";
    String cPh = prefs.getString('compPh') ?? "";

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
          child: pw.Column(children: [
            // HEADER
            pw.Row(children: [
              pw.Container(width: 300, height: 80, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(cName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8)),
                pw.Text("Phone: $cPh | GSTIN: $cGst", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text("D.L.No: $cDl", style: const pw.TextStyle(fontSize: 8)),
              ])),
              pw.Container(width: 180, height: 80, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(children: [
                pw.Container(width: double.infinity, color: PdfColors.blue50, child: pw.Center(child: pw.Text("GST INVOICE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)))),
                pw.Text(sale.paymentMode.toUpperCase(), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("Inv No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 8)),
                ])),
              ])),
              pw.Container(width: 320, height: 80, padding: const pw.EdgeInsets.all(8), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("PARTY DETAILS:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                pw.Text(party.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
                pw.Text("GSTIN: ${party.gst} | D.L.No: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ])),
            ]),
            // TABLE
            pw.Container(color: PdfColors.blue50, child: pw.Row(children: [
              _c("S.N", 30), _c("Qty", 45), _c("Pack", 45), _c("Product Name", 180, a: pw.Alignment.centerLeft), _c("Batch", 80), _c("Exp", 50), _c("HSN", 50), _c("MRP", 60), _c("Rate", 60), _c("DIS%", 35), _c("SGST%", 45), _c("CGST%", 45), _c("Net Amt", 75),
            ])),
            pw.Expanded(child: pw.Container(decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(children: sale.items.map((i)=>pw.Row(children: [
              _ce("${i.srNo}", 30), _ce("${i.qty}", 45), _ce(i.packing, 45), _ce(i.name, 180, a: pw.Alignment.centerLeft), _ce(i.batch, 80), _ce(i.exp, 50), _ce(i.hsn, 50), _ce("${i.mrp}", 60), _ce("${i.rate}", 60), _ce("${i.discountPercent}", 35), _ce("${i.gstRate/2}%", 45), _ce("${i.gstRate/2}%", 45), _ce("${i.total}", 75),
            ])).toList()))),
            // FOOTER
            pw.Container(height: 100, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Row(children: [
              pw.Container(width: 340, padding: const pw.EdgeInsets.all(5), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("Status: ${sale.status}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: sale.status == "Active" ? PdfColors.green : PdfColors.red)),
                pw.Spacer(),
                pw.Text("Amount in Words:", style: const pw.TextStyle(fontSize: 7)),
                pw.Text("RUPEES ${sale.totalAmount.toInt()} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              ])),
              pw.Container(width: 260, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text("Terms & Conditions:\n1. Goods once sold will not be taken back.\n2. All disputes subject to local jurisdiction.", style: const pw.TextStyle(fontSize: 7))),
              pw.Container(width: 200, color: PdfColors.blue50, child: pw.Center(child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Text("Grand Total", style: const pw.TextStyle(fontSize: 10)),
                pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ]))),
            ])),
          ]),
        );
      },
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Invoice_${sale.billNo}");
  }

  static pw.Widget _c(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, height: 20, alignment: a, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _ce(String t, double w, {pw.Alignment a = pw.Alignment.center}) => pw.Container(width: w, alignment: a, padding: const pw.EdgeInsets.all(2), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));
}
