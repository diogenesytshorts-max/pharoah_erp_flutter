import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audit_logs_view.dart';
import 'file_management_view.dart';
import 'user_master_view.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';

class SystemMenuView extends StatelessWidget {
  final VoidCallback onLogout;
  const SystemMenuView({super.key, required this.onLogout});

  void _startResetProcess(BuildContext context) {
    final List<Map<String, String>> steps = [
      {"t": "Step 1/7", "m": "Kya aap vastav me sara data delete karna chahte hain?", "b": "AGREE"},
      {"t": "Step 2/7", "m": "Isse aapki saari Sales, Purchase aur Inventory zero ho jayegi. Sure?", "b": "YES, I KNOW"},
      {"t": "Step 3/7", "m": "Kya aapne pehle backup le liya hai?", "b": "I HAVE BACKUP"},
      {"t": "Step 4/7", "m": "Ye action permanent hai. Proceed?", "b": "YES"},
      {"t": "Step 5/7", "m": "Pharoah ERP ka sara setup reset ho jayega.", "b": "RESET"},
      {"t": "Step 6/7", "m": "Are you REALLY sure? Last chance.", "b": "DELETE EVERYTHING"},
      {"t": "FINAL - 7/7", "m": "Ok, No undo possible!", "b": "WIPE NOW"},
    ];
    _showStep(context, steps, 0);
  }

  void _showStep(BuildContext context, List<Map<String, String>> steps, int index) {
    showDialog(context: context, barrierDismissible: false, builder: (c) => AlertDialog(
      title: Text(steps[index]['t']!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      content: Text(steps[index]['m']!),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
          Navigator.pop(c);
          if (index < steps.length - 1) _showStep(context, steps, index + 1);
          else { Provider.of<PharoahManager>(context, listen: false).masterReset(); }
        }, child: Text(steps[index]['b']!, style: const TextStyle(color: Colors.white))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("System Administration"), backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12,
        children: [
          ActionIconBtn(title: "Company", icon: Icons.business, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout)))),
          ActionIconBtn(title: "Audit Logs", icon: Icons.history_edu, color: Colors.brown, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AuditLogsView()))),
          ActionIconBtn(title: "Backup", icon: Icons.cloud_done, color: Colors.blueGrey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView()))),
          ActionIconBtn(title: "Change FY", icon: Icons.calendar_month, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView()))),
          ActionIconBtn(title: "Admin User", icon: Icons.admin_panel_settings, color: Colors.deepPurple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout)))),
          ActionIconBtn(title: "Reset Data", icon: Icons.delete_forever, color: Colors.red, onTap: () => _startResetProcess(context)),
        ],
      ),
    );
  }
}
