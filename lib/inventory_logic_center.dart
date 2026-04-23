import 'models.dart';

class InventoryLogicCenter {
  
  /// 1. DASHBOARD VALUATION ENGINE
  static double calculateTotalStockValue({
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Medicine> medicines,
  }) {
    double grandTotal = 0;
    batchHistory.forEach((medKey, batches) {
      Medicine? parentMed;
      try {
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

  /// 2. BATCH TRACKER: SALE
  static void updateBatchOnSale(List<BatchInfo> batches, String batchNo, double outQty) {
    try {
      var b = batches.firstWhere((element) => element.batch.toUpperCase() == batchNo.toUpperCase());
      b.qty -= outQty;
    } catch (e) {
      // Safety: Item exists in bill but not in history (Edge Case)
    }
  }

  /// 3. BATCH TRACKER: PURCHASE
  static void updateBatchOnPurchase(List<BatchInfo> batches, BatchInfo newInfo) {
    int idx = batches.indexWhere((b) => b.batch.toUpperCase() == newInfo.batch.toUpperCase());
    if (idx != -1) {
      batches[idx].qty += newInfo.qty;
      batches[idx].rate = newInfo.rate;
      batches[idx].mrp = newInfo.mrp;
      batches[idx].exp = newInfo.exp;
    } else {
      batches.add(newInfo);
    }
  }

  /// 4. THE GREAT REPAIR (Corrected Key Logic)
  static void rebuildAllInventory({
    required List<Medicine> medicines,
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Purchase> purchases,
    required List<Sale> sales,
  }) {
    // A. Reset all quantities to zero first
    batchHistory.forEach((key, list) {
      for (var b in list) { b.qty = 0; }
    });

    // B. Re-process all Purchases (Stock IN)
    for (var pur in purchases) {
      for (var item in pur.items) {
        try {
          // Medicine find karna by ID or Name
          Medicine med = medicines.firstWhere((m) => m.id == item.medicineID || m.name == item.name);
          String key = med.identityKey;

          if (!batchHistory.containsKey(key)) batchHistory[key] = [];
          var batches = batchHistory[key]!;
          
          int idx = batches.indexWhere((b) => b.batch == item.batch);
          if (idx != -1) {
            batches[idx].qty += (item.qty + item.freeQty);
          } else {
            batches.add(BatchInfo(batch: item.batch, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: item.purchaseRate, qty: (item.qty + item.freeQty)));
          }
        } catch (e) {}
      }
    }

    // C. Re-process all Sales (Stock OUT)
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
            }
          }
        } catch (e) {}
      }
    }

    // D. Final Sync with Medicine Master Total Stock
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
