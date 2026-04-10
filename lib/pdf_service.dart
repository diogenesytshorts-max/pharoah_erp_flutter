import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  // ==========================================
  // 1. STANDARD SALE INVOICE (CUSTOMER BILL)
  // ==========================================
  static Future<void> generateInvoice(Sale sale, Party party, {bool isPurchase = false}) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    String cGst = prefs.getString('compGST') ?? "GSTIN NOT SET";
    String cAddr = prefs.getString('compAddr') ?? "Address";

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(cName, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text("GSTIN: $cGst | $cAddr", style: const pw.TextStyle(fontSize: 10)),
          pw.Divider(thickness: 2, color: PdfColors.blueGrey),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              pw.Text(party.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text("GSTIN: ${party.gst}"),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text(isPurchase ? "PURCHASE ENTRY" : "TAX INVOICE", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
              pw.Text("Inv No: ${sale.billNo}"),
              pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}"),
            ]),
          ]),
          pw.SizedBox(height: 15),
          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
            headers: ['S.N', 'Product Description', 'Batch', 'Exp', 'Qty', 'Rate', 'GST%', 'Total'],
            data: sale.items.map((i) => [i.srNo, i.name, i.batch, i.exp, i.qty.toInt(), i.rate, "${i.gstRate}%", i.total.toStringAsFixed(2)]).toList(),
          ),
          pw.Spacer(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: const pw.BoxDecoration(color: PdfColors.grey200),
              child: pw.Text("Grand Total: ₹${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
            )
          ]),
        ]);
      },
    ));

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Bill_${sale.billNo}");
  }

  // ==========================================
  // 2. MARG STYLE GST REPORT (FOR FILING)
  // ==========================================
  static Future<void> generateGstReport(String title, List<Sale> sales, List<Purchase> purchases) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = prefs.getString('compName') ?? "Pharoah ERP";

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(30),
      header: (pw.Context context) => pw.Column(children: [
        pw.Text(cName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(title, style: const pw.TextStyle(fontSize: 14)),
        pw.Divider(),
      ]),
      build: (pw.Context context) {
        if (title.contains("GSTR-1")) {
          return [
            pw.Text("Outward Supplies (Sales Register)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Date', 'Bill No', 'Party Name', 'GSTIN', 'Taxable', 'GST Amt', 'Total'],
              data: sales.map((s) {
                double taxable = 0; double gstAmt = 0;
                for (var it in s.items) {
                  taxable += (it.rate * it.qty);
                  gstAmt += (it.cgst + it.sgst + it.igst);
                }
                return [DateFormat('dd/MM').format(s.date), s.billNo, s.partyName, "Registered", taxable.toStringAsFixed(2), gstAmt.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)];
              }).toList(),
            ),
          ];
        } else if (title.contains("GSTR-3B")) {
          double sTax = 0; double sTotal = 0;
          for (var s in sales) { sTotal += s.totalAmount; s.items.forEach((it) => sTax += (it.cgst + it.sgst + it.igst)); }
          
          return [
            pw.Text("Monthly Tax Summary", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 15),
            pw.TableHelper.fromTextArray(
              headers: ['Table No', 'Description', 'Taxable Value', 'Integrated Tax'],
              data: [
                ['3.1', 'Outward Taxable Supplies (Sales)', sTotal.toStringAsFixed(2), sTax.toStringAsFixed(2)],
                ['4.0', 'Eligible ITC (Purchases)', 'Calculated', 'From Purchases'],
              ],
            ),
          ];
        }
        return [pw.Text("No Report Data")];
      },
    ));

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_Report");
  }
}
