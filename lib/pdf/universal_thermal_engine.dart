// FILE: lib/pdf/universal_thermal_engine.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models.dart';
import '../pharoah_manager.dart';
import '../gateway/company_registry_model.dart';
import '../logic/app_settings_model.dart';
import 'pdf_master_service.dart';

class UniversalThermalEngine {
  
  // ===========================================================================
  // 📠 1. MAIN GENERATOR (The Entry Point)
  // ===========================================================================
  static Future<void> generate({
    required dynamic doc,      // Sale, Challan, Return, Voucher etc.
    required Party party,      // Consignee Details
    required PharoahManager ph, 
    required String type,     // "SALE", "CHALLAN", "RETURN", "VOUCHER", "LEDGER", "STOCK"
  }) async {
    final pdf = pw.Document();
    final shop = ph.activeCompany!;
    final config = ph.config;

    // Logo Load Logic (B/W for Thermal)
    pw.MemoryImage? logoImg;
    if (config.showLogo && config.logoPath != null && File(config.logoPath!).existsSync()) {
      logoImg = pw.MemoryImage(File(config.logoPath!).readAsBytesSync());
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80, // 80mm Standard Width
        margin: const pw.EdgeInsets.all(5),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // --- A. ADVANCED SHOP HEADER ---
              _buildShopHeader(shop, config, logoImg, type),
              
              PdfMasterService.thermalDivider(),

              // --- B. ADVANCED CONSIGNEE (PARTY) HEADER ---
              _buildPartyHeader(party, doc, type),

              PdfMasterService.thermalDivider(),

              // --- C. TRANSACTION METADATA (No, Date, Time) ---
              _buildDocMetadata(doc, type),

              PdfMasterService.thermalDivider(),

              // --- D. THE DYNAMIC CONTENT AREA ---
              // (Iska code hum agle hisse mein likhenge: Table Builder)
           PdfMasterService.thermalDivider(),

              // --- D. THE DYNAMIC CONTENT AREA (FIXED) ---
              _buildDynamicContent(doc, type, config),

              PdfMasterService.thermalDivider(),

              // --- E. ADVANCED SUMMARY & FOOTER ---
              _buildAdvancedFooter(doc, shop, config, ph, type),
              // ===========================================================================
  // 📦 4. DYNAMIC CONTENT ENGINE (Stacked Row Logic)
  // ===========================================================================

  static pw.Widget _buildDynamicContent(dynamic doc, String type, AppConfig config) {
    List<dynamic> items = [];
    if (doc is Sale || doc is SaleChallan || doc is SaleReturn) items = doc.items;
    else if (doc is Purchase || doc is PurchaseChallan || doc is PurchaseReturn) items = doc.items;
    
    // Ledger aur Stock ke liye hum bad mein alag table banayenge
    if (type == "LEDGER" || type == "STOCK") return pw.Center(child: pw.Text("Statement Data Processing..."));

    return pw.Column(
      children: List.generate(items.length, (index) {
        final item = items[index];
        bool isShaded = config.useZebraShading && (index % 2 != 0);

        return pw.Container(
          padding: const pw.EdgeInsets.all(3),
          decoration: pw.BoxDecoration(
            color: isShaded ? PdfColors.grey100 : null,
            border: const pw.Border(bottom: pw.BorderSide(width: 0.2, color: PdfColors.grey400))
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Row 1: S.N + Product Name + Packing
              pw.Row(children: [
                pw.Text("${(index + 1).toString().padLeft(2, '0')}. ", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                pw.Expanded(child: pw.Text("${item.name} (${item.packing})", style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
              ]),
              
              pw.SizedBox(height: 1),

              // Row 2: Technicals (Batch, Exp, HSN, Qty)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("B: ${item.batch}", style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text("E: ${item.exp}", style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text("HSN: ${item.hsn}", style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text("Qty: ${item.qty.toInt()}${item.freeQty > 0 ? '+${item.freeQty.toInt()}' : ''}", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              ]),

              pw.SizedBox(height: 1),

              // Row 3: Financials (MRP, Rate, Total)
              pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                pw.Text("MRP: ${item.mrp.toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text("Rate: ${(item is PurchaseItem ? item.purchaseRate : item.rate).toStringAsFixed(2)}", style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text("GST: ${item.gstRate.toInt()}%", style: const pw.TextStyle(fontSize: 7.5)),
                pw.Text("Amt: ${item.total.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
              ]),
            ],
          ),
        );
      }),
    );
  }

  // ===========================================================================
  // 📊 5. TAX SUMMARY TABLE (For Sales/Purchase)
  // ===========================================================================
  static pw.Widget _buildTaxSummary(dynamic doc) {
    // Ye function har bill ke niche Tax ka GST% wise break-up dikhayega
    // Jaisa A4 bill ke end mein hota hai.
    return pw.SizedBox.shrink(); // Coming in Step 5
  }
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save(), name: 'Print_${type}_${DateTime.now().millisecond}');
  }

  // ===========================================================================
  // 🏗️ 2. HEADER BUILDER (Dukan & Party Details)
  // ===========================================================================

  static pw.Widget _buildShopHeader(CompanyProfile shop, AppConfig config, pw.MemoryImage? logo, String type) {
    return pw.Center(child: pw.Column(children: [
      if (logo != null) pw.Container(width: 45, height: 45, child: pw.Image(logo)),
      pw.Text(shop.name.toUpperCase(), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      pw.Text(shop.address.toUpperCase(), textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7)),
      pw.SizedBox(height: 2),
      pw.Text("GST: ${shop.gstin}  |  DL: ${shop.dlNo}", style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold)),
      pw.Text("Mob: ${shop.phone}  |  Email: ${shop.email.toLowerCase()}", style: const pw.TextStyle(fontSize: 7)),
    ]));
  }

  static pw.Widget _buildPartyHeader(Party p, dynamic doc, String type) {
    String title = "CONSIGNEE (CUSTOMER):";
    if (type == "PURCHASE") title = "SUPPLIER (VENDOR):";
    if (type == "LEDGER") title = "ACCOUNT STATEMENT FOR:";

    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(title, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
      pw.Text(p.name.toUpperCase(), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      pw.Text("${p.address}, ${p.city}", style: const pw.TextStyle(fontSize: 7.5)),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text("GST: ${p.gst}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
        pw.Text("DL: ${p.dl}", style: const pw.TextStyle(fontSize: 7)),
      ]),
      if (p.phone.isNotEmpty) pw.Text("Mob: ${p.phone}", style: const pw.TextStyle(fontSize: 7)),
    ]);
  }

