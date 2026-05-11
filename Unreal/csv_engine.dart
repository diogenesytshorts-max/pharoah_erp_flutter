// FILE: lib/csv_engine.dart

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class CsvEngine {
  static List<String> get _universalHeader => [
    "DATE", "BILL_NO", "PARTY_NAME", "PARTY_GSTIN", "PARTY_STATE",
    "ITEM_NAME", "MANUFACTURER", "PACKING", "BATCH", "EXPIRY",
    "HSN", "QTY", "FREE_QTY", "MRP", "UNIT_RATE",
    "DISCOUNT_PER", "GST_PERCENT", "NET_TOTAL",
    "PARTY_DL", "PARTY_PAN", "PARTY_CITY", "PARTY_MOBILE", "PARTY_EMAIL", "PARTY_ADDRESS",
    "ITEM_SALT", "ITEM_FLAGS", "SENDER_STATE",
    "BILL_DISC", "BILL_ROUNDOFF"
  ];

  static String convertSalesToCsv({
    required List<Sale> sales, 
    required List<Medicine> allMeds, 
    required List<Company> allComps, 
    required List<Salt> allSalts, 
    required String senderState
  }) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var s in sales) {
      for (var i in s.items) {
        String mfgName = "N/A";
        String saltName = "N/A";
        String flags = "NORMAL";

        try {
          // Robust Matching Logic
          Medicine med = allMeds.firstWhere(
            (m) => m.id == i.medicineID || m.name.trim().toUpperCase() == i.name.trim().toUpperCase(),
            orElse: () => Medicine(id: '', name: '', packing: '')
          );

          if (med.id.isNotEmpty) {
            if (med.companyId.isNotEmpty) {
              mfgName = allComps.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'N/A')).name;
            }
            if (med.saltId.isNotEmpty) {
              saltName = allSalts.firstWhere((sl) => sl.id == med.saltId, orElse: () => Salt(id: '', name: 'N/A')).name;
            }
            flags = "${med.isNarcotic ? 'NRX' : ''}|${med.isScheduleH1 ? 'H1' : ''}";
          }
        } catch (e) {}

        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date), 
          s.billNo.trim().toUpperCase(), 
          s.partyName.trim().toUpperCase(), 
          s.partyGstin.trim().toUpperCase(), 
          s.partyState.trim(),
          i.name.trim().toUpperCase(), 
          mfgName.trim().toUpperCase(), 
          i.packing.trim().toUpperCase(), 
          i.batch.trim(), // Case Preserved
          i.exp.trim(), 
          i.hsn.trim(),
          i.qty, 
          i.freeQty, 
          i.mrp.toStringAsFixed(2), 
          i.rate.toStringAsFixed(2),
          "0.0", 
          "${i.gstRate.toInt()}%", 
          i.total.toStringAsFixed(2),
          s.partyDl.trim().toUpperCase(),
          s.partyPan.trim().toUpperCase(),
          s.partyCity.trim().toUpperCase(),
          s.partyPhone.trim(),
          s.partyEmail.trim().toLowerCase(),
          s.partyAddress.trim().toUpperCase(),
          saltName.trim().toUpperCase(),
          flags,
          senderState.trim(),
          s.extraDiscount.toStringAsFixed(2), 
          s.roundOff.toStringAsFixed(2)
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static String convertPurchasesToCsv({
    required List<Purchase> purchases, 
    required List<Medicine> allMeds, 
    required List<Company> allComps, 
    required List<Salt> allSalts, 
    required String senderState
  }) {
    List<List<dynamic>> rows = [_universalHeader];
    for (var p in purchases) {
      for (var i in p.items) {
        String mfgName = "N/A";
        String saltName = "N/A";
        try {
          Medicine med = allMeds.firstWhere((m) => m.id == i.medicineID || m.name == i.name);
          if (med.companyId.isNotEmpty) mfgName = allComps.firstWhere((c) => c.id == med.companyId).name;
          if (med.saltId.isNotEmpty) saltName = allSalts.firstWhere((sl) => sl.id == med.saltId).name;
        } catch (e) {}
        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date), 
          p.billNo.trim().toUpperCase(), 
          p.distributorName.trim().toUpperCase(), 
          "N/A", "N/A", 
          i.name.trim().toUpperCase(), 
          mfgName.trim().toUpperCase(), 
          i.packing.trim().toUpperCase(), 
          i.batch.trim(), 
          i.exp.trim(), 
          i.hsn.trim(),
          i.qty, 
          i.freeQty, 
          i.mrp.toStringAsFixed(2), 
          i.purchaseRate.toStringAsFixed(2),
          "0.0", 
          "${i.gstRate.toInt()}%", 
          i.total.toStringAsFixed(2),
          "N/A", "N/A", "N/A", "N/A", "N/A", "N/A",
          saltName.trim().toUpperCase(),
          "NORMAL",
          senderState.trim(),
          "0.00", "0.00"
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter(shouldParseNumbers: true, allowInvalid: true).convert(content);
  }
}
