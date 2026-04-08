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
    String cName = prefs.getString('compName') ?? "PHAROAH ERP";
    String cAddr = prefs.getString('compAddr') ?? "";
    String cGst = prefs.getString('compGST') ?? "";
    String cDl = prefs.getString('compDL') ?? "";
    String cPh = prefs.getString('compPh') ?? "";

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(cName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
              pw.Text(cAddr, style: const pw.TextStyle(fontSize: 9)),
              pw.Text("GSTIN: $cGst | DL: $cDl", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              pw.Text("Phone: $cPh", style: const pw.TextStyle(fontSize: 9)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.Text("Inv No: ${sale.billNo}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}"),
              pw.Text("Mode: ${sale.paymentMode}"),
            ]),
          ]),
          pw.Divider(),
          pw.Text("BILL TO: ${party.name}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.Text(party.address, style: const pw.TextStyle(fontSize: 9)),
          pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
            data: <List<String>>[
              ['S.N', 'Product', 'Batch', 'Exp', 'Qty', 'Rate', 'GST%', 'Total'],
              ...sale.items.map((i) => [i.srNo.toString(), i.name, i.batch, i.exp, i.qty.toStringAsFixed(0), i.rate.toStringAsFixed(2), "${i.gstRate}%", i.total.toStringAsFixed(2)])
            ],
          ),
          pw.SizedBox(height: 15),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("GRAND TOTAL: Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800))),
          pw.Spacer(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Receiver's Signature"), pw.Text("For $cName (Auth. Signatory)")]),
        ]);
      },
    ));
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
