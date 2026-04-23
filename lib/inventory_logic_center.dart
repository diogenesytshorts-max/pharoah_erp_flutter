import 'models.dart';

class InventoryLogicCenter {
  
  /// 1. DASHBOARD VALUATION ENGINE
  /// Calculates taxable stock value based on Batch Rates and GST.
  static double calculateTotalStockValue({
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Medicine> medicines,
  }) {
    double grandTotal = 0;

    batchHistory.forEach((medKey, batches) {
      Medicine? parentMed;
      try {
        // Now matching via systemId (The identityKey)
        parentMed = medicines.firstWhere((m) => m.identityKey == medKey);
      } catch (e) { parentMed = null; }

      double gstRate = parentMed?.gst ?? 12.0;

      for (var batch in batches) {
        // Only value positive physical stock
        if (batch.qty > 0) {
          double taxableRate = batch.rate / (1 + (gstRate / 100));
          grandTotal += (batch.qty * taxableRate);
        }
      }
    });
    return grandTotal;
  }

  /// 2. BATCH TRACKER: SALE
  static void updateBatchOnSale(List<BatchInfo> batches, String batchNo, double outQty) {
    try {
      var b = batches.firstWhere((element) => element.batch.toUpperCase() == batchNo.toUpperCase());
      b.qty -= outQty;
    } catch (e) {
      // In flexible mode, we allow sales even if batch record is missing in local list
    }
  }

  /// 3. BATCH TRACKER: PURCHASE
  static void updateBatchOnPurchase(List<BatchInfo> batches, BatchInfo newInfo) {
    int idx = batches.indexWhere((b) => b.batch.toUpperCase() == newInfo.batch.toUpperCase());
    if (idx != -1) {
      // Update existing batch with new qty and latest rates
      batches[idx].qty += newInfo.qty;
      batches[idx].rate = newInfo.rate;
      batches[idx].mrp = newInfo.mrp;
      batches[idx].exp = newInfo.exp;
      batches[idx].isShell = false; 
    } else {
      // Create new batch record
      batches.add(newInfo);
    }
  }

  /// 4. THE GREAT REPAIR (Corrected ID Logic for Batch Master)
  /// This function is the "Source of Truth" for the entire system.
  static void rebuildAllInventory({
    required List<Medicine> medicines,
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Purchase> purchases,
    required List<Sale> sales,
  }) {
    // A. Reset current qty to the sum of Opening + Manual Adjustments
    batchHistory.forEach((key, list) {
      for (var b in list) { 
        b.qty = b.openingQty + b.adjustmentQty; 
      }
    });

    // B. Re-process all Purchases (Stock IN)
    for (var pur in purchases) {
      for (var item in pur.items) {
        try {
          Medicine med = medicines.firstWhere((m) => m.id == item.medicineID || m.name == item.name);
          String key = med.identityKey;

          if (!batchHistory.containsKey(key)) batchHistory[key] = [];
          var batches = batchHistory[key]!;
          
          int idx = batches.indexWhere((b) => b.batch == item.batch);
          if (idx != -1) {
            batches[idx].qty += (item.qty + item.freeQty);
            batches[idx].isShell = false;
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

    // C. Re-process all Active Sales (Stock OUT)
    for (var sale in sales.where((s) => s.status == "Active")) {
      for (var item in sale.items) {
        try {
          Medicine med = medicines.firstWhere((m) => m.id == item.medicineID || m.name == item.name);
          String key = med.identityKey;

          if (batchHistory.containsKey(key)) {
            var batches = batchHistory[key]!;
            int idx = batches.indexWhere((b) => b.batch == item.batch);
            if (idx != -1) {
              batches[idx].qty -= (item.qty + item.freeQty);
            } else {
              // Create a shell batch for sales that happened before purchase entry
              batches.add(BatchInfo(
                batch: item.batch, 
                exp: item.exp, 
                packing: item.packing, 
                mrp: item.mrp, 
                rate: item.rate, 
                qty: -(item.qty + item.freeQty),
                isShell: true
              ));
            }
          }
        } catch (e) {}
      }
    }

    // D. Final Sync with Medicine Master for Display
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
