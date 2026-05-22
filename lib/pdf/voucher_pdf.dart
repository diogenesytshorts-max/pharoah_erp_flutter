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
  // Dimension: Professional Horizontal Voucher
  static final PdfPageFormat voucherLayout = PdfPageFormat(
    250 * PdfPageFormat.mm, 
    140 * PdfPageFormat.mm, // Increased height slightly to prevent overflow
    marginAll: 10 * PdfPageFormat.mm
  );

  static Future<void> generate(Voucher v, Party party, CompanyProfile shop, PharoahManager ph) async {
    final pdf = pw.Document();
    
    // 🔥 SAFE LOOKUP: Prevent crash if bill not found
    List<Map<String, dynamic>> refDetails = [];
    for (var bNo in v.linkedBillNumbers) {
      DateTime? originalDate;
      try {
        if (v.type == "Receipt") {
          // orElse logic ensures no crash
          var sale = ph.sales.firstWhere((s) => s.billNo == bNo);
          originalDate = sale.date;
        } else {
          var purchase = ph.purchases.firstWhere((p) => p.billNo == bNo);
          originalDate = purchase.date;
        }
      } catch (e) { originalDate = null; }

      refDetails.add({
        'no': bNo,
        'date': originalDate != null ? DateFormat('dd/MM/yy').format(originalDate) : "N/A",
        'days': originalDate != null ? v.date.difference(originalDate).inDays : 0
      });
    }

    bool isReceipt = v.type == "Receipt";
    PdfColor accentColor = isReceipt ? PdfColors.green900 : PdfColors.red900;
    PdfColor lightTint = isReceipt ? PdfColors.green50 : PdfColors.red50;

    pdf.addPage(pw.Page(
      pageFormat: voucherLayout,
      build: (pw.Context context) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(width: 1.5, color: accentColor),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
          ),
          child: pw.Column(children: [
            // --- HEADER ---
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(color: lightTint, border: pw.Border(bottom: pw.BorderSide(width: 1, color: accentColor))),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: accentColor)),
                  pw.Text("${shop.address}, ${shop.state}", style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("GSTIN: ${shop.gstin} | DL: ${shop.dlNo}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                ])),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  pw.Text(isReceipt ? "RECEIPT VOUCHER" : "PAYMENT ADVICE", style: pw.TextStyle(color: accentColor, fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text("No: ${v.voucherNo}", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                  pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(v.date)}", style: const pw.TextStyle(fontSize: 9)),
                ]),
              ]),
            ),

            // --- PARTY & BANK ---
            pw.Padding(
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Expanded(flex: 5, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text(isReceipt ? "RECEIVED FROM:" : "PAID TO:", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                  pw.Text(party.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text("${party.city}, ${party.state}", style: const pw.TextStyle(fontSize: 8)),
                  pw.Text("GST: ${party.gst} | DL: ${party.dl}", style: const pw.TextStyle(fontSize: 8)),
                ])),
                pw.Expanded(flex: 4, child: pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(5)),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text("SETTLEMENT DETAILS:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                    pw.Text("Mode: ${v.paymentMode.toUpperCase()}", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    if (v.paymentMode == "Bank") ...[
                      pw.Text("Chq/Ref: ${v.chequeNo}", style: const pw.TextStyle(fontSize: 8)),
                      if (v.chequeDate != null) pw.Text("Dated: ${DateFormat('dd/MM/yy').format(v.chequeDate!)}", style: const pw.TextStyle(fontSize: 8)),
                      pw.Text("Bank: ${v.bankName}", style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ]),
                )),
              ]),
            ),

            // --- BILL REFERENCE GRID ---
            if (refDetails.isNotEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(horizontal: 12),
                child: pw.Table(
                  border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey400),
                  children: [
                    pw.TableRow(decoration: pw.BoxDecoration(color: PdfColors.grey200), children: [
                      _p(pw.Text("Ref Bill Number", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      _p(pw.Text("Bill Date", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                      _p(pw.Text("Pay-in Delay", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
                    ]),
                    ...refDetails.map((det) => pw.TableRow(children: [
                      _p(pw.Text(det['no'], style: const pw.TextStyle(fontSize: 8))),
                      _p(pw.Text(det['date'], style: const pw.TextStyle(fontSize: 8))),
                      _p(pw.Text("${det['days']} Days", style: const pw.TextStyle(fontSize: 8))),
                    ])),
                  ],
                ),
              ),

            pw.Spacer(),

            // --- FOOTER ---
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(width: 0.5, color: PdfColors.grey400))),
              child: pw.Row(children: [
                pw.Expanded(flex: 6, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Text("RUPEES ${PdfMasterService.numberToWords(v.amount.round())} ONLY", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentColor)),
                  pw.SizedBox(height: 5),
                  pw.Text("Remarks: ${v.narration}", style: const pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic)),
                ])),
                pw.Expanded(flex: 4, child: pw.Column(children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(width: 1.5, color: accentColor), color: lightTint),
                    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text("NET AMOUNT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text("Rs. ${v.amount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ]),
                  ),
                  pw.SizedBox(height: 15),
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                    pw.Column(children: [
                      pw.Container(width: 60, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5)))),
                      pw.Text("Receiver's Sign", style: const pw.TextStyle(fontSize: 7)),
                    ]),
                    pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                      pw.Text("For ${shop.name}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 15),
                      pw.Text("Authorized Signatory", style: const pw.TextStyle(fontSize: 7)),
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

  static pw.Widget _p(pw.Widget child) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: child);
}
