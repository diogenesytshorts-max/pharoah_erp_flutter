// FILE: lib/logic/pharoah_numbering_engine.dart

import 'package:shared_preferences/shared_preferences.dart';

class PharoahNumberingEngine {
  
  // ===========================================================================
  // 1. UNIVERSAL GETTER: Agla Number nikalne ke liye
  // ===========================================================================
  static Future<String> getNextNumber({
    required String type,       // SALE_BILL, SALE_CHALLAN, SALE_RETURN, etc.
    required String companyID,  // Har dukan ka alag counter
    required List<dynamic> currentList, // Maujooda bills ki list (Gaps check karne ke liye)
  }) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Prefix decide karna type ke hisaab se
    String prefix = _getDefaultPrefix(type, companyID, prefs);
    String key = 'lastID_${type}_$companyID';
    int lastCounter = prefs.getInt(key) ?? 0;

    // 1. Gaps Check Karo (Professional Logic)
    // Agar koi Beech ka bill delete hua hai, toh wahi number wapas do.
    List<int> existingNumbers = [];
    for (var item in currentList) {
      String billNo = "";
      if (type.contains("SALE")) billNo = item.billNo;
      else if (type.contains("PURCHASE")) billNo = item.internalNo;
      else billNo = item.id; // Vouchers ke liye

      if (billNo.startsWith(prefix)) {
        int? n = int.tryParse(billNo.replaceFirst(prefix, ""));
        if (n != null) existingNumbers.add(n);
      }
    }

    if (existingNumbers.isNotEmpty) {
      existingNumbers.sort();
      for (int i = 1; i <= lastCounter; i++) {
        if (!existingNumbers.contains(i)) {
          return "$prefix$i"; // Gap mil gaya!
        }
      }
    }

    // 2. Agar gap nahi hai, toh naya number lastCounter + 1
    return "$prefix${lastCounter + 1}";
  }

  // ===========================================================================
  // 2. COUNTER UPDATER: Bill save hone ke baad counter badhane ke liye
  // ===========================================================================
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

  // ===========================================================================
  // 3. INTERNAL HELPER: Prefixes define karne ke liye
  // ===========================================================================
  static String _getDefaultPrefix(String type, String companyID, SharedPreferences prefs) {
    // User ne agar custom prefix set kiya hai toh wo uthao, varna default
    String customKey = 'prefix_${type}_$companyID';
    
    switch (type) {
      case "SALE_BILL": return prefs.getString(customKey) ?? "INV-";
      case "SALE_CHALLAN": return prefs.getString(customKey) ?? "SCH-";
      case "SALE_RETURN": return prefs.getString(customKey) ?? "SRN-";
      case "PUR_BILL": return prefs.getString(customKey) ?? "PUR-";
      case "PUR_CHALLAN": return prefs.getString(customKey) ?? "PCH-";
      case "PUR_RETURN": return prefs.getString(customKey) ?? "PRN-";
      case "VOUCHER": return prefs.getString(customKey) ?? "VOU-";
      default: return "TXN-";
    }
  }
}
