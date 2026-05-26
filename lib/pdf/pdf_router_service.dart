// FILE: lib/pdf/pdf_router_service.dart (FINAL COMPREHENSIVE VERSION)

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

// --- PDF Generators (A4/Architect) ---
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

// --- The New Power Engine ---
import 'universal_thermal_engine.dart'; // 🚀 UNIVERSAL THERMAL

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
  // 2. VOUCHER PRINT (Receipt & Payment) - UNIVERSAL SYNC
  // ===========================================================================
  static Future<void> printVoucher({required Voucher voucher, required Party party, required PharoahManager ph}) async {
    if (ph.activeCompany == null) return;
    try {
      if (ph.config.printFormat == "Thermal") {
        // 📠 Route to Universal Thermal
        await UniversalThermalEngine.generate(doc: voucher, party: party, ph: ph, type: "VOUCHER");
      } else {
        await VoucherPdf.generate(voucher, party, ph.activeCompany!, ph);
      }
    } catch (e) {
      debugPrint("PDF Routing Error (Voucher): $e");
    }
  }

  // ===========================================================================
  // 3. TRANSACTION PRINTS (Sale, Purchase, Challan, Return)
  // ===========================================================================

  static Future<void> printSale({required Sale sale, required Party party, required PharoahManager ph}) async {
    final config = ph.config;
    final shop = ph.activeCompany!;
    final latestParty = _getLatestParty(ph, sale.partyId, sale.partyName, gst: sale.partyGstin, state: sale.partyState);

    if (config.printFormat == "Thermal") {
      // 📠 Route to Universal Thermal
      await UniversalThermalEngine.generate(doc: sale, party: latestParty, ph: ph, type: "SALE");
    } else {
      if (config.isArchitectMode) {
        await ArchitectSalePdf.generate(sale, latestParty, shop, config);
      } else {
        await SaleInvoicePdf.generate(sale, latestParty, shop);
      }
    }
  }

  static Future<void> printPurchase({required Purchase purchase, required Party supplier, required PharoahManager ph}) async {
    if (ph.config.printFormat == "Thermal") {
      // 📠 Route to Universal Thermal
      await UniversalThermalEngine.generate(doc: purchase, party: supplier, ph: ph, type: "PURCHASE");
    } else {
      await PurchasePdf.generate(purchase, supplier, ph.activeCompany!);
    }
  }

  static Future<void> printChallan({required dynamic challan, required Party party, required PharoahManager ph, required bool isSaleChallan}) async {
    if (ph.config.printFormat == "Thermal") {
      // 📠 Route to Universal Thermal
      await UniversalThermalEngine.generate(doc: challan, party: party, ph: ph, type: "CHALLAN");
    } else {
      if (isSaleChallan) await SaleChallanPdf.generate(challan, party, ph.activeCompany!);
      else await PurchaseChallanPdf.generate(challan, party, ph.activeCompany!);
    }
  }

  static Future<void> printCreditNote({required SaleReturn returnObj, required Party party, required PharoahManager ph}) async {
    if (ph.config.printFormat == "Thermal") {
      // 📠 Route to Universal Thermal
      await UniversalThermalEngine.generate(doc: returnObj, party: party, ph: ph, type: "RETURN");
    } else {
      await CreditNotePdf.generate(returnObj, party, ph.activeCompany!, ph.config);
    }
  }

  static Future<void> printDebitNote({required PurchaseReturn returnObj, required Party supplier, required PharoahManager ph}) async {
    if (ph.config.printFormat == "Thermal") {
      // 📠 Route to Universal Thermal
      await UniversalThermalEngine.generate(doc: returnObj, party: supplier, ph: ph, type: "RETURN");
    } else {
      await DebitNotePdf.generate(returnObj, supplier, ph.activeCompany!, ph.config);
    }
  }

  // ===========================================================================
  // 📧 4. MASTER EMAIL DISPATCHER (Professional A4 Focus)
  // ===========================================================================
  static Future<void> emailDocument({
    required BuildContext context,
    required dynamic doc, 
    required Party party,
    required PharoahManager ph,
    required String type, 
  }) async {
    final config = ph.config;

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text("Preparing professional PDF for email..."),
      duration: Duration(seconds: 2),
    ));

    if (!config.isEmailActive) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email service is OFF in Settings."), backgroundColor: Colors.orange));
      return;
    }

    // Quick Add Email if Missing
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
      else if (type == "RETURN" || type == "CN" || type == "DN") {
        if (doc is SaleReturn) {
          docNo = doc.billNo;
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
      } 
      else if (type == "VOUCHER") {
        docNo = (doc as Voucher).voucherNo;
        pdfBytes = await VoucherPdf.generateBytes(doc, party, ph.activeCompany!, ph);
      }
      else { return; }

      final template = PharoahEmailService.getTemplate(type: type, shopName: ph.activeCompany!.name, docNo: docNo, dateRange: dateRange);
      
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sending to $targetEmail..."), backgroundColor: Colors.indigo));

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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Email Sent Successfully!"), backgroundColor: Colors.green));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("❌ Failed to send email."), backgroundColor: Colors.red));
      }
    } catch (e) {
      debugPrint("Router Email Error: $e");
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
  // 5. BULK EXPORT LOGIC (ZIP)
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
