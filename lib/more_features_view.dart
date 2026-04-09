import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audit_logs_view.dart';
import 'file_management_view.dart';
import 'user_master_view.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';

class MoreFeaturesView extends StatelessWidget {
  final VoidCallback onLogout;
  const MoreFeaturesView({super.key, required this.onLogout});

  void _startResetProcess(BuildContext context) {
    final List<Map<String, String>> steps = [
      {"t": "Step 1/7", "m": "Kya aap vastav me sara data delete karna chahte hain?", "b": "AGREE"},
      {"t": "Step 2/7", "m": "Isse aapki saari Sales, Purchase aur Inventory zero ho jayegi. Sure?", "b": "YES, I KNOW"},
      {"t": "Step 3/7", "m": "Kya aapne pehle backup le liya hai? Bina backup data wapas nahi aayega!", "b": "I HAVE BACKUP"},
      {"t": "Step 4/7", "m": "Ye action permanent hai. Kya aap abhi bhi aage badhna chahte hain?", "b": "YES, PROCEED"},
      {"t": "Step 5/7", "m": "Final warning: Pharoah ERP ka sara setup reset ho jayega.", "b": "AGREE & RESET"},
      {"t": "Step 6/7", "m": "Are you REALLY REALLY SURE? Last chance to go back.", "b": "YES, DELETE ALL"},
      {"t": "FINAL - 7/7", "m": "Ok, Tap below to wipe everything. No undo possible!", "b": "WIPE EVERYTHING NOW"},
    ];
    _showStep(context, steps, 0);
  }

  void _showStep(BuildContext context, List<Map<String, String>> steps, int index) {
    showDialog(
      context: context, barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: Text(steps[index]['t']!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(steps[index]['m']!),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO / CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(c);
              if (index < steps.length - 1) {
                _showStep(context, steps, index + 1);
              } else {
                Provider.of<PharoahManager>(context, listen: false).masterReset();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("MASTER RESET COMPLETED!")));
              }
            },
            child: Text(steps[index]['b']!, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("More Features & Tools"), backgroundColor: Colors.indigo, foregroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("GST & RETURNS"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85,
              children: [
                ActionIconBtn(title: "GSTR-1", icon: Icons.pie_chart_outline, color: Colors.green, onTap: () {}),
                ActionIconBtn(title: "GSTR-2", icon: Icons.analytics_outlined, color: Colors.orange, onTap: () {}),
                ActionIconBtn(title: "GST Sum", icon: Icons.account_balance_wallet, color: Colors.blue, onTap: () {}),
              ],
            ),
            const SizedBox(height: 35),
            _buildSectionTitle("SYSTEM & ADMINISTRATION"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85,
              children: [
                ActionIconBtn(title: "Company", icon: Icons.business, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout)))),
                ActionIconBtn(title: "Audit Logs", icon: Icons.history_edu, color: Colors.brown, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AuditLogsView()))),
                ActionIconBtn(title: "Backup", icon: Icons.cloud_done, color: Colors.blueGrey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView()))),
                ActionIconBtn(title: "Change FY", icon: Icons.calendar_month, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView()))),
                ActionIconBtn(title: "Admin User", icon: Icons.admin_panel_settings, color: Colors.deepPurple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout)))),
                ActionIconBtn(title: "Reset Data", icon: Icons.delete_forever, color: Colors.red, onTap: () => _startResetProcess(context)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(padding: const EdgeInsets.only(left: 5), child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2)));
  }
}
