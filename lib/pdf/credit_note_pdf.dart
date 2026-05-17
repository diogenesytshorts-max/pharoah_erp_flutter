// FILE: lib/pdf/credit_note_pdf.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import '../logic/app_settings_model.dart';
import 'pdf_master_service.dart';

class CreditNotePdf {
  static Future<void> generate(SaleReturn ret, Party party, CompanyProfile shop, AppConfig config) async {
    final pdf = pw.Document();
    const double masterWidth = 800;

    // Filter items into two lists
    final sellable = ret.items.where((i) => !i.isBreakage).toList();
    final breakage = ret.items.where((i) => i.isBreakage).toList();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.all(15),
      header: (context) => _buildHeader(shop, ret, party, config),
      footer: (context) => pw.Container(
        alignment: pw.Alignment.centerRight,
        child: pw.Text("Page ${context.pageNumber} of ${context.pagesCount}", style: const pw.TextStyle(fontSize: 8)),
      ),
      build: (context) => [
        // SECTION 1: SELLABLE
        if (sellable.isNotEmpty) ...[
          _sectionTitle("SECTION A: SELLABLE RETURNS (STOCK RE-ENTRY)"),
          _buildTable(sellable),
          pw.SizedBox(height: 15),
        ],
        // SECTION 2: BREAKAGE
        if (breakage.isNotEmpty) ...[
          _sectionTitle("SECTION B: EXPIRY & BREAKAGE (NON-SELLABLE)"),
          _buildTable(breakage),
        ],
        pw.Divider(thickness: 1, color: PdfColors.grey400),
        _buildSummary(ret, config, shop),
      ],
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'CreditNote_${ret.billNo}');
  }

  static pw.Widget _sectionTitle(String t) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 5),
    child: pw.Text(t, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
  );

  static pw.Widget _buildHeader(CompanyProfile shop, SaleReturn ret, Party party, AppConfig config) {
    return pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)),
      child: pw.Row(children: [
        _hBox(280, true, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text(shop.address, style: const pw.TextStyle(fontSize: 7)),
          pw.Text("GST: ${shop.gstin}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        ])),
        _hBox(180, true, pw.Column(children: [
          pw.Text("CREDIT NOTE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
          pw.Divider(thickness: 0.5),
          pw.Text("No: ${ret.billNo}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(ret.date)}", style: const pw.TextStyle(fontSize: 9)),
        ])),
        _hBox(340, false, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("CUSTOMER DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
          pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
          pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: const pw.TextStyle(fontSize: 8)),
        ])),
      ]),
    );
  }

  static pw.Widget _buildTable(List<BillItem> list) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellStyle: const pw.TextStyle(fontSize: 8),
      headers: ['S.N', 'Product Name', 'Pack', 'Batch', 'Qty', 'MRP', 'Rate', 'GST%', 'Total'],
      data: list.asMap().entries.map((e) => [
        "${e.key + 1}", e.value.name, e.value.packing, e.value.batch, 
        "${e.value.qty.toInt()}", e.value.mrp.toStringAsFixed(2), 
        e.value.rate.toStringAsFixed(2), "${e.value.gstRate}%", e.value.total.toStringAsFixed(2)
      ]).toList(),
    );
  }

  static pw.Widget _buildSummary(SaleReturn ret, AppConfig config, CompanyProfile shop) {
    return pw.Row(children: [
      pw.Expanded(flex: 2, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("Amt in Words: RUPEES ${PdfMasterService.numberToWords(ret.totalAmount.round())} ONLY", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 20),
        pw.Text("Note: This credit note is issued against sales return/breakage. The respective party's account has been credited.", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ])),
      pw.Expanded(flex: 1, child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: const pw.BoxDecoration(color: PdfColors.grey100),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("NET PAYABLE", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text("Rs. ${ret.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
        ])
      )),
    ]);
  }

  static pw.Widget _hBox(double w, bool b, pw.Widget child) => pw.Container(width: w, height: 80, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: b ? 0.5 : 0))), child: child);
}
