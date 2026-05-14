// FILE: lib/inventory_logic_center.dart

import 'models.dart';

class InventoryLogicCenter {
  
  /// 1. DASHBOARD VALUATION ENGINE (Batch-wise & Without GST)
  /// Positive stock wale batches ka taxable value calculate karta hai.
  static double calculateTotalStockValue({
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Medicine> medicines,
  }) {
    double grandTotal = 0;

    batchHistory.forEach((medKey, batches) {
      Medicine? parentMed;
      try {
        // identityKey (SystemId or ID) se match karna sabse safe hai
        parentMed = medicines.firstWhere((m) => m.identityKey == medKey);
      } catch (e) { parentMed = null; }

      double gstRate = parentMed?.gst ?? 12.0;

      for (var batch in batches) {
        if (batch.qty > 0) {
          double taxableRate = batch.rate / (1 + (gstRate / 100));
          grandTotal += (batch.qty * taxableRate);
        }
      }
    });

    return grandTotal;
  }

  /// 2. BATCH TRACKER: SALE (CASE SENSITIVE SAFE)
  static void updateBatchOnSale(List<BatchInfo> batches, String batchNo, double outQty) {
    try {
      // FIXED: Exact string match (No toUpperCase)
      var b = batches.firstWhere((element) => element.batch.trim() == batchNo.trim());
      b.qty -= outQty;
    } catch (e) {
      // Missing batch handling logic stays same
    }
  }

  /// 3. BATCH TRACKER: PURCHASE (CASE SENSITIVE SAFE)
  static void updateBatchOnPurchase(List<BatchInfo> batches, BatchInfo newInfo) {
    // FIXED: Exact string match for mirroring
    int idx = batches.indexWhere((b) => b.batch.trim() == newInfo.batch.trim());
    
    if (idx != -1) {
      batches[idx].qty += newInfo.qty;
      batches[idx].rate = newInfo.rate;
      batches[idx].mrp = newInfo.mrp;
      batches[idx].exp = newInfo.exp;
    } else {
      batches.add(newInfo);
    }
  }

  /// 4. THE GREAT REPAIR (Inventory Rebuilder - MIRROR READY)
  /// Transactions scan karke master stock ko correct karta hai.
  static void rebuildAllInventory({
    required List<Medicine> medicines,
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Purchase> purchases,
    required List<Sale> sales,
  }) {
    // A. RESET: 0 ki jagah Base Stock (Opening + Adjustments) par reset karein
    batchHistory.forEach((key, list) {
      for (var b in list) { 
        b.qty = b.openingQty + b.adjustmentQty; 
      }
    });

    // B. PROCESS PURCHASES (Stock IN)
    for (var pur in purchases) {
      for (var item in pur.items) {
        try {
          // Identify medicine using Master logic
          Medicine med = medicines.firstWhere((m) => m.id == item.medicineID || m.name == item.name);
          String key = med.identityKey;

          if (!batchHistory.containsKey(key)) batchHistory[key] = [];
          var batches = batchHistory[key]!;
          
          // FIXED: Strict Case matching for mirroring
          int idx = batches.indexWhere((b) => b.batch == item.batch);
          if (idx != -1) {
            batches[idx].qty += (item.qty + item.freeQty);
          } else {
            batches.add(BatchInfo(
              batch: item.batch, 
              exp: item.exp, 
              packing: item.packing, 
              mrp: item.mrp, 
              rate: item.purchaseRate, 
              qty: (item.qty + item.freeQty),
              isShell: false
            ));
          }
        } catch (e) {}
      }
    }

    // C. PROCESS SALES (Stock OUT)
    for (var sale in sales.where((s) => s.status == "Active")) {
      for (var item in sale.items) {
        try {
          Medicine med = medicines.firstWhere((m) => m.id == item.medicineID || m.name == item.name);
          String key = med.identityKey;

          if (batchHistory.containsKey(key)) {
            var batches = batchHistory[key]!;
            // FIXED: Strict Case matching
            int idx = batches.indexWhere((b) => b.batch == item.batch);
            if (idx != -1) {
              batches[idx].qty -= (item.qty + item.freeQty);
            }
          }
        } catch (e) {}
      }
    }

    // D. SYNC: Medicine Master ka 'stock' field update karein
    for (var med in medicines) {
      double total = 0;
      if (batchHistory.containsKey(med.identityKey)) {
        for (var b in batchHistory[med.identityKey]!) {
          total += b.qty;
        }
      }
      med.stock = total;
    }
  }
}
