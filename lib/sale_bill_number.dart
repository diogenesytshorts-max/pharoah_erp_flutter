import 'package:shared_preferences/shared_preferences.dart';

class SaleBillNumber {
  static const String _keyLastId = 'lastBillID';
  static const String _keyPrefix = 'billPrefix';

  // Agla number lene ke liye
  static Future<String> getNextNumber() async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt(_keyLastId) ?? 0;
    String prefix = prefs.getString(_keyPrefix) ?? "INV-";
    return "$prefix${lastId + 1}";
  }

  // Bill save hone par number badhane ke liye
  static Future<void> increment() async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt(_keyLastId) ?? 0;
    await prefs.setInt(_keyLastId, lastId + 1);
  }

  // Series badalne ke liye (Settings se)
  static Future<void> updateSeries(int newStart, String newPrefix) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastId, newStart - 1);
    await prefs.setString(_keyPrefix, newPrefix);
  }
}
