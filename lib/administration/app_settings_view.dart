// FILE: lib/administration/app_settings_view.dart (UPDATED WITH WEB CLOUD & HINDI GUIDE GATEWAY)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../pharoah_manager.dart';
import 'architect_control_view.dart';

class AppSettingsView extends StatefulWidget {
  const AppSettingsView({super.key});

  @override
  State<AppSettingsView> createState() => _AppSettingsViewState();
}

class _AppSettingsViewState extends State<AppSettingsView> {
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FC),
      appBar: AppBar(
        title: const Text("Global ERP Settings", style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: THE ARCHITECT & CLOUD GATEWAY ---
            _buildArchitectGateway(context),
            const SizedBox(height: 25),
            
            // --- SECTION 2: SYSTEM INFORMATION CARD ---
            _buildSystemInfoCard(ph),
          ],
        ),
      ),
    );
  }

  // Architect & Web Cloud Control Center में जाने का खूबसूरत गेटवे कार्ड
  Widget _buildArchitectGateway(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ArchitectControlView())),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: const Row(
          children: [
            Icon(Icons.cloud_sync_rounded, color: Colors.cyanAccent, size: 45),
            SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "ARCHITECT & WEB CLOUD HUB", 
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5)
                  ),
                  SizedBox(height: 5),
                  Text(
                    "Live Website, Google Drive 2-Way Sync, 📖 हिंदी गाइड, Logo & Bank Details", 
                    style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3)
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  // सिस्टम की जानकारी कार्ड
  Widget _buildSystemInfoCard(PharoahManager ph) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF1A237E), size: 20),
              SizedBox(width: 10),
              Text("SYSTEM INFORMATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
            ],
          ),
          const Divider(height: 25),
          _infoRow("Active Company ID", ph.activeCompany?.id ?? "N/A"),
          _infoRow("Business Type", ph.activeCompany?.businessType ?? "N/A"),
          _infoRow("Financial Year", ph.currentFY),
          _infoRow("Web Cloud Sync", ph.config.isArchitectMode ? "🟢 ACTIVE (2-Way)" : "⚪ OFFLINE"),
          _infoRow("Live Web Portal", "pharoah-erp-flutter.diogenesytshorts.workers.dev"),
          _infoRow("ERP Version", "v1.0.9 (Cloud Architect Series)"),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
