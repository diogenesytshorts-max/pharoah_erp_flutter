import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  // --- 1. RETAIL/TAX INVOICE (Landscape) ---
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = prefs.getString('compName') ?? "Pharoah ERP";

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(cName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("Bill To: ${sale.partyName}\nGSTIN: ${sale.partyGstin}\nState: ${sale.partyState}"),
            pw.Text("Invoice No: ${sale.billNo}\nDate: ${DateFormat('dd/MM/yyyy').format(sale.date)}"),
          ]),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['S.N', 'Product', 'Batch', 'Exp', 'Qty', 'Rate', 'GST%', 'Total'],
            data: sale.items.map((i) => [i.srNo, i.name, i.batch, i.exp, i.qty.toInt(), i.rate, "${i.gstRate}%", i.total.toStringAsFixed(2)]).toList(),
          ),
          pw.Divider(),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Grand Total: Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        ]);
      },
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Invoice_${sale.billNo}");
  }

  // --- 2. GSTR-1 PROFESSIONAL PDF REPORT (Marg Style) ---
  static Future<void> generateGstReport(String title, List<Sale> allSales, String month) async {
    final pdf = pw.Document();
    List<Sale> active = allSales.where((s) => s.status == "Active").toList();
    List<Sale> b2b = active.where((s) => s.invoiceType == "B2B").toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      build: (pw.Context context) => [
        pw.Text("$title - $month", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        pw.Text("Table 4: B2B Invoices", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.TableHelper.fromTextArray(
          headers: ['Date', 'Bill No', 'Party', 'GSTIN', 'Taxable', 'Total'],
          data: b2b.map((s) => [DateFormat('dd/MM').format(s.date), s.billNo, s.partyName, s.partyGstin, (s.totalAmount/1.12).toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)]).toList(),
        ),
        pw.SizedBox(height: 20),
        pw.Text("Table 12: HSN Summary", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        _buildHsnTable(active),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_Report_$month");
  }

  // --- 3. GSTR-1 PORTAL JSON EXPORT ---
  static Future<void> generateGstJson(List<Sale> allSales, String monthYear) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, dynamic>> b2bList = [];
    Map<String, Map<String, dynamic>> hsnMap = {};

    for (var s in allSales.where((s) => s.status == "Active")) {
      if (s.invoiceType == "B2B") {
        b2bList.add({"inv": [{"inum": s.billNo, "idt": DateFormat('dd-MM-yyyy').format(s.date), "val": s.totalAmount, "itms": [{"itm_det": {"txval": s.totalAmount/1.12, "rt": 12}}]}]});
      }
      for (var it in s.items) {
        if (!hsnMap.containsKey(it.hsn)) hsnMap[it.hsn] = {"hsn_sc": it.hsn, "qty": 0.0, "txval": 0.0};
        hsnMap[it.hsn]!['qty'] += it.qty; hsnMap[it.hsn]!['txval'] += (it.rate * it.qty);
      }
    }

    String js = jsonEncode({"gstin": prefs.getString('compGST'), "fp": monthYear, "b2b": b2bList, "hsn": {"data": hsnMap.values.toList()}});
    await Share.share(js, subject: "GSTR1_JSON_$monthYear");
  }

  static pw.Widget _buildHsnTable(List<Sale> sales) {
    Map<String, Map<String, dynamic>> hsn = {};
    for (var s in sales) {
      for (var it in s.items) {
        if (!hsn.containsKey(it.hsn)) hsn[it.hsn] = {'qty': 0.0, 'val': 0.0};
        hsn[it.hsn]!['qty'] += it.qty; hsn[it.hsn]!['val'] += (it.rate * it.qty);
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: ['HSN Code', 'Qty', 'Taxable Value'],
      data: hsn.entries.map((e) => [e.key, e.value['qty'].toString(), e.value['val']!.toStringAsFixed(2)]).toList(),
    );
  }
}
