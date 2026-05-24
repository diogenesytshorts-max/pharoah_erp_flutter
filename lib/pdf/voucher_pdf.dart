import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../pharoah_manager.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class VoucherPdf {
  // A6 Portrait (105mm x 148mm) - Perfect 1/4 of A4
  static const PdfPageFormat a6Portrait = PdfPageFormat(
    105 * PdfPageFormat.mm, 
    148 * PdfPageFormat.mm, 
    marginAll: 4 * PdfPageFormat.mm,
  );

  static Future<void> generate(Voucher v, Party party, CompanyProfile shop, PharoahManager ph) async {
    final pdf = pw.Document();
    bool isReceipt = v.type == "Receipt";
    final now = DateTime.now();

    // Bill adjustment details with Pending Days calculation
    List<Map<String, String>> adjDetails = [];
    for (var bNo in v.linkedBillNumbers) {
      int days = 0;
      try {
        if (isReceipt) {
          final s = ph.sales.firstWhere((element) => element.billNo == bNo);
          days = v.date.difference(s.date).inDays;
        } else {
          final p = ph.purchases.firstWhere((element) => element.billNo == bNo);
          days = v.date.difference(p.date).inDays;
        }
        adjDetails.add({'ref': bNo, 'days': "$days Days"});
      } catch (e) {
        adjDetails.add({'ref': bNo, 'days': "N/A"});
      }
    }

    pdf.addPage(pw.Page(
      pageFormat: a6Portrait,
      build: (pw.Context context) {
        return pw.Stack(children: [
          // 1. SHADOW WATERMARK
          pw.Center(child: pw.Opacity(opacity: 0.05, child: pw.Transform.rotate(angle: 0.5, child: pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 25, fontWeight: pw.FontWeight.bold))))),

          // 2. MAIN CONTENT
          pw.Column(children: [
            // HEADER (Centered)
            pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            pw.Text(shop.address.toUpperCase(), style: const pw.TextStyle(fontSize: 5.5), textAlign: pw.TextAlign.center),
            pw.Text("GSTIN: ${shop.gstin} | Mob: ${shop.phone}", style: const pw.TextStyle(fontSize: 6)),
            
            pw.SizedBox(height: 3),

            // MAIN BOX
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
              child: pw.Column(children: [
                // Type Title
                pw.Container(
                  width: double.infinity, padding: const pw.EdgeInsets.all(2),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                  child: pw.Center(child: pw.Text("${v.type.toUpperCase()} VOUCHER", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                ),
                // No & Date
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text("Voucher No: ${v.voucherNo}", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Date: ${DateFormat('dd-MM-yyyy').format(v.date)}", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                  ]),
                ),
                // Table Header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), bottom: pw.BorderSide(width: 0.5))),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 5, child: pw.Text("Particulars", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text("Debit", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text("Credit", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                  ]),
                ),
                // Table Body (Ledgers)
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(children: [
                    // ROW 1: Principal Account
                    pw.Row(children: [
                      pw.Expanded(flex: 5, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(isReceipt ? "CASH / BANK ACCOUNT" : party.name.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        if (!isReceipt) pw.Text("${party.city} | GST: ${party.gst}", style: const pw.TextStyle(fontSize: 5)),
                      ])),
                      pw.Expanded(flex: 2, child: pw.Text(v.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 2, child: pw.Text("", textAlign: pw.TextAlign.right)),
                    ]),
                    pw.SizedBox(height: 3),
                    // ROW 2: Counter Account
                    pw.Row(children: [
                      pw.Expanded(flex: 5, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(isReceipt ? party.name.toUpperCase() : "CASH / BANK ACCOUNT", style: const pw.TextStyle(fontSize: 7.5)),
                        if (isReceipt) pw.Text("${party.city} | GST: ${party.gst}", style: const pw.TextStyle(fontSize: 5)),
                      ])),
                      pw.Expanded(flex: 2, child: pw.Text("", textAlign: pw.TextAlign.right)),
                      pw.Expanded(flex: 2, child: pw.Text(v.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    ]),
                  ]),
                ),
                // ADJ REFERENCE STRIP (New)
                if (adjDetails.isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(3),
                    decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.3, style: pw.BorderStyle.dashed))),
                    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.Text("BILL ADJUSTMENT DETAILS:", style: pw.TextStyle(fontSize: 5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.Wrap(spacing: 5, children: adjDetails.map((det) => pw.Text("Ref: ${det['ref']} (${det['days']})", style: const pw.TextStyle(fontSize: 5))).toList()),
                    ]),
                  ),
                // TOTAL
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 5, child: pw.Text("TOTAL", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text(v.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text(v.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                  ]),
                ),
                // AMOUNT IN WORDS
                pw.Container(
                  width: double.infinity, padding: const pw.EdgeInsets.all(4),
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
                  child: pw.Text("Rs. ${PdfMasterService.numberToWords(v.amount.round())} Only", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            ),
            pw.Spacer(),
            // SIGNATURES
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("(Prepared By)", style: const pw.TextStyle(fontSize: 6)),
                pw.Text("(Receiver)", style: const pw.TextStyle(fontSize: 6)),
                pw.Text("(Accountant)", style: const pw.TextStyle(fontSize: 6)),
                pw.Text("(Prop.)", style: const pw.TextStyle(fontSize: 6)),
              ]),
            ),
          ]),
        ]);
      },
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Voucher_${v.voucherNo}', format: a6Portrait);
  }
}
