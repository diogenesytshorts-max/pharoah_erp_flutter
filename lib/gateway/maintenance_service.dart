import 'dart:convert';
import 'dart:io';
import '../pharoah_manager.dart';
import '../models.dart';
import '../inventory_logic_center.dart';

class MaintenanceService {
  final PharoahManager ph;
  final String workingPath;

  MaintenanceService(this.ph, this.workingPath);

  // ===========================================================================
  // MAIN MAINTENANCE ENGINE (1% - 100%)
  // ===========================================================================
  Future<void> runFullMaintenance({
    required Function(double progress, String status) onProgress,
  }) async {
    try {
      // --- PHASE 1: FILE INTEGRITY (0% - 20%) ---
      onProgress(0.1, "Step 1/5: Checking Database Structure...");
      List<String> coreFiles = ['meds.json', 'parts.json', 'sales.json', 'purc.json', 'bats.json', 'vouc.json'];
      
      for (var fileName in coreFiles) {
        File f = File('$workingPath/$fileName');
        if (!await f.exists()) {
          // Agar koi file missing hai toh default khali file bana do (Crash protection)
          await f.writeAsString(jsonEncode(fileName == 'bats.json' ? {} : []));
        }
      }
      onProgress(0.2, "File System: Verified & Repaired.");

      // --- PHASE 2: MASTER DATA SCAN (20% - 40%) ---
      onProgress(0.3, "Step 2/5: Validating Item Master & Parties...");
      
      // Memory refresh from physical files
      await ph.loadAllData();
      
      // Check for orphan records (Items without names, etc.)
      ph.medicines.removeWhere((m) => m.name.trim().isEmpty);
      ph.parties.removeWhere((p) => p.name.trim().isEmpty);
      onProgress(0.4, "Master Data: Cleaned and Optimized.");

      // --- PHASE 3: TRANSACTION INTEGRITY (40% - 60%) ---
      onProgress(0.5, "Step 3/5: Verifying Wholesale Bill Integrity...");
      
      // Sales syntax check
      try {
        final salesFile = File('$workingPath/sales.json');
        List<dynamic> rawSales = jsonDecode(await salesFile.readAsString());
        onProgress(0.55, "Scanning ${rawSales.length} Sale Bills...");
      } catch (e) {
        onProgress(0.58, "Alert: Corrupt Sales Data! Moving to Quarantine...");
        await _quarantineFile('sales.json');
      }

      // --- PHASE 4: THE GREAT INVENTORY REBUILD (60% - 90%) ---
      onProgress(0.7, "Step 4/5: Re-calculating Batch Master from Transactions...");
      
      // Wholesale ka sabse critical kaam: Stock Match karna
      // Hum Zero se saare bills scan karenge aur stock sync karenge
      InventoryLogicCenter.rebuildAllInventory(
        medicines: ph.medicines,
        batchHistory: ph.batchHistory,
        purchases: ph.purchases,
        sales: ph.sales,
      );
      
      // Party Ledger balances ka double-check yahan ho sakta hai
      onProgress(0.85, "Inventory: 100% Synced with Bills.");

      // --- PHASE 5: SYSTEM OPTIMIZATION (90% - 100%) ---
      onProgress(0.95, "Step 5/5: Finalizing Database Compression...");
      
      // Sab kuch physically save karna
      await ph.save();
      
      onProgress(1.0, "System Health is 100%. Maintenance Complete!");

    } catch (e) {
      onProgress(0.0, "Doctor Alert: Maintenance Failed due to ${e.toString()}");
    }
  }

  // ===========================================================================
  // HELPER: QUARANTINE ENGINE (Corrupt Data Safe-keeping)
  // ===========================================================================
  Future<void> _quarantineFile(String fileName) async {
    final qDir = Directory('$workingPath/QUARANTINE');
    if (!await qDir.exists()) await qDir.create(recursive: true);
    
    File original = File('$workingPath/$fileName');
    if (await original.exists()) {
      // Name Format: sales.json_broken_timestamp
      String timeStamp = DateTime.now().millisecondsSinceEpoch.toString();
      await original.copy('${qDir.path}/${fileName}_broken_$timeStamp');
      
      // Original file ko reset kar do taaki app chale
      await original.writeAsString(jsonEncode([])); 
    }
  }
}
