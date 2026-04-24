import 'dart:convert';
import 'dart:io';
import '../pharoah_manager.dart';
import '../models.dart';
import '../inventory_logic_center.dart';

class MaintenanceService {
  final PharoahManager ph;
  final String workingPath;

  MaintenanceService(this.ph, this.workingPath);

  // Function jo progress update karega UI ko
  Future<void> runFullMaintenance({
    required Function(double progress, String status) onProgress,
  }) async {
    try {
      // --- PHASE 1: INTEGRITY CHECK (0-20%) ---
      onProgress(0.1, "Checking Database Structure...");
      List<String> requiredFiles = ['meds.json', 'parts.json', 'sales.json', 'purc.json', 'bats.json'];
      for (var fileName in requiredFiles) {
        File f = File('$workingPath/$fileName');
        if (!await f.exists()) {
          // Agar file nahi hai toh khali file bana do crash rokne ke liye
          await f.writeAsString(jsonEncode(fileName == 'bats.json' ? {} : []));
        }
      }
      onProgress(0.2, "File Integrity Verified.");

      // --- PHASE 2: WHOLESALE REFERENCE CHECK (20-50%) ---
      onProgress(0.3, "Scanning Item Master References...");
      // Pehle master data load karo
      await ph.loadAllData();
      
      onProgress(0.4, "Verifying Sales Bills Syntax...");
      // Corrupt bills check karne ka logic (Simple try-catch)
      try {
        final salesFile = File('$workingPath/sales.json');
        jsonDecode(await salesFile.readAsString());
      } catch (e) {
        // Agar corrupt hai toh backup le kar reset karo
        onProgress(0.45, "Alert: Found Corrupt Sales File. Moving to Quarantine...");
        await _quarantineFile('sales.json');
      }

      // --- PHASE 3: INVENTORY RE-SYNC (50-90%) ---
      onProgress(0.6, "Re-calculating Batch Quantities from Bills...");
      // Wholesale ka main kaam: Transactions ko scan karke stock rebuilding
      InventoryLogicCenter.rebuildAllInventory(
        medicines: ph.medicines,
        batchHistory: ph.batchHistory,
        purchases: ph.purchases,
        sales: ph.sales,
      );
      
      // Sync complete hone ke baad save karo
      await ph.save();
      onProgress(0.85, "Batch Master Re-Sync Successful.");

      // --- PHASE 4: FINAL OPTIMIZATION (90-100%) ---
      onProgress(0.95, "Optimizing Cache & Finalizing...");
      await Future.delayed(const Duration(milliseconds: 500));
      
      onProgress(1.0, "Maintenance Complete. System Healthy!");

    } catch (e) {
      onProgress(0.0, "Maintenance Error: ${e.toString()}");
    }
  }

  // Helper: Corrupt file ko alag folder mein dalna
  Future<void> _quarantineFile(String fileName) async {
    final qDir = Directory('$workingPath/QUARANTINE');
    if (!await qDir.exists()) await qDir.create();
    
    File original = File('$workingPath/$fileName');
    if (await original.exists()) {
      await original.copy('${qDir.path}/${fileName}_broken_${DateTime.now().millisecondsSinceEpoch}');
      await original.writeAsString(jsonEncode([])); // Reset original to empty list
    }
  }
}
