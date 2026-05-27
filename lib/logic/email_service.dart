// FILE: lib/logic/email_service.dart (FINAL STABLE VERSION)

import 'dart:io';
import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'app_settings_model.dart';

class PharoahEmailService {
  
  // ===========================================================================
  // 📧 1. MAIN SENDING LOGIC (CORE)
  // ===========================================================================
  static Future<bool> sendEmailWithPdf({
    required AppConfig config,
    required String shopName,
    required String recipientEmail,
    required String subject,
    required String body,
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    if (!config.isEmailActive || config.smtpEmail.isEmpty || config.smtpPassword.isEmpty) {
      print("Email service not configured in settings.");
      return false;
    }

    // A. Bytes को अस्थायी फाइल (Temporary File) में बदलना
    final tempDir = await getTemporaryDirectory();

    // --- 🛡️ CRITICAL FIX: EXTENSION LOGIC ---
    // अगर fileName में पहले से ही '.zip' है (जैसे Audit Bundle), तो हम दोबारा '.pdf' नहीं जोड़ेंगे।
    // इससे "File Corrupted" वाला एरर जड़ से खत्म हो जाएगा।
    String finalFileName = fileName.toLowerCase().endsWith('.zip') 
        ? fileName 
        : '$fileName.pdf';
        
    final file = File('${tempDir.path}/$finalFileName');
    await file.writeAsBytes(pdfBytes);
    
    // B. SMTP Server कॉन्फ़िगर करना
    final smtpServer = SmtpServer(
      config.smtpHost,
      port: config.smtpPort,
      username: config.smtpEmail,
      password: config.smtpPassword,
    );

    // C. Email Message तैयार करना
    final message = Message()
      ..from = Address(config.smtpEmail, shopName)
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..text = body
      ..attachments.add(FileAttachment(file));

    try {
      // D. मेल भेजना
      await send(message, smtpServer);
      print("Email sent successfully to $recipientEmail as $finalFileName");
      return true;
    } catch (e) {
      print("Email Dispatch Error: $e");
      return false;
    }
  }

  // ===========================================================================
  // 📝 2. SMART MESSAGE TEMPLATES
  // ===========================================================================
  static Map<String, String> getTemplate({
    required String type, 
    required String shopName,
    String docNo = "",
    String dateRange = "",
  }) {
    String subject = "";
    String body = "";

    switch (type) {
      case "SALE":
        subject = "Invoice Attached: $docNo from $shopName";
        body = "Dear Sir/Madam,\n\nPlease find attached the Tax Invoice ($docNo).\n\nRegards,\n$shopName\nPowered by Pharoah ERP";
        break;
      case "CHALLAN":
        subject = "Delivery Challan: $docNo from $shopName";
        body = "Dear Sir,\n\nAttached is the Delivery Challan ($docNo) for the material dispatched.\n\nRegards,\n$shopName";
        break;
      case "LEDGER":
        subject = "Account Statement: $shopName";
        body = "Dear Sir,\n\nYour Ledger Statement for the period $dateRange has been attached.\n\nRegards,\n$shopName";
        break;
      case "STOCK":
        subject = "Stock Report: $shopName";
        body = "Dear Sir,\n\nStock summary report has been attached for your review.\n\nRegards,\n$shopName";
        break;
      default:
        subject = "Document from $shopName";
        body = "Please find the attached document.\n\nRegards,\n$shopName";
    }

    return {"subject": subject, "body": body};
  }
}
