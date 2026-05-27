// FILE: lib/logic/email_service.dart

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

    // A. PDF Bytes ko temporary file mein badalna (Mailer file path maangta hai)
    final tempDir = await getTemporaryDirectory();
  // --- FIXED: Extension check logic ---
   // --- FIXED: Checking if it's already a ZIP or needs PDF extension ---
    String finalPath = fileName.toLowerCase().endsWith('.zip') 
        ? '${tempDir.path}/$fileName' 
        : '${tempDir.path}/$fileName.pdf';
        
    final file = File(finalPath);
    await file.writeAsBytes(pdfBytes);
    
    // B. SMTP Server Configure karna
    final smtpServer = SmtpServer(
      config.smtpHost,
      port: config.smtpPort,
      username: config.smtpEmail,
      password: config.smtpPassword,
    );

    // C. Email Message taiyar karna
    final message = Message()
      ..from = Address(config.smtpEmail, shopName)
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..text = body
      ..attachments.add(FileAttachment(file));

    try {
      // D. Bhejna
      await send(message, smtpServer);
      print("Email sent successfully to $recipientEmail");
      return true;
    } catch (e) {
      print("Email Error: $e");
      return false;
    }
  }

  // ===========================================================================
  // 📝 2. SMART MESSAGE TEMPLATES (Aapke bataye anusar)
  // ===========================================================================

  static Map<String, String> getTemplate({
    required String type, // "SALE", "CHALLAN", "LEDGER", "STOCK"
    required String shopName,
    String docNo = "",
    String dateRange = "",
  }) {
    String subject = "";
    String body = "";

    switch (type) {
      case "SALE":
        subject = "Invoice Attached: $docNo from $shopName";
        body = "Dear Sir/Madam,\n\nPlease find attached the Tax Invoice ($docNo) for your recent purchase.\n\nWith Regards,\n$shopName\nPowered by Pharoah ERP";
        break;
      case "CHALLAN":
        subject = "Delivery Challan: $docNo from $shopName";
        body = "Dear Sir,\n\nAttached is the Delivery Challan ($docNo) for the material dispatched to you today.\n\nWith Regards,\n$shopName\nPowered by Pharoah ERP";
        break;
      case "LEDGER":
        subject = "Account Statement: $shopName";
        body = "Dear Sir,\n\nYour Ledger Statement for the period $dateRange has been attached for your review.\n\nWith Regards,\n$shopName\nPowered by Pharoah ERP";
        break;
      case "STOCK":
        subject = "Stock Statement: $shopName";
        body = "Dear Sir,\n\nStock statement from $dateRange has been attached.\n\nWith Regards,\n$shopName\nPowered by Pharoah ERP";
        break;
      default:
        subject = "Document from $shopName";
        body = "Please find the attached document.\n\nWith Regards,\n$shopName";
    }

    return {"subject": subject, "body": body};
  }
}
