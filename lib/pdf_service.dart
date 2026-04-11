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
  // 1. PROFESSIONAL LANDSCAPE INVOICE (FULL A4)
  // ===================================================
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    // --- LOAD ALL COMPANY DETAILS ---
    String cName = (prefs.getString('compName') ?? "PHAROAH ERP").toUpperCase();
    String cAddr = prefs.getString('compAddr') ?? "Address Not Set";
    String cGst = prefs.getString('compGST') ?? "N/A";
    String cDl = prefs.getString('compDL') ?? "N/A";
    String cPh = prefs.getString('compPh') ?? "0000000000";
    String cEm = prefs.getString('compEmail') ?? "N/A";
    String cSt = prefs.getString('compState') ?? "Rajasthan";

    // --- GST SLABS CALCULATION ---
    Map<double, Map<String, double>> slabs = {};
    for (var it in sale.items) {
      if (!slabs.containsKey(it.gstRate)) slabs[it.gstRate] = {'taxable': 0, 'gst': 0};
      double txbl = (it.rate * it.qty) - it.discountRupees;
      slabs[it.gstRate]!['taxable'] = slabs[it.gstRate]!['taxable']! + txbl;
      slabs[it.gstRate]!['gst'] = slabs[it.gstRate]!['gst']! + (it.cgst + it.sgst + it.igst);
    }

    const int itemsPerPage = 12;
    int totalPages = (sale.items.length / itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;

    for (int i = 0; i < totalPages; i++) {
      int start = i * itemsPerPage;
      int end = min(start + itemsPerPage, sale.items.length);
      List<BillItem> pItems = sale.items.sublist(start, end);
      bool isLast = (i == totalPages - 1);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(12),
        build: (pw.Context context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
          child: pw.Column(children: [
            // --- HEADER: 3 DISTINCT BOXES ---
            pw.Row(children: [
              // Box 1: Seller Details
              pw.Expanded(child: pw.Container(height: 110, padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(cName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(cAddr, style: const pw.TextStyle(fontSize: 9), maxLines: 2),
                  pw.Spacer(),
                  pw.Text("GSTIN: $cGst", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text("D.L. No: $cDl", style: const pw.TextStyle(fontSize: 9)),
                  pw.Text("Contact: $cPh | $cEm", style: const pw.TextStyle(fontSize: 8)),
                ]))),
              // Box 2: Invoice Info
              pw.Expanded(child: pw.Container(height: 110, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), color: PdfColors.grey100), 
                child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                  pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text("Invoice No: ${sale.billNo}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 11)),
                  pw.Text("Page ${i+1} of $totalPages", style: const pw.TextStyle(fontSize: 8)),
                ]))),
              // Box 3: Buyer Details
              pw.Expanded(child: pw.Container(height: 110, padding: const pw.EdgeInsets.all(6), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("BILL TO / BUYER:", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Text(sale.partyName, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                  pw.Text(sale.partyAddress, style: const pw.TextStyle(fontSize: 9), maxLines: 2),
                  pw.Spacer(),
                  pw.Text("GSTIN: ${sale.partyGstin}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text("D.L. No: ${sale.partyDl} | State: ${sale.partyState}", style: const pw.TextStyle(fontSize: 9)),
                ]))),
            ]),

            // --- TABLE SECTION ---
            pw.Expanded(child: pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 10),
              columnWidths: {0: const pw.FixedColumnWidth(30), 1: const pw.FlexColumnWidth(3), 4: const pw.FixedColumnWidth(40)},
              headers: ['S.N', 'Product Description', 'Batch', 'Exp', 'Qty', 'MRP', 'Rate', 'GST%', 'Total'],
              data: pItems.map((it)=>[
                it.srNo, it.name, it.batch, it.exp, it.qty.toInt(), 
                it.mrp.toStringAsFixed(2), it.rate.toStringAsFixed(2), 
                "${it.gstRate.toInt()}%", it.total.toStringAsFixed(2)
              ]).toList(),
            )),
            // --- FOOTER SECTION (Summary & Slabs only on last page) ---
            if (isLast)
              pw.Container(
                padding: const EdgeInsets.all(5),
                decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  // GST Slab Summary Table
                  pw.Container(width: 400, child: pw.TableHelper.fromTextArray(
                    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                    cellStyle: const pw.TextStyle(fontSize: 8),
                    headers: ['Tax Slab Summary', 'Taxable Value', 'GST Amount'],
                    data: slabs.entries.map((e) => [
                      "GST ${e.key.toInt()}% Slab Items", 
                      e.value['taxable']!.toStringAsFixed(2), 
                      e.value['gst']!.toStringAsFixed(2)
                    ]).toList(),
                  )),
                  pw.Spacer(),
                  // Total Amount Box
                  pw.Container(
                    width: 250, padding: const pw.EdgeInsets.all(10), 
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 1), color: PdfColors.grey200),
                    child: pw.Column(children: [
                      pw.Text("GRAND TOTAL", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                      pw.Divider(thickness: 1),
                      pw.Text("Rupees ${sale.totalAmount.toInt()} Only", style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                    ])),
                ]),
              )
            else
              pw.Container(
                padding: const pw.EdgeInsets.all(8),
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Continued to Page ${i + 2}...", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic)),
              )
          ]),
        ),
      ));
    }

    // Direct Print Command with Forced Landscape Format
    await Printing.layoutPdf(
      onLayout: (f) async => pdf.save(), 
      name: "Invoice_${sale.billNo}",
      format: PdfPageFormat.a4.landscape 
    );
  }

  // ===================================================
  // 2. GSTR-1 PROFESSIONAL PDF REPORT (LANDSCAPE)
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
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          headers: ['Date', 'Bill No', 'Party Name', 'GSTIN', 'POS', 'Taxable Value', 'Total Amt'],
          data: activeSales.map((s) => [
            DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.partyState, 
            (s.totalAmount/1.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)
          ]).toList(),
        ),
        pw.SizedBox(height: 30),
        pw.Text("Table 12: HSN Wise Summary", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildHsnPdfTable(activeSales),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_REPORT_$period", format: PdfPageFormat.a4.landscape);
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
        if (!hsnMap.containsKey(it.hsn)) {
          hsnMap[it.hsn] = {"hsn_sc": it.hsn, "qty": 0.0, "txval": 0.0, "camt": 0.0, "samt": 0.0};
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
        "doc_det": [{"doc_num": 1, "docs": [{"from": allSales.isNotEmpty ? allSales.first.billNo : "0", "to": allSales.isNotEmpty ? allSales.last.billNo : "0", "totnum": allSales.length, "cancel": allSales.where((x)=>x.status=="Cancelled").length}]}]
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
      headers: ['HSN Code', 'Total Quantity', 'Taxable Value'],
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      data: hsn.entries.map((e) => [e.key, e.value['qty'].toString(), e.value['val']!.toStringAsFixed(2)]).toList(),
    );
  }
}
