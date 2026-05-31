// FILE: lib/logic/pharoah_numbering_engine.dart

import 'package:shared_preferences/shared_preferences.dart';

class PharoahNumberingEngine {
  
  // ===========================================================================
  // 1. GET NEXT SMART NUMBER (Gap-Filling Sequential Engine)
  // ===========================================================================
  static Future<String> getNextNumber({
    required String type,           // SALE, PURCHASE, PRODUCT, etc.
    required String companyID,      
    required String prefix,         
    required int startFrom,         
    required List<dynamic> currentList, 
  }) async {
    
    final prefs = await SharedPreferences.getInstance();
    
    // Pointer check in persistent storage
    String counterKey = 'lastID_${type}_${prefix}_$companyID';
    // Note: We don't rely only on the stored int because items might have been deleted/added
    
    List<int> existingNumbers = [];

    // STEP A: SCAN CURRENT MEMORY FOR THE PREFIX
    for (var item in currentList) {
      String idToParse = "";
      
     // loop ke andar jahan idToParse assign ho raha hai, wahan ye logic jodein:

      try {
        if (type == "PURCHASE" || type == "CHALLAN_PUR") {
          idToParse = item.internalNo;
        } 
        else if (type == "PRODUCT") {
          idToParse = item.systemId;
        } 
        // --- NAYA LOGIC YAHAN JODEIN ---
        else if (type == "RECEIPT" || type == "PAYMENT") {
          idToParse = item.voucherNo; // Kyunki Voucher model mein field ka naam voucherNo hai
        }
        // ------------------------------
        else {
          idToParse = item.billNo; 
        }
      } catch (e) {
        idToParse = ""; 
      }

      if (idToParse.startsWith(prefix)) {
        String numPart = idToParse.replaceFirst(prefix, "");
        int? n = int.tryParse(numPart);
        if (n != null) existingNumbers.add(n);
      }
    }

    // STEP B: SEQUENTIAL & GAP FILLING LOGIC
    if (existingNumbers.isNotEmpty) {
      existingNumbers.sort();
      
      // Look for the first available gap from startFrom
      for (int i = startFrom; i <= existingNumbers.last; i++) {
        if (!existingNumbers.contains(i)) {
          return "$prefix$i"; // Found a missing number (e.g. 1, 2, [gap 3], 4)
        }
      }
      
      // No gaps, return next incremental number
      return "$prefix${existingNumbers.last + 1}";
    }

    // STEP C: START FROM DEFAULT IF LIST IS EMPTY
    return "$prefix$startFrom";
  }

  // ===========================================================================
  // 2. UPDATE PERSISTENT POINTER
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
      // Sirf tabhi update karein jab naya number bada ho
      if (usedInt > currentSaved) {
        await prefs.setInt(counterKey, usedInt);
      }
    }
  }

  // ===========================================================================
  // 3. COUNTER RESET (DANGER ZONE)
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
