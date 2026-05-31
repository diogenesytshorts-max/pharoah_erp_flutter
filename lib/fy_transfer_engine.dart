// FILE: lib/fy_transfer_engine.dart (UPDATED VERSION)

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class FYTransferEngine {
  
  /// MAIN FUNCTION: Purane saal se naye saal mein data le jana (Multi-Company Ready)
  static Future<bool> transferData({
    required String companyID,      
    required String businessType,   
    required String sourceFY,       
    required String targetFY,       
  }) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      
      // Path Logic: Documents/Pharoah_Data/ID/TYPE/FY
      final basePath = '${root.path}/Pharoah_Data/$companyID/$businessType';
      final sourcePath = '$basePath/$sourceFY';
      final targetPath = '$basePath/$targetFY';

      final sourceDir = Directory(sourcePath);
      final targetDir = Directory(targetPath);

      // 1. Agar naya folder nahi hai toh bana do
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // 2. Load Source Data (Purane saal ki files)
      dynamic loadJson(String name) {
        final f = File('$sourcePath/$name');
        return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
      }

      List<Medicine> oldMeds = (loadJson('meds.json') as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? [];
      List<Party> oldParties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [];
      List<Sale> oldSales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
      List<Purchase> oldPurc = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
      List<Voucher> oldVouc = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
      Map<String, dynamic> oldBatchesRaw = loadJson('bats.json') ?? {};

      // 3. CALCULATE NEW PARTY BALANCES (Opening Balances for New Year)
      List<Party> newParties = oldParties.map((p) {
        if (p.name == "CASH") return p;

        double runningBal = p.opBal;
        // Sales add to Dr
        for (var s in oldSales.where((s) => s.partyName == p.name && s.status == "Active")) {
          runningBal += s.totalAmount;
        }
        // Purchases subtract (Credit)
        for (var pr in oldPurc.where((pr) => pr.distributorName == p.name)) {
          runningBal -= pr.totalAmount;
        }
        // Vouchers
        for (var v in oldVouc.where((v) => v.partyName == p.name)) {
          if (v.type == "Receipt") runningBal -= v.amount;
          if (v.type == "Payment") runningBal += v.amount;
        }

        // Ye ab naye saal ka Opening Balance ban jayega
        p.opBal = runningBal;
        return p;
      }).toList();

      // 4. 🔥 NAYA: MEDICINE STOCK CORRECTION (Negative to 0)
      List<Map<String, dynamic>> correctedMeds = oldMeds.map((m) {
        // Business Rule: Agar stock negative hai toh naye saal mein 0 se shuru karein
        if (m.stock < 0) m.stock = 0; 
        return m.toMap();
      }).toList();

      // 5. 🔥 NAYA: BATCH HISTORY CORRECTION (Negative to 0)
      Map<String, dynamic> correctedBatches = {};
      oldBatchesRaw.forEach((medKey, batchList) {
        List<dynamic> batches = batchList as List;
        List<Map<String, dynamic>> processedBatches = batches.map((b) {
          BatchInfo bObj = BatchInfo.fromMap(b);
          // Batch level par bhi negative stock ko zero kar rahe hain consistency ke liye
          if (bObj.qty < 0) bObj.qty = 0;
          // Opening Qty ko update karna zaroori hai kyunki naya saal hai
          bObj.openingQty = bObj.qty;
          bObj.adjustmentQty = 0; // Adjustments reset
          return bObj.toMap();
        }).toList();
        correctedBatches[medKey] = processedBatches;
      });

      // 6. SAVE TO NEW FY DIRECTORY
      Future saveToNew(String name, dynamic data) async {
        await File('$targetPath/$name').writeAsString(jsonEncode(data));
      }

      await saveToNew('meds.json', correctedMeds);
      await saveToNew('parts.json', newParties.map((e) => e.toMap()).toList());
      await saveToNew('bats.json', correctedBatches); 
      await saveToNew('routs.json', loadJson('routs.json') ?? []);
      await saveToNew('comps.json', loadJson('comps.json') ?? []);
      await saveToNew('salts.json', loadJson('salts.json') ?? []);
      await saveToNew('dtypes.json', loadJson('dtypes.json') ?? []);

      // RESET TRANSACTIONS FOR NEW YEAR
      await saveToNew('sales.json', []);
      await saveToNew('purc.json', []);
      await saveToNew('vouc.json', []);
      await saveToNew('s_challan.json', []);
      
      // Audit log entry for transfer
      await saveToNew('logs.json', [
        LogEntry(
          id: '1', 
          action: 'SYSTEM', 
          details: 'Data Transferred from $sourceFY to $targetFY. Negative stocks reset to 0.', 
          time: DateTime.now()
        ).toMap()
      ]);

      return true;
    } catch (e) {
      print("FY Transfer Error: $e");
      return false;
    }
  }
}
