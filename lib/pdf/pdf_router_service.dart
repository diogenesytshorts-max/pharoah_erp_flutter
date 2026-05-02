// FILE: lib/pdf/pdf_router_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw; 
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../pharoah_manager.dart';
import '../gateway/company_registry_model.dart';

import 'sale_invoice_pdf.dart';
import 'architect_sale_pdf.dart';
import 'thermal_invoice_pdf.dart';
import 'purchase_pdf.dart';
import 'sale_challan_pdf.dart';
import 'purchase_challan_pdf.dart';

class PdfRouterService {
  
  // 1. SINGLE SALE PRINT
  static Future<void> printSale({required Sale sale, required Party party, required PharoahManager ph}) async {
    final config = ph.config;
    final shop = ph.activeCompany!;
    if (config.printFormat == "Thermal") {
      await ThermalInvoicePdf.generate(sale, party, shop, config);
    } else if (config.isArchitectMode) {
      await ArchitectSalePdf.generate(sale, party, shop, config);
    } else {
      await SaleInvoicePdf.generate(sale, party, shop);
    }
  }

  // 2. SINGLE PURCHASE PRINT
  static Future<void> printPurchase({required Purchase purchase, required Party supplier, required PharoahManager ph}) async {
    await PurchasePdf.generate(purchase, supplier, ph.activeCompany!);
  }

  // 3. SINGLE CHALLAN PRINT
  static Future<void> printChallan({required dynamic challan, required Party party, required PharoahManager ph, required bool isSaleChallan}) async {
    if (isSaleChallan) {
      await SaleChallanPdf.generate(challan, party, ph.activeCompany!);
    } else {
      await PurchaseChallanPdf.generate(challan, party, ph.activeCompany!);
    }
  }

  // 4. BULK ZIP GENERATOR (Fixed Brackets)
  static Future<String> createBulkZip({
    required List<Map<String, dynamic>> selectedDrafts,
    required PharoahManager ph,
    required Function(double progress, String filename) onProgress,
  }) async {
    final archive = Archive();
    final shop = ph.activeCompany!;
    final config = ph.config;

    for (int i = 0; i < selectedDrafts.length; i++) {
      var draft = selectedDrafts[i];
      dynamic billObj = draft['saleObj']; 
      Party party = draft['party'];

      onProgress((i + 1) / selectedDrafts.length, party.name);

      Uint8List pdfBytes;
      String billNo;

      if (billObj is Sale) {
        pdfBytes = await ArchitectSalePdf.generateBytes(billObj, party, shop, config);
        billNo = billObj.billNo;
      } else {
        pdfBytes = await PurchasePdf.generateBytes(billObj as Purchase, party, shop);
        billNo = (billObj as Purchase).billNo;
      }

      String cleanName = party.name.replaceAll(RegExp(r'[^A-Z0-9]'), '');
      String p5 = cleanName.padRight(5, 'X').substring(0, 5);
      String fileName = "${p5}_$billNo.pdf";

      archive.addFile(ArchiveFile(fileName, pdfBytes.length, pdfBytes));
    }

    final zipData = ZipEncoder().encode(archive);
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/ERP_Batch_${DateFormat('ddMM_HHmm').format(DateTime.now())}.zip';
    await File(zipPath).writeAsBytes(zipData!);
    
    return zipPath;
  }
} // Class ends here correctly
