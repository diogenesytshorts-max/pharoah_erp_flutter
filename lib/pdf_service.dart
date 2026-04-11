import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateInvoice(Sale sale, Party party, {bool isPurchase = false}) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    String cAddr = prefs.getString('compAddr') ?? "Address Line";
    String cGst = prefs.getString('compGST') ?? "GSTIN NOT SET";
    String cPh = prefs.getString('compPh') ?? "0000000000";

    // GST Buckets for Slab Summary
    Map<double, Map<String, double>> gstBuckets = {};
    for (var item in sale.items) {
      if (!gstBuckets.containsKey(item.gstRate)) {
        gstBuckets[item.gstRate] = {'taxable': 0, 'gst': 0};
      }
      double taxable = (item.rate * item.qty) - item.discountRupees;
      gstBuckets[item.gstRate]!['taxable'] = gstBuckets[item.gstRate]!['taxable']! + taxable;
      gstBuckets[item.gstRate]!['gst'] = gstBuckets[item.gstRate]!['gst']! + (item.cgst + item.sgst + item.igst);
    }

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(15),
      build: (pw.Context context) {
        return pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            // --- HEADER: 3 BOXES ---
            pw.Row(children: [
              // Box 1: Seller
              pw.Container(width: 250, height: 80, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(cName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("GSTIN: $cGst | Ph: $cPh", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
              // Box 2: Bill Info
              pw.Expanded(child: pw.Container(height: 80, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                  pw.Text(isPurchase ? "PURCHASE BILL" : "TAX INVOICE", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text("No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 10)),
                ]))),
              // Box 3: Customer
              pw.Container(width: 250, height: 80, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("GSTIN: ${party.gst}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
            ]),

            // --- PRODUCT TABLE ---
            pw.Expanded(child: pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['S.N', 'Product Name', 'Batch', 'Exp', 'Qty', 'MRP', 'Rate', 'GST%', 'Total'],
              data: sale.items.map((i) => [i.srNo, i.name, i.batch, i.exp, i.qty.toInt(), i.mrp, i.rate, "${i.gstRate}%", i.total.toStringAsFixed(2)]).toList(),
            )),

            // --- FOOTER: GST SUMMARY & GRAND TOTAL ---
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              // Slabs
              pw.Container(width: 300, padding: const pw.EdgeInsets.all(5), 
                child: pw.TableHelper.fromTextArray(
                  headers: ['Slab', 'Taxable', 'GST Amt'],
                  data: gstBuckets.entries.map((e) => ["${e.key}%", e.value['taxable']!.toStringAsFixed(2), e.value['gst']!.toStringAsFixed(2)]).toList(),
                )),
              pw.Spacer(),
              pw.Container(padding: const pw.EdgeInsets.all(10), color: PdfColors.grey200, 
                child: pw.Column(children: [
                  pw.Text("GRAND TOTAL", style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                ])),
            ])
          ]),
        );
      },
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Bill_${sale.billNo}");
  }

  static Future<void> generateGstReport(String title, List<Sale> sales, String month) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, build: (pw.Context context) => [
      pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
      pw.Divider(),
      pw.TableHelper.fromTextArray(
        headers: ['Date', 'Bill No', 'Party', 'Taxable', 'CGST', 'SGST', 'IGST', 'Total'],
        data: sales.map((s) {
          double tx = 0, c = 0, sg = 0, ig = 0;
          for (var it in s.items) { tx += (it.rate * it.qty); c += it.cgst; sg += it.sgst; ig += it.igst; }
          return [DateFormat('dd/MM').format(s.date), s.billNo, s.partyName, tx.toStringAsFixed(2), c.toStringAsFixed(2), sg.toStringAsFixed(2), ig.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)];
        }).toList(),
      ),
    ]));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Report_$month");
  }

  static Future<void> generateGstJson(List<Sale> sales, String monthYear) async {
    List<Map<String, dynamic>> b2b = [];
    for (var s in sales) {
      if (s.invoiceType == "B2B") {
        b2b.add({"inv": [{"inum": s.billNo, "idt": DateFormat('dd-MM-yyyy').format(s.date), "val": s.totalAmount, "itms": [{"itm_det": {"txval": s.totalAmount, "rt": 12}}]}]});
      }
    }
    await Share.share(jsonEncode({"b2b": b2b}), subject: "GSTR1_$monthYear");
  }
}
