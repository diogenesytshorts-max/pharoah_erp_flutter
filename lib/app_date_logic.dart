import 'package:intl/intl.dart';

class AppDateLogic {
  /// Yeh function faisla karta hai ki bill par kaunsi date dikhani hai
  static DateTime getSmartDate(String currentFY) {
    try {
      DateTime now = DateTime.now();
      // Aaj ki date (samay 00:00:00 kar diya taaki calculation sahi rahe)
      DateTime today = DateTime(now.year, now.month, now.day);
      
      // Financial Year string se start aur end year nikaalna (e.g., "2025-26")
      List<String> parts = currentFY.split('-');
      int startYear = int.parse(parts[0]);
      if (startYear < 2000) startYear += 2000;
      
      // FY ki boundary dates tay karna
      DateTime fyStart = DateTime(startYear, 4, 1); // 1st April
      DateTime fyEnd = DateTime(startYear + 1, 3, 31, 23, 59, 59); // 31st March

      // --- LOGIC 1: AGAR AAJ KI DATE FY KE ANDAR HAI ---
      // Agar aaj 15 May 2025 hai aur FY 2025-26 chal raha hai, toh 'Today' return karega.
      if (today.isAfter(fyStart.subtract(const Duration(days: 1))) && 
          today.isBefore(fyEnd.add(const Duration(days: 1)))) {
        return today; 
      } 
      
      // --- LOGIC 2: AGAR AAJ KI DATE FY SE AAGE NIKAL GAYI HAI ---
      // Agar aaj April 2026 hai par aap 2025-26 ke khate mein kaam kar rahe hain, 
      // toh ye automatic '31 March 2026' dikhayega (Late Date Logic).
      else if (today.isAfter(fyEnd)) {
        return DateTime(startYear + 1, 3, 31);
      } 
      
      // --- LOGIC 3: AGAR AAJ KI DATE FY SE PEHLE KI HAI ---
      // Agar aapne aage ka saal chuna hai par aaj ki date piche hai, toh 1st April dikhayega.
      else {
        return fyStart;
      }
    } catch (e) {
      // Kisi bhi error ki surat mein aaj ki default date return karega
      return DateTime.now();
    }
  }

  /// Date ko standard Indian format (dd/MM/yyyy) mein dikhane ke liye
  static String format(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }

  /// Check karta hai ki user jo date select kar raha hai wo FY ke andar hai ya nahi
  static bool isValidInFY(DateTime pickedDate, String currentFY) {
    List<String> parts = currentFY.split('-');
    int startYear = int.parse(parts[0]);
    if (startYear < 2000) startYear += 2000;
    
    DateTime fyStart = DateTime(startYear, 4, 1);
    DateTime fyEnd = DateTime(startYear + 1, 3, 31, 23, 59, 59);

    return pickedDate.isAfter(fyStart.subtract(const Duration(days: 1))) && 
           pickedDate.isBefore(fyEnd.add(const Duration(days: 1)));
  }
}
