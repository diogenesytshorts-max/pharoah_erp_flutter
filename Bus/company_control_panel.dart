// FILE: lib/gateway/company_control_panel.dart (UPDATED VERSION)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';
import 'maintenance_service.dart';
import 'modify_company_view.dart';
import 'export_service.dart';
import '../app_date_logic.dart'; // Naya import for FY logic

class CompanyControlPanelView extends StatefulWidget {
  const CompanyControlPanelView({super.key});

  @override
  State<CompanyControlPanelView> createState() => _CompanyControlPanelViewState();
}

class _CompanyControlPanelViewState extends State<CompanyControlPanelView> {
  bool isMaintenanceRunning = false;
  String maintenanceStatus = "";
  double maintenanceProgress = 0.0;

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

  // --- MAINTENANCE ENGINE (Updated with Professional UI Control) ---
  void _runMaintenance(PharoahManager ph) async {
    String latestFY = ph.activeCompany?.fYears.last ?? "";
    if (latestFY.isEmpty) return;

    setState(() {
      isMaintenanceRunning = true;
      maintenanceProgress = 0.0;
      maintenanceStatus = "Initializing Structural Audit...";
    });

    await ph.loginToCompany(ph.activeCompany!, latestFY);
    String path = await ph.getWorkingPath();

    final engine = MaintenanceService(ph, path);
    await engine.runFullMaintenance(onProgress: (p, s) {
      if (mounted) {
        setState(() {
          maintenanceProgress = p;
          maintenanceStatus = s;
        });
      }
    });

    ph.currentFY = ""; 
    ph.notifyListeners();

    if (mounted) setState(() => isMaintenanceRunning = false);
  }

