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
  // 1. PROFESSIONAL LANDSCAPE INVOICE (FULL A4 FILL)
  // ===================================================
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();

    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    String cAddr = prefs.getString('compAddr') ?? "Address";
    String cGst = prefs.getString('compGST') ?? "N/A";
    String cDl = prefs.getString('compDL') ?? "N/A";
    String cPh = prefs.getString('compPh') ?? "0000";
    String cEm = prefs.getString('compEmail') ?? "N/A";

    // GST Slabs Calculation
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
        margin: const pw.EdgeInsets.all(10),
        build: (pw.Context context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5)),
          child: pw.Column(children: [
            // --- HEADER: 3 BOXES ---
            pw.Row(children: [
              pw.Expanded(child: pw.Container(height: 105, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(cName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  pw.Text(cAddr, style: const pw.TextStyle(fontSize: 8)),
                  pw.Spacer(),
                  pw.Text("GSTIN: $cGst", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text("DL: $cDl | Email: $cEm", style: const pw.TextStyle(fontSize: 8)),
                ]))),
              pw.Expanded(child: pw.Container(height: 105, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5), color: PdfColors.grey100), 
                child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                  pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                  pw.Text("No: ${sale.billNo}", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}", style: const pw.TextStyle(fontSize: 10)),
                  pw.Text("Page ${i+1} of $totalPages", style: const pw.TextStyle(fontSize: 8)),
                ]))),
              pw.Expanded(child: pw.Container(height: 105, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), 
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Text(sale.partyName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(sale.partyAddress, style: const pw.TextStyle(fontSize: 8), maxLines: 2),
                  pw.Spacer(),
                  pw.Text("GSTIN: ${sale.partyGstin}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text("DL: ${sale.partyDl} | State: ${sale.partyState}", style: const pw.TextStyle(fontSize: 8)),
                ]))),
            ]),

            // --- TABLE ---
            pw.Expanded(child: pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headers: ['S.N', 'Product Name', 'Batch', 'Exp', 'Qty', 'MRP', 'Rate', 'GST%', 'Total'],
              data: pItems.map((it)=>[it.srNo, it.name, it.batch, it.exp, it.qty.toInt(), it.mrp.toStringAsFixed(2), it.rate.toStringAsFixed(2), "${it.gstRate.toInt()}%", it.total.toStringAsFixed(2)]).toList(),
            )),

            // --- FOOTER ---
            if (isLast)
              pw.Container(padding: const pw.EdgeInsets.all(5), decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 1))),
                child: pw.Row(children: [
                  pw.Container(width: 380, child: pw.TableHelper.fromTextArray(
                    headers: ['Tax Slab Summary', 'Taxable Val', 'GST Amt'],
                    data: slabs.entries.map((e)=>["GST ${e.key.toInt()}% Slab", e.value['taxable']!.toStringAsFixed(2), e.value['gst']!.toStringAsFixed(2)]).toList(),
                  )),
                  pw.Spacer(),
                  pw.Container(width: 250, padding: const pw.EdgeInsets.all(10), color: PdfColors.grey200, child: pw.Column(children: [
                    pw.Text("GRAND TOTAL", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.Divider(thickness: 0.5),
                    pw.Text("Rupees ${sale.totalAmount.toInt()} Only", style: const pw.TextStyle(fontSize: 8)),
                  ])),
                ]))
            else
              pw.Container(padding: const pw.EdgeInsets.all(10), alignment: pw.Alignment.centerRight, child: pw.Text("Continued to Page ${i+2}...", style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic))),
          ]),
        ),
      ));
    }

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Bill_${sale.billNo}", format: PdfPageFormat.a4.landscape);
  }

  // ===================================================
  // 2. GSTR-1 LANDSCAPE PDF REPORT
  // ===================================================
  static Future<void> generateGstReport(String title, List<Sale> all, String p) async {
    final pdf = pw.Document();
    List<Sale> active = all.where((s)=>s.status=="Active").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => pw.Column(children: [pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)), pw.Text("Period: $p"), pw.Divider()]),
      build: (c) => [
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          headers: ['Date', 'Bill No', 'Party', 'GSTIN', 'Taxable', 'Total'],
          data: active.map((s)=>[DateFormat('dd/MM/yy').format(s.date), s.billNo, s.partyName, s.partyGstin, (s.totalAmount/1.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)]).toList(),
        ),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), format: PdfPageFormat.a4.landscape);
  }

  // ===================================================
  // 3. GSTR-1 JSON EXPORT
  // ===================================================
  static Future<void> generateGstJson(List<Sale> all, String month) async {
    final p = await SharedPreferences.getInstance();
    List b2b = []; Map hsn = {};
    for (var s in all.where((s)=>s.status=="Active")) {
      if (s.invoiceType == "B2B") b2b.add({"inv": [{"inum": s.billNo, "idt": DateFormat('dd-MM-yyyy').format(s.date), "val": s.totalAmount, "pos": "08", "itms": [{"itm_det": {"txval": s.totalAmount/1.12, "rt": 12}}]}]});
      for (var it in s.items) {
        if (!hsn.containsKey(it.hsn)) hsn[it.hsn] = {"hsn_sc": it.hsn, "qty": 0.0, "txval": 0.0};
        hsn[it.hsn]!['qty'] += it.qty; hsn[it.hsn]!['txval'] += (it.rate * it.qty);
      }
    }
    String js = jsonEncode({"gstin": p.getString('compGST'), "fp": month, "b2b": b2b, "hsn": {"data": hsn.values.toList()}});
    await Share.share(js, subject: "GSTR1_$month");
  }
}
