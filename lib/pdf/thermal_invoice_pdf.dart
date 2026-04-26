// FILE: lib/pdf/thermal_invoice_pdf.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import '../logic/app_settings_model.dart';

class ThermalInvoicePdf {
  static Future<void> generate(Sale sale, Party party, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();

    // Data Mapping
    String shopName = shop.name.toUpperCase();
    String invNo = sale.billNo;
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // 80mm standard thermal roll
        margin: const pw.EdgeInsets.all(5),
        build: (pw.Context context) {
          return pw.Container(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // --- HEADER ---
                pw.Center(
                  child: pw.Column(children: [
                    if (config.logoPath != null && File(config.logoPath!).existsSync())
                       pw.Container(width: 40, height: 40, child: pw.Image(pw.MemoryImage(File(config.logoPath!).readAsBytesSync()))),
                    pw.Text(shopName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(shop.address, style: const pw.TextStyle(fontSize: 7), textAlign: pw.TextAlign.center),
                    pw.Text("GSTIN: ${shop.gstin}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(thickness: 0.5),
                  ]),
                ),

                // --- BILL INFO ---
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("Inv: $invNo", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Date: ${DateFormat('dd/MM/yy').format(sale.date)}", style: const pw.TextStyle(fontSize: 8)),
                ]),
                pw.Text("Customer: ${party.name}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                if (party.gst != "N/A") pw.Text("GST: ${party.gst}", style: const pw.TextStyle(fontSize: 7)),
                pw.Divider(thickness: 0.5),

                // --- ITEM TABLE HEADER ---
                pw.Row(children: [
                  pw.Expanded(flex: 6, child: pw.Text("ITEM DESCRIPTION", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 4, child: pw.Text("TOTAL", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                ]),
                pw.SizedBox(height: 2),

                // --- DYNAMIC ITEMS (3-LINE STRATEGY) ---
                ...sale.items.asMap().entries.map((entry) {
                  int idx = entry.key + 1;
                  var it = entry.value;
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 2),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        // Line 1: S.N + Name
                        pw.Text("$idx. ${it.name}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        // Line 2: Batch, Exp, HSN
                        pw.Text("B:${it.batch} E:${it.exp} HSN:${it.hsn}", style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey700)),
                        // Line 3: Qty, Rate, GST, Total
                        pw.Row(children: [
                           pw.Text("Qty:${it.qty.toInt()}+${it.freeQty.toInt()}", style: const pw.TextStyle(fontSize: 7)),
                           pw.Spacer(),
                           pw.Text("R:${it.rate.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 7)),
                           pw.Spacer(),
                           pw.Text("G:${it.gstRate}%", style: const pw.TextStyle(fontSize: 7)),
                           pw.Spacer(),
                           pw.Text("₹${it.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        ]),
                        pw.SizedBox(height: 1, child: pw.Divider(thickness: 0.1, color: PdfColors.grey400)),
                      ],
                    ),
                  );
                }).toList(),

                pw.Divider(thickness: 0.5),

                // --- TOTALS ---
                _sumRow("GROSS TOTAL", sale.totalAmount * 0.88), // Simplified logic
                _sumRow("TOTAL GST", sale.totalAmount * 0.12),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text("NET PAYABLE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text("₹${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                ]),

                pw.SizedBox(height: 10),

                // --- BARCODE SECTION (The Advanced Part) ---
                pw.Center(
                  child: pw.Column(children: [
                    pw.Container(
                      height: 30,
                      width: 120,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.code128(), // Standard Barcode
                        data: invNo,
                        drawText: false,
                      ),
                    ),
                    pw.Text(invNo, style: const pw.TextStyle(fontSize: 6)),
                  ]),
                ),

                pw.SizedBox(height: 10),
                pw.Center(child: pw.Text("Thank You! Visit Again", style: const pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic))),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Receipt_$invNo');
  }

  static pw.Widget _sumRow(String l, double v) => pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 2),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(l, style: const pw.TextStyle(fontSize: 8)),
      pw.Text("₹${v.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 8)),
    ]),
  );
}
