// FILE: lib/pdf/pdf_router_service.dart (FINAL COMPREHENSIVE & FIXED)

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
import 'sale_report_pdf.dart';     // NAYA IMPORT
import 'purchase_report_pdf.dart'; // NAYA IMPORT
import '../gst_report_service.dart'; // NAYA IMPORT

class PdfRouterService {
  
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

  // ---------------------------------------------------------------------------
  // 📧 MASTER EMAIL DISPATCHER (FULLY FIXED)
  // ---------------------------------------------------------------------------
  static Future<void> emailDocument({
    required BuildContext context,
    required dynamic doc, 
    required Party party,
    required PharoahManager ph,
    required String type, 
  }) async {
    final config = ph.config;
    if (!config.isEmailActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email service is OFF."), backgroundColor: Colors.orange));
      return;
    }

    // AUDIT MODE REDIRECTION
    String targetEmail = (config.isAuditMode && config.caEmail.isNotEmpty) 
        ? config.caEmail.trim() 
        : party.email.trim();

    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      String? newEmail = await _showQuickEmailDialog(context, config.isAuditMode ? "CA Profile" : party.name);
      if (newEmail == null || newEmail.isEmpty) return;
      targetEmail = newEmail;
    }

    Uint8List pdfBytes;
    String docNo = "Report";

    try {
      // --- LOGIC: TYPE BASED BYTE GENERATION ---
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
        pdfBytes = (doc is SaleChallan) 
            ? await SaleChallanPdf.generateBytes(doc, party, ph.activeCompany!)
            : await PurchaseChallanPdf.generateBytes(doc, party, ph.activeCompany!);
      }
      // 🔥 NEW: GSTR & REGISTER SUMMARIES LOGIC
      else if (type == "LEDGER") {
        if (party.name.contains("GSTR-1")) {
          pdfBytes = await GstReportService.generateGstr1Bytes(doc, ph.activeCompany!);
        } else if (party.name.contains("GSTR-3B")) {
          pdfBytes = await GstReportService.generateGstr3bBytes(doc, ph.purchases, ph.activeCompany!);
        } else if (party.name.contains("GSTR-2")) {
          pdfBytes = await GstReportService.generateGstr2Bytes(doc, ph.vouchers, ph.parties, ph.activeCompany!);
        } else if (party.name.contains("CA Summary")) {
           // Check if it's Sale or Purchase summary
           if (doc is List<Sale>) pdfBytes = await SaleReportPdf.generateBytes(doc, ph.activeCompany!);
           else pdfBytes = await PurchaseReportPdf.generateBytes(doc, ph.activeCompany!);
        } else {
          pdfBytes = await PartyLedgerPdf.generateBytes(shop: ph.activeCompany!, party: party, data: doc, from: DateTime.now(), to: DateTime.now());
        }
      }
      else { return; }

      final template = PharoahEmailService.getTemplate(type: type, shopName: ph.activeCompany!.name, docNo: docNo);
      
      bool success = await PharoahEmailService.sendEmailWithPdf(
        config: config,
        shopName: ph.activeCompany!.name,
        recipientEmail: targetEmail,
        subject: config.isAuditMode ? "AUDIT: ${template['subject']}" : template['subject']!,
        body: config.isAuditMode ? "Respected CA, Attached is the required audit report." : template['body']!,
        pdfBytes: pdfBytes,
        fileName: "${type}_${docNo.replaceAll(' ', '_')}",
      );

