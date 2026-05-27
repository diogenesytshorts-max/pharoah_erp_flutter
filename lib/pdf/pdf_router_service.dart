// FILE: lib/pdf/pdf_router_service.dart (FINAL STABLE VERSION)

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; 
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw; 
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart'; 

import '../models.dart';
import '../pharoah_manager.dart';
import '../gateway/company_registry_model.dart';
import '../logic/email_service.dart';

// --- PDF Generators ---
import 'sale_invoice_pdf.dart';
import 'architect_sale_pdf.dart';
import 'purchase_pdf.dart';
import 'sale_challan_pdf.dart';
import 'purchase_challan_pdf.dart';
import 'credit_note_pdf.dart'; 
import 'debit_note_pdf.dart';
import 'voucher_pdf.dart'; 
import 'statements/party_ledger_pdf.dart';
import 'statements/company_stock_pdf.dart';
import 'statements/party_stock_pdf.dart';
import 'universal_thermal_engine.dart'; 
import 'sale_report_pdf.dart';
import 'purchase_report_pdf.dart';
import '../gst_report_service.dart';

class PdfRouterService {
  
  // ===========================================================================
  // 1. HELPER: PARTY FINDER
  // ===========================================================================
  static Party _getLatestParty(PharoahManager ph, String partyId, String partyName, {String gst = "", String state = "Rajasthan"}) {
    try {
      return ph.parties.firstWhere((p) => p.id == partyId || p.name == partyName);
    } catch (e) {
      try {
        return ph.parties.firstWhere((p) => p.name.toUpperCase() == partyName.toUpperCase());
      } catch (e) {
        return Party(id: 'temp', name: partyName, gst: gst, state: state);
      }
    }
  }

  // ===========================================================================
  // 2. PUBLIC PRINT METHODS (FIXED: Added Back)
  // ===========================================================================
  
  static Future<void> printVoucher({required Voucher voucher, required Party party, required PharoahManager ph}) async {
    if (ph.activeCompany == null) return;
    if (ph.config.printFormat == "Thermal") {
      await UniversalThermalEngine.generate(doc: voucher, party: party, ph: ph, type: "VOUCHER");
    } else {
      await VoucherPdf.generate(voucher, party, ph.activeCompany!, ph);
    }
  }

  static Future<void> printSale({required Sale sale, required Party party, required PharoahManager ph}) async {
    final latestParty = _getLatestParty(ph, sale.partyId, sale.partyName, gst: sale.partyGstin, state: sale.partyState);
    if (ph.config.printFormat == "Thermal") {
      await UniversalThermalEngine.generate(doc: sale, party: latestParty, ph: ph, type: "SALE");
    } else {
      if (ph.config.isArchitectMode) {
        await ArchitectSalePdf.generate(sale, latestParty, ph.activeCompany!, ph.config);
      } else {
        await SaleInvoicePdf.generate(sale, latestParty, ph.activeCompany!);
      }
    }
  }

  static Future<void> printPurchase({required Purchase purchase, required Party supplier, required PharoahManager ph}) async {
    if (ph.config.printFormat == "Thermal") {
      await UniversalThermalEngine.generate(doc: purchase, party: supplier, ph: ph, type: "PURCHASE");
    } else {
      await PurchasePdf.generate(purchase, supplier, ph.activeCompany!);
    }
  }

  static Future<void> printChallan({required dynamic challan, required Party party, required PharoahManager ph, required bool isSaleChallan}) async {
    if (ph.config.printFormat == "Thermal") {
      await UniversalThermalEngine.generate(doc: challan, party: party, ph: ph, type: "CHALLAN");
    } else {
      if (isSaleChallan) await SaleChallanPdf.generate(challan, party, ph.activeCompany!);
      else await PurchaseChallanPdf.generate(challan, party, ph.activeCompany!);
    }
  }

