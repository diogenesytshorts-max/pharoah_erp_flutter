import 'package:flutter/material.dart';
import 'audit_logs_view.dart';
import 'file_management_view.dart';
import 'user_master_view.dart';
import 'widgets.dart';

class MoreFeaturesView extends StatelessWidget {
  final VoidCallback onLogout;
  const MoreFeaturesView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("More Features & Tools"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("ADMIN & MAINTENANCE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                ActionIconBtn(
                  title: "Audit Logs",
                  icon: Icons.history_edu,
                  color: Colors.brown,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AuditLogsView())),
                ),
                ActionIconBtn(
                  title: "Backup",
                  icon: Icons.cloud_upload,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView())),
                ),
                ActionIconBtn(
                  title: "Company",
                  icon: Icons.business_center,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Center(
              child: Text("More reports and analysis tools coming soon...", style: TextStyle(color: Colors.grey, fontSize: 12)),
            )
          ],
        ),
      ),
    );
  }
}