      if (success) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Sent to $targetEmail"), backgroundColor: Colors.green));
    } catch (e) { debugPrint("Router Error: $e"); }
  }

  // ---------------------------------------------------------------------------
  // 📦 6. NEW CA AUDIT ZIP DISPATCH (STITCHER LOGIC)
  // ---------------------------------------------------------------------------
  static Future<void> sendBatchToCa({
    required List<dynamic> documents, 
    required PharoahManager ph,
    required String type, 
  }) async {
    final config = ph.config;
    if (!config.isAuditMode || config.caEmail.isEmpty) return;

    try {
      final archive = Archive();

      for (var doc in documents) {
        Uint8List pdfBytes;
        String fileName = "";

        if (type == "SALE" && doc is Sale) {
          final p = _getLatestParty(ph, doc.partyId, doc.partyName);
          pdfBytes = config.isArchitectMode 
              ? await ArchitectSalePdf.generateBytes(doc, p, ph.activeCompany!, config)
              : await SaleInvoicePdf.generateBytes(doc, p, ph.activeCompany!);
          fileName = "${doc.billNo}.pdf";
        } 
        else if (type == "PURCHASE" && doc is Purchase) {
          final p = _getLatestParty(ph, doc.partyId, doc.distributorName);
          pdfBytes = await PurchasePdf.generateBytes(doc, p, ph.activeCompany!);
          fileName = "${doc.billNo}.pdf";
        } else { continue; }

        archive.addFile(ArchiveFile(fileName, pdfBytes.length, pdfBytes));
      }

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return;

      // 🔥 IMPORTANT: FileName must end with .zip
      await PharoahEmailService.sendEmailWithPdf(
        config: config,
        shopName: ph.activeCompany!.name,
        recipientEmail: config.caEmail,
        subject: "AUDIT BUNDLE: ${documents.length} $type Records",
        body: "Respected CA, Attached is the zipped audit bundle for ${ph.activeCompany!.name}.",
        pdfBytes: Uint8List.fromList(zipData),
        fileName: "Audit_Bundle_${DateFormat('ddMM').format(DateTime.now())}.zip",
      );

      ph.addLog("AUDIT", "Mailed ZIP bundle to CA.");
    } catch (e) { debugPrint("Batch Error: $e"); }
  }

  // (createBulkZip और _showQuickEmailDialog पहले जैसे ही रहेंगे...)
  static Future<String> createBulkZip({required List<Map<String, dynamic>> selectedDrafts, required PharoahManager ph, required Function(double progress, String filename) onProgress}) async {
    final archive = Archive();
    final shop = ph.activeCompany!;
    final config = ph.config;
    for (int i = 0; i < selectedDrafts.length; i++) {
      var draft = selectedDrafts[i];
      dynamic billObj = draft['saleObj']; 
      Uint8List pdfBytes;
      if (billObj is Sale) {
        final latestParty = _getLatestParty(ph, billObj.partyId, billObj.partyName);
        onProgress((i + 1) / selectedDrafts.length, latestParty.name);
        pdfBytes = config.isArchitectMode ? await ArchitectSalePdf.generateBytes(billObj, latestParty, shop, config) : await SaleInvoicePdf.generateBytes(billObj, latestParty, shop);
      } else {
        final latestSupplier = _getLatestParty(ph, (billObj as Purchase).partyId, billObj.distributorName);
        onProgress((i + 1) / selectedDrafts.length, latestSupplier.name);
        pdfBytes = await PurchasePdf.generateBytes(billObj, latestSupplier, shop);
      }
      archive.addFile(ArchiveFile("${billObj.billNo}.pdf", pdfBytes.length, pdfBytes));
    }
    final zipData = ZipEncoder().encode(archive);
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/Batch_Export_${DateFormat('ddMM_HHmm').format(DateTime.now())}.zip';
    await File(zipPath).writeAsBytes(zipData!);
    return zipPath;
  }

  static Future<String?> _showQuickEmailDialog(BuildContext context, String partyName) async {
    final emailC = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("Email Required"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Target: $partyName. Enter Email:"),
          const SizedBox(height: 15),
          TextField(controller: emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email ID", border: OutlineInputBorder())),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(onPressed: () => Navigator.pop(c, emailC.text.trim()), child: const Text("PROCEED")),
        ],
      ),
    );
  }
}