  static Future<void> printCreditNote({required SaleReturn returnObj, required Party party, required PharoahManager ph}) async {
    if (ph.config.printFormat == "Thermal") await UniversalThermalEngine.generate(doc: returnObj, party: party, ph: ph, type: "RETURN");
    else await CreditNotePdf.generate(returnObj, party, ph.activeCompany!, ph.config);
  }

  static Future<void> printDebitNote({required PurchaseReturn returnObj, required Party supplier, required PharoahManager ph}) async {
    if (ph.config.printFormat == "Thermal") await UniversalThermalEngine.generate(doc: returnObj, party: supplier, ph: ph, type: "RETURN");
    else await DebitNotePdf.generate(returnObj, supplier, ph.activeCompany!, ph.config);
  }

  // ===========================================================================
  // 📧 3. EMAIL DISPATCHER (FIXED)
  // ===========================================================================
  static Future<void> emailDocument({
    required BuildContext context,
    required dynamic doc, 
    required Party party,
    required PharoahManager ph,
    required String type, 
  }) async {
    final config = ph.config;
    if (!config.isEmailActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email OFF")));
      return;
    }

    String targetEmail = (config.isAuditMode && config.caEmail.isNotEmpty) ? config.caEmail.trim() : party.email.trim();

    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      String? newEmail = await _showQuickEmailDialog(context, config.isAuditMode ? "CA Profile" : party.name);
      if (newEmail == null || newEmail.isEmpty) return;
      targetEmail = newEmail;
    }

    Uint8List pdfBytes;
    String docNo = "Report";

