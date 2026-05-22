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
  // A5 Portrait Size (148mm x 210mm) - A4 ka perfect aadha
  static final PdfPageFormat a5Portrait = PdfPageFormat(
    148 * PdfPageFormat.mm, 
    210 * PdfPageFormat.mm, 
    marginAll: 7 * PdfPageFormat.mm,
  );

  static Future<void> generate(Voucher v, Party party, CompanyProfile shop, PharoahManager ph) async {
    final pdf = pw.Document();
    
    bool isReceipt = v.type == "Receipt";
    PdfColor themeColor = isReceipt ? PdfColors.green900 : PdfColors.red900;
    PdfColor lightBg = isReceipt ? PdfColors.green50 : PdfColors.red50;

    // Safety: Bill details fetch logic
    List<Map<String, dynamic>> billRows = [];
    for (var bNo in v.linkedBillNumbers) {
      String dt = "N/A";
      try {
        if (isReceipt) {
          final s = ph.sales.firstWhere((element) => element.billNo == bNo);
          dt = DateFormat('dd/MM/yy').format(s.date);
        } else {
          final p = ph.purchases.firstWhere((element) => element.billNo == bNo);
          dt = DateFormat('dd/MM/yy').format(p.date);
        }
      } catch (e) { dt = "Ref."; }
      billRows.add({'no': bNo, 'date': dt});
    }

    pdf.addPage(pw.Page(
      pageFormat: a5Portrait,
      build: (context) => pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(width: 1.2, color: themeColor),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(10)),
        ),
        child: pw.Column(children: [
          // 1. HEADER
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: lightBg, 
              border: pw.Border(bottom: pw.BorderSide(width: 1, color: themeColor))
            ),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: themeColor)),
                pw.Text(shop.address, style: const pw.TextStyle(fontSize: 6.5), maxLines: 1),
                pw.Text("GSTIN: ${shop.gstin}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
              ])),
              pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                pw.Text(isReceipt ? "RECEIPT" : "PAYMENT", style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: themeColor)),
                pw.Text("No: ${v.voucherNo}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Text(DateFormat('dd/MM/yyyy').format(v.date), style: const pw.TextStyle(fontSize: 7.5)),
              ]),
            ]),
          ),

          // 2. PARTY INFO
          pw.Padding(
            padding: const pw.EdgeInsets.all(10), 
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(isReceipt ? "RECEIVED FROM:" : "PAID TO:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
              pw.SizedBox(height: 2),
              pw.Text(party.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.Text("${party.city}, ${party.state}", style: const pw.TextStyle(fontSize: 8)),
              pw.Divider(thickness: 0.5, color: PdfColors.grey300),
              
              pw.SizedBox(height: 5),
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("MODE: ${v.paymentMode.toUpperCase()}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                if (v.paymentMode != "Cash") pw.Text("CHQ/REF: ${v.chequeNo}", style: const pw.TextStyle(fontSize: 8)),
              ]),
            ]),
          ),

          // 3. AMOUNT BOX
          pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: lightBg, 
              borderRadius: pw.BorderRadius.circular(8), 
              border: pw.Border.all(color: themeColor, width: 0.5)
            ),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
              pw.Text("NET SETTLEMENT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: themeColor)),
              pw.Text("Rs. ${v.amount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: themeColor)),
            ]),
          ),

          // 4. ADJUSTMENT TABLE
          if (billRows.isNotEmpty) ...[
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: pw.BoxDecoration(color: themeColor),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Adjusted Bill Number', 'Bill Date'],
                data: billRows.map((r) => [r['no'], r['date']]).toList(),
              ),
            ),
          ],

          pw.Spacer(),

          // 5. FOOTER & SIGNATURE
          pw.Padding(
            padding: const pw.EdgeInsets.all(10),
            child: pw.Column(children: [
               pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, 
                crossAxisAlignment: pw.CrossAxisAlignment.end, // FIXED: pw.End se pw.CrossAxisAlignment.end kiya
                children: [
                  pw.Column(children: [
                    pw.Container(width: 60, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5)))),
                    pw.SizedBox(height: 2),
                    pw.Text("Receiver's Sign", style: const pw.TextStyle(fontSize: 7)),
                  ]),
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                    pw.Text("For ${shop.name}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 25),
                    pw.Text("Authorized Signatory", style: const pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
                  ]),
               ]),
               pw.SizedBox(height: 8),
               pw.Text("Computer Generated Payment Advice", style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey500)),
            ]),
          ),
        ]),
      ),
    ));

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(), 
      name: 'Voucher_${v.voucherNo}',
      format: a5Portrait, 
    );
  }
}
