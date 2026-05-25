// FILE: lib/logic/app_settings_model.dart

class AppConfig {
  // --- 1. TRANSACTION PREFIXES ---
  String salePrefix;
  String saleChallanPrefix;
  String saleReturnPrefix;
  String purPrefix;
  String purReturnPrefix;

  // --- 2. ARCHITECT MASTER TOGGLES (Missing in your snippet) ---
  bool isArchitectMode; // Switch between Standard and Architect PDF
  bool useZebraShading; // Light grey stripes in table rows

  // --- 3. MASTER SIGNATURE CONTROLS ---
  bool showStaffSign;
  String signLabel; // e.g. "Authorised Signatory"
  bool showCustomerSignChallan; // Step 1 specific for Challan

  // --- 4. LOGO & BRANDING ENGINE ---
  bool showLogo;
  String? logoPath; 

  // --- 5. SMART PRINT ENGINE ---
  String printFormat; // "A4" or "Thermal"
  bool askFormatEveryTime;

  // --- 6. FINANCIAL IDENTITY ---
  bool showQrCode;
  String? qrCodePath;
  String bankAccName;
  String bankAccNumber;
  String bankIfsc;
  String bankNameBranch;

  // --- 7. TERMS & CONDITIONS ---
  bool showTerms;
  String termsAndConditions;

  AppConfig({
    this.salePrefix = "INV-",
    this.saleChallanPrefix = "SCH-",
    this.saleReturnPrefix = "SRN-",
    this.purPrefix = "PUR-",
    this.purReturnPrefix = "PRN-",
    this.isArchitectMode = false, // NAYA
    this.useZebraShading = true,  // NAYA
    this.showStaffSign = true,
    this.signLabel = "Authorised Signatory",
    this.showCustomerSignChallan = false,
    this.showLogo = true,
    this.logoPath,
    this.printFormat = "A4",
    this.askFormatEveryTime = false,
    this.showQrCode = false,
    this.qrCodePath,
    this.bankAccName = "",
    this.bankAccNumber = "",
    this.bankIfsc = "",
    this.bankNameBranch = "",
    this.showTerms = true,
    this.termsAndConditions = "1. Goods once sold will not be taken back.\n2. All disputes subject to local jurisdiction.",
  });

  // --- MAPPING (For JSON Save) ---
  Map<String, dynamic> toMap() {
    return {
      'salePrefix': salePrefix,
      'saleChallanPrefix': saleChallanPrefix,
      'saleReturnPrefix': saleReturnPrefix,
      'purPrefix': purPrefix,
      'purReturnPrefix': purReturnPrefix,
      'isArchitectMode': isArchitectMode, // NAYA
      'useZebraShading': useZebraShading, // NAYA
      'showStaffSign': showStaffSign,
      'signLabel': signLabel,
      'showCustomerSignChallan': showCustomerSignChallan,
      'showLogo': showLogo,
      'logoPath': logoPath,
      'printFormat': printFormat,
      'askFormatEveryTime': askFormatEveryTime,
      'showQrCode': showQrCode,
      'qrCodePath': qrCodePath,
      'bankAccName': bankAccName,
      'bankAccNumber': bankAccNumber,
      'bankIfsc': bankIfsc,
      'bankNameBranch': bankNameBranch,
      'showTerms': showTerms,
      'termsAndConditions': termsAndConditions,
    };
  }

  // --- MAPPING (For JSON Load) ---
  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      salePrefix: map['salePrefix'] ?? "INV-",
      saleChallanPrefix: map['saleChallanPrefix'] ?? "SCH-",
      saleReturnPrefix: map['saleReturnPrefix'] ?? "SRN-",
      purPrefix: map['purPrefix'] ?? "PUR-",
      purReturnPrefix: map['purReturnPrefix'] ?? "PRN-",
      isArchitectMode: map['isArchitectMode'] ?? false, // NAYA
      useZebraShading: map['useZebraShading'] ?? true,  // NAYA
      showStaffSign: map['showStaffSign'] ?? true,
      signLabel: map['signLabel'] ?? "Authorised Signatory",
      showCustomerSignChallan: map['showCustomerSignChallan'] ?? false,
      showLogo: map['showLogo'] ?? true,
      logoPath: map['logoPath'],
      printFormat: map['printFormat'] ?? "A4",
      askFormatEveryTime: map['askFormatEveryTime'] ?? false,
      showQrCode: map['showQrCode'] ?? false,
      qrCodePath: map['qrCodePath'],
      bankAccName: map['bankAccName'] ?? "",
      bankAccNumber: map['bankAccNumber'] ?? "",
      bankIfsc: map['bankIfsc'] ?? "",
      bankNameBranch: map['bankNameBranch'] ?? "",
      showTerms: map['showTerms'] ?? true,
      termsAndConditions: map['termsAndConditions'] ?? "",
    );
  }
}
