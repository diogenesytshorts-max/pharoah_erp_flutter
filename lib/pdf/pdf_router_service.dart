// FILE: lib/pdf/pdf_router_service.dart (UPDATED WITH CA AUDIT NEXUS)

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

class PdfRouterService {
  
  // 1. UNIVERSAL PARTY FINDER (Original preserved)
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

  // 2. VOUCHER PRINT (Original preserved)
  static Future<void> printVoucher({required Voucher voucher, required Party party, required PharoahManager ph}) async {
    if (ph.activeCompany == null) return;
    try {
      if (ph.config.printFormat == "Thermal") {
        await UniversalThermalEngine.generate(doc: voucher, party: party, ph: ph, type: "VOUCHER");
      } else {
        await VoucherPdf.generate(voucher, party, ph.activeCompany!, ph);
      }
    } catch (e) { debugPrint("PDF Routing Error (Voucher): $e"); }
  }

  // 3. TRANSACTION PRINTS (Original preserved)
  static Future<void> printSale({required Sale sale, required Party party, required PharoahManager ph}) async {
    final config = ph.config;
    final shop = ph.activeCompany!;
    final latestParty = _getLatestParty(ph, sale.partyId, sale.partyName, gst: sale.partyGstin, state: sale.partyState);
    if (config.printFormat == "Thermal") {
      await UniversalThermalEngine.generate(doc: sale, party: latestParty, ph: ph, type: "SALE");
    } else {
      if (config.isArchitectMode) await ArchitectSalePdf.generate(sale, latestParty, shop, config);
      else await SaleInvoicePdf.generate(sale, latestParty, shop);
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
  // 📧 4. MASTER EMAIL DISPATCHER (UPDATED FOR CA REDIRECTION)
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email service is OFF in Settings."), backgroundColor: Colors.orange));
      return;
    }

    // --- NAYA AUDIT CODE: RECIPIENT LOGIC ---
    String targetEmail = "";
    if (config.isAuditMode && config.caEmail.isNotEmpty) {
      targetEmail = config.caEmail.trim(); // Audit Mode में CA का ईमेल
    } else {
      targetEmail = party.email.trim(); // Normal Mode में ग्राहक का ईमेल
    }

    // Email missing check
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      String? newEmail = await _showQuickEmailDialog(context, config.isAuditMode ? "Your CA Profile" : party.name);
      if (newEmail == null || newEmail.isEmpty) return;
      if (config.isAuditMode) {
        config.caEmail = newEmail;
      } else {
        int idx = ph.parties.indexWhere((p) => p.id == party.id);
        if (idx != -1) { ph.parties[idx].email = newEmail; await ph.save(); }
      }
      targetEmail = newEmail;
    }

    Uint8List pdfBytes;
    String docNo = "";
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
        pdfBytes = (doc is SaleChallan) 
            ? await SaleChallanPdf.generateBytes(doc, party, ph.activeCompany!)
            : await PurchaseChallanPdf.generateBytes(doc, party, ph.activeCompany!);
      }
      else if (type == "RETURN" || type == "CN" || type == "DN") {
        docNo = doc.billNo;
        pdfBytes = (doc is SaleReturn)
            ? await CreditNotePdf.generateBytes(doc, party, ph.activeCompany!, config)
            : await DebitNotePdf.generateBytes(doc, party, ph.activeCompany!, config);
      }
      else if (type == "LEDGER") {
        docNo = "Summary";
        pdfBytes = await PartyLedgerPdf.generateBytes(shop: ph.activeCompany!, party: party, data: doc, from: DateTime.now(), to: DateTime.now());
      }
      else { return; }

      final template = PharoahEmailService.getTemplate(type: type, shopName: ph.activeCompany!.name, docNo: docNo);
      
      // Send Email
      bool success = await PharoahEmailService.sendEmailWithPdf(
        config: config,
        shopName: ph.activeCompany!.name,
        recipientEmail: targetEmail,
        subject: config.isAuditMode ? "AUDIT: ${template['subject']}" : template['subject']!,
        body: config.isAuditMode ? "Dear CA,\n\nPlease find attached the audit report for your review.\n\nRegards,\n${ph.activeCompany!.name}" : template['body']!,
        pdfBytes: pdfBytes,
        fileName: "${type}_$docNo",
      );

      if (success) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Dispatched Successfully!"), backgroundColor: Colors.green));
      else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Failed to send."), backgroundColor: Colors.red));

    } catch (e) { debugPrint("Email Router Error: $e"); }
  }

  // ===========================================================================
  // 📦 5. NAYA AUDIT CODE: BATCH ZIP DISPATCH (STITCHER STYLE)
  // ===========================================================================
  static Future<void> sendBatchToCa({
    required List<dynamic> documents, 
    required PharoahManager ph,
    required String type, // "SALE" or "PURCHASE"
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

      await PharoahEmailService.sendEmailWithPdf(
        config: config,
        shopName: ph.activeCompany!.name,
        recipientEmail: config.caEmail,
        subject: "AUDIT BUNDLE: ${documents.length} $type Bills",
        body: "Respected CA,\n\nPlease find attached the zipped batch of ${documents.length} bills for the audit period.\n\nRegards,\n${ph.activeCompany!.name}",
        pdfBytes: Uint8List.fromList(zipData),
        fileName: "Audit_Package_${DateFormat('ddMM').format(DateTime.now())}",
      );

      ph.addLog("AUDIT", "Mailed a ZIP bundle of ${documents.length} bills to CA.");

    } catch (e) { debugPrint("Batch ZIP Error: $e"); throw e; }
  }

  // --- PRIVATE HELPER: QUICK EMAIL DIALOG ---
  static Future<String?> _showQuickEmailDialog(BuildContext context, String partyName) async {
    final emailC = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Email Required"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("Target: $partyName. Please enter email to proceed."),
          const SizedBox(height: 15),
          TextField(controller: emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Email ID", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(onPressed: () => Navigator.pop(c, emailC.text.trim()), child: const Text("PROCEED")),
        ],
      ),
    );
  }
}
