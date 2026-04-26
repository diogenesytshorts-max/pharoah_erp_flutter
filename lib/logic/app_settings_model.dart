// FILE: lib/logic/app_settings_model.dart

import 'dart:convert';

class AppConfig {
  // --- PREFIX SETTINGS ---
  String salePrefix;
  String saleChallanPrefix;
  String saleReturnPrefix;
  String purPrefix;
  String purReturnPrefix;

  // --- PRINT SETTINGS ---
  String printFormat; // "A4" or "Thermal"
  String termsAndConditions;
  String? logoPath; // Image file path (Stability focused)

  AppConfig({
    this.salePrefix = "INV-",
    this.saleChallanPrefix = "SCH-",
    this.saleReturnPrefix = "SRN-",
    this.purPrefix = "PUR-",
    this.purReturnPrefix = "PRN-",
    this.printFormat = "A4",
    this.termsAndConditions = "1. Goods once sold will not be taken back.\n2. All disputes subject to local jurisdiction.",
    this.logoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'salePrefix': salePrefix,
      'saleChallanPrefix': saleChallanPrefix,
      'saleReturnPrefix': saleReturnPrefix,
      'purPrefix': purPrefix,
      'purReturnPrefix': purReturnPrefix,
      'printFormat': printFormat,
      'termsAndConditions': termsAndConditions,
      'logoPath': logoPath,
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      salePrefix: map['salePrefix'] ?? "INV-",
      saleChallanPrefix: map['saleChallanPrefix'] ?? "SCH-",
      saleReturnPrefix: map['saleReturnPrefix'] ?? "SRN-",
      purPrefix: map['purPrefix'] ?? "PUR-",
      purReturnPrefix: map['purReturnPrefix'] ?? "PRN-",
      printFormat: map['printFormat'] ?? "A4",
      termsAndConditions: map['termsAndConditions'] ?? "",
      logoPath: map['logoPath'],
    );
  }
}
