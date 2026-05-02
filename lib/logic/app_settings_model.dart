// FILE: lib/logic/app_settings_model.dart

class AppConfig {
  // --- 1. TRANSACTION PREFIXES (Preserved from Old Code) ---
  String salePrefix;
  String saleChallanPrefix;
  String saleReturnPrefix;
  String purPrefix;
  String purReturnPrefix;

  // --- 2. MASTER SIGNATURE CONTROLS (New) ---
  bool showStaffSign;
  String signLabel; // e.g. "Authorised Signatory"
  bool showCustomerSignChallan; // Step 1 specific for Challan

  // --- 3. LOGO & BRANDING ENGINE (Old logic + Visibility) ---
  bool showLogo;
  String? logoPath; 

  // --- 4. SMART PRINT ENGINE (Old logic + Advanced) ---
  String printFormat; // "A4" or "Thermal"
  bool askFormatEveryTime;

  // --- 5. FINANCIAL IDENTITY (New) ---
  bool showQrCode;
  String? qrCodePath;
  String bankAccName;
  String bankAccNumber;
  String bankIfsc;
  String bankNameBranch;

  // --- 6. TERMS & CONDITIONS (Preserved from Old Code) ---
  bool showTerms;
  String termsAndConditions;

  AppConfig({
    // Defaults from your old code
    this.salePrefix = "INV-",
    this.saleChallanPrefix = "SCH-",
    this.saleReturnPrefix = "SRN-",
    this.purPrefix = "PUR-",
    this.purReturnPrefix = "PRN-",
    this.printFormat = "A4",
    this.termsAndConditions = "1. Goods once sold will not be taken back.\n2. All disputes subject to local jurisdiction.",
    this.logoPath,

    // Defaults for new advanced features
    this.showStaffSign = true,
    this.signLabel = "Authorised Signatory",
    this.showCustomerSignChallan = false,
    this.showLogo = true,
    this.askFormatEveryTime = false,
    this.showQrCode = false,
    this.qrCodePath,
    this.bankAccName = "",
    this.bankAccNumber = "",
    this.bankIfsc = "",
    this.bankNameBranch = "",
    this.showTerms = true,
  });

  // --- MAPPING (For JSON Save/Load) ---

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
      // New fields mapping
      'showStaffSign': showStaffSign,
      'signLabel': signLabel,
      'showCustomerSignChallan': showCustomerSignChallan,
      'showLogo': showLogo,
      'askFormatEveryTime': askFormatEveryTime,
      'showQrCode': showQrCode,
      'qrCodePath': qrCodePath,
      'bankAccName': bankAccName,
      'bankAccNumber': bankAccNumber,
      'bankIfsc': bankIfsc,
      'bankNameBranch': bankNameBranch,
      'showTerms': showTerms,
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      // Loading old fields with safety
      salePrefix: map['salePrefix'] ?? "INV-",
      saleChallanPrefix: map['saleChallanPrefix'] ?? "SCH-",
      saleReturnPrefix: map['saleReturnPrefix'] ?? "SRN-",
      purPrefix: map['purPrefix'] ?? "PUR-",
      purReturnPrefix: map['purReturnPrefix'] ?? "PRN-",
      printFormat: map['printFormat'] ?? "A4",
      termsAndConditions: map['termsAndConditions'] ?? "",
      logoPath: map['logoPath'],
      
      // Loading new fields with safety
      showStaffSign: map['showStaffSign'] ?? true,
      signLabel: map['signLabel'] ?? "Authorised Signatory",
      showCustomerSignChallan: map['showCustomerSignChallan'] ?? false,
      showLogo: map['showLogo'] ?? true,
      askFormatEveryTime: map['askFormatEveryTime'] ?? false,
      showQrCode: map['showQrCode'] ?? false,
      qrCodePath: map['qrCodePath'],
      bankAccName: map['bankAccName'] ?? "",
      bankAccNumber: map['bankAccNumber'] ?? "",
      bankIfsc: map['bankIfsc'] ?? "",
      bankNameBranch: map['bankNameBranch'] ?? "",
      showTerms: map['showTerms'] ?? true,
    );
  }
}