  static pw.Widget _buildDocMetadata(dynamic doc, String type) {
    String docNo = "";
    String date = "";
    String time = DateFormat('hh:mm a').format(DateTime.now());

    if (doc is Sale) { docNo = doc.billNo; date = DateFormat('dd/MM/yyyy').format(doc.date); }
    else if (doc is SaleChallan) { docNo = doc.billNo; date = DateFormat('dd/MM/yyyy').format(doc.date); }
    // (Baki logic hum transactions jode waqt badhayenge)

    return pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text("${type.toUpperCase()} NO: $docNo", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Text("MODE: ${doc is Sale ? doc.paymentMode : 'N/A'}", style: const pw.TextStyle(fontSize: 7)),
      ]),
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        pw.Text("DATE: $date", style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
        pw.Text("TIME: $time", style: const pw.TextStyle(fontSize: 7)),
      ]),
    ]);
  }

  // ===========================================================================
  // 💰 3. FOOTER BUILDER (Totals, QR, Sign)
  // ===========================================================================

  static pw.Widget _buildAdvancedFooter(dynamic doc, CompanyProfile shop, AppConfig config, PharoahManager ph, String type) {
    double netAmt = 0;
    if (doc is Sale) netAmt = doc.totalAmount;
    // ...

    return pw.Column(children: [
      // Grand Total Section
      pw.Container(
        padding: const pw.EdgeInsets.all(5),
        color: PdfColors.grey100,
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text("NET PAYABLE", style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.Text("Rs. ${netAmt.toStringAsFixed(2)}", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      pw.SizedBox(height: 5),
      
      // Amount in Words
      pw.Text("Rupees ${PdfMasterService.numberToWords(netAmt.round())} Only", textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7, fontStyle: pw.FontStyle.italic)),
      
      PdfMasterService.thermalDivider(),

      // UPI QR Code (Small centered)
      if (config.showQrCode && config.qrCodePath != null && File(config.qrCodePath!).existsSync())
        pw.Center(child: pw.Column(children: [
          pw.Text("SCAN TO PAY", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 3),
          pw.Container(width: 80, height: 80, child: pw.Image(pw.MemoryImage(File(config.qrCodePath!).readAsBytesSync()))),
        ])),

      pw.SizedBox(height: 10),

      // Signatures
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(children: [
          pw.SizedBox(height: 20),
          pw.Text("Receiver's Sign", style: const pw.TextStyle(fontSize: 7)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text("For ${shop.name}", style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Text("Authorised Signatory", style: const pw.TextStyle(fontSize: 7)),
        ]),
      ]),
      
      pw.SizedBox(height: 5),
      pw.Center(child: pw.Text("Thank you! Visit Again.", style: const pw.TextStyle(fontSize: 7))),
    ]);
  }
}
