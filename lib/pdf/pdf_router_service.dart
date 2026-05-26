// FILE: lib/pdf/pdf_router_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // 🔥 FIXED: debugPrint ke liye zaroori import
import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw; 
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../pharoah_manager.dart';
import '../gateway/company_registry_model.dart';
import '../logic/email_service.dart'; // NAYA
import 'package:flutter/material.dart'; // UI Dialogs ke liye

import 'sale_invoice_pdf.dart';
import 'architect_sale_pdf.dart';
import 'thermal_invoice_pdf.dart';
import 'purchase_pdf.dart';
import 'sale_challan_pdf.dart';
import 'purchase_challan_pdf.dart';
import 'credit_note_pdf.dart'; 
import 'debit_note_pdf.dart';
import 'voucher_pdf.dart'; 
import 'statements/party_ledger_pdf.dart'; // NAYA
import 'statements/company_stock_pdf.dart'; // NAYA
import 'statements/party_stock_pdf.dart';   // NAYA

class PdfRouterService {
  
  // ===========================================================================
  // 1. UNIVERSAL PARTY FINDER (Live Data Fetcher)
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
  // 2. VOUCHER PRINT (Receipt & Payment) - CORRECTED
  // ===========================================================================
  static Future<void> printVoucher({required Voucher voucher, required Party party, required PharoahManager ph}) async {
    if (ph.activeCompany == null) return;
    try {
      // Direct call to our new Portrait A5 Generator
      await VoucherPdf.generate(voucher, party, ph.activeCompany!, ph);
    } catch (e) {
      debugPrint("PDF Routing Error: $e");
    }
  }

  // ===========================================================================
  // 3. OTHER TRANSACTION PRINTS
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

  static Future<void> printPurchase({required Purchase purchase, required Party supplier, required PharoahManager ph}) async {
    final latestSupplier = _getLatestParty(ph, purchase.partyId, purchase.distributorName);
    await PurchasePdf.generate(purchase, latestSupplier, ph.activeCompany!);
  }

  static Future<void> printCreditNote({required SaleReturn returnObj, required Party party, required PharoahManager ph}) async {
    final shop = ph.activeCompany!;
    final config = ph.config;
    final latestParty = _getLatestParty(ph, "", returnObj.partyName);
    await CreditNotePdf.generate(returnObj, latestParty, shop, config);
  }

