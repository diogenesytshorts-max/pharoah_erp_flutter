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
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("More Features & Tools"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- SECTION 1: GST & TAX REPORTS ---
            _buildSectionTitle("GST & RETURNS"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                ActionIconBtn(
                  title: "GSTR-1 (Sales)",
                  icon: Icons.pie_chart_outline_rounded,
                  color: Colors.green.shade700,
                  onTap: () => _showComingSoon(context, "GSTR-1 Report"),
                ),
                ActionIconBtn(
                  title: "GSTR-2 (Purc)",
                  icon: Icons.analytics_outlined,
                  color: Colors.orange.shade700,
                  onTap: () => _showComingSoon(context, "GSTR-2 Report"),
                ),
                ActionIconBtn(
                  title: "GST Summary",
                  icon: Icons.account_balance_wallet_outlined,
                  color: Colors.blue.shade700,
                  onTap: () => _showComingSoon(context, "GST Tax Summary"),
                ),
              ],
            ),

            const SizedBox(height: 35),

            // --- SECTION 2: SYSTEM & ADMINISTRATION (THE 6 CORE TOOLS) ---
            _buildSectionTitle("SYSTEM & ADMINISTRATION"),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                // 1. Company Profile
                ActionIconBtn(
                  title: "Company",
                  icon: Icons.business_rounded,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                ),
                // 2. Audit Logs
                ActionIconBtn(
                  title: "Audit Logs",
                  icon: Icons.history_edu_rounded,
                  color: Colors.brown,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AuditLogsView())),
                ),
                // 3. Backup & Share
                ActionIconBtn(
                  title: "Backup",
                  icon: Icons.cloud_done_rounded,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView())),
                ),
                // 4. Change FY
                ActionIconBtn(
                  title: "Change FY",
                  icon: Icons.calendar_month_rounded,
                  color: Colors.teal,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView())),
                ),
                // 5. User Settings
                ActionIconBtn(
                  title: "Admin User",
                  icon: Icons.admin_panel_settings_rounded,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                ),
                // 6. Master Reset
                ActionIconBtn(
                  title: "Reset Data",
                  icon: Icons.restart_alt_rounded,
                  color: Colors.red,
                  onTap: () => _confirmReset(context),
                ),
              ],
            ),

            const SizedBox(height: 40),
            Center(
              child: Text(
                "Pharoah ERP Toolset v1.0.5",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER METHODS ---

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 5),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.blueGrey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("$feature is being prepared for next update.")),
    );
  }

  void _confirmReset(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Master Reset?"),
        content: const Text("This will delete all dummy data and reset masters. This action cannot be undone!"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          TextButton(
            onPressed: () {
              // Reset logic will go here
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset requested.")));
            },
            child: const Text("YES, RESET", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
