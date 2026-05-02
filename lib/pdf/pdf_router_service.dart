// FILE: lib/pdf/pdf_router_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models.dart';
import '../pharoah_manager.dart';
import '../gateway/company_registry_model.dart';

// Import Engines (Inme hum agle steps mein badlav karenge)
import 'sale_invoice_pdf.dart';
import 'architect_sale_pdf.dart';
import 'thermal_invoice_pdf.dart';
import 'purchase_pdf.dart';
import 'sale_challan_pdf.dart';
import 'purchase_challan_pdf.dart';

class PdfRouterService {
  
  // ===========================================================================
  // 1. SALE PRINT ROUTER (Standard, Architect, or Thermal)
  // ===========================================================================
  static Future<void> printSale({
    required Sale sale,
    required Party party,
    required PharoahManager ph,
  }) async {
    final config = ph.config;
    final shop = ph.activeCompany!;

    if (config.printFormat == "Thermal") {
      // 1. Thermal Receipt (Portrait 3-inch)
      await ThermalInvoicePdf.generate(sale, party, shop, config);
    } 
    else if (config.isArchitectMode) {
      // 2. Architect Landscape (800pt wide)
      await ArchitectSalePdf.generate(sale, party, shop, config);
    } 
    else {
      // 3. Standard A4 Landscape
      await SaleInvoicePdf.generate(sale, party, shop);
    }
  }

  // ===========================================================================
  // 2. PURCHASE PRINT ROUTER
  // ===========================================================================
  static Future<void> printPurchase({
    required Purchase purchase,
    required Party supplier,
    required PharoahManager ph,
  }) async {
    // Purchase hamesha Landscape Architect/Professional format mein aayegi
    await PurchasePdf.generate(purchase, supplier, ph.activeCompany!);
  }

  // ===========================================================================
  // 3. CHALLAN PRINT ROUTER (Outward/Inward)
  // ===========================================================================
  static Future<void> printChallan({
    required dynamic challan, // SaleChallan or PurchaseChallan
    required Party party,
    required PharoahManager ph,
    required bool isSaleChallan,
  }) async {
    if (isSaleChallan) {
      await SaleChallanPdf.generate(challan, party, ph.activeCompany!);
    } else {
      await PurchaseChallanPdf.generate(challan, party, ph.activeCompany!);
    }
  }
}
