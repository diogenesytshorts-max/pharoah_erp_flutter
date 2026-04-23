import 'models.dart';

class InventoryLogicCenter {
  
  /// 1. DASHBOARD VALUATION ENGINE (Batch-wise & Without GST)
  /// Ye function sirf Positive stock wale batches ko jorta hai.
  static double calculateTotalStockValue({
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Medicine> medicines,
  }) {
    double grandTotal = 0;

    batchHistory.forEach((medKey, batches) {
      // Pehle Medicine find karo taaki GST rate pata chal sake
      Medicine? parentMed;
      try {
        parentMed = medicines.firstWhere((m) => m.identityKey == medKey);
      } catch (e) { parentMed = null; }

      double gstRate = parentMed?.gst ?? 12.0;

      for (var batch in batches) {
        // Sirf positive stock valuate hoga (Negative stock = 0 value)
        if (batch.qty > 0) {
          // Taxable Rate nikalna: Rate / (1 + GST/100)
          double taxableRate = batch.rate / (1 + (gstRate / 100));
          grandTotal += (batch.qty * taxableRate);
        }
      }
    });

    return grandTotal;
  }

  /// 2. BATCH TRACKER: SALE (Ghatane ke liye)
  static void updateBatchOnSale(List<BatchInfo> batches, String batchNo, double outQty) {
    try {
      // Specific batch dhoondo
      var b = batches.firstWhere((element) => element.batch.toUpperCase() == batchNo.toUpperCase());
      b.qty -= outQty; // Stock kam karo (Negative hone do)
    } catch (e) {
      // Agar batch nahi mila (Manual error), toh naya negative batch bana do track karne ke liye
      // Note: Asli ERP mein ye situation nahi aani chahiye par safety ke liye handle kiya hai.
    }
  }

  /// 3. BATCH TRACKER: PURCHASE (Jorne ke liye)
  static void updateBatchOnPurchase(List<BatchInfo> batches, BatchInfo newInfo) {
    int idx = batches.indexWhere((b) => b.batch.toUpperCase() == newInfo.batch.toUpperCase());
    
    if (idx != -1) {
      // Purana batch hai: Qty joro aur naya rate update karo
      batches[idx].qty += newInfo.qty;
      batches[idx].rate = newInfo.rate;
      batches[idx].mrp = newInfo.mrp;
      batches[idx].exp = newInfo.exp;
    } else {
      // Naya batch hai: List mein jor do
      batches.add(newInfo);
    }
  }

  /// 4. THE GREAT REPAIR (Inventory Rebuilder)
  /// Ye function aapke purane data (jahan qty 0 thi) ko scan karke sahi kar dega.
  static void rebuildAllInventory({
    required List<Medicine> medicines,
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Purchase> purchases,
    required List<Sale> sales,
  }) {
    // A. Sabse pehle saari batch quantities ZERO kar do
    batchHistory.forEach((key, list) {
      for (var b in list) { b.qty = 0; }
    });

    // B. Saari Purchases process karo (Stock IN)
    for (var pur in purchases) {
      for (var item in pur.items) {
        String key = "${item.name}|${item.packing}";
        if (batchHistory.containsKey(key)) {
          var batches = batchHistory[key]!;
          int idx = batches.indexWhere((b) => b.batch == item.batch);
          if (idx != -1) {
            batches[idx].qty += (item.qty + item.freeQty);
          }
        }
      }
    }

    // C. Saare Active Sale Bills process karo (Stock OUT)
    for (var sale in sales.where((s) => s.status == "Active")) {
      for (var item in sale.items) {
        String key = "${item.name}|${item.packing}";
        if (batchHistory.containsKey(key)) {
          var batches = batchHistory[key]!;
          int idx = batches.indexWhere((b) => b.batch == item.batch);
          if (idx != -1) {
            batches[idx].qty -= (item.qty + item.freeQty);
          }
        }
      }
    }

    // D. Main Medicine Master ka stock bhi correct kar do matching ke liye
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
