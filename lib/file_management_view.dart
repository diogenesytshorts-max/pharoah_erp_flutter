import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'pharoah_manager.dart';
import 'audit_logs_view.dart'; // NAYA

class FileManagementView extends StatefulWidget {
  const FileManagementView({super.key});
  @override State<FileManagementView> createState() => _FileManagementViewState();
}

class _FileManagementViewState extends State<FileManagementView> {
  String currentFy = "";
  @override void initState() { super.initState(); _load(); }
  _load() async { final p = await SharedPreferences.getInstance(); setState(() => currentFy = p.getString('fy') ?? "2025-26"); }

  Future<void> _backupData() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    // Hum sirf Sales file ko backup ke taur par bhej rahe hain (Testing ke liye)
    // Aap poore folder ko bhi ZIP kar sakte hain aage
    File file = File('$path/sales_$currentFy.json');
    if (await file.exists()) {
      await Share.shareXFiles([XFile(file.path)], text: 'Pharoah ERP Backup - $currentFy');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No data found to backup!")));
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("File Management")),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        // 1. CHANGE FY
        ListTile(
          tileColor: Colors.blue[50], leading: const Icon(Icons.calendar_month), title: const Text("Change Financial Year"), subtitle: Text("Selected: $currentFy"),
          onTap: () {
            showDialog(context: context, builder: (c)=>SimpleDialog(title: const Text("Select Financial Year"), children: ["2024-25", "2025-26", "2026-27"].map((y)=>SimpleDialogOption(child: Text(y), onPressed: () async {
              if (y == currentFy) { Navigator.pop(c); return; }
              final p = await SharedPreferences.getInstance(); await p.setString('fy', y); Navigator.pop(c);
              showDialog(context: context, barrierDismissible: false, builder: (c2)=>AlertDialog(title: const Text("Switching Year"), content: Text("Logging out to load $y."), actions: [TextButton(onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst), child: const Text("OK"))]));
            })).toList()));
          },
        ),
        const SizedBox(height: 10),
        // 2. BACKUP DATA
        ListTile(
          tileColor: Colors.green[50], leading: const Icon(Icons.cloud_upload), title: const Text("Backup Data & Share"), subtitle: const Text("Share your JSON database to WhatsApp/Email"),
          onTap: _backupData,
        ),
        const SizedBox(height: 10),
        // 3. AUDIT LOGS
        ListTile(
          tileColor: Colors.orange[50], leading: const Icon(Icons.history), title: const Text("View Audit Logs"), subtitle: const Text("Track every modification and deletion"),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AuditLogsView())),
        ),
      ]),
    );
  }
}
