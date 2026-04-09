import 'package:flutter/material.dart';
import 'gst_menu_view.dart';
import 'system_menu_view.dart';
import 'widgets.dart';

class MoreFeaturesView extends StatelessWidget {
  final VoidCallback onLogout;
  const MoreFeaturesView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("More Features"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. GST SECTION ICON
              _buildLargeMenuCard(
                context,
                title: "GST & TAXATION",
                subtitle: "GSTR-1, GSTR-3B & Tax Reports",
                icon: Icons.account_balance_rounded,
                color: Colors.green.shade600,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const GSTMenuView())),
              ),
              
              const SizedBox(height: 25),

              // 2. SYSTEM SECTION ICON
              _buildLargeMenuCard(
                context,
                title: "SYSTEM & ADMIN",
                subtitle: "Company, Backup, Logs & Reset",
                icon: Icons.settings_suggest_rounded,
                color: Colors.blue.shade700,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SystemMenuView(onLogout: onLogout))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLargeMenuCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))],
          border: Border.all(color: color.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 5),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color.withOpacity(0.5), size: 18),
          ],
        ),
      ),
    );
  }
}