  // --- 🚀 NEW YEAR SETUP: WITH CHECKLIST & AUTO-FILL ---
  void _showNewYearDialog(PharoahManager ph) {
    // 1. AUTO-FILL LOGIC: Last FY se agla saal nikalna
    String lastFY = ph.activeCompany!.fYears.last;
    String suggestedNextFY = AppDateLogic.getNextFYString(lastFY);
    final fyC = TextEditingController(text: suggestedNextFY);

    // 2. CHECKLIST LOGIC: Pending Challans check karna
    final pendingChallans = ph.saleChallans.where((c) => c.status == "Pending").toList();

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Setup New Year"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (pendingChallans.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  const SizedBox(width: 10),
                  Expanded(child: Text("Warning: ${pendingChallans.length} Pending Challans found! Inka stock automatic transfer nahi hoga.", style: const TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold))),
                ]),
              ),
              const SizedBox(height: 15),
            ],
            const Text("Enter target Financial Year name:", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: fyC, 
              decoration: const InputDecoration(labelText: "New FY", border: OutlineInputBorder(), hintText: "e.g. 2026-27")
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
            onPressed: () async {
              if (fyC.text.isEmpty) return;
              Navigator.pop(c);
              
              // Full Screen Loader for Transfer
              setState(() { isMaintenanceRunning = true; maintenanceStatus = "Transferring Masters & Balances..."; maintenanceProgress = 0.5; });
              
              bool ok = await ph.startNewFinancialYear(fyC.text.trim());
              
              setState(() => isMaintenanceRunning = false);
              if (ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ New Year Created Successfully!")));
            }, 
            child: const Text("START TRANSFER")
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final comp = ph.activeCompany;
    if (comp == null) return const Scaffold(body: Center(child: Text("Error: No active company")));

    bool isAdmin = ph.loggedInStaff == null;
    bool canMaintain = isAdmin || (ph.loggedInStaff?.canRunMaintenance ?? false);
    bool canExport = isAdmin || (ph.loggedInStaff?.canExportData ?? false);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(comp.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        leading: IconButton(icon: const Icon(Icons.logout), onPressed: () => ph.clearSession()),
      ),
      body: Stack( // PROFESSIONAL OVERLAY SUPPORT
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildHeaderCard(comp, isAdmin),
                const SizedBox(height: 25),
                GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.1,
                  ),
                  children: [
                    _menuItem("LOGIN TO WORK", Icons.play_circle_fill_rounded, Colors.green, () => _showFYSelectionDialog(ph, comp)),
                    if (canMaintain)
                      _menuItem("FILE MAINTENANCE", Icons.health_and_safety_rounded, Colors.orange.shade800, () => _runMaintenance(ph)),
                    if (canExport)
                      _menuItem("BACKUP & EXPORT", Icons.cloud_upload_rounded, Colors.blue, () => ExportService(ph).exportEntireCompany(comp)),
                    if (isAdmin)
                      _menuItem("NEW YEAR SETUP", Icons.fiber_new_rounded, Colors.purple, () => _showNewYearDialog(ph)),
                    if (isAdmin)
                      _menuItem("MODIFY COMPANY", Icons.settings_applications_rounded, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (c) => ModifyCompanyView(comp: comp)))),
                    if (isAdmin)
                      _menuItem("DELETE COMPANY", Icons.delete_forever_rounded, Colors.red, () => _confirmDelete(ph)),
                  ],
                ),
              ],
            ),
          ),
          
          // --- THE MAINTENANCE "CURTAIN" OVERLAY ---
          if (isMaintenanceRunning) 
            _buildMaintenanceOverlay(),
        ],
      ),
    );
  }

  // ===========================================================================
  // UI COMPONENTS
  // ===========================================================================

  Widget _buildMaintenanceOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.9), // Dark Dimmer
      width: double.infinity,
      height: double.infinity,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.health_and_safety_outlined, color: Colors.orange, size: 90),
          const SizedBox(height: 30),
          Text(
            "${(maintenanceProgress * 100).toInt()}%",
            style: const TextStyle(color: Colors.white, fontSize: 45, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: 250,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: maintenanceProgress, 
                color: Colors.orange, 
                backgroundColor: Colors.white10,
                minHeight: 10,
              ),
            ),
          ),
          const SizedBox(height: 30),
          Text(
            maintenanceStatus.toUpperCase(), 
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5)
          ),
          const SizedBox(height: 60),
          const Text("DO NOT CLOSE THE APPLICATION", style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(CompanyProfile comp, bool isAdmin) {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(children: [
          const CircleAvatar(radius: 30, backgroundColor: Color(0xFFF0F2F5), child: Icon(Icons.business_rounded, size: 30, color: Color(0xFF0D47A1))),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(comp.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1))),
            Text("Business Type: ${comp.businessType}", style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          ]))
      ]),
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
          border: Border.all(color: color.withOpacity(0.1), width: 2)
        ), 
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, 
          children: [
            Icon(icon, color: color, size: 40), 
            const SizedBox(height: 12), 
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))
          ]
        )
      )
    );
  }

  void _confirmDelete(PharoahManager ph) {
    int clickCount = 0;
    showDialog(context: context, builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text("PERMANENT DELETE"),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text("Warning: All years of this company will be wiped.", style: TextStyle(fontSize: 12, color: Colors.red)),
                const SizedBox(height: 15),
                Text("Confirm deletion: $clickCount/15"),
                LinearProgressIndicator(value: clickCount/15),
            ]),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("STOP")),
              ElevatedButton(onPressed: () async {
                setDialogState(() => clickCount++);
                if (clickCount >= 15) {
                  final root = await getApplicationDocumentsDirectory();
                  final dir = Directory('${root.path}/Pharoah_Data/${ph.activeCompany!.id}');
                  if (await dir.exists()) await dir.delete(recursive: true);
                  ph.companiesRegistry.removeWhere((x) => x.id == ph.activeCompany!.id);
                  await ph.saveRegistry();
                  ph.clearSession();
                  if (context.mounted) Navigator.pop(context);
                }
              }, child: const Text("YES, DELETE")),
            ],
          );
        });
    });
  }
}
