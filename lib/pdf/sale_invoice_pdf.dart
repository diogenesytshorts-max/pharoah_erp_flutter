import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models.dart'; // Models import zaroori hai data lene ke liye

class SaleInvoicePdf {
  static Future<void> generate(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    // Shop details load karna
    String shopName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();
    String shopAddr = prefs.getString('compAddr') ?? "";
    String shopGst = prefs.getString('compGST') ?? "N/A";
    String shopDl = prefs.getString('compDL') ?? "N/A";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(25),
        build: (pw.Context context) {
          return [
            // --- HEADER ---
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(shopName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                    pw.Text(shopAddr, style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("GSTIN: $shopGst | DL: $shopDl", style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                    pw.Text("Invoice No: ${sale.billNo}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}"),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),

            // --- CUSTOMER DETAILS ---
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Text(party.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(party.address, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("GSTIN: ${party.gst}", style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),

            // --- ITEMS TABLE ---
            pw.TableHelper.fromTextArray(
              headers: ['SN', 'Item Description', 'Batch', 'Exp', 'Qty', 'Rate', 'GST%', 'Total'],
              headerStyle: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue900),
              cellStyle: const pw.TextStyle(fontSize: 9),
              data: sale.items.map((it) => [
                it.srNo.toString(),
                it.name,
                it.batch,
                it.exp,
                it.qty.toStringAsFixed(0),
                it.rate.toStringAsFixed(2),
                "${it.gstRate}%",
                it.total.toStringAsFixed(2),
              ]).toList(),
            ),

            // --- SUMMARY ---
            pw.SizedBox(height: 20),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Payment Mode: ${sale.paymentMode}", style: pw.TextStyle(fontStyle: pw.FontStyle.italic, fontSize: 10)),
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                  child: pw.Text("GRAND TOTAL: INR ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
            
            pw.SizedBox(height: 50),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Column(
                children: [
                  pw.Divider(width: 150),
                  pw.Text("Authorized Signatory", style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Sale_Bill_${sale.billNo}');
  }
}
