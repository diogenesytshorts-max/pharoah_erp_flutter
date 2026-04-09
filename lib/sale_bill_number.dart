import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class SaleBillNumber {
  // --- 1. GET NEXT SMART NUMBER ---
  // Yeh function check karega ki koi purana bill delete toh nahi hua.
  // Agar #50 delete hua hai aur series #101 par hai, toh ye pehle #50 dega.
  static Future<String> getNextNumber(List<Sale> allSales) async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastBillID') ?? 0;
    String prefix = prefs.getString('billPrefix') ?? "INV-";

    // Maujooda bills mein se sirf numbers nikaalein (jo current prefix se match karte hon)
    List<int> existingNums = [];
    for (var s in allSales) {
      if (s.billNo.startsWith(prefix)) {
        String numPart = s.billNo.replaceFirst(prefix, "");
        int? n = int.tryParse(numPart);
        if (n != null) existingNums.add(n);
      }
    }
    existingNums.sort();

    // Pehle Gaps check karein (1 se lekar last recorded ID tak)
    for (int i = 1; i <= lastId; i++) {
      if (!existingNums.contains(i)) {
        return "$prefix$i"; // Missing number (gap) mil gaya
      }
    }

    // Agar koi gap nahi hai, toh agla fresh number dein
    return "$prefix${lastId + 1}";
  }

  // --- 2. INCREMENT SEQUENCE ---
  // Sirf tabhi increment karein jab user ne series ke aage ka naya number use kiya ho.
  // Agar gap wala bill (purana number) bhara gaya hai, toh counter nahi badhega.
  static Future<void> incrementIfNecessary(String usedBillNo) async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastBillID') ?? 0;
    String prefix = prefs.getString('billPrefix') ?? "INV-";

    if (usedBillNo.startsWith(prefix)) {
      String numPart = usedBillNo.replaceFirst(prefix, "");
      int? usedNum = int.tryParse(numPart);
      
      // Agar used number lastId se bada hai, matlab nayi series shuru hui hai
      if (usedNum != null && usedNum > lastId) {
        await prefs.setInt('lastBillID', usedNum);
      }
    }
  }

  // --- 3. MANUALLY UPDATE SERIES ---
  // Regex use karke prefix aur number ko alag karke series update karein.
  // Example: "SALE/2025/101" -> Prefix: "SALE/2025/", Number: 101
  static Future<void> updateSeriesFromFull(String fullBill) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Regex: Numbers ko end se pakadta hai aur baaki ko prefix maanta hai
    final match = RegExp(r'^([^\d]+)(\d+)$').firstMatch(fullBill);
    
    if (match != null) {
      String prefix = match.group(1)!;
      int num = int.parse(match.group(2)!);
      
      await prefs.setString('billPrefix', prefix);
      await prefs.setInt('lastBillID', num - 1); // Set to previous so getNext gives current
    } else {
      // Agar sirf text hai, toh usey prefix maan lein aur series 1 se shuru karein
      await prefs.setString('billPrefix', fullBill);
      await prefs.setInt('lastBillID', 0);
    }
  }
}
