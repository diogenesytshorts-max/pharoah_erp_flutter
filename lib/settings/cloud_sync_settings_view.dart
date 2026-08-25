// FILE: lib/settings/cloud_sync_settings_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

import '../pharoah_manager.dart';
import '../logic/google_drive_sync_service.dart';

class CloudSyncSettingsView extends StatefulWidget {
  const CloudSyncSettingsView({super.key});

  @override
  State<CloudSyncSettingsView> createState() => _CloudSyncSettingsViewState();
}

class _CloudSyncSettingsViewState extends State<CloudSyncSettingsView> {
  bool isOnlineSyncEnabled = false;
  final TextEditingController _webhookController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  bool isSyncingNow = false;
  String lastSyncTimeStr = "Never";
  String syncStatusMessage = "Offline Mode Active";
  Color syncStatusColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    _loadSyncSettings();
  }

  Future<void> _loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final ph = Provider.of<PharoahManager>(context, listen: false);

    setState(() {
      isOnlineSyncEnabled = prefs.getBool('isOnlineSyncEnabled') ?? false;
      _webhookController.text = prefs.getString('cloudWebhookUrl') ?? "";
      _emailController.text = prefs.getString('cloudUserEmail') ?? (ph.activeCompany?.email ?? "");
      lastSyncTimeStr = prefs.getString('lastCloudSyncTime') ?? "Never";
      
      if (isOnlineSyncEnabled) {
        syncStatusMessage = "Online Mode (Google Drive Sync Ready)";
        syncStatusColor = Colors.green;
      } else {
        syncStatusMessage = "Offline Mode (Local Storage Only)";
        syncStatusColor = Colors.grey;
      }
    });
  }

  Future<void> _saveSyncSettings(bool enableSync) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isOnlineSyncEnabled', enableSync);
    await prefs.setString('cloudWebhookUrl', _webhookController.text.trim());
    await prefs.setString('cloudUserEmail', _emailController.text.trim().toLowerCase());

    setState(() {
      isOnlineSyncEnabled = enableSync;
      if (enableSync) {
        syncStatusMessage = "Online Mode (Google Drive Sync Ready)";
        syncStatusColor = Colors.green;
      } else {
        syncStatusMessage = "Offline Mode (Local Storage Only)";
        syncStatusColor = Colors.grey;
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(enableSync 
              ? "✅ Online Mode Activated!" 
              : "🔒 Switched to 100% Offline Mode (Local Storage)"),
          backgroundColor: enableSync ? Colors.green : Colors.blueGrey,
        ),
      );
    }
  }

  Future<void> _handleManualSync(PharoahManager ph) async {
    String url = _webhookController.text.trim();
    String email = _emailController.text.trim();

    if (url.isEmpty || !url.startsWith("http")) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please enter a valid Webhook URL first!"),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      isSyncingNow = true;
      syncStatusMessage = "Syncing with Google Drive...";
      syncStatusColor = Colors.orange;
    });

    bool pushOk = await GoogleDriveSyncService.pushDataToDrive(
      webhookUrl: url,
      userEmail: email,
      ph: ph,
    );

    bool pullOk = await GoogleDriveSyncService.pullDataFromDrive(
      webhookUrl: url,
      userEmail: email,
      ph: ph,
    );

    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastCloudSyncTime', nowStr);

    setState(() {
      isSyncingNow = false;
      lastSyncTimeStr = nowStr;
      if (pushOk || pullOk) {
        syncStatusMessage = "Sync Successful!";
        syncStatusColor = Colors.green;
      } else {
        syncStatusMessage = "Sync Failed. Check URL or Internet.";
        syncStatusColor = Colors.red;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Cloud & Sync Center"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: MASTER ONLINE / OFFLINE TOGGLE CARD ---
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                border: Border.all(
                  color: isOnlineSyncEnabled ? Colors.green.shade300 : Colors.grey.shade300,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: (isOnlineSyncEnabled ? Colors.green : Colors.grey).withOpacity(0.1),
                    child: Icon(
                      isOnlineSyncEnabled ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                      color: isOnlineSyncEnabled ? Colors.green.shade800 : Colors.grey.shade700,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isOnlineSyncEnabled ? "ONLINE SYNC (ACTIVE)" : "OFFLINE MODE (ACTIVE)",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isOnlineSyncEnabled ? Colors.green.shade900 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isOnlineSyncEnabled
                              ? "Data syncs automatically with Google Drive & Web."
                              : "Data is 100% private & saved in device memory only.",
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isOnlineSyncEnabled,
                    activeColor: Colors.green,
                    onChanged: (val) => _saveSyncSettings(val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 25),

            // --- SECTION 2: STATUS & LAST SYNC INFO ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: syncStatusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: syncStatusColor.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: syncStatusColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        syncStatusMessage,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: syncStatusColor),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Last Synchronized:", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(lastSyncTimeStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- SECTION 3: CLOUD CONFIGURATION ---
            const Text(
              "GOOGLE DRIVE / CLOUD CONFIGURATION",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
            ),
            const SizedBox(height: 12),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)],
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _webhookController,
                    decoration: const InputDecoration(
                      labelText: "Google Drive Webhook / Script URL",
                      hintText: "https://script.google.com/macros/s/.../exec",
                      prefixIcon: Icon(Icons.link_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: "Registered Business Email",
                      hintText: "shop@gmail.com",
                      prefixIcon: Icon(Icons.email_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.save_rounded),
                      label: const Text("SAVE CONFIGURATION", style: TextStyle(fontWeight: FontWeight.bold)),
                      onPressed: () => _saveSyncSettings(isOnlineSyncEnabled),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // --- SECTION 4: MANUAL SYNC ACTION BUTTON ---
            if (isOnlineSyncEnabled) ...[
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo.shade900,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                  onPressed: isSyncingNow ? null : () => _handleManualSync(ph),
                  icon: isSyncingNow
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(
                    isSyncingNow ? "SYNCING DATA..." : "SYNC NOW (PUSH & PULL)",
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
