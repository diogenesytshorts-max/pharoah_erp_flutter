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
  
  // 1. MAIN ENGINE: Create Zip from multiple bills
  static Future<String> createBillsZip({
    required List<Map<String, dynamic>> selectedDrafts,
    required CompanyProfile shop,
    required Function(double progress, String filename) onProgress,
  }) async {
    final archive = Archive();

    for (int i = 0; i < selectedDrafts.length; i++) {
      var draft = selectedDrafts[i];
      Sale sale = draft['saleObj']; // Saved Sale Object
      Party party = draft['party'];

      // Progress Update
      onProgress((i + 1) / selectedDrafts.length, party.name);

      // A. Generate PDF Bytes (Silent mode - no dialog)
      final pdfBytes = await _generateSilentPdfBytes(sale, party, shop);

      // B. Smart Naming Style: Party 5 Digit + BillNo
      String cleanName = party.name.replaceAll(RegExp(r'[^A-Z]'), '');
      String p5 = cleanName.length > 5 ? cleanName.substring(0, 5) : cleanName.padRight(5, 'X');
      String fileName = "${p5}_${sale.billNo}.pdf";

      // C. Add to Archive
      archive.addFile(ArchiveFile(fileName, pdfBytes.length, pdfBytes));
    }

    // 2. SAVE ZIP TO TEMPORARY DIRECTORY
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/Batch_Bills_${DateFormat('ddMM_HHmm').format(DateTime.now())}.zip';
    
    final zipFile = File(zipPath);
    await zipFile.writeAsBytes(zipData!);

    return zipPath;
  }

  // INTERNAL: Simple PDF Generator for Bulk (Similar to your A4 style)
  static Future<Uint8List> _generateSilentPdfBytes(Sale sale, Party party, CompanyProfile shop) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Column(children: [
        pw.Text(shop.name, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("Invoice: ${sale.billNo}"),
          pw.Text("Date: ${DateFormat('dd/MM/yy').format(sale.date)}"),
        ]),
        pw.SizedBox(height: 20),
        pw.Text("Bill To: ${party.name}"),
        pw.Divider(),
        pw.TableHelper.fromTextArray(
          headers: ['Item', 'Batch', 'Qty', 'Total'],
          data: sale.items.map((it) => [it.name, it.batch, it.qty.toInt().toString(), it.total.toStringAsFixed(2)]).toList(),
        ),
        pw.Spacer(),
        pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text("Total Amount: Rs. ${sale.totalAmount.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
      ]),
    ));
    return pdf.save();
  }
}
