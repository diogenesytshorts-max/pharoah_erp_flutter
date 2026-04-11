import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  // ===================================================
  // 1. PROFESSIONAL LANDSCAPE INVOICE (CUSTOMER BILL)
  // ===================================================
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    String cAddr = prefs.getString('compAddr') ?? "Office Address";
    String cGst = prefs.getString('compGST') ?? "GSTIN NOT SET";
    String cPh = prefs.getString('compPh') ?? "0000000000";

    // GST Breakdown for Slab Summary Table
    Map<double, Map<String, double>> slabs = {};
    for (var item in sale.items) {
      if (!slabs.containsKey(item.gstRate)) {
        slabs[item.gstRate] = {'taxable': 0, 'gst': 0};
      }
      double taxable = (item.rate * item.qty) - item.discountRupees;
      slabs[item.gstRate]!['taxable'] = slabs[item.gstRate]!['taxable']! + taxable;
      slabs[item.gstRate]!['gst'] = slabs[item.gstRate]!['gst']! + (item.cgst + item.sgst + item.igst);
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
              // Box 1: Seller Info
              pw.Container(width: 280, height: 85, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(cName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                  pw.Spacer(),
                  pw.Text("GSTIN: $cGst", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Phone: $cPh", style: const pw.TextStyle(fontSize: 8)),
                ])),
              // Box 2: Invoice Center
              pw.Expanded(child: pw.Container(height: 85, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                  pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Inv No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 10)),
                ]))),
              // Box 3: Buyer Info
              pw.Container(width: 280, height: 85, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("BILL TO / BUYER:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  pw.Text(sale.partyName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text("GSTIN: ${sale.partyGstin}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                  pw.Text("State: ${sale.partyState}", style: const pw.TextStyle(fontSize: 8)),
                ])),
            ]),

            // --- MAIN PRODUCT TABLE ---
            pw.Expanded(child: pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['S.N', 'Product Description', 'Batch', 'Exp', 'Qty', 'MRP', 'Rate', 'GST%', 'Total'],
              data: sale.items.map((i) => [i.srNo, i.name, i.batch, i.exp, i.qty.toInt(), i.mrp.toStringAsFixed(2), i.rate.toStringAsFixed(2), "${i.gstRate}%", i.total.toStringAsFixed(2)]).toList(),
            )),

            // --- FOOTER: BREAKUP & TOTALS ---
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              // Slab Breakdown Table
              pw.Container(width: 350, padding: const pw.EdgeInsets.all(5), 
                child: pw.TableHelper.fromTextArray(
                  headers: ['GST Slab', 'Taxable Value', 'GST Amount'],
                  headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 7),
                  data: slabs.entries.map((e) => ["${e.key}% Slab", e.value['taxable']!.toStringAsFixed(2), e.value['gst']!.toStringAsFixed(2)]).toList(),
                )),
              pw.Spacer(),
              // Grand Total Box
              pw.Container(width: 200, padding: const pw.EdgeInsets.all(10), color: PdfColors.grey200, 
                child: pw.Column(children: [
                  pw.Text("GRAND TOTAL", style: const pw.TextStyle(fontSize: 8, color: PdfColors.blueGrey800)),
                  pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(thickness: 0.5),
                  pw.Text("E. & O.E.", style: const pw.TextStyle(fontSize: 6, fontStyle: pw.FontStyle.italic)),
                ])),
            ])
          ]),
        );
      },
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Invoice_${sale.billNo}");
  }

  // ===================================================
  // 2. GOVERNMENT GST REPORT (PDF REPORT)
  // ===================================================
  static Future<void> generateGstReport(String title, List<Sale> allSales, String period) async {
    final pdf = pw.Document();
    List<Sale> activeSales = allSales.where((s) => s.status == "Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => pw.Column(children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text("Reporting Period: $period", style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(),
      ]),
      build: (pw.Context context) => [
        pw.Text("Table 4 & 7: Sales Details", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Date', 'Bill No', 'Party Name', 'GSTIN', 'POS', 'Taxable Value', 'Total Amt'],
          data: activeSales.map((s) => [
            DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.partyState, (s.totalAmount/1.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)
          ]).toList(),
        ),
        pw.SizedBox(height: 30),
        pw.Text("Table 12: HSN Summary", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildHsnPdfTable(activeSales),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_REPORT_$period");
  }

  // ===================================================
  // 3. GOVERNMENT JSON EXPORT (PORTAL UPLOAD)
  // ===================================================
  static Future<void> generateGstJson(List<Sale> allSales, String monthYear) async {
    final prefs = await SharedPreferences.getInstance();
    String myGstin = prefs.getString('compGST') ?? "YOUR_GSTIN";

    List<Map<String, dynamic>> b2bList = [];
    Map<String, Map<String, dynamic>> hsnMap = {};

    for (var s in allSales.where((s) => s.status == "Active")) {
      // 1. Build B2B List
      if (s.invoiceType == "B2B") {
        b2bList.add({
          "inv": [{
            "inum": s.billNo, "idt": DateFormat('dd-MM-yyyy').format(s.date), "val": s.totalAmount, "pos": "08", "itms": [{"itm_det": {"txval": s.totalAmount/1.12, "rt": 12}}]
          }]
        });
      }
      // 2. Build HSN Data
      for (var it in s.items) {
        if (!hsnMap.containsKey(it.hsn)) {
          hsnMap[it.hsn] = {"hsn_sc": it.hsn, "qty": 0.0, "txval": 0.0};
        }
        hsnMap[it.hsn]!['qty'] += it.qty;
        hsnMap[it.hsn]!['txval'] += (it.rate * it.qty);
      }
    }

    Map<String, dynamic> finalJson = {
      "gstin": myGstin,
      "fp": monthYear,
      "b2b": b2bList,
      "hsn": {"data": hsnMap.values.toList()},
      "doc_issue": {
        "doc_det": [{"doc_num": 1, "docs": [{"from": allSales.first.billNo, "to": allSales.last.billNo, "totnum": allSales.length, "cancel": allSales.where((x)=>x.status=="Cancelled").length}]}]
      }
    };

    String jsonString = jsonEncode(finalJson);
    await Share.share(jsonString, subject: "GSTR1_JSON_$monthYear");
  }

  // --- INTERNAL HELPER FOR HSN TABLE ---
  static pw.Widget _buildHsnPdfTable(List<Sale> sales) {
    Map<String, Map<String, dynamic>> hsn = {};
    for (var s in sales) {
      for (var it in s.items) {
        if (!hsn.containsKey(it.hsn)) hsn[it.hsn] = {'qty': 0.0, 'val': 0.0};
        hsn[it.hsn]!['qty'] += it.qty;
        hsn[it.hsn]!['val'] += (it.rate * it.qty);
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: ['HSN Code', 'Total Quantity', 'Taxable Value'],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      data: hsn.entries.map((e) => [e.key, e.value['qty'].toString(), e.value['val']!.toStringAsFixed(2)]).toList(),
    );
  }
}
