import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';
import 'maintenance_service.dart';
import 'modify_company_view.dart';
import 'export_service.dart'; // NAYA: Service connect kar di

class CompanyControlPanelView extends StatefulWidget {
  const CompanyControlPanelView({super.key});

  @override
  State<CompanyControlPanelView> createState() => _CompanyControlPanelViewState();
}

class _CompanyControlPanelViewState extends State<CompanyControlPanelView> {
  bool isMaintenanceRunning = false;
  double maintenanceProgress = 0.0;
  String maintenanceStatus = "";

  // --- 1. ASLI MAINTENANCE ENGINE ---
  void _runMaintenance(PharoahManager ph) async {
    String path = await ph.getWorkingPath();
    if (path.isEmpty) {
      final fy = ph.activeCompany?.fYears.first ?? "2025-26";
      await ph.loginToCompany(ph.activeCompany!, fy);
      path = await ph.getWorkingPath();
    }

    setState(() {
      isMaintenanceRunning = true;
      maintenanceProgress = 0.0;
      maintenanceStatus = "Waking up Pharoah Doctor...";
    });

    final engine = MaintenanceService(ph, path);
    await engine.runFullMaintenance(
      onProgress: (p, s) {
        if (mounted) setState(() { maintenanceProgress = p; maintenanceStatus = s; });
      },
    );

    await Future.delayed(const Duration(seconds: 1));
    if (mounted) setState(() => isMaintenanceRunning = false);
  }

  // --- 2. NEW YEAR SETUP LOGIC ---
  void _showNewYearDialog(PharoahManager ph) {
    final fyC = TextEditingController();
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Setup New Financial Year"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the new year name. This will transfer closing stock to the next year.", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 15),
            TextField(
              controller: fyC, 
              decoration: const InputDecoration(labelText: "New FY (e.g. 2026-27)", border: OutlineInputBorder())
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              if (fyC.text.isEmpty) return;
              Navigator.pop(c);
              bool ok = await ph.startNewFinancialYear(fyC.text.trim());
              if (ok) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ New Year Created Successfully!")));
              }
            },
            child: const Text("START TRANSFER"),
          )
        ],
      ),
    );
  }

  // --- 3. LOGIN LOGIC ---
  void _showFYLoginDialog(PharoahManager ph) {
    List<String> years = ph.activeCompany?.fYears ?? [];
    if (years.isEmpty) years = ["2025-26"];

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
              onTap: () async {
                Navigator.pop(c);
                // NAYA: Pehle saal login hote hi registry mein saal add karna (agar missing ho)
                if (!ph.activeCompany!.fYears.contains(fy)) {
                   int idx = ph.companiesRegistry.indexWhere((comp) => comp.id == ph.activeCompany!.id);
                   ph.companiesRegistry[idx].fYears.add(fy);
                   await ph.saveRegistry();
                }
                ph.loginToCompany(ph.activeCompany!, fy);
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => ph.clearSession()),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeaderCard(comp),
                const SizedBox(height: 25),
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
                    
                    // NAYA: EXPORT SERVICE CALL
                    _menuItem("BACKUP & EXPORT", Icons.cloud_upload_rounded, Colors.blue, () {
                      ExportService(ph).exportEntireCompany(comp);
                    }),
                    
                    _menuItem("NEW YEAR SETUP", Icons.fiber_new_rounded, Colors.purple, () => _showNewYearDialog(ph)),
                    _menuItem("MODIFY COMPANY", Icons.settings_applications_rounded, Colors.blueGrey, () {
                       Navigator.push(context, MaterialPageRoute(builder: (c) => ModifyCompanyView(comp: comp)));
                    }),
                    _menuItem("DELETE COMPANY", Icons.delete_forever_rounded, Colors.red, () => _confirmDelete(ph)),
                  ],
                ),
              ],
            ),
          ),
          if (isMaintenanceRunning) _buildMaintenanceOverlay(),
        ],
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _buildHeaderCard(CompanyProfile comp) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(children: [
          CircleAvatar(radius: 30, backgroundColor: const Color(0xFF0D47A1).withOpacity(0.1), child: const Icon(Icons.business_rounded, color: Color(0xFF0D47A1), size: 30)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("ACTIVE COMPANY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
            Text(comp.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text("Nature: ${comp.businessType}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ]))
      ]),
    );
  }

  Widget _menuItem(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withOpacity(0.1), width: 2)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 40), const SizedBox(height: 12), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold))])));
  }

  Widget _buildMaintenanceOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85), width: double.infinity, height: double.infinity,
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.medical_services_outlined, color: Colors.orange, size: 80),
          const SizedBox(height: 25),
          const Text("PHAROAH DOCTOR RUNNING", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(maintenanceStatus, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 30),
          Container(width: 250, height: 10, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: maintenanceProgress, color: Colors.orange, backgroundColor: Colors.transparent))),
          const SizedBox(height: 10),
          Text("${(maintenanceProgress * 100).toInt()}% Complete", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  void _confirmDelete(PharoahManager ph) {
    showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text("Delete Entire Company?"),
        content: const Text("Isse is company ka sara data hamesha ke liye delete ho jayega."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { ph.companiesRegistry.removeWhere((x) => x.id == ph.activeCompany!.id); ph.saveRegistry(); ph.clearSession(); Navigator.pop(c); }, child: const Text("YES, WIPE DATA", style: TextStyle(color: Colors.white))),
        ],
    ));
  }
}
