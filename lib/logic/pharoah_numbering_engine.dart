// FILE: lib/logic/pharoah_numbering_engine.dart

import 'package:shared_preferences/shared_preferences.dart';

class PharoahNumberingEngine {
  
  // ===========================================================================
  // 1. GET NEXT SMART NUMBER (Old Logic Preserved + Product Support Added)
  // ===========================================================================
  static Future<String> getNextNumber({
    required String type,           // SALE, PURCHASE, PRODUCT, etc.
    required String companyID,      
    required String prefix,         // e.g. "PH-"
    required int startFrom,         
    required List<dynamic> currentList, 
  }) async {
    
    final prefs = await SharedPreferences.getInstance();
    
    // Unique key logic - same as before
    String counterKey = 'lastID_${type}_${prefix}_$companyID';
    int lastPersistedID = prefs.getInt(counterKey) ?? (startFrom - 1);

    // Step A: Scan current list to find numbers
    List<int> existingNumbers = [];
    for (var item in currentList) {
      String idToParse = "";
      
      try {
        if (type == "PURCHASE") {
          idToParse = item.internalNo; 
        } 
        // --- NAYA BADLAV YAHAN HAI: PRODUCT SUPPORT ---
        else if (type == "PRODUCT") {
          idToParse = item.systemId; // Medicine ke liye systemId check karo
        } 
        // ----------------------------------------------
        else {
          idToParse = item.billNo;     
        }
      } catch (e) {
        idToParse = item.id; 
      }

      if (idToParse.startsWith(prefix)) {
        String numPart = idToParse.replaceFirst(prefix, "");
        int? n = int.tryParse(numPart);
        if (n != null) existingNumbers.add(n);
      }
    }

    // Step B: Gap Filling Logic - same as before
    if (existingNumbers.isNotEmpty) {
      existingNumbers.sort();
      
      for (int i = startFrom; i <= existingNumbers.last; i++) {
        if (!existingNumbers.contains(i)) {
          return "$prefix$i"; // Found a gap! Return it.
        }
      }
      
      return "$prefix${existingNumbers.last + 1}";
    }

    // Step C: If list is empty - same as before
    return "$prefix$startFrom";
  }

  // ===========================================================================
  // 2. UPDATE PERSISTENT COUNTER (Old Logic - Unchanged)
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
  // 3. RESET LOGIC (Old Logic - Unchanged)
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
