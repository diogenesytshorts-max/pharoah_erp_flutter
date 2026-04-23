import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class SaleBillNumber {
  // --- 1. GET NEXT SMART NUMBER ---
  static Future<String> getNextNumber(List<Sale> allSales) async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastBillID') ?? 0;
    String prefix = prefs.getString('billPrefix') ?? "INV-";

    // Maujooda bills ke numbers extract karna
    List<int> existingNums = [];
    for (var s in allSales) {
      if (s.billNo.startsWith(prefix)) {
        String numPart = s.billNo.replaceFirst(prefix, "");
        int? n = int.tryParse(numPart);
        if (n != null) existingNums.add(n);
      }
    }
    
    // Agar koi bill nahi hai, toh seedha 1 se start karo
    if (existingNums.isEmpty) {
      return "${prefix}1";
    }

    existingNums.sort();

    // Pehle gaps check karein (Agar koi bill beech mein delete hua hai)
    for (int i = 1; i <= lastId; i++) {
      if (!existingNums.contains(i)) {
        return "$prefix$i"; 
      }
    }

    // Agar koi gap nahi, toh lastId + 1
    return "$prefix${lastId + 1}";
  }

  // --- 2. INCREMENT SEQUENCE ---
  // Isse hum Sale save karte waqt call karenge
  static Future<void> incrementIfNecessary(String usedBillNo) async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastBillID') ?? 0;
    String prefix = prefs.getString('billPrefix') ?? "INV-";

    if (usedBillNo.startsWith(prefix)) {
      String numPart = usedBillNo.replaceFirst(prefix, "");
      int? usedNum = int.tryParse(numPart);
      
      // Agar user ne series aage badhayi hai, toh lastId update karo
      if (usedNum != null && usedNum > lastId) {
        await prefs.setInt('lastBillID', usedNum);
      }
    }
  }

  // --- 3. INITIAL SETUP ---
  static Future<void> initializeSeries(String prefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('billPrefix', prefix);
    // lastBillID 0 rahega taaki pehla bill 1 bane
    await prefs.setInt('lastBillID', 0);
  }
}
