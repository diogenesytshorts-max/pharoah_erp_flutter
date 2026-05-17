// FILE: lib/inventory_logic_center.dart

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
      var b = batches.firstWhere((element) => element.batch.trim() == batchNo.trim());
      b.qty -= outQty;
    } catch (e) {}
  }

  /// 3. BATCH TRACKER: PURCHASE
  static void updateBatchOnPurchase(List<BatchInfo> batches, BatchInfo newInfo) {
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

  /// 4. THE GREAT REPAIR (Advanced Inventory Rebuilder)
  /// 🔥 UPDATED: Now accounts for Sellable vs Breakage Returns
  static void rebuildAllInventory({
    required List<Medicine> medicines,
    required Map<String, List<BatchInfo>> batchHistory,
    required List<Purchase> purchases,
    required List<Sale> sales,
    List<SaleReturn>? saleReturns,      // 🔥 NAYA
    List<PurchaseReturn>? purchaseReturns // 🔥 NAYA
  }) {
    // A. RESET: Base Stock (Opening + Adjustments) par reset karein
    batchHistory.forEach((key, list) {
      for (var b in list) { b.qty = b.openingQty + b.adjustmentQty; }
    });

    // B. PROCESS PURCHASES (Stock IN)
    for (var pur in purchases) {
      for (var item in pur.items) {
        _updateStock(batchHistory, medicines, item.medicineID, item.name, item.batch, (item.qty + item.freeQty), true, item);
      }
    }

    // C. PROCESS SALES (Stock OUT)
    for (var sale in sales.where((s) => s.status == "Active")) {
      for (var item in sale.items) {
        _updateStock(batchHistory, medicines, item.medicineID, item.name, item.batch, (item.qty + item.freeQty), false, item);
      }
    }

    // D. PROCESS SALE RETURNS / CREDIT NOTES (Stock IN - Only if Sellable)
    if (saleReturns != null) {
      for (var ret in saleReturns.where((r) => r.status == "Active")) {
        for (var item in ret.items) {
          // 🔥 LOGIC: Agar item 'Breakage' nahi hai, tabhi main stock mein jorein
          if (item.isBreakage == false) {
            _updateStock(batchHistory, medicines, item.medicineID, item.name, item.batch, (item.qty + item.freeQty), true, item);
          }
        }
      }
    }

    // E. PROCESS PURCHASE RETURNS / DEBIT NOTES (Stock OUT)
    if (purchaseReturns != null) {
      for (var ret in purchaseReturns.where((r) => r.status == "Active")) {
        for (var item in ret.items) {
          // Purchase return (Debit Note) hamesha stock kam karta hai
          _updateStock(batchHistory, medicines, item.medicineID, item.name, item.batch, (item.qty + item.freeQty), false, item);
        }
      }
    }

    // F. FINAL SYNC: Medicine Master stock field update
    for (var med in medicines) {
      double total = 0;
      if (batchHistory.containsKey(med.identityKey)) {
        for (var b in batchHistory[med.identityKey]!) { total += b.qty; }
      }
      med.stock = total;
    }
  }

  // Private Helper to avoid code repetition
  static void _updateStock(Map<String, List<BatchInfo>> batchHistory, List<Medicine> medicines, String medId, String medName, String batchNo, double qty, bool isAdd, dynamic item) {
    try {
      Medicine med = medicines.firstWhere((m) => m.id == medId || m.name == medName);
      String key = med.identityKey;
      if (!batchHistory.containsKey(key)) batchHistory[key] = [];
      var batches = batchHistory[key]!;
      int idx = batches.indexWhere((b) => b.batch == batchNo);
      
      if (idx != -1) {
        batches[idx].qty += isAdd ? qty : -qty;
      } else if (isAdd) {
        batches.add(BatchInfo(batch: batchNo, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: (item is PurchaseItem) ? item.purchaseRate : item.rate, qty: qty, isShell: false));
      }
    } catch (e) {}
  }
}
