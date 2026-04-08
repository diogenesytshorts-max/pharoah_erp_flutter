import 'package:shared_preferences/shared_preferences.dart';

class SaleBillNumber {
  static Future<String> getNextNumber() async {
    final p = await SharedPreferences.getInstance();
    int lastId = p.getInt('lastBillID') ?? 0;
    String prefix = p.getString('billPrefix') ?? "INV-";
    return "$prefix${lastId + 1}";
  }

  static Future<void> increment() async {
    final p = await SharedPreferences.getInstance();
    int lastId = p.getInt('lastBillID') ?? 0;
    await p.setInt('lastBillID', lastId + 1);
  }

  static Future<void> updateSeriesFromFull(String fullBill) async {
    final p = await SharedPreferences.getInstance();
    // Regex to separate Prefix and Number (e.g. "INV-101" -> "INV-" and 101)
    final match = RegExp(r'^([^\d]+)(\d+)$').firstMatch(fullBill);
    if (match != null) {
      String prefix = match.group(1)!;
      int num = int.parse(match.group(2)!);
      await p.setString('billPrefix', prefix);
      await p.setInt('lastBillID', num - 1);
    } else {
      // If no digits, just save as prefix
      await p.setString('billPrefix', fullBill);
      await p.setInt('lastBillID', 0);
    }
  }
}
