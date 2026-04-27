// FILE: lib/batch_sync_engine.dart

import 'models.dart';
import 'pharoah_manager.dart';
import 'expiry_master.dart';

class BatchSyncEngine {
  
  /// ===========================================================================
  /// 1. BATCH REGISTRATION (The Memory Guard)
  /// Ye function "Rahul Enterprise" ki diary mein batch ko permanent likhta hai.
  /// Ise Sale, Purchase, Challan ya kisi bhi module se call kiya ja sakta hai.
  /// ===========================================================================
  static void registerBatchActivity({
    required PharoahManager ph,
    required String productKey, // Hamari Product ID (e.g. PH-10001)
    required String batchNo,    // Batch Number
    required String exp,
    required String packing,
    required double mrp,
    required double rate,
  }) {
    // --- LEVEL 1: SHOP SECURITY CHECK ---
    // Agar koi dukan (Rahul Enterprise) active nahi hai toh entry mat karo.
    if (ph.activeCompany == null) return;

    // --- LEVEL 2: PRODUCT NAMESPACE ---
    // Check karo ki is product ka record master map mein maujood hai ya nahi.
    if (!ph.batchHistory.containsKey(productKey)) {
      ph.batchHistory[productKey] = [];
    }

    List<BatchInfo> history = ph.batchHistory[productKey]!;
    
    // --- LEVEL 3: BATCH ISOLATION CHECK ---
    // Hum sirf tabhi update karenge jab Product ID aur Batch No dono match honge.
    // Isse ek product ke alag-alag batches (80 MRP aur 90 MRP) mix nahi honge.
    int existingIdx = history.indexWhere(
      (b) => b.batch.trim().toUpperCase() == batchNo.trim().toUpperCase()
    );

    if (existingIdx != -1) {
      // MATCH FOUND: Batch pehle se hai, toh uski details update karo (Correction logic)
      history[existingIdx].exp = exp;
      history[existingIdx].mrp = mrp;
      history[existingIdx].rate = rate;
      history[existingIdx].packing = packing;
    } else {
      // NEW BATCH: Ye batch Rahul Enterprise ke liye naya hai, ise register karo.
      history.add(BatchInfo(
        batch: batchNo.trim().toUpperCase(),
        exp: exp,
        packing: packing,
        mrp: mrp,
        rate: rate,
        qty: 0, // Transaction records iski quantity handle karenge
        isShell: false,
      ));
    }

    // --- PERSISTENCE: Yadaasht Save Karo ---
    // PharoahManager ko bolo ki is dukan ke 'bats.json' mein ye badlav turant likh de.
    // Isse screen logout hone par bhi data yaad rahega.
    ph.save();
  }

  /// ===========================================================================
  /// 2. SMART BATCH SUGGESTION (The Intelligent Recall)
  /// Ye function screens ko batches ki list deta hai.
  /// ===========================================================================
  static List<BatchInfo> getFilteredBatches({
    required PharoahManager ph,
    required String productKey,
    bool hideExpired = false, // Sale screen ke liye 'true' bhejenge
  }) {
    // Pehle dukan check karo
    if (ph.activeCompany == null) return [];

    // Agar is product ka koi history nahi hai, toh khali list bhej do
    if (!ph.batchHistory.containsKey(productKey)) return [];

    List<BatchInfo> allBatches = ph.batchHistory[productKey]!;
    
    if (hideExpired) {
      // SALE SHIELD: Sirf wahi batches dikhao jo expire nahi huye hain.
      // Ye hamare 'expiry_master.dart' ka use karke auto-filter karta hai.
      return allBatches.where((b) => ExpiryMaster.isSaleAllowed(b.exp)).toList();
    }

    // Purchase aur Master screen ke liye saare batches dikhao (taaki adjustment ho sake)
    return allBatches;
  }
}
