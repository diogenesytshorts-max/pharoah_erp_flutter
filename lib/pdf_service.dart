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
  // 1. RETAIL/TAX INVOICE (Customer ke liye)
  // ===================================================
  static Future<void> generateInvoice(Sale sale, Party party, {bool isPurchase = false}) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = prefs.getString('compName') ?? "Pharoah ERP";
    String cGst = prefs.getString('compGST') ?? "GSTIN NOT SET";

    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4.landscape,
      build: (pw.Context context) {
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(cName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.Text("GSTIN: $cGst"),
          pw.Divider(),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("Bill To: ${party.name}\nGSTIN: ${party.gst}"),
            pw.Text("Invoice: ${sale.billNo}\nDate: ${DateFormat('dd/MM/yyyy').format(sale.date)}"),
          ]),
          pw.SizedBox(height: 10),
          pw.TableHelper.fromTextArray(
            headers: ['S.N', 'Product', 'Batch', 'Qty', 'Rate', 'GST%', 'Total'],
            data: sale.items.map((i) => [i.srNo, i.name, i.batch, i.qty.toInt(), i.rate, "${i.gstRate}%", i.total.toStringAsFixed(2)]).toList(),
          ),
          pw.Divider(),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Grand Total: ₹${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold))),
        ]);
      },
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "Invoice_${sale.billNo}");
  }

  // ===================================================
  // 2. GOVERNMENT GST REPORT (PDF Format)
  // ===================================================
  static Future<void> generateGstReport(String title, List<Sale> sales, List<Purchase> purchases, String currentMonth) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = prefs.getString('compName') ?? "Pharoah ERP";

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => pw.Column(children: [
        pw.Text(cName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
        pw.Divider(),
      ]),
      build: (pw.Context context) {
        if (title.contains("GSTR-1")) {
          return [
            pw.Text("Detailed Sales Register", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['Date', 'Bill No', 'Party Name', 'GSTIN', 'Taxable Val', 'CGST', 'SGST', 'IGST', 'Total Amt'],
              data: sales.map((s) {
                double taxable = 0; double cgst = 0; double sgst = 0; double igst = 0;
                for (var it in s.items) {
                  taxable += (it.rate * it.qty) - it.discountRupees;
                  cgst += it.cgst; sgst += it.sgst; igst += it.igst;
                }
                return [DateFormat('dd/MM').format(s.date), s.billNo, s.partyName, "N/A", taxable.toStringAsFixed(2), cgst.toStringAsFixed(2), sgst.toStringAsFixed(2), igst.toStringAsFixed(2), s.totalAmount.toStringAsFixed(2)];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text("HSN Wise Summary", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            _buildHsnTable(sales),
          ];
        }
        return [pw.Text("Summary Report generated.")];
      },
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_REPORT_$currentMonth");
  }

  // ===================================================
  // 3. GOVERNMENT JSON EXPORT (Portal Filing)
  // ===================================================
  static Future<void> generateGstJson(List<Sale> sales, String monthYear) async {
    final prefs = await SharedPreferences.getInstance();
    String myGstin = prefs.getString('compGST') ?? "YOUR_GSTIN";

    // Build HSN Summary for JSON
    Map<String, Map<String, dynamic>> hsnData = {};
    List<Map<String, dynamic>> b2bList = [];

    for (var s in sales) {
      double taxable = 0; double igst = 0; double cgst = 0; double sgst = 0;
      for (var it in s.items) {
        taxable += (it.rate * it.qty);
        igst += it.igst; cgst += it.cgst; sgst += it.sgst;
        
        // HSN Grouping
        if (!hsnData.containsKey(it.hsn)) {
          hsnData[it.hsn] = {"hsn_sc": it.hsn, "desc": it.name, "uqc": "OTH", "qty": 0.0, "txval": 0.0, "iamt": 0.0, "camt": 0.0, "samt": 0.0};
        }
        hsnData[it.hsn]!['qty'] += it.qty;
        hsnData[it.hsn]!['txval'] += (it.rate * it.qty);
        hsnData[it.hsn]!['iamt'] += it.igst;
        hsnData[it.hsn]!['camt'] += it.cgst;
        hsnData[it.hsn]!['samt'] += it.sgst;
      }

      if (s.invoiceType == "B2B") {
        b2bList.add({
          "inv": [{
            "inum": s.billNo, "idt": DateFormat('dd-MM-yyyy').format(s.date), "val": s.totalAmount, "pos": "08", "rchrg": "N", "inv_typ": "R",
            "itms": [{"num": 1, "itm_det": {"txval": taxable, "rt": 12, "iamt": igst, "camt": cgst, "samt": sgst}}]
          }]
        });
      }
    }

    Map<String, dynamic> finalJson = {
      "gstin": myGstin,
      "fp": monthYear, // Format: MMYYYY
      "gt": 0.0, "cur_gt": 0.0,
      "b2b": b2bList,
      "hsn": {"data": hsnData.values.toList()}
    };

    String jsonString = jsonEncode(finalJson);
    await Share.share(jsonString, subject: "GSTR1_JSON_$monthYear");
  }

  static pw.Widget _buildHsnTable(List<Sale> sales) {
    Map<String, Map<String, dynamic>> hsnMap = {};
    for (var s in sales) {
      for (var it in s.items) {
        if (!hsnMap.containsKey(it.hsn)) hsnMap[it.hsn] = {'qty': 0.0, 'taxable': 0.0, 'tax': 0.0};
        hsnMap[it.hsn]!['qty'] += it.qty;
        hsnMap[it.hsn]!['taxable'] += (it.rate * it.qty);
        hsnMap[it.hsn]!['tax'] += (it.cgst + it.sgst + it.igst);
      }
    }
    return pw.TableHelper.fromTextArray(
      headers: ['HSN', 'Qty', 'Taxable Value', 'GST Amount'],
      data: hsnMap.entries.map((e) => [e.key, e.value['qty'].toString(), e.value['taxable'].toStringAsFixed(2), e.value['tax'].toStringAsFixed(2)]).toList(),
    );
  }
}
