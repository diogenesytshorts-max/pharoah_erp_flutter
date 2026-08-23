// FILE: lib/logic/cloud_sync_helper.dart
// ISOLATED AUTO-SYNC HELPER (Zero conflict with core app)

import 'package:flutter/foundation.dart';
import '../pharoah_manager.dart';
import 'google_drive_sync_service.dart';

class CloudSyncHelper {
  /// Auto-trigger sync if Architect Mode (Cloud Sync) is ON
  static void triggerAutoSync(PharoahManager ph) {
    if (!ph.config.isArchitectMode) return;

    final String webhookUrl = ph.config.smtpHost.startsWith("http") 
        ? ph.config.smtpHost 
        : "";
    final String email = ph.activeCompany?.email ?? "";

    if (webhookUrl.isNotEmpty && email.isNotEmpty) {
      debugPrint("☁️ CloudSyncHelper: Auto-syncing database to Google Drive...");
      GoogleDriveSyncService.pushDataToDrive(
        webhookUrl: webhookUrl,
        userEmail: email,
        ph: ph,
      );
    }
  }
}
