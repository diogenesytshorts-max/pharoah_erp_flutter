// FILE: lib/gateway/company_control_panel.dart (FULLY UPGRADED CONSOLIDATED STABLE VERSION)

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';
import 'maintenance_service.dart';
import 'modify_company_view.dart';
import 'export_service.dart';
import '../app_date_logic.dart'; // Import to calculate smart next financial year

class CompanyControlPanelView extends StatefulWidget {
  const CompanyControlPanelView({super.key});

  @override
  State<CompanyControlPanelView> createState() => _CompanyControlPanelViewState();
}

class _CompanyControlPanelViewState extends State<CompanyControlPanelView> {
  bool isMaintenanceRunning = false;
  String maintenanceStatus = "";
  double maintenanceProgress = 0.0;

  // --- 🛡️ NAYA: REPORT CARD STATE VARIABLES ---
  bool isMaintenanceCompleted = false; // Sync finished flag
  String successReportTitle = "";      // Banner Title
  List<String> successReportDetails = []; // Bullet points

  // ===========================================================================
  // 🏢 1. POPUP: FINANCIAL YEAR SELECTOR
  // ===========================================================================
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

  // ===========================================================================
  // 🛠️ 2. THE FILE MAINTENANCE PROCESS (WITH SILENT LOADING & REPORT CARD)
  // ===========================================================================
  void _runMaintenance(PharoahManager ph) async {
    String latestFY = ph.activeCompany?.fYears.last ?? "";
    if (latestFY.isEmpty) return;

    setState(() {
      isMaintenanceRunning = true;
      isMaintenanceCompleted = false; // Reset completed status
      maintenanceProgress = 0.0;
      maintenanceStatus = "Waking up Database Doctor...";
    });

    try {
      // 1. SILENT LOAD: Bina notify kiye background data reload kiya (No-flashing)
      await ph.loadDataForMaintenanceSilently(latestFY);
      String path = await ph.getWorkingPath();

      final engine = MaintenanceService(ph, path);
      
      // Drive progress in real-time from actual calculated tasks
      await engine.runFullMaintenance(onProgress: (p, s) {
        if (mounted) {
          setState(() {
            maintenanceProgress = p;
            maintenanceStatus = s;
          });
        }
      });

      // 2. SILENT RESET: Bina screen change kiye saal reset kiya
      ph.resetYearSilently();

      // --- 🏛️ NAYA: Audit Report Card Setup ---
      if (mounted) {
        setState(() {
          isMaintenanceCompleted = true; // Show success report card
          successReportTitle = "DATABASE INTEGRITY REPAIR COMPLETE";
          successReportDetails = [
            "• Structural Integrity: Verified & Healthy",
            "• Dynamic Stock Rebuild: Calculated & Synced",
            "• Orphaned Batches: Purged & Cleaned up from disk",
            "• Date & Cache Indices: Optimised successfully",
            "• Atomic Save: Compressed JSON saved on Disk"
          ];
        });
      }

    } catch (e) {
      ph.resetYearSilently();
      if (mounted) {
        setState(() {
          isMaintenanceRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error during maintenance: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // ===========================================================================
  // 🏛️ 3. NAYA: PROVISIONAL BALANCE SYNC (CASCADE COMPATIBLE WITH SUCCESS CARD)
  // ===========================================================================
  void _runProvisionalSync(PharoahManager ph, String startYear) async {
    setState(() {
      isMaintenanceRunning = true;
      isMaintenanceCompleted = false; // Reset completed status
      maintenanceProgress = 0.0;
      maintenanceStatus = "Initializing Cascade Sync...";
    });

    try {
      // Main sync engine call passing parameters directly on file-level
      bool success = await ph.syncOpeningBalancesFromPreviousYear(
        startYear: startYear,
        onStepProgress: (p, s) {
          if (mounted) {
            setState(() {
              maintenanceProgress = p;
              maintenanceStatus = s;
            });
          }
        }
      );

      // --- 🏛️ NAYA: Sync Report Card Setup ---
      if (success && mounted) {
        setState(() {
          isMaintenanceCompleted = true; // Show success report card
          successReportTitle = "CARRY BALANCES SYNC COMPLETE";
          successReportDetails = [
            "• Ledger Balances: Re-calculated & Synced successfully",
            "• Bank Accounts: Cash flow closing balances carried forward",
            "• Missing Masters: Missing parties & items delta imported",
            "• Pending Challans: Transferred smoothly to naye saal",
            "• Active Bills/Vouchers: 100% Untouched and Safe"
          ];
        });
      } else if (mounted) {
        setState(() {
          isMaintenanceRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Sync Failed! Please check year folders."), backgroundColor: Colors.red)
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isMaintenanceRunning = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Sync Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  // ===========================================================================
  // 🚀 4. NEW FINANCIAL YEAR SETUP (WITH WARNING CHECKLIST & AUTO-FILL)
  // ===========================================================================
  void _showNewYearDialog(PharoahManager ph) {
    // A. AUTO-FILL LOGIC: automatically pre-fills next logical year
    String lastFY = ph.activeCompany!.fYears.last;
    String suggestedNextFY = AppDateLogic.getNextFYString(lastFY);
    final fyC = TextEditingController(text: suggestedNextFY);

    // B. CHECKLIST WATCHDOG: scans for unbilled pending challans
    final pendingChallans = ph.saleChallans.where((c) => c.status == "Pending").toList();

    // Checkbox Local States
    bool skipZeroStock = false;
    bool skipExpired = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder( // StatefulBuilder lagaya taaki checkboxes tick ho sakein
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Setup New Financial Year"),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Checklist Warning Box
                    if (pendingChallans.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50, 
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200)
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Warning: ${pendingChallans.length} Pending Challans Found!", 
                                    style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    "Unbilled stocks cannot be carried forward properly. Please bill them or ignore to proceed.", 
                                    style: TextStyle(fontSize: 9, color: Colors.black87)
                                  ),
                                ],
                              )
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],
                    
                    const Text("Enter target Financial Year name:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: fyC, 
                      decoration: const InputDecoration(
                        labelText: "Target FY (MM/YY format)", 
                        border: OutlineInputBorder(), 
                        hintText: "e.g. 2026-27"
                      )
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const Text("DATABASE OPTIMIZATION FILTERS (MARG STYLE)", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1)),
                    const SizedBox(height: 8),

                    // Checkbox 1: Zero Stock Filter
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.purple,
                      title: const Text("Skip Zero-Stock Batches", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Dead stock will not be copied (Lightweight DB)", style: TextStyle(fontSize: 9)),
                      value: skipZeroStock, 
                      onChanged: (v) => setDialogState(() => skipZeroStock = v!),
                    ),

                    // Checkbox 2: Expired Stock Filter
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      activeColor: Colors.purple,
                      title: const Text("Skip Expired Batches", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: const Text("Expired items will not be transfered", style: TextStyle(fontSize: 9)),
                      value: skipExpired, 
                      onChanged: (v) => setDialogState(() => skipExpired = v!),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
                onPressed: () async {
                  if (fyC.text.isEmpty) return;
                  Navigator.pop(c); // Close Dialog
                  
                  // Trigger Immersive Progress Screen for transfer
                  setState(() {
                    isMaintenanceRunning = true;
                    isMaintenanceCompleted = false;
                    maintenanceStatus = "Transferring Masters, Checking Filters & Closing Balances...";
                    maintenanceProgress = 0.50; // Set half way
                  });

                  bool ok = await ph.startNewFinancialYear(
                    fyC.text.trim(),
                    filterZeroStock: skipZeroStock,
                    filterExpired: skipExpired,
                  );

                  setState(() {
                    isMaintenanceRunning = false;
                  });
                  
                  if (ok && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("✅ New Financial Year environment built!"), backgroundColor: Colors.green)
                    );
                  }
                }, 
                child: const Text("START TRANSFER")
              )
            ],
          );
        }
      ),
    );
  }

  // ===========================================================================
  // 🏢 5. THE IMMERSIVE "SPLASH" PROGRESS & SUCCESS OVERLAY
  // ===========================================================================
  Widget _buildMaintenanceOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.95), // Deep glass dimmer for report contrast
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // --- CASE A: SYSTEM REPORT CARD (SUCCESS WINDOW) ---
              if (isMaintenanceCompleted) ...[
                const Icon(Icons.verified_rounded, color: Colors.greenAccent, size: 90),
                const SizedBox(height: 20),
                const Text(
                  "SUCCESS!", 
                  style: TextStyle(color: Colors.greenAccent, fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)
                ),
                const SizedBox(height: 10),
                Text(
                  successReportTitle, 
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1)
                ),
                const SizedBox(height: 25),
                
                // Report details container
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white10)
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: successReportDetails.map((detail) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        detail,
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 40),

                // Prominent Manual Dismiss Button
                SizedBox(
                  width: 200, height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C
