// FILE: lib/pdf/purchase_challan_pdf.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class PurchaseChallanPdf {
  static Future<void> generate(PurchaseChallan challan, Party supplier, CompanyProfile shop) async {
    final pdf = pw.Document();
    String compName = shop.name.toUpperCase();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape, 
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return pw.Container(
            decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
            child: pw.Column(
              children: [
                _buildHeader(shop, challan, supplier),
                pw.TableHelper.fromTextArray(
                  headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold),
                  cellStyle: const pw.TextStyle(fontSize: 8),
                  headers: ['S.N', 'ITEM NAME', 'PACK', 'BATCH', 'EXP', 'QTY', 'RATE', 'TOTAL'],
                  data: challan.items.map((i) => [
                    i.srNo, i.name, i.packing, i.batch, i.exp, i.qty.toInt(), i.purchaseRate.toStringAsFixed(2), i.total.toStringAsFixed(2)
                  ]).toList(),
                ),
                pw.Spacer(),
                _buildFooter(challan),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Inward_${challan.internalNo}');
  }

  static pw.Widget _buildHeader(CompanyProfile shop, PurchaseChallan challan, Party supplier) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(shop.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.Text("PURCHASE INWARD NOTE (CHALLAN)", style: const pw.TextStyle(fontSize: 10)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text("Internal ID: ${challan.internalNo}"),
            pw.Text("Supplier Ref: ${challan.billNo}"),
            pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(challan.date)}"),
          ]),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter(PurchaseChallan challan) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      color: PdfColors.grey100,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text("Remarks: ${challan.remarks}", style: const pw.TextStyle(fontSize: 9)),
          pw.Text("Total Value: Rs. ${challan.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );
  }
}
