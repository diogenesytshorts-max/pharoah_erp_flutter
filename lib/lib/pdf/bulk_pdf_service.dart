import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';
import 'pdf_master_service.dart';

class BulkPdfService {
  
  // ===========================================================================
  // 1. MAIN ZIP GENERATOR
  // ===========================================================================
  static Future<String> createBillsZip({
    required List<Map<String, dynamic>> selectedDrafts,
    required CompanyProfile shop,
    required Function(double progress, String filename) onProgress,
  }) async {
    final archive = Archive();

    for (int i = 0; i < selectedDrafts.length; i++) {
      var draft = selectedDrafts[i];
      dynamic billObj = draft['saleObj']; // Could be Sale or Purchase object
      Party party = draft['party'];

      onProgress((i + 1) / selectedDrafts.length, party.name);

      Uint8List pdfBytes;
      String billNo;

      // Detect Mode and use correct Clone Template
      if (billObj is Sale) {
        pdfBytes = await _generateSaleCloneBytes(billObj, party, shop);
        billNo = billObj.billNo;
      } else {
        pdfBytes = await _generatePurchaseCloneBytes(billObj, party, shop);
        billNo = (billObj as Purchase).billNo;
      }

      // Naming Style: Party(5 chars) + BillNo
      String cleanName = party.name.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      String p5 = cleanName.length > 5 ? cleanName.substring(0, 5) : cleanName.padRight(5, '_');
      String fileName = "${p5}_$billNo.pdf";

      archive.addFile(ArchiveFile(fileName, pdfBytes.length, pdfBytes));
    }

    final zipData = ZipEncoder().encode(archive);
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/Batch_Bills_${DateFormat('ddMM_HHmm').format(DateTime.now())}.zip';
    await File(zipPath).writeAsBytes(zipData!);
    
    return zipPath;
  }

