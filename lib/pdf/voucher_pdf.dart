// FILE: lib/pdf/voucher_pdf.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../pharoah_manager.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class VoucherPdf {
  // Dimension: B5 Half Page Horizontal (Approx 250mm x 110mm)
  static final PdfPageFormat b5HalfLandscape = PdfPageFormat(
    250 * PdfPageFormat.mm, 
    110 * PdfPageFormat.mm, 
    marginAll: 8 * PdfPageFormat.mm
  );

  static Future<void> generate(Voucher v, Party party, CompanyProfile shop, PharoahManager ph) async {
    final pdf = pw.Document();
    
    // Logic: Bill References and Days Calculation
    List<Map<String, dynamic>> refDetails = [];
    for (var bNo in v.linkedBillNumbers) {
      DateTime? originalDate;
      try {
        if (v.type == "Receipt") {
          originalDate = ph.sales.firstWhere((s) => s.billNo == bNo).date;
        } else {
          originalDate = ph.purchases.firstWhere((p) => p.billNo == bNo).date;
        }
      } catch (e) { originalDate = null; }

      int days = 0;
      if (originalDate != null) {
        days = v.date.difference(originalDate).inDays;
      }

      refDetails.add({
        'no': bNo,
        'date': originalDate != null ? DateFormat('dd/MM/yy').format(originalDate) : "N/A",
        'days': days
      });
    }

    bool isReceipt = v.type == "Receipt";
    PdfColor accentColor = isReceipt ? PdfColors.green900 : PdfColors.red900;
    PdfColor lightTint = isReceipt ? PdfColors.green50 : PdfColors.red50;

    pdf.addPage(pw.Page(
      pageFormat: b5HalfLandscape,
      build: (pw.Context context) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1, color: PdfColors.grey400),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
          ),
          child: pw.Column(children: [
            // --- SECTION 1: HEADER ---
            pw.Container(
              padding: const pw.EdgeInsets.all(6),
              decoration: pw.BoxDecoration(color: lightTint, border: const pw.Border(bottom: pw.BorderSide(width: 0.5))),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: accentColor)),
                  pw.Text("${shop.address}, ${shop.state}", style: const pw.TextStyle(fontSize: 7)),
                  pw.Text("GST: ${shop.gstin} | DL: ${shop.dlNo}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ])),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: pw.BoxDecoration(color: accentColor, borderRadius: pw.BorderRadius.circular(4)),
                    child: pw.Text(isReceipt ? "RECEIPT VOUCHER" : "PAYMENT ADVICE", style: pw.TextStyle(color: PdfColors.white, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text("No: ${v.voucherNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(v.date)}", style: const pw.TextStyle(fontSize: 8)),
                ]),
              ]),
            ),

            // --- SECTION 2: PARTY & INSTRUMENT ---
            pw.Padding(
              padding: const pw.EdgeInsets.all(8),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(flex: 5, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(isReceipt ? "RECEIVED FROM:" : "PAID TO:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Text(party.name, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text("${party.city}, ${party.state}", style: const pw.TextStyle(fontSize: 7)),
                  pw.Text("GST: ${party.gst} | DL: ${party.dl}", style: const pw.TextStyle(fontSize: 7)),
                ])),
                pw.Expanded(flex: 4, child: pw.Container(
                  padding: const pw.EdgeInsets.all(5),
                  decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5, color: PdfColors.grey200), color: PdfColors.grey50),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("INSTRUMENT DETAILS:", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Mode: ${v.paymentMode}", style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                    if (v.paymentMode == "Bank") ...[
                      pw.Text("Ref/Cheque: ${v.chequeNo}", style: const pw.TextStyle(fontSize: 7)),
                      if (v.chequeDate != null) pw.Text("Dated: ${DateFormat('dd/MM/yy').format(v.chequeDate!)}", style: const pw.TextStyle(fontSize: 7)),
                      pw.Text("Drawn on: ${v.bankName}", style: const pw.TextStyle(fontSize: 7)),
                      pw.Text("Deposited: ${v.depositedIn}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: accentColor)),
                    ],
                  ]),
                )),
              ]),
            ),

            // --- SECTION 3: BILL REFERENCE TABLE ---
            if (refDetails.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 8),
                child: pw.Table(
                  border: pw.TableBorder.all(width: 0.2, color: PdfColors.grey400),
                  children: [
                    pw.TableRow(
                      decoration: pw.BoxDecoration(color: PdfColors.grey100),
                      children: [
                        _tHeader("Ref Bill No"), _tHeader("Bill Date"), _tHeader("Settle In"),
                      ],
                    ),
                    ...refDetails.map((det) => pw.TableRow(children: [
                      _tCell(det['no']), _tCell(det['date']), _tCell("${det['days']} Days"),
                    ])),
                  ],
                ),
              ),

            pw.Spacer(),

            // --- SECTION 4: FOOTER (AMOUNT & SIGN) ---
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5))),
              child: pw.Row(children: [
                pw.Expanded(flex: 6, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("AMOUNT IN WORDS:", style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold)),
                  pw.Text("RUPEES ${PdfMasterService.numberToWords(v.amount.round())} ONLY", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentColor)),
                  pw.SizedBox(height: 4),
                  pw.Text("Narration: ${v.narration.isEmpty ? 'N/A' : v.narration}", style: const pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
                ])),
                pw.Expanded(flex: 4, child: pw.Column(children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 1, color: accentColor)),
                    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text("TOTAL", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Rs. ${v.amount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ),
                  pw.SizedBox(height: 10),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Column(children: [
                      // 🔥 FIXED: Container border logic fixed for PDF package
                      pw.Container(width: 50, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5)))),
                      pw.Text("Receiver's Sign", style: const pw.TextStyle(fontSize: 6)),
                    ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text("For ${shop.name}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 12),
                      pw.Text("Authorized Signatory", style: const pw.TextStyle(fontSize: 6)),
                    ]),
                  ]),
                ])),
              ]),
            ),
          ]),
        );
      },
    ));

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Voucher_${v.voucherNo}');
  }

  static pw.Widget _tHeader(String t) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  static pw.Widget _tCell(String t) => pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(t, style: const pw.TextStyle(fontSize: 7)));
}
