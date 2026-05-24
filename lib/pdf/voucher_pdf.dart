// FILE: lib/pdf/voucher_pdf.dart
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

    // Bill adjustment details with Date Lookup
    List<String> billRefs = [];
    for (var bNo in v.linkedBillNumbers) {
      String bDate = "";
      try {
        if (isReceipt) {
          final s = ph.sales.firstWhere((element) => element.billNo == bNo);
          bDate = DateFormat('dd/MM').format(s.date);
        } else {
          final p = ph.purchases.firstWhere((element) => element.billNo == bNo);
          bDate = DateFormat('dd/MM').format(p.date);
        }
        billRefs.add("$bNo ($bDate)");
      } catch (e) {
        billRefs.add(bNo);
      }
    }

    pdf.addPage(pw.Page(
      pageFormat: a6Portrait,
      build: (pw.Context context) {
        return pw.Stack(children: [
          // 1. FIXED SHADOW WATERMARK (Centered & Scaled for A6)
          pw.Center(
            child: pw.Opacity(
              opacity: 0.05, 
              child: pw.Transform.rotate(
                angle: 0.5, 
                child: pw.Text(shop.name.toUpperCase(), 
                  style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
                  textAlign: pw.TextAlign.center,
                )
              )
            )
          ),

          // 2. MAIN CONTENT
          pw.Column(children: [
            // HEADER
            pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text(shop.address.toUpperCase(), style: const pw.TextStyle(fontSize: 5.5), textAlign: pw.TextAlign.center),
            pw.Text("GSTIN: ${shop.gstin} | PH: ${shop.phone}", style: const pw.TextStyle(fontSize: 5.5)),
            
            pw.SizedBox(height: 3),

            // MAIN BORDERED BOX
            pw.Container(
              decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.7)),
              child: pw.Column(children: [
                // Title Bar
                pw.Container(
                  width: double.infinity, padding: const pw.EdgeInsets.all(1.5),
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100, border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
                  child: pw.Center(child: pw.Text("${v.type.toUpperCase()} VOUCHER", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
                ),
                
                // No & Date Row
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Text("Voucher No: ${v.voucherNo}", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Date: ${DateFormat('dd-MM-yyyy').format(v.date)}", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                  ]),
                ),

                // BANK / CHEQUE DETAILS (Conditional)
                if (v.paymentMode == "Bank" && v.chequeNo.isNotEmpty)
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.3, style: pw.BorderStyle.dashed))),
                    child: pw.Text("CHQ NO: ${v.chequeNo}  |  CHQ DATE: ${v.chequeDate != null ? DateFormat('dd-MM-yyyy').format(v.chequeDate!) : 'N/A'}", 
                      style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
                  ),

                // Table Header
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5), bottom: pw.BorderSide(width: 0.5))),
                  child: pw.Row(children: [
                    pw.Expanded(flex: 5, child: pw.Text("Particulars", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text("Debit", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
                    pw.Expanded(flex: 2, child: pw.Text("Credit", textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold))),
                  ]),
                ),

                // Ledger Details
                pw.Container(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Column(children: [
                    // Party Row
                    pw.Row(children: [
                      pw.Expanded(flex: 5, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.Text(party.name.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                        pw.Text("${party.city} | GST: ${party.gst}", style: const pw.TextStyle(fontSize: 5)),
                      ])),
                      pw.Expanded(flex: 2, child: pw.Text(isReceipt ? "" : v.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 2, child: pw.Text(isReceipt ? v.amount.toStringAsFixed(2) : "", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    ]),
                    pw.SizedBox(height: 3),
                    // Contra Account Row (Cash/Bank)
                    pw.Row(children: [
                      pw.Expanded(flex: 5, child: pw.Text(v.depositedIn.toUpperCase(), style: const pw.TextStyle(fontSize: 7))),
                      pw.Expanded(flex: 2, child: pw.Text(isReceipt ? v.amount.toStringAsFixed(2) : "", textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                      pw.Expanded(flex: 2, child: pw.Text(isReceipt ? "" : v.amount.toStringAsFixed(2), textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 7.5))),
                    ]),
                  ]),
                ),

                // BILL ADJUSTMENT STRIP (Bill No + Bill Date)
                if (billRefs.isNotEmpty)
                  pw.Container(
                    padding: const pw.EdgeInsets.all(3),
                    width: double.infinity,
                    decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.3, style: pw.BorderStyle.dashed))),
                    child: pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: "ADJ AGAINST: ", style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold)),
                      pw.TextSpan(text: billRefs.join(", "), style: const pw.TextStyle(fontSize: 5.5)),
                    ])),
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
                  child: pw.Text("Rupees ${PdfMasterService.numberToWords(v.amount.round())} Only", style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold)),
                ),
              ]),
            ),

            pw.Spacer(),

            // CLEAN SIGNATURE FOOTER (A6 Safe)
            pw.Container(
              width: double.infinity,
              child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text("Authorised Signatory for", style: const pw.TextStyle(fontSize: 6)),
                pw.SizedBox(height: 2),
                pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Container(width: 80, border: const pw.Border(top: pw.BorderSide(width: 0.5))),
              ]),
            ),
            pw.SizedBox(height: 2),
            pw.Text("System Generated via Pharoah ERP", style: const pw.TextStyle(fontSize: 4, color: PdfColors.grey500)),
          ]),
        ]);
      },
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Voucher_${v.voucherNo}', format: a6Portrait);
  }
}
