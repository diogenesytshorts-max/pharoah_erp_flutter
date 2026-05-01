import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models.dart';
import '../gateway/company_registry_model.dart';

class BulkPdfService {
  
  static Future<String> createBillsZip({
    required List<Map<String, dynamic>> selectedDrafts,
    required CompanyProfile shop,
    required Function(double progress, String filename) onProgress,
  }) async {
    final archive = Archive();

    for (int i = 0; i < selectedDrafts.length; i++) {
      var draft = selectedDrafts[i];
      Sale sale = draft['saleObj'];
      Party party = draft['party'];

      onProgress((i + 1) / selectedDrafts.length, party.name);

      // Generate Silent PDF (Same as professional invoice)
      final pdfBytes = await _generateProfessionalBytes(sale, party, shop);

      // Naming: Party(5) + BillNo
      String cleanName = party.name.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      String p5 = cleanName.length > 5 ? cleanName.substring(0, 5) : cleanName.padRight(5, 'X');
      String fileName = "${p5}_${sale.billNo}.pdf";

      archive.addFile(ArchiveFile(fileName, pdfBytes.length, pdfBytes));
    }

    final zipData = ZipEncoder().encode(archive);
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/Batch_Invoices_${DateFormat('ddMM_HHmm').format(DateTime.now())}.zip';
    await File(zipPath).writeAsBytes(zipData!);
    return zipPath;
  }

  static Future<Uint8List> _generateProfessionalBytes(Sale sale, Party party, CompanyProfile shop) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(20),
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header (Like your real invoice)
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(shop.name, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text(shop.address, style: const pw.TextStyle(fontSize: 9)),
              pw.Text("GSTIN: ${shop.gstin} | DL: ${shop.dlNo}", style: const pw.TextStyle(fontSize: 9)),
            ]),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("TAX INVOICE", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text("Inv No: ${sale.billNo}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text("Date: ${DateFormat('dd/MM/yyyy').format(sale.date)}"),
            ]),
          ]),
          pw.Divider(thickness: 1),
          pw.Text("Bill To: ${party.name}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(party.address, style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 15),
          // Professional Table
          pw.TableHelper.fromTextArray(
            headers: ['Item Name', 'Batch', 'Exp', 'Qty', 'Rate', 'Total'],
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 8),
            data: sale.items.map((it) => [it.name, it.batch, it.exp, it.qty.toInt(), it.rate.toStringAsFixed(2), it.total.toStringAsFixed(2)]).toList(),
          ),
          pw.Divider(),
          pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(children: [
            pw.Text("Grand Total: Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          ])),
        ],
      ),
    ));
    return pdf.save();
  }
}
