// FILE: lib/logic/google_drive_sync_service.dart
// ISOLATED 2-WAY SYNC SERVICE (Zero disruption to local storage)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models.dart';
import '../pharoah_manager.dart';

class GoogleDriveSyncService {
  /// 1. Push Mobile App Data to Google Drive Webhook
  static Future<bool> pushDataToDrive({
    required String webhookUrl,
    required String userEmail,
    required PharoahManager ph,
  }) async {
    if (webhookUrl.isEmpty || !webhookUrl.startsWith("http")) return false;

    try {
      final payload = {
        'sales': ph.sales.map((e) => e.toMap()).toList(),
        'purchases': ph.purchases.map((e) => e.toMap()).toList(),
        'medicines': ph.medicines.map((e) => e.toMap()).toList(),
        'parties': ph.parties.map((e) => e.toMap()).toList(),
        'vouchers': ph.vouchers.map((e) => e.toMap()).toList(),
        'lastSyncTime': DateTime.now().toIso8601String(),
      };

      final response = await http.post(
        Uri.parse(webhookUrl),
        body: jsonEncode({
          'action': 'SAVE_DATABASE',
          'tenantEmail': userEmail,
          'timestamp': DateTime.now().toIso8601String(),
          'payload': payload,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 302;
    } catch (e) {
      debugPrint("Drive Sync Push Error: $e");
      return false;
    }
  }

  /// 2. Pull Web Changes from Google Drive to Mobile App
  static Future<bool> pullDataFromDrive({
    required String webhookUrl,
    required String userEmail,
    required PharoahManager ph,
  }) async {
    if (webhookUrl.isEmpty || !webhookUrl.startsWith("http")) return false;

    try {
      final fetchUrl = "$webhookUrl?action=GET_DATABASE&tenantEmail=${Uri.encodeComponent(userEmail)}";
      final response = await http.get(Uri.parse(fetchUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'SUCCESS' && data['payload'] != null) {
          final cloudPayload = data['payload'];

          // Safe Delta Merge for Web Bills
          if (cloudPayload['sales'] != null) {
            for (var s in cloudPayload['sales']) {
              if (s is Map<String, dynamic> && s['billNo'] != null) {
                bool exists = ph.sales.any((item) => item.billNo == s['billNo']);
                if (!exists) {
                  ph.sales.add(Sale(
                    id: s['billNo'] ?? DateTime.now().toString(),
                    billNo: s['billNo'] ?? "WEB-INV",
                    partyId: s['customer'] ?? "cash",
                    date: DateTime.tryParse(s['billDate'] ?? "") ?? DateTime.now(),
                    partyName: s['customer'] ?? "CASH CUSTOMER",
                    partyGstin: "",
                    partyState: "Rajasthan",
                    items: [],
                    totalAmount: (s['totalAmount'] ?? 0.0).toDouble(),
                    paymentMode: "CASH",
                    sourceTag: "CLOUD-WEB",
                  ));
                }
              }
            }
          }

          await ph.save();
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint("Drive Sync Pull Error: $e");
      return false;
    }
  }
}
