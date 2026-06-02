// FILE: lib/pdf/statements/company_stock_pdf.dart

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import '../../models.dart';
import '../../gateway/company_registry_model.dart';
import '../../finance/stock_flow_engine.dart';
import '../../pharoah_manager.dart';

class CompanyStockPdf {
  
  // 1. DIRECT PRINT IN LANDSCAPE
  static Future<void> generate({
    required CompanyProfile shop,
    required Map<String, List<Medicine>> groupedData,
    required DateTime from,
    required DateTime to,
    required String valuationBasis,
    required PharoahManager ph,
  }) async {
    final pdf = pw.Document();

    for (var companyName in groupedData.keys) {
      List<Medicine> meds = groupedData[companyName]!;
      if (meds.isEmpty) continue;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => _buildHeader(shop, companyName, from, to, valuationBasis),
          build: (context) {
            double totalOpStock = 0; double totalOpVal = 0;
            double totalRecQty = 0; double totalRecVal = 0;
            double totalIssueQty = 0; double totalIssueVal = 0;
            double totalCloStock = 0; double totalCloVal = 0;

            List<List<String>> tableRows = [];

            for (int i = 0; i < meds.length; i++) {
              var m = meds[i];
              final flow = StockFlowEngine.getItemFlow(med: m, from: from, to: to, ph: ph);
              double rate = (valuationBasis == "PURCHASE") ? m.purRate : (valuationBasis == "SALE" ? m.rateA : m.mrp);

              double opStock = (flow['opening'] ?? 0.0);
              double recQty = (flow['received'] ?? 0.0);
              double issueQty = (flow['sale'] ?? 0.0);
              double cloStock = (flow['closing'] ?? 0.0);

              double opVal = opStock * rate;
              double recVal = recQty * rate;
              double issueVal = issueQty * rate;
              double cloVal = cloStock * rate;

              totalOpStock += opStock; totalOpVal += opVal;
              totalRecQty += recQty; totalRecVal += recVal;
              totalIssueQty += issueQty; totalIssueVal += issueVal;
              totalCloStock += cloStock; totalCloVal += cloVal;

              tableRows.add([
                m.name,
                m.packing,
                opStock.toInt().toString(),
                opVal.toStringAsFixed(2),
                recQty.toInt().toString(),
                recVal.toStringAsFixed(2),
                issueQty.toInt().toString(),
                issueVal.toStringAsFixed(2),
                cloStock.toInt().toString(),
                cloVal.toStringAsFixed(2),
              ]);
            }

            // Append Grand Total Row at bottom of list
            tableRows.add([
              "TOTAL",
              "-",
              totalOpStock.toInt().toString(),
              totalOpVal.toStringAsFixed(2),
              totalRecQty.toInt().toString(),
              totalRecVal.toStringAsFixed(2),
              totalIssueQty.toInt().toString(),
              totalIssueVal.toStringAsFixed(2),
              totalCloStock.toInt().toString(),
              totalCloVal.toStringAsFixed(2),
            ]);

            return [
              _buildDataTable(tableRows),
            ];
          },
        ),
      );
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'Stock_Statement_${DateFormat('ddMMMyy').format(from)}',
    );
  }

  // 2. EMAIL COMPATIBLE BYTES GENERATION
  static Future<Uint8List> generateBytes({
    required CompanyProfile shop,
    required Map<String, List<Medicine>> groupedData,
    required DateTime from,
    required DateTime to,
    required String valuationBasis,
    required PharoahManager ph,
  }) async {
    final pdf = pw.Document();

    for (var companyName in groupedData.keys) {
      List<Medicine> meds = groupedData[companyName]!;
      if (meds.isEmpty) continue;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          header: (context) => _buildHeader(shop, companyName, from, to, valuationBasis),
          build: (context) {
            double totalOpStock = 0; double totalOpVal = 0;
            double totalRecQty = 0; double totalRecVal = 0;
            double totalIssueQty = 0; double totalIssueVal = 0;
            double totalCloStock = 0; double totalCloVal = 0;

            List<List<String>> tableRows = [];

            for (int i = 0; i < meds.length; i++) {
              var m = meds[i];
              final flow = StockFlowEngine.getItemFlow(med: m, from: from, to: to, ph: ph);
              double rate = (valuationBasis == "PURCHASE") ? m.purRate : (valuationBasis == "SALE" ? m.rateA : m.mrp);

              double opStock = (flow['opening'] ?? 0.0);
              double recQty = (flow['received'] ?? 0.0);
              double issueQty = (flow['sale'] ?? 0.0);
              double cloStock = (flow['closing'] ?? 0.0);

              double opVal = opStock * rate;
              double recVal = recQty * rate;
              double issueVal = issueQty * rate;
              double cloVal = cloStock * rate;

              totalOpStock += opStock; totalOpVal += opVal;
              totalRecQty += recQty; totalRecVal += recVal;
              totalIssueQty += issueQty; totalIssueVal += issueVal;
              totalCloStock += cloStock; totalCloVal += cloVal;

              tableRows.add([
                m.name,
                m.packing,
                opStock.toInt().toString(),
                opVal.toStringAsFixed(2),
                recQty.toInt().toString(),
                recVal.toStringAsFixed(2),
                issueQty.toInt().toString(),
                issueVal.toStringAsFixed(2),
                cloStock.toInt().toString(),
                cloVal.toStringAsFixed(2),
              ]);
            }

            tableRows.add([
              "TOTAL",
              "-",
              totalOpStock.toInt().toString(),
              totalOpVal.toStringAsFixed(2),
              totalRecQty.toInt().toString(),
              totalRecVal.toStringAsFixed(2),
              totalIssueQty.toInt().toString(),
              totalIssueVal.toStringAsFixed(2),
              totalCloStock.toInt().toString(),
              totalCloVal.toStringAsFixed(2),
            ]);

            return [
              _buildDataTable(tableRows),
            ];
          },
        ),
      );
    }
    return pdf.save();
  }

  // --- COMPACT MARG REPORT HEADER ---
  static pw.Widget _buildHeader(CompanyProfile shop, String company, DateTime from, DateTime to, String basis) {
    return pw.Column(children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start, 
            children: [
              pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
              pw.Text(shop.address.toUpperCase(), style: const pw.TextStyle(fontSize: 7.5)),
              pw.Text("D.L.No. : ${shop.dlNo} | GST: ${shop.gstin}", style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700)),
            ]
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end, 
            children: [
              pw.Text("STOCK & SALES STATEMENT REPORT", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
              pw.Text("Period: ${DateFormat('dd/MM/yyyy').format(from)} to ${DateFormat('dd/MM/yyyy').format(to)}", style: const pw.TextStyle(fontSize: 8.5)),
              pw.Text("Valuation: $basis RATE", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
            ]
          ),
        ]
      ),
      pw.SizedBox(height: 10),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(5),
        decoration: const pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border(left: pw.BorderSide(width: 3, color: PdfColors.indigo900))),
        child: pw.Text("COMPANY / BRAND: $company", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 10),
    ]);
  }

  // --- 10 COLUMNS LANDSCAPE TABLE ---
  static pw.Widget _buildDataTable(List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
      cellStyle: const pw.TextStyle(fontSize: 7.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(180), // Description
        1: const pw.FixedColumnWidth(40),  // Packing
        2: const pw.FixedColumnWidth(55),  // Op Stock
        3: const pw.FixedColumnWidth(75),  // Op Val
        4: const pw.FixedColumnWidth(55),  // Rec Qty
        5: const pw.FixedColumnWidth(75),  // Rec Val
        6: const pw.FixedColumnWidth(55),  // Issue Qty
        7: const pw.FixedColumnWidth(75),  // Issue Val
        8: const pw.FixedColumnWidth(55),  // Close Stock
        9: const pw.FixedColumnWidth(75),  // Close Val
      },
      headers: [
        'PRODUCT DESCRIPTION', 'UNIT', 'OPENING\nSTOCK', 'OPENING\nVALUE', 
        'RECEIVE\nQTY', 'RECEIVE\nVALUE', 'ISSUE\nQTY', 'ISSUE\nVALUE', 
        'CLOSING\nSTOCK', 'CLOSING\nVALUE'
      ],
      data: rows,
    );
  }
}
