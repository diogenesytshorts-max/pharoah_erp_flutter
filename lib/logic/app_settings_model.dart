// FILE: lib/logic/app_settings_model.dart

class AppConfig {
  // --- EXISTING FIELDS ---
  String salePrefix;
  String saleChallanPrefix;
  String saleReturnPrefix;
  String purPrefix;
  String purReturnPrefix;
  bool isArchitectMode; 
  bool useZebraShading; 
  bool showStaffSign;
  String signLabel; 
  bool showCustomerSignChallan;
  bool showLogo;
  String? logoPath; 
  String printFormat; 
  bool askFormatEveryTime;
  bool showQrCode;
  String? qrCodePath;
  String bankAccName;
  String bankAccNumber;
  String bankIfsc;
  String bankNameBranch;
  bool showTerms;
  String termsAndConditions;

  // --- 📧 EMAIL SMTP CONFIGURATION ---
  bool isEmailActive;
  String smtpEmail;
  String smtpPassword; 
  String smtpHost;
  int smtpPort;

  // --- 🛡️ NAYA: CA AUDIT NEXUS FIELDS ---
  String caName;
  String caEmail;
  String caPhone;
  bool isAuditMode; // Master Toggle Switch for Audit Features

  AppConfig({
    this.salePrefix = "INV-",
    this.saleChallanPrefix = "SCH-",
    this.saleReturnPrefix = "SRN-",
    this.purPrefix = "PUR-",
    this.purReturnPrefix = "PRN-",
    this.isArchitectMode = false,
    this.useZebraShading = true,
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
    
    // Default Email Values
    this.isEmailActive = false,
    this.smtpEmail = "",
    this.smtpPassword = "",
    this.smtpHost = "smtp.gmail.com",
    this.smtpPort = 587,

    // CA Nexus Defaults
    this.caName = "",
    this.caEmail = "",
    this.caPhone = "",
    this.isAuditMode = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'salePrefix': salePrefix,
      'saleChallanPrefix': saleChallanPrefix,
      'saleReturnPrefix': saleReturnPrefix,
      'purPrefix': purPrefix,
      'purReturnPrefix': purReturnPrefix,
      'isArchitectMode': isArchitectMode,
      'useZebraShading': useZebraShading,
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
      'isEmailActive': isEmailActive,
      'smtpEmail': smtpEmail,
      'smtpPassword': smtpPassword,
      'smtpHost': smtpHost,
      'smtpPort': smtpPort,
      // Naya mapping
      'caName': caName,
      'caEmail': caEmail,
      'caPhone': caPhone,
      'isAuditMode': isAuditMode,
    };
  }

  factory AppConfig.fromMap(Map<String, dynamic> map) {
    return AppConfig(
      salePrefix: map['salePrefix'] ?? "INV-",
      saleChallanPrefix: map['saleChallanPrefix'] ?? "SCH-",
      saleReturnPrefix: map['saleReturnPrefix'] ?? "SRN-",
      purPrefix: map['purPrefix'] ?? "PUR-",
      purReturnPrefix: map['purReturnPrefix'] ?? "PRN-",
      isArchitectMode: map['isArchitectMode'] ?? false,
      useZebraShading: map['useZebraShading'] ?? true,
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
      isEmailActive: map['isEmailActive'] ?? false,
      smtpEmail: map['smtpEmail'] ?? "",
      smtpPassword: map['smtpPassword'] ?? "",
      smtpHost: map['smtpHost'] ?? "smtp.gmail.com",
      smtpPort: map['smtpPort'] ?? 587,
      // Naya load logic
      caName: map['caName'] ?? "",
      caEmail: map['caEmail'] ?? "",
      caPhone: map['caPhone'] ?? "",
      isAuditMode: map['isAuditMode'] ?? false,
    );
  }
}
