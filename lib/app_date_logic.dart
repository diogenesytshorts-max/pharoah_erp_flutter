import 'package:intl/intl.dart';

class AppDateLogic {
  static DateTime getSmartDate(String currentFY) {
    try {
      DateTime now = DateTime.now();
      // Sirf Aaj ki Date (samay zero kar rahe hain)
      DateTime today = DateTime(now.year, now.month, now.day);
      
      // Financial Year parsing (e.g. "2025-26")
      int startYear = int.parse(currentFY.split('-')[0]);
      if (startYear < 2000) startYear += 2000;
      
      DateTime fyStart = DateTime(startYear, 4, 1);
      DateTime fyEnd = DateTime(startYear + 1, 3, 31);

      // Check: Kya aaj ki date FY range ke andar hai?
      if (today.isAtSameMomentAs(fyStart) || 
          today.isAtSameMomentAs(fyEnd) || 
          (today.isAfter(fyStart) && today.isBefore(fyEnd))) {
        return today; // Agar range mein hai toh Aaj ki date
      } else {
        return fyStart; // Agar bahar hai (jaise purane saal ka kam kar rahe ho) toh 1st April
      }
    } catch (e) {
      return DateTime.now();
    }
  }

  static String format(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
