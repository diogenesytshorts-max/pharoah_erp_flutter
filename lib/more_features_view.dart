import 'package:flutter/material.dart';
import 'gst_menu_view.dart';
import 'system_menu_view.dart';

class MoreFeaturesView extends StatelessWidget {
  final VoidCallback onLogout;
  const MoreFeaturesView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("More Features & Advanced Tools"),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- 1. GST & TAXATION SECTION ---
              _buildLargeMenuCard(
                context,
                title: "GST & TAXATION",
                subtitle: "GSTR-1, GSTR-3B, HSN Summary & JSON Export for Portal",
                icon: Icons.account_balance_rounded,
                color: Colors.green.shade600,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const GSTMenuView()),
                ),
              ),
              
              const SizedBox(height: 25),

              // --- 2. SYSTEM & ADMINISTRATION SECTION ---
              _buildLargeMenuCard(
                context,
                title: "SYSTEM & ADMIN",
                subtitle: "Company Setup, Database Backup, Audit Logs & System Reset",
                icon: Icons.settings_suggest_rounded,
                color: Colors.blue.shade700,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (c) => SystemMenuView(onLogout: onLogout),
                  ),
                ),
              ),

              const SizedBox(height: 50),
              
              // Bottom Branding
              const Icon(Icons.verified_user_rounded, color: Colors.blueGrey, size: 30),
              const SizedBox(height: 10),
              Text(
                "Pharoah ERP Premium Technical Suite",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              Text(
                "Secure Administrator Access Only",
                style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- HELPER WIDGET FOR LARGE MENU CARDS ---
  Widget _buildLargeMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.1), width: 2),
        ),
        child: Row(
          children: [
            // Icon Background
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(width: 20),
            // Text Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w900, 
                      color: color.withOpacity(0.9),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12, 
                      color: Colors.grey.shade600,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // Forward Arrow
            Icon(
              Icons.arrow_forward_ios_rounded, 
              color: color.withOpacity(0.3), 
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
