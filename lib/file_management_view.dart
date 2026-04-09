import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'pharoah_manager.dart';
import 'audit_logs_view.dart';

class FileManagementView extends StatefulWidget {
  const FileManagementView({super.key});

  @override
  State<FileManagementView> createState() => _FileManagementViewState();
}

class _FileManagementViewState extends State<FileManagementView> {
  String currentFy = "";

  @override
  void initState() {
    super.initState();
    _loadCurrentFY();
  }

  // Load the FY currently stored in SharedPreferences
  _loadCurrentFY() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      currentFy = prefs.getString('fy') ?? "2025-26";
    });
  }

  // --- FEATURE: BACKUP & SHARE DATA ---
  // This collects all JSON database files for the current FY and shares them
  Future<void> _backupAndShareData() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      
      // List of all database files we want to backup
      List<String> filePrefixes = ['meds', 'parts', 'sales', 'purc', 'logs', 'bats'];
      List<XFile> filesToShare = [];

      for (String prefix in filePrefixes) {
        File file = File('$path/${prefix}_$currentFy.json');
        if (await file.exists()) {
          filesToShare.add(XFile(file.path));
        }
      }

      if (filesToShare.isNotEmpty) {
        await Share.shareXFiles(
          filesToShare, 
          text: 'Pharoah ERP Complete Database Backup\nYear: $currentFy\nGenerated on: ${DateTime.now()}'
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No data found for the current Financial Year to backup."))
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Backup Error: $e"))
        );
      }
    }
  }

  // --- FEATURE: CHANGE FINANCIAL YEAR ---
  void _showFYDialog() {
    showDialog(
      context: context,
      builder: (c) => SimpleDialog(
        title: const Text("Select Financial Year"),
        children: ["2024-25", "2025-26", "2026-27"].map((year) {
          return SimpleDialogOption(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: year == currentFy ? Colors.blue : Colors.grey),
                const SizedBox(width: 15),
                Text(
                  year, 
                  style: TextStyle(
                    fontWeight: year == currentFy ? FontWeight.bold : FontWeight.normal,
                    color: year == currentFy ? Colors.blue : Colors.black
                  )
                ),
                if (year == currentFy) ...[
                  const Spacer(),
                  const Icon(Icons.check_circle, color: Colors.blue, size: 20)
                ]
              ],
            ),
            onPressed: () async {
              if (year == currentFy) {
                Navigator.pop(c);
                return;
              }
              
              // Update Shared Preferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('fy', year);
              
              if (mounted) {
                Navigator.pop(c);
                _showRestartAlert(year);
              }
            },
          );
        }).toList(),
      ),
    );
  }

  // Alert user that changing FY requires a reload
  void _showRestartAlert(String newYear) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("Switching Financial Year"),
        content: Text("The application will now load data for $newYear. You will be logged out to ensure data integrity."),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Exit to the very first screen (Setup/Login) to trigger re-initialization
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("PROCEED"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Data & File Management"),
        backgroundColor: Colors.blueGrey.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Financial Year Card
          _buildActionCard(
            title: "Change Financial Year",
            subtitle: "Current: $currentFy",
            icon: Icons.calendar_month_rounded,
            color: Colors.blue,
            onTap: _showFYDialog,
          ),
          
          const SizedBox(height: 15),

          // 2. Backup Card
          _buildActionCard(
            title: "Backup Data & Share",
            subtitle: "Export database files to WhatsApp/Cloud",
            icon: Icons.cloud_upload_rounded,
            color: Colors.green,
            onTap: _backupAndShareData,
          ),

          const SizedBox(height: 15),

          // 3. Audit Logs Card
          _buildActionCard(
            title: "System Audit Logs",
            subtitle: "Track all modifications and deletions",
            icon: Icons.history_rounded,
            color: Colors.brown,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AuditLogsView())),
          ),

          const SizedBox(height: 30),

          // Information section
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.blueGrey.shade100),
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
                    SizedBox(width: 10),
                    Text("Database Info", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ],
                ),
                SizedBox(height: 10),
                Text(
                  "All your data is stored locally in JSON format. Switching the Financial Year will create a fresh set of files for that period without affecting previous years.",
                  style: TextStyle(fontSize: 12, color: Colors.blueGrey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActionCard({required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
