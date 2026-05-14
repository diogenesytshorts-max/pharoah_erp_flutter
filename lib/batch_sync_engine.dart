// FILE: lib/batch_sync_engine.dart

import 'models.dart';
import 'pharoah_manager.dart';
import 'expiry_master.dart';

class BatchSyncEngine {
  
  /// ===========================================================================
  /// 1. BATCH REGISTRATION (CASE SENSITIVE SAFE)
  /// Isse Sale/Purchase/Import ke waqt batch memory mein likha jata hai.
  /// ===========================================================================
  static void registerBatchActivity({
    required PharoahManager ph,
    required String productKey, 
    required String batchNo,    
    required String exp,
    required String packing,
    required double mrp,
    required double rate,
  }) {
    if (ph.activeCompany == null) return;

    if (!ph.batchHistory.containsKey(productKey)) {
      ph.batchHistory[productKey] = [];
    }

    List<BatchInfo> history = ph.batchHistory[productKey]!;
    
    // MATCHING: Exact string matching (aQ != AQ)
    int existingIdx = history.indexWhere(
      (b) => b.batch.trim() == batchNo.trim()
    );

    if (existingIdx != -1) {
      // UPDATE: Purane batch ki details refresh karna
      history[existingIdx].exp = exp;
      history[existingIdx].mrp = mrp;
      history[existingIdx].rate = rate;
      history[existingIdx].packing = packing;
    } else {
      // NEW: Naya batch register karna (Literal String)
      history.add(BatchInfo(
        batch: batchNo.trim(), // FIXED: No toUpperCase()
        exp: exp,
        packing: packing,
        mrp: mrp,
        rate: rate,
        qty: 0, 
        isShell: false,
      ));
    }

    // Disk par save karo taaki next session mein yaad rahe
    ph.save();
  }

  /// ===========================================================================
  /// 2. BATCH SUGGESTIONS (FOR SEARCH & SELECTION)
  /// ===========================================================================
  static List<BatchInfo> getFilteredBatches({
    required PharoahManager ph,
    required String productKey,
    bool hideExpired = false, 
  }) {
    if (ph.activeCompany == null) return [];
    if (!ph.batchHistory.containsKey(productKey)) return [];

    List<BatchInfo> allBatches = ph.batchHistory[productKey]!;
    
    if (hideExpired) {
      // Sale screen par sirf valid batches dikhane ke liye
      return allBatches.where((b) => ExpiryMaster.isSaleAllowed(b.exp)).toList();
    }

    return allBatches;
  }
}
