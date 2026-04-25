// FILE: lib/logic/pharoah_numbering_engine.dart (Poora replace karein)

import 'package:shared_preferences/shared_preferences.dart';

class PharoahNumberingEngine {
  
  static Future<String> getNextNumber({
    required String type,      
    required String companyID,  
    required List<dynamic> currentList, 
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    String prefix = _getDefaultPrefix(type, companyID, prefs);
    String key = 'lastID_${type}_$companyID';
    int lastCounter = prefs.getInt(key) ?? 0;

    List<int> existingNumbers = [];
    for (var item in currentList) {
      String billNo = "";
      if (type.contains("SALE") || type.contains("BREAKAGE")) billNo = item.billNo;
      else if (type.contains("PURCHASE")) billNo = item.internalNo;
      else billNo = item.id; 

      if (billNo.startsWith(prefix)) {
        int? n = int.tryParse(billNo.replaceFirst(prefix, ""));
        if (n != null) existingNumbers.add(n);
      }
    }

    if (existingNumbers.isNotEmpty) {
      existingNumbers.sort();
      for (int i = 1; i <= lastCounter; i++) {
        if (!existingNumbers.contains(i)) {
          return "$prefix$i"; 
        }
      }
    }
    return "$prefix${lastCounter + 1}";
  }

  static Future<void> updateCounter({
    required String type,
    required String companyID,
    required String usedNumber,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    String prefix = _getDefaultPrefix(type, companyID, prefs);
    String key = 'lastID_${type}_$companyID';

    if (usedNumber.startsWith(prefix)) {
      int? num = int.tryParse(usedNumber.replaceFirst(prefix, ""));
      int currentMax = prefs.getInt(key) ?? 0;
      if (num != null && num > currentMax) {
        await prefs.setInt(key, num);
      }
    }
  }

  static String _getDefaultPrefix(String type, String companyID, SharedPreferences prefs) {
    String customKey = 'prefix_${type}_$companyID';
    
    switch (type) {
      case "SALE_BILL": return prefs.getString(customKey) ?? "INV-";
      case "SALE_CHALLAN": return prefs.getString(customKey) ?? "SCH-";
      case "SALE_RETURN": return prefs.getString(customKey) ?? "SRN-";
      case "BREAKAGE_RETURN": return prefs.getString(customKey) ?? "BRK-"; // NAYA
      case "PUR_BILL": return prefs.getString(customKey) ?? "PUR-";
      case "PUR_CHALLAN": return prefs.getString(customKey) ?? "PCH-";
      case "PUR_RETURN": return prefs.getString(customKey) ?? "PRN-";
      case "VOUCHER": return prefs.getString(customKey) ?? "VOU-";
      default: return "TXN-";
    }
  }
}