    try {
      if (type == "SALE") {
        if (doc is Sale) {
          docNo = doc.billNo;
          pdfBytes = config.isArchitectMode 
              ? await ArchitectSalePdf.generateBytes(doc, party, ph.activeCompany!, config)
              : await SaleInvoicePdf.generateBytes(doc, party, ph.activeCompany!);
        } else {
          docNo = (doc as Purchase).billNo;
          pdfBytes = await PurchasePdf.generateBytes(doc, party, ph.activeCompany!);
        }
      } 
      else if (type == "CHALLAN") {
        docNo = doc.billNo;
        pdfBytes = (doc is SaleChallan) ? await SaleChallanPdf.generateBytes(doc, party, ph.activeCompany!) : await PurchaseChallanPdf.generateBytes(doc, party, ph.activeCompany!);
      }
      else if (type == "LEDGER") {
        if (party.name.contains("GSTR-1")) pdfBytes = await GstReportService.generateGstr1Bytes(doc, ph.activeCompany!);
        else if (party.name.contains("GSTR-3B")) pdfBytes = await GstReportService.generateGstr3bBytes(doc, ph.purchases, ph.activeCompany!);
        else if (party.name.contains("CA Summary")) {
          if (doc is List<Sale>) pdfBytes = await SaleReportPdf.generateBytes(doc, ph.activeCompany!);
          else pdfBytes = await PurchaseReportPdf.generateBytes(doc, ph.activeCompany!);
        } else {
          pdfBytes = await PartyLedgerPdf.generateBytes(shop: ph.activeCompany!, party: party, data: doc, from: DateTime.now(), to: DateTime.now());
        }
      } else { return; }

      final template = PharoahEmailService.getTemplate(type: type, shopName: ph.activeCompany!.name, docNo: docNo);
      
      bool success = await PharoahEmailService.sendEmailWithPdf(
        config: config, shopName: ph.activeCompany!.name, recipientEmail: targetEmail,
        subject: config.isAuditMode ? "AUDIT: ${template['subject']}" : template['subject']!,
        body: config.isAuditMode ? "Dear CA, Attached is the audit report." : template['body']!,
        pdfBytes: pdfBytes, fileName: "${type}_${docNo.replaceAll(' ', '_')}",
      );

      if (success) {
        // FIXED: Removed 'const' because of variable $targetEmail
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Sent to $targetEmail"), backgroundColor: Colors.green));
      }
    } catch (e) { debugPrint("Router Error: $e"); }
  }

  // ===========================================================================
  // 📦 4. BATCH DISPATCHERS (STITCHER & AUDIT)
  // ===========================================================================
  
  // For Stitcher Wizard
  static Future<String> createBulkZip({required List<Map<String, dynamic>> selectedDrafts, required PharoahManager ph, required Function(double progress, String filename) onProgress}) async {
    final archive = Archive();
    for (int i = 0; i < selectedDrafts.length; i++) {
      var draft = selectedDrafts[i];
      dynamic billObj = draft['saleObj']; 
      Uint8List pdfBytes;
      if (billObj is Sale) {
        final p = _getLatestParty(ph, billObj.partyId, billObj.partyName);
        onProgress((i + 1) / selectedDrafts.length, p.name);
        pdfBytes = ph.config.isArchitectMode ? await ArchitectSalePdf.generateBytes(billObj, p, ph.activeCompany!, ph.config) : await SaleInvoicePdf.generateBytes(billObj, p, ph.activeCompany!);
      } else {
        final p = _getLatestParty(ph, (billObj as Purchase).partyId, billObj.distributorName);
        onProgress((i + 1) / selectedDrafts.length, p.name);
        pdfBytes = await PurchasePdf.generateBytes(billObj, p, ph.activeCompany!);
      }
      archive.addFile(ArchiveFile("${billObj.billNo}.pdf", pdfBytes.length, pdfBytes));
    }
    final zipData = ZipEncoder().encode(archive);
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/Export_${DateFormat('HHmm').format(DateTime.now())}.zip';
    await File(zipPath).writeAsBytes(zipData!);
    return zipPath;
  }

  // For CA Audit Mode
  static Future<void> sendBatchToCa({required List<dynamic> documents, required PharoahManager ph, required String type}) async {
    if (!ph.config.isAuditMode || ph.config.caEmail.isEmpty) return;
    try {
      final archive = Archive();
      for (var doc in documents) {
        Uint8List pdfBytes;
        if (type == "SALE" && doc is Sale) {
          final p = _getLatestParty(ph, doc.partyId, doc.partyName);
          pdfBytes = ph.config.isArchitectMode ? await ArchitectSalePdf.generateBytes(doc, p, ph.activeCompany!, ph.config) : await SaleInvoicePdf.generateBytes(doc, p, ph.activeCompany!);
        } else if (type == "PURCHASE" && doc is Purchase) {
          final p = _getLatestParty(ph, doc.partyId, doc.distributorName);
          pdfBytes = await PurchasePdf.generateBytes(doc, p, ph.activeCompany!);
        } else { continue; }
        archive.addFile(ArchiveFile("${doc.billNo}.pdf", pdfBytes.length, pdfBytes));
      }
      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return;
      await PharoahEmailService.sendEmailWithPdf(
        config: ph.config, shopName: ph.activeCompany!.name, recipientEmail: ph.config.caEmail,
        subject: "AUDIT BUNDLE: ${documents.length} $type Bills",
        body: "Attached is the zipped bundle for audit.",
        pdfBytes: Uint8List.fromList(zipData),
        fileName: "Audit_${type}_${DateFormat('ddMM').format(DateTime.now())}.zip",
      );
    } catch (e) { debugPrint("Batch Error: $e"); }
  }

  static Future<String?> _showQuickEmailDialog(BuildContext context, String partyName) async {
    final emailC = TextEditingController();
    return showDialog<String>(
      context: context, barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("Email Required"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [Text("Target: $partyName. Enter Email:"), const SizedBox(height: 15), TextField(controller: emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email ID", border: OutlineInputBorder()))]),
        actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")), ElevatedButton(onPressed: () => Navigator.pop(c, emailC.text.trim()), child: const Text("PROCEED"))],
      ),
    );
  }
}
