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
import 'credit_note_pdf.dart'; // 🔥 NAYA IMPORT
import 'debit_note_pdf.dart';  // 🔥 NAYA IMPORT

class PdfRouterService {
  
  // ===========================================================================
  // 1. UNIVERSAL PARTY FINDER (Live Data Fetcher)
  // ===========================================================================
  static Party _getLatestParty(PharoahManager ph, String partyId, String partyName, {String gst = "", String state = "Rajasthan"}) {
    try {
      return ph.parties.firstWhere((p) => p.id == partyId);
    } catch (e) {
      try {
        return ph.parties.firstWhere((p) => p.name.toUpperCase() == partyName.toUpperCase());
      } catch (e) {
        return Party(id: 'temp', name: partyName, gst: gst, state: state);
      }
    }
  }

  // ===========================================================================
  // 2. SINGLE SALE PRINT
  // ===========================================================================
  static Future<void> printSale({required Sale sale, required Party party, required PharoahManager ph}) async {
    final config = ph.config;
    final shop = ph.activeCompany!;
    final latestParty = _getLatestParty(ph, sale.partyId, sale.partyName, gst: sale.partyGstin, state: sale.partyState);

    if (config.printFormat == "Thermal") {
      await ThermalInvoicePdf.generate(sale, latestParty, shop, config);
    } else if (config.isArchitectMode) {
      await ArchitectSalePdf.generate(sale, latestParty, shop, config);
    } else {
      await SaleInvoicePdf.generate(sale, latestParty, shop);
    }
  }

  // ===========================================================================
  // 3. SINGLE PURCHASE PRINT
  // ===========================================================================
  static Future<void> printPurchase({required Purchase purchase, required Party supplier, required PharoahManager ph}) async {
    final latestSupplier = _getLatestParty(ph, purchase.partyId, purchase.distributorName);
    await PurchasePdf.generate(purchase, latestSupplier, ph.activeCompany!);
  }

  // ===========================================================================
  // 4. 🔥 NAYA: CREDIT NOTE PRINT (Sales Return)
  // ===========================================================================
  static Future<void> printCreditNote({required SaleReturn returnObj, required Party party, required PharoahManager ph}) async {
    final shop = ph.activeCompany!;
    final config = ph.config;
    final latestParty = _getLatestParty(ph, "", returnObj.partyName); // Find by name
    await CreditNotePdf.generate(returnObj, latestParty, shop, config);
  }

  // ===========================================================================
  // 5. 🔥 NAYA: DEBIT NOTE PRINT (Purchase Return)
  // ===========================================================================
  static Future<void> printDebitNote({required PurchaseReturn returnObj, required Party supplier, required PharoahManager ph}) async {
    final shop = ph.activeCompany!;
    final config = ph.config;
    final latestSupplier = _getLatestParty(ph, "", returnObj.distributorName);
    await DebitNotePdf.generate(returnObj, latestSupplier, shop, config);
  }

  // ===========================================================================
  // 6. SINGLE CHALLAN PRINT
  // ===========================================================================
  static Future<void> printChallan({required dynamic challan, required Party party, required PharoahManager ph, required bool isSaleChallan}) async {
    if (isSaleChallan) {
      final latestParty = _getLatestParty(ph, challan.partyId, challan.partyName, gst: challan.partyGstin, state: challan.partyState);
      await SaleChallanPdf.generate(challan, latestParty, ph.activeCompany!);
    } else {
      final latestSupplier = _getLatestParty(ph, challan.partyId, challan.distributorName);
      await PurchaseChallanPdf.generate(challan, latestSupplier, ph.activeCompany!);
    }
  }

  // ===========================================================================
  // 7. BULK ZIP GENERATOR (Batch Export)
  // ===========================================================================
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
      Uint8List pdfBytes;
      String billNo;

      if (billObj is Sale) {
        final latestParty = _getLatestParty(ph, billObj.partyId, billObj.partyName, gst: billObj.partyGstin, state: billObj.partyState);
        onProgress((i + 1) / selectedDrafts.length, latestParty.name);
        if (config.isArchitectMode) pdfBytes = await ArchitectSalePdf.generateBytes(billObj, latestParty, shop, config);
        else pdfBytes = await SaleInvoicePdf.generateBytes(billObj, latestParty, shop);
        billNo = billObj.billNo;
      } else {
        final latestSupplier = _getLatestParty(ph, (billObj as Purchase).partyId, billObj.distributorName);
        onProgress((i + 1) / selectedDrafts.length, latestSupplier.name);
        pdfBytes = await PurchasePdf.generateBytes(billObj, latestSupplier, shop);
        billNo = billObj.billNo;
      }

      String fileName = "${billNo}.pdf";
      archive.addFile(ArchiveFile(fileName, pdfBytes.length, pdfBytes));
    }

    final zipData = ZipEncoder().encode(archive);
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/ERP_Batch_${DateFormat('ddMM_HHmm').format(DateTime.now())}.zip';
    await File(zipPath).writeAsBytes(zipData!);
    return zipPath;
  }
}
