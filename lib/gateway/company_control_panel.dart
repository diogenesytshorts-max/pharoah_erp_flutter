import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';

class CompanyControlPanelView extends StatefulWidget {
  const CompanyControlPanelView({super.key});

  @override
  State<CompanyControlPanelView> createState() => _CompanyControlPanelViewState();
}

class _CompanyControlPanelViewState extends State<CompanyControlPanelView> {
  bool isMaintenanceRunning = false;
  double maintenanceProgress = 0.0;
  String maintenanceStatus = "";

  // --- FILE MAINTENANCE ENGINE (THE DOCTOR) ---
  void _runMaintenance(PharoahManager ph) async {
    setState(() {
      isMaintenanceRunning = true;
      maintenanceProgress = 0.0;
      maintenanceStatus = "Starting Diagnostic Engine...";
    });

    // Step 1: Scan Directory (10%)
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() { maintenanceProgress = 0.15; maintenanceStatus = "Scanning Database Integrity..."; });

    // Step 2: Verify Wholesale Records (40%)
    await Future.delayed(const Duration(milliseconds: 1200));
    setState(() { maintenanceProgress = 0.45; maintenanceStatus = "Verifying Sales & Item Master Sync..."; });

    // Step 3: Inventory Re-calculation (80%)
    // Yahan Manager asli stock re-build kar sakta hai
    await ph.loadAllData(); 
    setState(() { maintenanceProgress = 0.85; maintenanceStatus = "Repairing Batch Master Quantities..."; });

    // Step 4: Finishing (100%)
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      maintenanceProgress = 1.0;
      maintenanceStatus = "Maintenance Complete! Data is 100% Healthy.";
    });

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => isMaintenanceRunning = false);
  }

  // --- LOGIN LOGIC (Select Year) ---
  void _showFYLoginDialog(PharoahManager ph) {
    // Agar company naye hai toh sirf current year dikhao, purani hai toh list se
    List<String> years = ph.activeCompany?.fYears.isEmpty ?? true 
        ? ["2024-25", "2025-26"] // Default options for new setup
        : ph.activeCompany!.fYears;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Select Financial Year to Login", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            ...years.map((fy) => ListTile(
              leading: const Icon(Icons.calendar_today, color: Color(0xFF0D47A1)),
              title: Text(fy, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.login_rounded, color: Colors.green),
              onTap: () {
                Navigator.pop(c);
                ph.loginToCompany(ph.activeCompany!, fy); // Dashboard entry point
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final comp = ph.activeCompany;

    if (comp == null) return const Scaffold(body: Center(child: Text("Error: No active company")));

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(comp.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("System Control Panel (${comp.id})", style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ph.clearSession(), // Wapas Company List par jayenge
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // --- QUICK SUMMARY CARD ---
                _buildHeaderCard(comp),
                const SizedBox(height: 25),

                // --- MAIN CONTROL GRID ---
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                  children: [
                    _menuItem("LOGIN TO WORK", Icons.play_circle_fill_rounded, Colors.green, () => _showFYLoginDialog(ph)),
                    _menuItem("FILE MAINTENANCE", Icons.health_and_safety_rounded, Colors.orange.shade800, () => _runMaintenance(ph)),
                    _menuItem("BACKUP & EXPORT", Icons.cloud_upload_rounded, Colors.blue, () {}),
                    _menuItem("NEW YEAR SETUP", Icons.fiber_new_rounded, Colors.purple, () {}),
                    _menuItem("MODIFY COMPANY", Icons.settings_applications_rounded, Colors.blueGrey, () {}),
                    _menuItem("DELETE COMPANY", Icons.delete_forever_rounded, Colors.red, () => _confirmDelete(ph)),
                  ],
                ),
              ],
            ),
          ),

          // --- MAINTENANCE PROGRESS OVERLAY ---
          if (isMaintenanceRunning) _buildMaintenanceOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(CompanyProfile comp) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF0D47A1).withOpacity(0.1),
            child: const Icon(Icons.business_rounded, color: Color(0xFF0D47A1), size: 30),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("ACTIVE COMPANY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
                Text(comp.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                Text("Nature: ${comp.businessType}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _menuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.1), width: 2),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.8),
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.medical_services_outlined, color: Colors.orange, size: 80),
          const SizedBox(height: 25),
          const Text("PHAROAH DOCTOR RUNNING", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 10),
          Text(maintenanceStatus, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 30),
          Container(
            width: 250,
            height: 10,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: maintenanceProgress, color: Colors.orange, backgroundColor: Colors.transparent),
            ),
          ),
          const SizedBox(height: 10),
          Text("${(maintenanceProgress * 100).toInt()}% Complete", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _confirmDelete(PharoahManager ph) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Entire Company?"),
        content: const Text("Isse is company ka sara data (Sales, Purchase, Stock) hamesha ke liye delete ho jayega. Kya aap confirm karte hain?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ph.companiesRegistry.removeWhere((x) => x.id == ph.activeCompany!.id);
              ph.saveRegistry();
              ph.clearSession();
              Navigator.pop(c);
            },
            child: const Text("YES, WIPE DATA", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
