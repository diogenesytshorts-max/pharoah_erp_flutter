// FILE: lib/logic/pharoah_numbering_engine.dart

import 'package:shared_preferences/shared_preferences.dart';

class PharoahNumberingEngine {
  
  // ===========================================================================
  // 1. GET NEXT SMART NUMBER (Supports Sale, Purchase, Product, Salt, Company)
  // ===========================================================================
  static Future<String> getNextNumber({
    required String type,           // SALE, PURCHASE, PRODUCT, SALT, COMPANY, etc.
    required String companyID,      
    required String prefix,         
    required int startFrom,         
    required List<dynamic> currentList, 
  }) async {
    
    final prefs = await SharedPreferences.getInstance();
    
    // Unique key for isolation - same as your old logic
    String counterKey = 'lastID_${type}_${prefix}_$companyID';
    int lastPersistedID = prefs.getInt(counterKey) ?? (startFrom - 1);

    List<int> existingNumbers = [];

    // Step A: Scan current list with field awareness
    for (var item in currentList) {
      String idToParse = "";
      
      try {
        // NAYA: CHALLAN_PUR ke liye internalNo check karo
        if (type == "PURCHASE" || type == "CHALLAN_PUR") {
          idToParse = item.internalNo; 
        } 
        else if (type == "PRODUCT") {
          idToParse = item.systemId;
        } 
        else if (type == "SALT" || type == "COMPANY" || type == "DRUGTYPE") {
          idToParse = item.id;
        }
        else {
          idToParse = item.billNo; 
        }
      } catch (e) {
        // Fallback for safety
        idToParse = item.id ?? ""; 
      }

      if (idToParse.startsWith(prefix)) {
        String numPart = idToParse.replaceFirst(prefix, "");
        int? n = int.tryParse(numPart);
        if (n != null) existingNumbers.add(n);
      }
    }

    // Step B: Gap Filling Logic - same as your smart old logic
    if (existingNumbers.isNotEmpty) {
      existingNumbers.sort();
      
      for (int i = startFrom; i <= existingNumbers.last; i++) {
        if (!existingNumbers.contains(i)) {
          return "$prefix$i"; // Found a gap! Return it.
        }
      }
      
      // No gaps, return next incremental
      return "$prefix${existingNumbers.last + 1}";
    }

    // Step C: If list is empty, start from default
    return "$prefix$startFrom";
  }

  // ===========================================================================
  // 2. UPDATE PERSISTENT COUNTER (Unchanged Old Logic)
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
  // 3. RESET LOGIC (Unchanged Old Logic)
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