  static Future<void> printDebitNote({required PurchaseReturn returnObj, required Party supplier, required PharoahManager ph}) async {
    final shop = ph.activeCompany!;
    final config = ph.config;
    final latestSupplier = _getLatestParty(ph, "", returnObj.distributorName);
    await DebitNotePdf.generate(returnObj, latestSupplier, shop, config);
  }

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
  // 📧 FINAL DISPATCHER: SALES, CHALLANS & STATEMENTS
  // ===========================================================================
  // ===========================================================================
  // 📧 MASTER EMAIL DISPATCHER (REFINED VERSION)
  // ===========================================================================
  static Future<void> emailDocument({
    required BuildContext context,
    required dynamic doc, 
    required Party party,
    required PharoahManager ph,
    required String type, 
  }) async {
    final config = ph.config;

    // 1. IMMEDIATE FEEDBACK (Sabse pehle message dikhao)
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Preparing document... please wait."),
      duration: Duration(seconds: 2),
    ));

    if (!config.isEmailActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email service is OFF in Settings."), backgroundColor: Colors.orange));
      return;
    }

    // 2. QUICK ADD EMAIL LOGIC
    String targetEmail = party.email.trim();
    if (targetEmail.isEmpty || !targetEmail.contains('@')) {
      String? newEmail = await _showQuickEmailDialog(context, party.name);
      if (newEmail == null || newEmail.isEmpty) return;
      if (party.id != 'internal') {
        int idx = ph.parties.indexWhere((p) => p.id == party.id);
        if (idx != -1) { ph.parties[idx].email = newEmail; await ph.save(); }
      }
      targetEmail = newEmail;
    }

    Uint8List pdfBytes;
    String docNo = "";
    String dateRange = "";

    try {
      // 3. ROBUST TYPE HANDLING (All Cases)
      if (type == "SALE") {
        if (doc is Sale) {
          docNo = doc.billNo;
          if (config.isArchitectMode) pdfBytes = await ArchitectSalePdf.generateBytes(doc, party, ph.activeCompany!, config);
          else pdfBytes = await SaleInvoicePdf.generateBytes(doc, party, ph.activeCompany!);
        } else {
          docNo = (doc as Purchase).billNo;
          pdfBytes = await PurchasePdf.generateBytes(doc, party, ph.activeCompany!);
        }
      } 
      else if (type == "CHALLAN") {
        if (doc is SaleChallan) {
          docNo = doc.billNo;
          pdfBytes = await SaleChallanPdf.generateBytes(doc, party, ph.activeCompany!);
        } else {
          docNo = (doc as PurchaseChallan).billNo;
          pdfBytes = await PurchaseChallanPdf.generateBytes(doc, party, ph.activeCompany!);
        }
      }
      else if (type == "RETURN") {
        if (doc is SaleReturn) {
          docNo = doc.billNo;
          // Note: Generating bytes for returns (using standard generator)
          pdfBytes = await CreditNotePdf.generateBytes(doc, party, ph.activeCompany!, config);
        } else {
          docNo = (doc as PurchaseReturn).billNo;
          pdfBytes = await DebitNotePdf.generateBytes(doc, party, ph.activeCompany!, config);
        }
      }
      else if (type == "LEDGER") {
        docNo = "Statement";
        pdfBytes = await PartyLedgerPdf.generateBytes(shop: ph.activeCompany!, party: party, data: doc, from: DateTime.now(), to: DateTime.now());
      }
      else if (type == "STOCK") {
        docNo = "StockReport";
        if (doc.containsKey('basis')) {
          pdfBytes = await CompanyStockPdf.generateBytes(shop: ph.activeCompany!, groupedData: doc['grouped'], from: doc['from'], to: doc['to'], valuationBasis: doc['basis'], ph: ph);
        } else {
          pdfBytes = await PartyStockPdf.generateBytes(shop: ph.activeCompany!, groupedData: doc['grouped'], from: doc['from'], to: doc['to'], mode: doc['mode']);
        }
      } else { return; }

      // 4. TEMPLATE & SEND
      final template = PharoahEmailService.getTemplate(type: type, shopName: ph.activeCompany!.name, docNo: docNo, dateRange: dateRange);
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connecting to Server... Sending to $targetEmail"), backgroundColor: Colors.indigo));

      bool success = await PharoahEmailService.sendEmailWithPdf(
        config: config,
        shopName: ph.activeCompany!.name,
        recipientEmail: targetEmail,
        subject: template['subject']!,
        body: template['body']!,
        pdfBytes: pdfBytes,
        fileName: "${type}_$docNo",
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Email Delivered Successfully!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Mail Failed. Check SMTP Credentials."), backgroundColor: Colors.red));
      }
    } catch (e) {
      print("Router Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("System Error: $e"), backgroundColor: Colors.red));
    }
  }

  // --- PRIVATE HELPER: QUICK EMAIL DIALOG ---
  static Future<String?> _showQuickEmailDialog(BuildContext context, String partyName) async {
    final emailC = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("Email Required"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text("No email found for $partyName. Enter email to send and save to master record."),
          const SizedBox(height: 15),
          TextField(controller: emailC, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: "Customer Email ID", border: OutlineInputBorder(), prefixIcon: Icon(Icons.email))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(onPressed: () => Navigator.pop(c, emailC.text.trim()), child: const Text("SAVE & SEND")),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. BULK EXPORT LOGIC
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

      if (billObj is Sale) {
        final latestParty = _getLatestParty(ph, billObj.partyId, billObj.partyName, gst: billObj.partyGstin, state: billObj.partyState);
        onProgress((i + 1) / selectedDrafts.length, latestParty.name);
        if (config.isArchitectMode) pdfBytes = await ArchitectSalePdf.generateBytes(billObj, latestParty, shop, config);
        else pdfBytes = await SaleInvoicePdf.generateBytes(billObj, latestParty, shop);
      } else {
        final latestSupplier = _getLatestParty(ph, (billObj as Purchase).partyId, billObj.distributorName);
        onProgress((i + 1) / selectedDrafts.length, latestSupplier.name);
        pdfBytes = await PurchasePdf.generateBytes(billObj, latestSupplier, shop);
      }

      archive.addFile(ArchiveFile("${billObj.billNo}.pdf", pdfBytes.length, pdfBytes));
    }

    final zipData = ZipEncoder().encode(archive);
    final tempDir = await getTemporaryDirectory();
    final zipPath = '${tempDir.path}/ERP_Batch_${DateFormat('ddMM_HHmm').format(DateTime.now())}.zip';
    await File(zipPath).writeAsBytes(zipData!);
    return zipPath;
  }
}
