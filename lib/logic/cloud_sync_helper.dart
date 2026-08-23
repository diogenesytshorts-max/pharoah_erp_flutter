// FILE: lib/logic/cloud_sync_helper.dart
// ISOLATED 2-WAY AUTO-SYNC HELPER (Push on Save + Pull on Boot)

import 'package:flutter/foundation.dart';
import '../pharoah_manager.dart';
import 'google_drive_sync_service.dart';

class CloudSyncHelper {
  /// Auto-trigger push to Google Drive on Save
  static void triggerAutoSync(PharoahManager ph) {
    if (!ph.config.isArchitectMode) return;

    final String webhookUrl = ph.config.smtpHost.startsWith("http") 
        ? ph.config.smtpHost 
        : "";
    final String email = ph.activeCompany?.email ?? "";

    if (webhookUrl.isNotEmpty && email.isNotEmpty) {
      debugPrint("☁️ CloudSyncHelper: Auto-pushing database to Google Drive...");
      GoogleDriveSyncService.pushDataToDrive(
        webhookUrl: webhookUrl,
        userEmail: email,
        ph: ph,
      );
    }
  }

  /// Auto-trigger pull from Google Drive when App opens / Company loads
  static Future<void> triggerAutoPull(PharoahManager ph) async {
    if (!ph.config.isArchitectMode) return;

    final String webhookUrl = ph.config.smtpHost.startsWith("http") 
        ? ph.config.smtpHost 
        : "";
    final String email = ph.activeCompany?.email ?? "";

    if (webhookUrl.isNotEmpty && email.isNotEmpty) {
      debugPrint("☁️ CloudSyncHelper: Auto-pulling fresh web bills from Google Drive...");
      await GoogleDriveSyncService.pullDataFromDrive(
        webhookUrl: webhookUrl,
        userEmail: email,
        ph: ph,
      );
    }
  }
}
