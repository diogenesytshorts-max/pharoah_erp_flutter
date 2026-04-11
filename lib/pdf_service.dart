import 'dart:convert';
import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  // ===================================================
  // 1. PROFESSIONAL LANDSCAPE INVOICE (FULL PAGE FILL)
  // ===================================================
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    String cAddr = prefs.getString('compAddr') ?? "Office Address Line";
    String cGst = prefs.getString('compGST') ?? "GSTIN NOT SET";
    String cPh = prefs.getString('compPh') ?? "0000000000";

    // GST Slabs Calculation logic for the last page summary
    Map<double, Map<String, double>> slabs = {};
    for (var item in sale.items) {
      if (!slabs.containsKey(item.gstRate)) {
        slabs[item.gstRate] = {'taxable': 0, 'gst': 0};
      }
      double taxable = (item.rate * item.qty) - item.discountRupees;
      slabs[item.gstRate]!['taxable'] = slabs[item.gstRate]!['taxable']! + taxable;
      slabs[item.gstRate]!['gst'] = slabs[item.gstRate]!['gst']! + (item.cgst + item.sgst + item.igst);
    }

    // --- PAGINATION LOGIC (12 Items per Landscape Page) ---
    const int itemsPerPage = 12;
    int totalItems = sale.items.length;
    int totalPages = (totalItems / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int i = 0; i < totalPages; i++) {
      int start = i * itemsPerPage;
      int end = min(start + itemsPerPage, totalItems);
      List<BillItem> pageItems = sale.items.sublist(start, end);
      bool isLastPage = (i == totalPages - 1);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, // Strictly Landscape
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) {
          return pw.Container(
            width: double.infinity,
            height: double.infinity,
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
            child: pw.Column(children: [
              // --- HEADER: 3 EQUAL BOXES ---
              pw.Row(children: [
                // Box 1: Seller Details
                pw.Expanded(child: pw.Container(height: 95, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(cName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                    pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8)),
                    pw.Spacer(),
                    pw.Text("GSTIN: $cGst", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Mobile: $cPh", style: const pw.TextStyle(fontSize: 8)),
                  ]))),
                // Box 2: Invoice Info
                pw.Expanded(child: pw.Container(height: 95, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), color: PdfColors.grey100), 
                  child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                    pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text("No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 10)),
                    pw.Text("Page ${i + 1} of $totalPages", style: const pw.TextStyle(fontSize: 7)),
                  ]))),
                // Box 3: Buyer Details
                pw.Expanded(child: pw.Container(height: 95, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("BILL TO / BUYER:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
                    pw.Text(sale.partyName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    pw.Text("GSTIN: ${sale.partyGstin}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    pw.Text("POS: ${sale.partyState}", style: const pw.TextStyle(fontSize: 8)),
                  ]))),
              ]),

              // --- MAIN TABLE (Full Width) ---
              pw.Expanded(child: pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellStyle: const pw.TextStyle(fontSize: 9),
                columnWidths: {
                  0: const pw.FixedColumnWidth(30), // S.N
                  1: const pw.FlexColumnWidth(3),   // Description
                  7: const pw.FixedColumnWidth(40), // GST%
                },
                headers: ['S.N', 'Product Name', 'Batch', 'Exp', 'Qty', 'MRP', 'Rate', 'GST%', 'Total'],
                data: pageItems.map((it) => [
                  it.srNo, it.name, it.batch, it.exp, it.qty.toInt(), 
                  it.mrp.toStringAsFixed(2), it.rate.toStringAsFixed(2), 
                  "${it.gstRate.toInt()}%", it.total.toStringAsFixed(2)
                ]).toList(),
              )),

              // --- FOOTER SECTION ---
              if (isLastPage)
                pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
                  child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    // Slab Breakdown
                    pw.Container(width: 380, child: pw.TableHelper.fromTextArray(
                      headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
                      cellStyle: const pw.TextStyle(fontSize: 7),
                      headers: ['Tax Slab Summary', 'Taxable Val', 'GST Amount'],
                      data: slabs.entries.map((e) => [
                        "GST ${e.key.toInt()}% Items", e.value['taxable']!.toStringAsFixed(2), e.value['gst']!.toStringAsFixed(2)
                      ]).toList(),
                    )),
                    pw.Spacer(),
                    // Total Box
                    pw.Container(width: 250, padding: const pw.EdgeInsets.all(10), decoration: pw.BoxDecoration(border: pw.Border.all(width: 1), color: PdfColors.grey200),
                      child: pw.Column(children: [
                        pw.Text("GRAND TOTAL", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                        pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                        pw.Divider(thickness: 0.5),
                        pw.Text("Rupees ${sale.totalAmount.toInt()} Only", style: const pw.TextStyle(fontSize: 7)),
                      ])),
                  ]),
                )
              else
                pw.Container(
                  padding: const EdgeInsets.all(8),
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text("Continued to Page ${i + 2}...", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
                )
            ]),
          );
        },
      ));
    }

    // Final Print Trigger with Forced Landscape Format
    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(), 
      name: "Invoice_${sale.billNo}", 
      format: PdfPageFormat.a4.landscape
    );
  }

  // ===================================================
  // 2. GSTR-1 PROFESSIONAL REPORT (PDF)
  // ===================================================
  static Future<void> generateGstReport(String title, List<Sale> allSales, String period) async {
    final pdf = pw.Document();
    List<Sale> active = allSales.where((s) => s.status == "Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => pw.Column(children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text("Reporting Period: $period", style: const pw.TextStyle(fontSize: 10)),
        pw.Divider(),
      ]),
      build: (pw.Context context) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Date', 'Bill No', 'Party Name', 'GSTIN', 'POS', 'Taxable Value', 'Total Amt'],
          data: active.map((s) => [
            DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.partyState, 
            (s.totalAmount/1.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)
          ]).toList(),
        ),
        pw.SizedBox(height: 30),
        pw.Text("HSN Wise Summary Table", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildHsnPdfTable(active),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_Report_$period", format: PdfPageFormat.a4.landscape);
  }

  // ===================================================
  // 3. GSTR-1 PORTAL JSON EXPORT
  // ===================================================
  static Future<void> generateGstJson(List<Sale> allSales, String monthYear) async {
    final prefs = await SharedPreferences.getInstance();
    String myGstin = prefs.getString('compGST') ?? "YOUR_GSTIN";

    List<Map<String, dynamic>> b2bList = [];
    Map<String, Map<String, dynamic>> hsnMap = {};

    for (var s in allSales.where((s) => s.status == "Active")) {
      if (s.invoiceType == "B2B") {
        b2bList.add({
          "inv": [{
            "inum": s.billNo, "idt": DateFormat('dd-MM-yyyy').format(s.date), "val": s.totalAmount, "pos": "08", 
            "itms": [{"itm_det": {"txval": s.totalAmount/1.12, "rt": 12, "camt": (s.totalAmount - s.totalAmount/1.12)/2, "samt": (s.totalAmount - s.totalAmount/1.12)/2}}]
          }]
        });
      }
      for (var it in s.items) {
        if (!hsnMap.containsKey(it.hsn)) hsnMap[it.hsn] = {"hsn_sc": it.hsn, "qty": 0.0, "txval": 0.0, "camt": 0.0, "samt": 0.0};
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

    await Share.share(jsonEncode(finalJson), subject: "GSTR1_JSON_$monthYear");
  }

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
      headers: ['HSN Code', 'Total Qty', 'Taxable Value'],
      data: hsn.entries.map((e) => [e.key, e.value['qty'].toString(), e.value['val']!.toStringAsFixed(2)]).toList(),
    );
  }
}
