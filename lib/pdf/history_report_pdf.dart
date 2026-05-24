// FILE: lib/pdf/history_report_pdf.dart
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class HistoryReportPdf {
  static Future<void> generate({
    required List<Voucher> list, 
    required DateTime fDate, 
    required DateTime tDate, 
    required CompanyProfile shop,
    required double openingFlow, // Range shuru hone se pehle ka net balance
  }) async {
    final pdf = pw.Document();
    
    // Totals calculation
    double totalRec = list.where((v) => v.type == "Receipt" && !v.narration.contains("CANCELLED")).fold(0, (s, e) => s + e.amount);
    double totalPaid = list.where((v) => v.type == "Payment" && !v.narration.contains("CANCELLED")).fold(0, (s, e) => s + e.amount);

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(25),
      header: (context) => pw.Column(children: [
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
            pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
            pw.Text("GSTIN: ${shop.gstin}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text("ACCOUNT STATEMENT", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.Text("Period: ${DateFormat('dd/MM/yy').format(fDate)} to ${DateFormat('dd/MM/yy').format(tDate)}", style: const pw.TextStyle(fontSize: 9)),
          ]),
        ]),
        pw.Divider(thickness: 1, color: PdfColors.grey400),
        pw.SizedBox(height: 5),
        // Opening Flow Bar
        pw.Container(
          padding: const pw.EdgeInsets.all(5),
          color: PdfColors.grey100,
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("OPENING BALANCE (Before ${DateFormat('dd/MM').format(fDate)})", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
            pw.Text("Rs. ${openingFlow.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          ]),
        ),
      ]),
      build: (context) => [
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
          cellStyle: const pw.TextStyle(fontSize: 8),
          columnWidths: {
            0: const pw.FixedColumnWidth(55), // Date
            1: const pw.FixedColumnWidth(60), // ID
            2: const pw.FlexColumnWidth(3),   // Account
            3: const pw.FixedColumnWidth(60), // Mode
            4: const pw.FixedColumnWidth(70), // Debit
            5: const pw.FixedColumnWidth(70), // Credit
          },
          headers: ['DATE', 'TXN ID', 'PARTICULARS / ACCOUNT NAME', 'MODE', 'DEBIT(PAID)', 'CREDIT(REC)'],
          data: list.map((v) {
            bool isCan = v.narration.contains("CANCELLED");
            bool isReceipt = v.type == "Receipt";
            return [
              DateFormat('dd/MM/yy').format(v.date),
              v.voucherNo,
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(v.partyName, style: pw.TextStyle(decoration: isCan ? pw.TextDecoration.lineThrough : null, color: isCan ? PdfColors.red : PdfColors.black)),
                if(v.narration.isNotEmpty) pw.Text(v.narration, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
              ]),
              v.paymentMode,
              isReceipt ? "" : v.amount.toStringAsFixed(2),
              isReceipt ? v.amount.toStringAsFixed(2) : "",
            ];
          }).toList(),
        ),
      ],
      footer: (context) => pw.Column(children: [
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("Statement Generated via Pharoah ERP", style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.Row(children: [
            _fSum("TOTAL REC: ", totalRec, PdfColors.green900),
            pw.SizedBox(width: 20),
            _fSum("TOTAL PAID: ", totalPaid, PdfColors.red900),
          ]),
        ]),
      ]),
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Statement_${shop.name}');
  }

  static pw.Widget _fSum(String l, double v, PdfColor c) => pw.RichText(text: pw.TextSpan(children: [
    pw.TextSpan(text: l, style: const pw.TextStyle(fontSize: 8)),
    pw.TextSpan(text: "Rs. ${v.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: c)),
  ]));
}
