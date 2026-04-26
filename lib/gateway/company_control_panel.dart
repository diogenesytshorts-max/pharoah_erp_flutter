// FILE: lib/gateway/company_control_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';
import 'maintenance_service.dart';
import 'modify_company_view.dart';
import 'export_service.dart';

class CompanyControlPanelView extends StatefulWidget {
  const CompanyControlPanelView({super.key});

  @override
  State<CompanyControlPanelView> createState() => _CompanyControlPanelViewState();
}

class _CompanyControlPanelViewState extends State<CompanyControlPanelView> {
  bool isMaintenanceRunning = false;
  String maintenanceStatus = "";

  // --- POPUP: FINANCIAL YEAR SELECTOR ---
  void _showFYSelectionDialog(PharoahManager ph, CompanyProfile comp) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Select Financial Year", style: TextStyle(fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: comp.fYears.length,
            itemBuilder: (context, i) {
              String fy = comp.fYears[i];
              return Card(
                elevation: 0,
                color: Colors.blue.shade50,
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.blue),
                  title: Text(fy, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.play_circle_fill, color: Colors.green),
                  onTap: () {
                    Navigator.pop(c);
                    // Manager mein saal set karke login process complete karo
                    ph.loginToCompany(comp, fy);
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // --- MAINTENANCE ENGINE ---
  void _runMaintenance(PharoahManager ph) async {
    // Maintenance ke liye humein latest FY ka context chahiye hota hai
    String latestFY = ph.activeCompany?.fYears.last ?? "";
    if (latestFY.isEmpty) return;

    setState(() {
      isMaintenanceRunning = true;
      maintenanceStatus = "Waking up Pharoah Doctor...";
    });

    // Pehle data load karo background mein
    await ph.loginToCompany(ph.activeCompany!, latestFY);
    String path = await ph.getWorkingPath();

    final engine = MaintenanceService(ph, path);
    await engine.runFullMaintenance(onProgress: (p, s) {
      if (mounted) setState(() { maintenanceStatus = s; });
    });

    // Maintenance khatam hone ke baad FY clear kar do taaki user phir se choice kare
    ph.currentFY = ""; 
    ph.notifyListeners();

    if (mounted) setState(() => isMaintenanceRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final comp = ph.activeCompany;
    if (comp == null) return const Scaffold(body: Center(child: Text("Error: No active company")));

    // --- PERMISSION LOGIC ---
    bool isAdmin = ph.loggedInStaff == null;
    bool canMaintain = isAdmin || (ph.loggedInStaff?.canRunMaintenance ?? false);
    bool canExport = isAdmin || (ph.loggedInStaff?.canExportData ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(comp.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          Text(isAdmin ? "Admin Control Panel" : "Staff Access: ${ph.loggedInStaff?.name}", 
               style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ]),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.logout), onPressed: () => ph.clearSession()),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeaderCard(comp, isAdmin),
                const SizedBox(height: 25),
                
                // GRID OF BUTTONS (With Visibility Logic)
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1,
                  ),
                  children: [
                    // 1. Always Visible: Login
                    _menuItem("LOGIN TO WORK", Icons.play_circle_fill_rounded, Colors.green, () => _showFYSelectionDialog(ph, comp)),
                    
                    // 2. Visible if Admin or permitted Staff: Maintenance
                    if (canMaintain)
                      _menuItem("FILE MAINTENANCE", Icons.health_and_safety_rounded, Colors.orange.shade800, () => _runMaintenance(ph)),
                    
                    // 3. Visible if Admin or permitted Staff: Backup
                    if (canExport)
                      _menuItem("BACKUP & EXPORT", Icons.cloud_upload_rounded, Colors.blue, () => ExportService(ph).exportEntireCompany(comp)),
                    
                    // 4. ADMIN ONLY: New Year
                    if (isAdmin)
                      _menuItem("NEW YEAR SETUP", Icons.fiber_new_rounded, Colors.purple, () => _showNewYearDialog(ph)),
                    
                    // 5. ADMIN ONLY: Modify
                    if (isAdmin)
                      _menuItem("MODIFY COMPANY", Icons.settings_applications_rounded, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (c) => ModifyCompanyView(comp: comp)))),
                    
                    // 6. ADMIN ONLY: Delete
                    if (isAdmin)
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

  Widget _buildHeaderCard(CompanyProfile comp, bool isAdmin) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(children: [
          CircleAvatar(radius: 30, backgroundColor: const Color(0xFF0D47A1).withOpacity(0.1), child: const Icon(Icons.business_rounded, color: Color(0xFF0D47A1), size: 30)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(comp.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text("Business Type: ${comp.businessType}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: isAdmin ? Colors.blue.shade100 : Colors.orange.shade100, borderRadius: BorderRadius.circular(5)),
              child: Text(isAdmin ? "FULL ADMIN ACCESS" : "RESTRICTED STAFF ACCESS", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isAdmin ? Colors.blue.shade900 : Colors.orange.shade900)),
            )
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
      ]),
    );
  }

  void _showNewYearDialog(PharoahManager ph) {
    final fyC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text("Setup New Financial Year"),
        content: TextField(controller: fyC, decoration: const InputDecoration(labelText: "New FY (e.g. 2026-27)", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(onPressed: () async {
              if (fyC.text.isEmpty) return;
              Navigator.pop(c);
              bool ok = await ph.startNewFinancialYear(fyC.text.trim());
              if (ok) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ New Year Created Successfully!")));
          }, child: const Text("START TRANSFER"))
        ],
    ));
  }

  void _confirmDelete(PharoahManager ph) {
    showDialog(context: context, builder: (c) => AlertDialog(
        title: const Text("Delete Entire Company?"),
        content: const Text("This action is irreversible. All your data will be permanently wiped."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { ph.companiesRegistry.removeWhere((x) => x.id == ph.activeCompany!.id); ph.saveRegistry(); ph.clearSession(); Navigator.pop(c); }, child: const Text("YES, DELETE EVERYTHING", style: TextStyle(color: Colors.white))),
        ],
    ));
  }
}
