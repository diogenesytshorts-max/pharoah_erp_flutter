import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class SaleBillNumber {
  // Ab ye function sales ki list lega missing number dhoondne ke liye
  static Future<String> getNextNumber(List<Sale> allSales) async {
    final p = await SharedPreferences.getInstance();
    int lastId = p.getInt('lastBillID') ?? 0;
    String prefix = p.getString('billPrefix') ?? "INV-";

    // 1. Saare existing numbers ki list nikalein jo current prefix se match karte hon
    List<int> existingNums = [];
    for (var s in allSales) {
      if (s.billNo.startsWith(prefix)) {
        String numPart = s.billNo.replaceFirst(prefix, "");
        int? n = int.tryParse(numPart);
        if (n != null) existingNums.add(n);
      }
    }
    existingNums.sort();

    // 2. 1 se lekar lastId tak Gaps check karein
    for (int i = 1; i <= lastId; i++) {
      if (!existingNums.contains(i)) {
        return "$prefix$i"; // Missing number mil gaya
      }
    }

    // 3. Agar koi gap nahi mila, toh agla fresh number
    return "$prefix${lastId + 1}";
  }

  // Sirf tab increment karein jab gap wala bill na ho
  static Future<void> incrementIfNecessary(String usedBillNo) async {
    final p = await SharedPreferences.getInstance();
    int lastId = p.getInt('lastBillID') ?? 0;
    String prefix = p.getString('billPrefix') ?? "INV-";

    if (usedBillNo.startsWith(prefix)) {
      int? usedNum = int.tryParse(usedBillNo.replaceFirst(prefix, ""));
      if (usedNum != null && usedNum > lastId) {
        await p.setInt('lastBillID', usedNum);
      }
    }
  }

  static Future<void> updateSeriesFromFull(String fullBill) async {
    final p = await SharedPreferences.getInstance();
    final match = RegExp(r'^([^\d]+)(\d+)$').firstMatch(fullBill);
    if (match != null) {
      String prefix = match.group(1)!;
      int num = int.parse(match.group(2)!);
      await p.setString('billPrefix', prefix);
      await p.setInt('lastBillID', num - 1);
    } else {
      await p.setString('billPrefix', fullBill);
      await p.setInt('lastBillID', 0);
    }
  }
}
