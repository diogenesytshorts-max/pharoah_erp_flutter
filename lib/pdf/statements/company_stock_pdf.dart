import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models.dart';
import '../../gateway/company_registry_model.dart';
import '../../finance/stock_flow_engine.dart';
import '../../pharoah_manager.dart';

class CompanyStockPdf {
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
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(25),
          header: (context) => _buildHeader(shop, companyName, from, to, valuationBasis),
          build: (context) {
            // Calculation for Company Sub-Totals
            double subOpVal = 0, subRecVal = 0, subSaleVal = 0, subCloVal = 0;

            List<List<String>> tableRows = [];
            for (int i = 0; i < meds.length; i++) {
              var m = meds[i];
              final flow = StockFlowEngine.getItemFlow(med: m, from: from, to: to, ph: ph);
              
              double rate = (valuationBasis == "PURCHASE") ? m.purRate : (valuationBasis == "SALE" ? m.rateA : m.mrp);
              
              subOpVal += (flow['opening']! * rate);
              subRecVal += (flow['received']! * rate);
              subSaleVal += (flow['sale']! * rate);
              subCloVal += (flow['closing']! * rate);

              tableRows.add([
                "${i + 1}",
                m.name,
                flow['opening']!.toStringAsFixed(2),
                flow['received']!.toStringAsFixed(2),
                flow['sale']!.toStringAsFixed(2),
                flow['closing']!.toStringAsFixed(2),
              ]);
            }

            return [
              _buildDataTable(tableRows),
              pw.SizedBox(height: 15),
              _buildValueFooter(subOpVal, subRecVal, subSaleVal, subCloVal, valuationBasis),
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
  // 📧 NAYA: EMAIL KE LIYE BYTES GENERATE KARNA
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
      
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(25),
          header: (context) => _buildHeader(shop, companyName, from, to, valuationBasis),
          build: (context) {
            double subOpVal = 0, subRecVal = 0, subSaleVal = 0, subCloVal = 0;
            List<List<String>> tableRows = [];
            for (int i = 0; i < meds.length; i++) {
              var m = meds[i];
              final flow = StockFlowEngine.getItemFlow(med: m, from: from, to: to, ph: ph);
              double rate = (valuationBasis == "PURCHASE") ? m.purRate : (valuationBasis == "SALE" ? m.rateA : m.mrp);
              subOpVal += (flow['opening']! * rate);
              subRecVal += (flow['received']! * rate);
              subSaleVal += (flow['sale']! * rate);
              subCloVal += (flow['closing']! * rate);
              tableRows.add([
                "${i + 1}", m.name, flow['opening']!.toStringAsFixed(2),
                flow['received']!.toStringAsFixed(2), flow['sale']!.toStringAsFixed(2),
                flow['closing']!.toStringAsFixed(2),
              ]);
            }
            return [
              _buildDataTable(tableRows),
              pw.SizedBox(height: 15),
              _buildValueFooter(subOpVal, subRecVal, subSaleVal, subCloVal, valuationBasis),
            ];
          },
        ),
      );
    }
    return pdf.save(); // Direct bytes return karega
  }

  // --- 1. LANDSCAPE HEADER ---
  static pw.Widget _buildHeader(CompanyProfile shop, String company, DateTime from, DateTime to, String basis) {
    return pw.Column(children: [
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text("STOCK FLOW STATEMENT (By Company)", style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text("Period: ${DateFormat('dd/MM/yy').format(from)} to ${DateFormat('dd/MM/yy').format(to)}", style: const pw.TextStyle(fontSize: 9)),
          pw.Text("Valuation Basis: $basis RATE", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
        ]),
      ]),
      pw.SizedBox(height: 10),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(5),
        color: PdfColors.grey200,
        child: pw.Text("COMPANY / BRAND: $company", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 10),
    ]);
  }

  // --- 2. THE GRID (6 Columns) ---
  static pw.Widget _buildDataTable(List<List<String>> rows) {
    return pw.TableHelper.fromTextArray(
      headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey900),
      cellStyle: const pw.TextStyle(fontSize: 8.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(30), // SN
        1: const pw.FlexColumnWidth(4),   // Name
        2: const pw.FlexColumnWidth(1),   // Op
        3: const pw.FlexColumnWidth(1),   // Rec
        4: const pw.FlexColumnWidth(1),   // Sale
        5: const pw.FlexColumnWidth(1),   // Close
      },
      headers: ['SN', 'MEDICINES NAME', 'OPENING', 'RECEIVED', 'SALE', 'CLOSING'],
      data: rows,
    );
  }

  // --- 3. VALUE SUMMARY FOOTER ---
  static pw.Widget _buildValueFooter(double op, double rec, double sale, double clo, String basis) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(border: pw.Border.all(width: 1), color: PdfColors.grey50),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceAround, children: [
        _valueBox("OPENING VAL", op),
        _valueBox("RECEIVED VAL", rec),
        _valueBox("SALE VAL", sale),
        _valueBox("CLOSING VAL", clo),
      ]),
    );
  }

  static pw.Widget _valueBox(String label, double val) => pw.Column(children: [
    pw.Text(label, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
    pw.Text("₹${val.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
  ]);
}
