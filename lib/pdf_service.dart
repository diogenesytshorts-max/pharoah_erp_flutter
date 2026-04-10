import 'dart:convert';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'models.dart';
import 'package:intl/intl.dart';

class PdfService {
  static Future<void> generateInvoice(Sale sale, Party party) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    pdf.addPage(pw.Page(pageFormat: PdfPageFormat.a4.landscape, build: (pw.Context context) {
      return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(cName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text("Bill To: ${party.name}"), pw.Text("Inv: ${sale.billNo}\nDate: ${DateFormat('dd/MM/yy').format(sale.date)}")]),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(headers: ['SN', 'Product', 'Batch', 'Exp', 'Qty', 'Rate', 'Total'], data: sale.items.map((i) => [i.srNo, i.name, i.batch, i.exp, i.qty.toInt(), i.rate, i.total.toStringAsFixed(2)]).toList()),
        pw.Divider(),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Grand Total: ₹${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
      ]);
    }));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Invoice_${sale.billNo}");
  }

  static Future<void> generateGstReport(String title, List<Sale> sales, String month) async {
    final pdf = pw.Document();
    pdf.addPage(pw.MultiPage(pageFormat: PdfPageFormat.a4.landscape, margin: const pw.EdgeInsets.all(20), build: (pw.Context context) => [
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
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_Report_$month");
  }

  static Future<void> generateGstJson(List<Sale> sales, String monthYear) async {
    List<Map<String, dynamic>> b2b = [];
    Map<String, Map<String, dynamic>> hsn = {};
    for (var s in sales) {
      if (s.invoiceType == "B2B") {
        b2b.add({"inv": [{"inum": s.billNo, "idt": DateFormat('dd-MM-yyyy').format(s.date), "val": s.totalAmount, "itms": [{"itm_det": {"txval": s.totalAmount, "rt": 12}}]}]});
      }
      for (var it in s.items) {
        if (!hsn.containsKey(it.hsn)) hsn[it.hsn] = {"hsn_sc": it.hsn, "qty": 0.0, "txval": 0.0};
        hsn[it.hsn]!['qty'] += it.qty; hsn[it.hsn]!['txval'] += (it.rate * it.qty);
      }
    }
    String js = jsonEncode({"b2b": b2b, "hsn": {"data": hsn.values.toList()}});
    await Share.share(js, subject: "GSTR1_$monthYear");
  }
}
