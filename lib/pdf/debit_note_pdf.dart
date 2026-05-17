// FILE: lib/pdf/debit_note_pdf.dart

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import '../logic/app_settings_model.dart';
import 'pdf_master_service.dart';

class DebitNotePdf {
  static Future<void> generate(PurchaseReturn ret, Party supplier, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();
    
    final sellable = ret.items.where((i) => !i.isBreakage).toList();
    final breakage = ret.items.where((i) => i.isBreakage).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(15),
      header: (context) => _buildHeader(shop, ret, supplier),
      build: (context) => [
        if (sellable.isNotEmpty) ...[
          _sectionTitle("SELLABLE RETURNS TO SUPPLIER"),
          _buildTable(sellable),
          pw.SizedBox(height: 15),
        ],
        if (breakage.isNotEmpty) ...[
          _sectionTitle("EXPIRY / BREAKAGE RETURNS"),
          _buildTable(breakage),
        ],
        pw.Divider(thickness: 1),
        _buildSummary(ret, shop),
      ],
    ));
    await Printing.layoutPdf(onLayout: (f) async => pdf.save(), name: 'DebitNote_${ret.billNo}');
  }

  static pw.Widget _sectionTitle(String t) => pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 5), child: pw.Text(t, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)));

  static pw.Widget _buildHeader(CompanyProfile shop, PurchaseReturn ret, Party supplier) => pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
    child: pw.Row(children: [
      _hBox(280, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)), pw.Text(shop.address, style: const pw.TextStyle(fontSize: 7))])),
      _hBox(180, true, pw.Column(children: [pw.Text("DEBIT NOTE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900)), pw.Divider(thickness: 0.5), pw.Text("No: ${ret.billNo}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)), pw.Text(DateFormat('dd/MM/yyyy').format(ret.date), style: const pw.TextStyle(fontSize: 9))])),
      _hBox(340, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [pw.Text("SUPPLIER DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)), pw.Text(supplier.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)), pw.Text("GST: ${supplier.gst}", style: const pw.TextStyle(fontSize: 8))])),
    ]),
  );

  static pw.Widget _buildTable(List<PurchaseItem> list) => pw.TableHelper.fromTextArray(
    headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.brown700),
    headers: ['S.N', 'Product Name', 'Pack', 'Batch', 'Qty', 'MRP', 'Pur.Rate', 'GST%', 'Total'],
    data: list.asMap().entries.map((e) => ["${e.key+1}", e.value.name, e.value.packing, e.value.batch, "${e.value.qty.toInt()}", e.value.mrp.toStringAsFixed(2), e.value.purchaseRate.toStringAsFixed(2), "${e.value.gstRate}%", e.value.total.toStringAsFixed(2)]).toList(),
  );

  static pw.Widget _buildSummary(PurchaseReturn ret, CompanyProfile shop) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
    pw.Text("Amt: RUPEES ${PdfMasterService.numberToWords(ret.totalAmount.round())} ONLY", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
    pw.Container(padding: const pw.EdgeInsets.all(10), decoration: const pw.BoxDecoration(color: PdfColors.grey100), child: pw.Text("NET DEBIT: Rs. ${ret.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.brown900))),
  ]);

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 80, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0))), child: child);
}
