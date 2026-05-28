// FILE: lib/logic/email_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:path_provider/path_provider.dart';
import 'app_settings_model.dart';

class PharoahEmailService {
  
  static Future<bool> sendEmailWithPdf({
    required AppConfig config,
    required String shopName,
    required String recipientEmail,
    required String subject,
    required String body,
    required Uint8List pdfBytes,
    required String fileName,
  }) async {
    // UPDATED: isMailActive, smtpMailID, smtpMailPass
    if (!config.isMailActive || config.smtpMailID.isEmpty || config.smtpMailPass.isEmpty) {
      print("Mail service not configured in settings.");
      return false;
    }

    final tempDir = await getTemporaryDirectory();
    String finalFileName = fileName.toLowerCase().endsWith('.zip') 
        ? fileName 
        : '$fileName.pdf';
        
    final file = File('${tempDir.path}/$finalFileName');
    await file.writeAsBytes(pdfBytes);
    
    // UPDATED: smtpMailID, smtpMailPass
    final smtpServer = SmtpServer(
      config.smtpHost,
      port: config.smtpPort,
      username: config.smtpMailID,
      password: config.smtpMailPass,
    );

    final message = Message()
      ..from = Address(config.smtpMailID, shopName)
      ..recipients.add(recipientEmail)
      ..subject = subject
      ..text = body
      ..attachments.add(FileAttachment(file));

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      print("Mail Dispatch Error: $e");
      return false;
    }
  }

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
      default:
        subject = "Document from $shopName";
        body = "Please find the attached document.\n\nRegards,\n$shopName";
    }

    return {"subject": subject, "body": body};
  }
}
