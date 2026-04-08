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
    
    // Company details from settings
    String cName = prefs.getString('compName') ?? "PHAROAH ERP";
    String cAddr = prefs.getString('compAddr') ?? "";
    String cGst = prefs.getString('compGST') ?? "";

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(cName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                      pw.Text(cAddr),
                      pw.Text("GSTIN: $cGst", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Inv No: ${sale.billNo}"),
                      pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}"),
                    ],
                  ),
                ],
              ),
              pw.Divider(),
              // Party Section
              pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
              pw.Text(party.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text(party.address),
              pw.Text("GSTIN: ${party.gst}"),
              pw.SizedBox(height: 20),
              // Table
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blue),
                data: <List<String>>[
                  <String>['S.N', 'Product Name', 'Batch', 'Exp', 'Qty', 'Rate', 'GST%', 'Total'],
                  ...sale.items.map((i) => [
                    i.srNo.toString(), i.name, i.batch, i.exp, i.qty.toStringAsFixed(0), 
                    i.rate.toStringAsFixed(2), "${i.gstRate}%", i.total.toStringAsFixed(2)
                  ])
                ],
              ),
              pw.SizedBox(height: 20),
              // Totals
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text("Taxable Amt: Rs. ${(sale.totalAmount / 1.12).toStringAsFixed(2)}"),
                    pw.Text("GST Amt: Rs. ${(sale.totalAmount - (sale.totalAmount / 1.12)).toStringAsFixed(2)}"),
                    pw.Divider(),
                    pw.Text("GRAND TOTAL: Rs. ${sale.totalAmount.toStringAsFixed(2)}", 
                        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