  // ===========================================================================
  // 2. SALE INVOICE CLONE (100% Matching Layout)
  // ===========================================================================
  static Future<Uint8List> _generateSaleCloneBytes(Sale sale, Party party, CompanyProfile shop) async {
    final pdf = pw.Document();
    final itemsPerPage = 22;
    int totalPages = (sale.items.length / itemsPerPage).ceil();

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < sale.items.length) ? start + itemsPerPage : sale.items.length;
      List<BillItem> pageItems = sale.items.sublist(start, end);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            // --- HEADER (3 BOX DESIGN) ---
            pw.Row(children: [
              _hBox(280, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text(shop.address, style: const pw.TextStyle(fontSize: 8)),
                pw.Text("GSTIN: ${shop.gstin} | Ph: ${shop.phone}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ])),
              _hBox(170, pw.Column(children: [
                pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Divider(thickness: 0.5),
                pw.Text("Inv: ${sale.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text("Date: ${DateFormat('dd/MM/yy').format(sale.date)}", style: const pw.TextStyle(fontSize: 8)),
                pw.Text("Page ${pageNum + 1}/$totalPages", style: const pw.TextStyle(fontSize: 7)),
              ])),
              _hBox(330, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("BILL TO:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                pw.Text(party.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text(party.address, style: const pw.TextStyle(fontSize: 8)),
                pw.Text("GSTIN: ${party.gst} | DL: ${party.dl}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ])),
            ]),
            // --- TABLE HEADER ---
            pw.Container(color: PdfColors.grey100, child: pw.Row(children: [
              _tCol("S.N", 25), _tCol("Qty+Free", 50), _tCol("Pack", 40), _tCol("Item Description", 185, align: pw.Alignment.centerLeft),
              _tCol("Batch", 75), _tCol("Exp", 45), _tCol("HSN", 50), _tCol("MRP", 55), _tCol("Rate", 55), _tCol("GST%", 40), _tCol("Net Amt", 80),
            ])),
            // --- ITEM ROWS ---
            pw.Expanded(child: pw.Column(children: pageItems.map((i) => pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1, color: PdfColors.grey400))),
              child: pw.Row(children: [
                _cell("${i.srNo}", 25), _cell("${i.qty.toInt()}+${i.freeQty.toInt()}", 50), _cell(i.packing, 40), 
                _cell(i.name, 185, align: pw.Alignment.centerLeft), _cell(i.batch, 75), _cell(i.exp, 45), 
                _cell(i.hsn, 50), _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.rate.toStringAsFixed(2), 55), 
                _cell("${i.gstRate}%", 40), _cell(i.total.toStringAsFixed(2), 80),
              ]),
            )).toList())),
            // --- FOOTER (ONLY ON LAST PAGE) ---
            if (pageNum == totalPages - 1) _buildFooter(shop.name, sale.totalAmount)
          ]),
        )
      ));
    }
    return pdf.save();
  }

  // ===========================================================================
  // 3. PURCHASE CLONE (100% Matching Layout)
  // ===========================================================================
  static Future<Uint8List> _generatePurchaseCloneBytes(Purchase pur, Party supplier, CompanyProfile shop) async {
    final pdf = pw.Document();
    final itemsPerPage = 12;
    int totalPages = (pur.items.length / itemsPerPage).ceil();

    for (int pageNum = 0; pageNum < totalPages; pageNum++) {
      int start = pageNum * itemsPerPage;
      int end = (start + itemsPerPage < pur.items.length) ? start + itemsPerPage : pur.items.length;
      List<PurchaseItem> pageItems = pur.items.sublist(start, end);

      pdf.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(15),
        build: (context) => pw.Container(
          decoration: pw.BoxDecoration(border: pw.Border.all(width: 1)),
          child: pw.Column(children: [
            // --- HEADER ---
            pw.Row(children: [
              _hBox(280, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                pw.Text("STOCK INWARD RECORD", style: const pw.TextStyle(fontSize: 8)),
              ])),
              _hBox(170, pw.Column(children: [
                pw.Text("PURCHASE BILL", style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: PdfColors.orange900)),
                pw.Divider(thickness: 0.5),
                pw.Text("Bill No: ${pur.billNo}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text("ID: ${pur.internalNo}", style: const pw.TextStyle(fontSize: 8)),
                pw.Text("Date: ${DateFormat('dd/MM/yy').format(pur.date)}", style: const pw.TextStyle(fontSize: 8)),
              ])),
              _hBox(330, pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text("SUPPLIER:", style: pw.TextStyle(fontSize: 7, color: PdfColors.grey)),
                pw.Text(supplier.name, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.Text("GSTIN: ${supplier.gst}", style: const pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ])),
            ]),
            // --- TABLE ---
            pw.Container(color: PdfColors.grey200, child: pw.Row(children: [
              _tCol("S.N", 25), _tCol("Qty", 40), _tCol("Free", 30), _tCol("Pack", 45), _tCol("Product Name", 190, align: pw.Alignment.centerLeft),
              _tCol("Batch", 75), _tCol("Exp", 45), _tCol("HSN", 50), _tCol("MRP", 55), _tCol("Pur.Rate", 55), _tCol("GST%", 35), _tCol("Net Amt", 85),
            ])),
            pw.Expanded(child: pw.Column(children: pageItems.map((i) => pw.Container(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.1))),
              child: pw.Row(children: [
                _cell("${i.srNo}", 25), _cell("${i.qty.toInt()}", 40), _cell("${i.freeQty.toInt()}", 30), _cell(i.packing, 45),
                _cell(i.name, 190, align: pw.Alignment.centerLeft), _cell(i.batch, 75), _cell(i.exp, 45), _cell(i.hsn, 50),
                _cell(i.mrp.toStringAsFixed(2), 55), _cell(i.purchaseRate.toStringAsFixed(2), 55), _cell("${i.gstRate}%", 35), _cell(i.total.toStringAsFixed(2), 85),
              ]),
            )).toList())),
            if (pageNum == totalPages - 1) _buildFooter(shop.name, pur.totalAmount)
          ]),
        )
      ));
    }
    return pdf.save();
  }

  // ===========================================================================
  // UI HELPERS (EXACT MATCHING ORIGINAL SPECS)
  // ===========================================================================

  static pw.Widget _hBox(double w, pw.Widget child) => pw.Container(width: w, height: 85, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: child);
  
  static pw.Widget _tCol(String text, double width, {pw.Alignment align = pw.Alignment.center}) => pw.Container(width: width, height: 20, alignment: align, decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Text(text, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)));
  
  static pw.Widget _cell(String t, double w, {pw.Alignment align = pw.Alignment.center}) => pw.Container(width: w, padding: const pw.EdgeInsets.symmetric(vertical: 3), alignment: align, child: pw.Text(t, style: const pw.TextStyle(fontSize: 7.5)));

  static pw.Widget _buildFooter(String shopName, double total) {
    return pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Container(width: 470, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text("Amount in Words:", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.Text("RUPEES ${PdfMasterService.numberToWords(total.round())} ONLY", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
        ])),
        pw.Container(width: 310, padding: const pw.EdgeInsets.all(5), decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.5)), child: pw.Column(children: [
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text("NET PAYABLE AMOUNT", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.Text("Rs. ${total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          ]),
          pw.SizedBox(height: 5),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("For $shopName", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold))),
        ])),
    ]);
  }
}
