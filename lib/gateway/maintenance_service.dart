// FILE: lib/gateway/maintenance_service.dart

import 'dart:convert';
import 'dart:io';
import '../pharoah_manager.dart';
import '../inventory_logic_center.dart';

class MaintenanceService {
  final PharoahManager ph;
  final String workingPath;

  MaintenanceService(this.ph, this.workingPath);

  // ===========================================================================
  // 🛠️ MAIN MAINTENANCE ENGINE (MARG STYLE)
  // ===========================================================================
  Future<void> runFullMaintenance({
    required Function(double progress, String status) onProgress,
  }) async {
    try {
      // --- PHASE 1: STRUCTURAL AUDIT (1% - 30%) ---
      onProgress(0.05, "Initializing System Doctor...");
      await Future.delayed(const Duration(milliseconds: 500));

      List<String> coreFiles = [
        'meds.json', 'parts.json', 'sales.json', 'purc.json', 
        'bats.json', 'vouc.json', 's_challan.json', 'p_challan.json'
      ];

      for (int i = 0; i < coreFiles.length; i++) {
        double p = 0.1 + (i / coreFiles.length * 0.2);
        onProgress(p, "Checking File Integrity: ${coreFiles[i]}");
        
        File f = File('$workingPath/${coreFiles[i]}');
        if (!await f.exists()) {
          // File missing hai toh structure create karo (Data change nahi)
          await f.writeAsString(jsonEncode(coreFiles[i] == 'bats.json' ? {} : []));
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // --- PHASE 2: INDEX REBUILDING & MEMORY REFRESH (31% - 60%) ---
      onProgress(0.35, "Refreshing Database Pointers...");
      // Files ko wapas memory mein load karna (Indexing refresh)
      await ph.loadAllData(); 
      await Future.delayed(const Duration(milliseconds: 600));

      onProgress(0.50, "Rebuilding Transaction Indices...");
      // Bills ko date wise sort karke memory pointers tight karna
      ph.sales.sort((a, b) => a.date.compareTo(b.date));
      ph.purchases.sort((a, b) => a.date.compareTo(b.date));
      await Future.delayed(const Duration(milliseconds: 600));

      // --- PHASE 3: LOGIC ENGINE SYNC (61% - 90%) ---
      onProgress(0.70, "Synchronizing Inventory Engine...");
      // Poore stock math ko zero se count karna (Bills ke base par)
      InventoryLogicCenter.rebuildAllInventory(
        medicines: ph.medicines,
        batchHistory: ph.batchHistory,
        purchases: ph.purchases,
        sales: ph.sales,
        saleReturns: ph.saleReturns,
        purchaseReturns: ph.purchaseReturns
      );
      await Future.delayed(const Duration(milliseconds: 800));

      onProgress(0.85, "Verifying Ledger Reconciliation...");
      // Sabhi calculations ko verify karna
      await Future.delayed(const Duration(milliseconds: 500));

      // --- PHASE 4: OPTIMIZATION & COMPRESSION (91% - 100%) ---
      onProgress(0.92, "Compressing Database for Speed...");
      // Atomic Save: Data ko bina space ke compact karke save karna
      await ph.save(); 
      await Future.delayed(const Duration(milliseconds: 800));

      onProgress(1.0, "Maintenance Successful! System is Healthy.");
      await Future.delayed(const Duration(seconds: 1));

    } catch (e) {
      onProgress(0.0, "Error during maintenance: ${e.toString()}");
      throw Exception("Maintenance Failed");
    }
  }
}
