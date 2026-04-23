import 'package:intl/intl.dart';

class AppDateLogic {
  
  /// NAYA: Aaj ki date ke hisaab se automatic FY string nikalna
  static String getCurrentFYString() {
    DateTime now = DateTime.now();
    if (now.month >= 4) {
      return "${now.year}-${(now.year + 1).toString().substring(2)}";
    } else {
      return "${now.year - 1}-${now.year.toString().substring(2)}";
    }
  }

  /// NAYA: Picker boundary ke liye Start Date helper
  static DateTime getFYStart(String fy) {
    try {
      int startYear = int.parse(fy.split('-')[0]);
      if (startYear < 2000) startYear += 2000;
      return DateTime(startYear, 4, 1);
    } catch (e) { return DateTime(DateTime.now().year, 4, 1); }
  }

  /// NAYA: Picker boundary ke liye End Date helper
  static DateTime getFYEnd(String fy) {
    try {
      int startYear = int.parse(fy.split('-')[0]);
      if (startYear < 2000) startYear += 2000;
      return DateTime(startYear + 1, 3, 31, 23, 59, 59);
    } catch (e) { return DateTime(DateTime.now().year + 1, 3, 31); }
  }

  /// AAPKA PURANA LOGIC (Improved): Default date decide karne ke liye
  static DateTime getSmartDate(String currentFY) {
    try {
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      
      DateTime fyStart = getFYStart(currentFY);
      DateTime fyEnd = getFYEnd(currentFY);

      if (today.isAfter(fyStart.subtract(const Duration(days: 1))) && 
          today.isBefore(fyEnd.add(const Duration(days: 1)))) {
        return today; 
      } else if (today.isAfter(fyEnd)) {
        return DateTime(fyEnd.year, 3, 31);
      } else {
        return fyStart;
      }
    } catch (e) { return DateTime.now(); }
  }

  static String format(DateTime date) => DateFormat('dd/MM/yyyy').format(date);

  static bool isValidInFY(DateTime pickedDate, String currentFY) {
    DateTime fyStart = getFYStart(currentFY);
    DateTime fyEnd = getFYEnd(currentFY);
    return pickedDate.isAfter(fyStart.subtract(const Duration(days: 1))) && 
           pickedDate.isBefore(fyEnd.add(const Duration(days: 1)));
  }
}
