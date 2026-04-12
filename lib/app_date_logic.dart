import 'package:intl/intl.dart';

class AppDateLogic {
  // --- YE FUNCTION SAHI DATE DHONDH KAR DEGA ---
  static DateTime getSmartDate(String currentFY) {
    try {
      DateTime today = DateTime.now();
      
      // Financial Year se dates nikalna (e.g. "2025-26")
      int startYear = int.parse(currentFY.split('-')[0]);
      if (startYear < 2000) startYear += 2000;
      
      DateTime fyStart = DateTime(startYear, 4, 1);
      DateTime fyEnd = DateTime(startYear + 1, 3, 31);

      // Check: Kya aaj ki date FY ke andar hai?
      if (today.isAfter(fyStart.subtract(const Duration(days: 1))) && 
          today.isBefore(fyEnd.add(const Duration(days: 1)))) {
        return today; // Agar haan, toh Aaj ki date do
      } else {
        return fyStart; // Agar nahi, toh 1st April do
      }
    } catch (e) {
      return DateTime.now(); // Kuch galat hua toh aaj ki date fallback
    }
  }

  // --- DATE KO DISPLAY KARNE KA FORMAT (dd/MM/yyyy) ---
  static String format(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
