import 'package:flutter/material.dart';
import 'app_date_logic.dart';

class PharoahDateController {
  
  /// Global function jo har jagah Date Picker ko lock karega
  static Future<DateTime?> pickDate({
    required BuildContext context,
    required String currentFY,
    required DateTime initialDate,
  }) async {
    
    // Boundary nikalna central file se
    DateTime first = AppDateLogic.getFYStart(currentFY);
    DateTime last = AppDateLogic.getFYEnd(currentFY);

    // Date Picker show karna
    return await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: first,
      lastDate: last,
      // Design settings bhi yahan se control ho sakti hain
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.indigo.shade900, // Header color
              onPrimary: Colors.white, // Header text
              onSurface: Colors.black, // Body text
            ),
          ),
          child: child!,
        );
      },
    );
  }

  /// Naya bill khulte waqt sahi date decide karne ke liye
  static DateTime getInitialBillDate(String fy) {
    return AppDateLogic.getSmartDate(fy);
  }
}
