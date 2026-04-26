// FILE: lib/logic/pharoah_numbering_engine.dart

import 'package:shared_preferences/shared_preferences.dart';

class PharoahNumberingEngine {
  
  // ===========================================================================
  // 1. GET NEXT SMART NUMBER
  // ===========================================================================
  static Future<String> getNextNumber({
    required String type,           // SALE, PURCHASE, CHALLAN, etc.
    required String companyID,      // To keep it isolated
    required String prefix,         // e.g. "CUSA-" or "INV/"
    required int startFrom,         // User defined start number
    required List<dynamic> currentList, // Full list of transactions from Manager
  }) async {
    
    final prefs = await SharedPreferences.getInstance();
    
    // Unique key for this specific series in this specific company
    // Key Format: lastID_SALE_CUSA-_PH-C-123
    String counterKey = 'lastID_${type}_${prefix}_$companyID';
    int lastPersistedID = prefs.getInt(counterKey) ?? (startFrom - 1);

    // Step A: Filter current list to find numbers only belonging to THIS prefix
    List<int> existingNumbers = [];
    for (var item in currentList) {
      String billNo = "";
      
      // Extracting bill number based on object type
      // Using 'dynamic' access for flexibility across models
      try {
        if (type == "PURCHASE") {
          billNo = item.internalNo; // Purchase uses internal tracking ID
        } else {
          billNo = item.billNo;     // Sales, Challans, Returns use billNo
        }
      } catch (e) {
        billNo = item.id; // Fallback
      }

      if (billNo.startsWith(prefix)) {
        String numPart = billNo.replaceFirst(prefix, "");
        int? n = int.tryParse(numPart);
        if (n != null) existingNumbers.add(n);
      }
    }

    // Step B: Gap Filling Logic
    if (existingNumbers.isNotEmpty) {
      existingNumbers.sort();
      
      // Scan from startNumber to current Max to find missing gaps (Deleted bills)
      for (int i = startFrom; i <= existingNumbers.last; i++) {
        if (!existingNumbers.contains(i)) {
          return "$prefix$i"; // Found a gap! Return it.
        }
      }
      
      // If no gaps, return Max + 1
      return "$prefix${existingNumbers.last + 1}";
    }

    // Step C: If list is empty, start from User's preferred Start Number
    return "$prefix$startFrom";
  }

  // ===========================================================================
  // 2. UPDATE PERSISTENT COUNTER (Call this on Save)
  // ===========================================================================
  static Future<void> updateSeriesCounter({
    required String type,
    required String companyID,
    required String usedNumber,
    required String prefix,
  }) async {
    if (!usedNumber.startsWith(prefix)) return;

    final prefs = await SharedPreferences.getInstance();
    String counterKey = 'lastID_${type}_${prefix}_$companyID';
    
    String numStr = usedNumber.replaceFirst(prefix, "");
    int? usedInt = int.tryParse(numStr);
    
    if (usedInt != null) {
      int currentSaved = prefs.getInt(counterKey) ?? 0;
      if (usedInt > currentSaved) {
        await prefs.setInt(counterKey, usedInt);
      }
    }
  }

  // ===========================================================================
  // 3. RESET LOGIC (For Maintenance)
  // ===========================================================================
  static Future<void> resetSeries({
    required String type,
    required String companyID,
    required String prefix,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String counterKey = 'lastID_${type}_${prefix}_$companyID';
    await prefs.remove(counterKey);
  }
}
