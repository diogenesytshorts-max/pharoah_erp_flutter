import 'dart:math';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  // 2. GOVERNMENT GST REPORT (Portal Filing ke liye)
  // ===================================================
  static Future<void> generateGstReport(String title, List<Sale> sales, List<Purchase> purchases, String currentMonth) async {
    final pdf = pw.Document();
    final prefs = await SharedPreferences.getInstance();
    String cName = prefs.getString('compName') ?? "Pharoah ERP";

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape, // Landscape best hai tabular data ke liye
      margin: const pw.EdgeInsets.all(20),
      header: (pw.Context context) => pw.Column(children: [
        pw.Text(cName, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Text(title, style: const pw.TextStyle(fontSize: 12)),
        pw.Divider(),
      ]),
      build: (pw.Context context) {
        
        // --- SECTION A: GSTR-1 (SALES) DETAIL ---
        if (title.contains("GSTR-1")) {
          return [
            pw.Text("Detailed Sales Register (Table 4A, 4B, 7)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
                return [
                  DateFormat('dd/MM').format(s.date),
                  s.billNo,
                  s.partyName,
                  "N/A", // Party GSTIN Model se fetch hona baki hai
                  taxable.toStringAsFixed(2),
                  cgst.toStringAsFixed(2),
                  sgst.toStringAsFixed(2),
                  igst.toStringAsFixed(2),
                  s.totalAmount.toStringAsFixed(2)
                ];
              }).toList(),
            ),
            pw.SizedBox(height: 20),
            pw.Text("HSN Wise Summary (Table 12)", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            _buildHsnTable(sales),
          ];
        }

        // --- SECTION B: GSTR-3B (SUMMARY) ---
        if (title.contains("GSTR-3B")) {
          double sTaxable = 0; double sCgst = 0; double sSgst = 0; double sIgst = 0;
          for (var s in sales) {
            for (var it in s.items) {
              sTaxable += (it.rate * it.qty) - it.discountRupees;
              sCgst += it.cgst; sSgst += it.sgst; sIgst += it.igst;
            }
          }
          return [
            pw.Text("Consolidated Tax Summary", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),
            pw.TableHelper.fromTextArray(
              headers: ['Nature of Supplies', 'Total Taxable Value', 'Integrated Tax', 'Central Tax', 'State Tax'],
              data: [
                ['3.1 Outward Taxable Supplies (Sales)', sTaxable.toStringAsFixed(2), sIgst.toStringAsFixed(2), sCgst.toStringAsFixed(2), sSgst.toStringAsFixed(2)],
                ['4. Eligible ITC (Purchases)', 'As per Books', '...', '...', '...'],
              ],
            ),
          ];
        }

        return [pw.Text("Report type not defined.")];
      },
    ));

    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: "GST_REPORT_$currentMonth");
  }

  // --- HELPER: HSN SUMMARY TABLE ---
  static pw.Widget _buildHsnTable(List<Sale> sales) {
    Map<String, Map<String, dynamic>> hsnMap = {};
    for (var s in sales) {
      for (var it in s.items) {
        if (!hsnMap.containsKey(it.hsn)) {
          hsnMap[it.hsn] = {'qty': 0.0, 'taxable': 0.0, 'tax': 0.0};
        }
        hsnMap[it.hsn]!['qty'] += it.qty;
        hsnMap[it.hsn]!['taxable'] += (it.rate * it.qty);
        hsnMap[it.hsn]!['tax'] += (it.cgst + it.sgst + it.igst);
      }
    }

    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['HSN Code', 'Total Qty', 'Total Taxable Value', 'Total GST Amount'],
      data: hsnMap.entries.map((e) => [
        e.key,
        e.value['qty'].toString(),
        e.value['taxable'].toStringAsFixed(2),
        e.value['tax'].toStringAsFixed(2)
      ]).toList(),
    );
  }
}
