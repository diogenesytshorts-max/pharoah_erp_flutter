// FILE: lib/csv_engine.dart

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class CsvEngine {
  /* 
     ===========================================================================
     PHAROAH P2P ENGINE V2 - 27 COLUMNS SMART STRUCTURE
     ===========================================================================
     0: DATE          | 1: BILL_NO        | 2: PARTY_NAME     | 3: PARTY_GSTIN
     4: PARTY_STATE   | 5: ITEM_NAME      | 6: MANUFACTURER   | 7: PACKING
     8: BATCH         | 9: EXPIRY         | 10: HSN           | 11: QTY
     12: FREE_QTY     | 13: MRP           | 14: UNIT_RATE     | 15: DISCOUNT_PER
     16: GST_PERCENT  | 17: NET_TOTAL     | 18: PARTY_DL      | 19: PARTY_PAN
     20: PARTY_CITY   | 21: PARTY_MOBILE  | 22: PARTY_EMAIL   | 23: PARTY_ADDRESS
     24: ITEM_SALT    | 25: ITEM_FLAGS    | 26: SENDER_STATE
  */

  static List<String> get _universalHeader => [
    "DATE", "BILL_NO", "PARTY_NAME", "PARTY_GSTIN", "PARTY_STATE",
    "ITEM_NAME", "MANUFACTURER", "PACKING", "BATCH", "EXPIRY",
    "HSN", "QTY", "FREE_QTY", "MRP", "UNIT_RATE",
    "DISCOUNT_PER", "GST_PERCENT", "NET_TOTAL",
    // --- P2P SMART DATA COLUMNS ---
    "PARTY_DL", "PARTY_PAN", "PARTY_CITY", "PARTY_MOBILE", "PARTY_EMAIL", "PARTY_ADDRESS",
    "ITEM_SALT", "ITEM_FLAGS", "SENDER_STATE"
  ];

  // ===========================================================================
  // 1. EXPORT SALES (DISTRIBUTOR SIDE) - Case Sensitive Batch Fix
  // ===========================================================================
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
          Medicine med = allMeds.firstWhere((m) => m.id == i.medicineID || m.name == i.name);
          if (med.companyId.isNotEmpty) {
            mfgName = allComps.firstWhere((c) => c.id == med.companyId).name;
          }
          if (med.saltId.isNotEmpty) {
            saltName = allSalts.firstWhere((sl) => sl.id == med.saltId).name;
          }
          flags = "${med.isNarcotic ? 'NRX' : ''}|${med.isScheduleH1 ? 'H1' : ''}";
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
          i.batch.trim(), // FIXED: Removed .toUpperCase() to preserve "baA" cases
          i.exp.trim(), 
          i.hsn.trim(),
          i.qty, // Kept as double for 5.05 precision
          i.freeQty, 
          i.mrp.toStringAsFixed(2), 
          i.rate.toStringAsFixed(2),
          "0.0", 
          "${i.gstRate.toInt()}%", 
          i.total.toStringAsFixed(2),
          // --- PARTY SNAPSHOTS ---
          s.partyDl.trim().toUpperCase(),
          s.partyPan.trim().toUpperCase(),
          s.partyCity.trim().toUpperCase(),
          s.partyPhone.trim(),
          s.partyEmail.trim().toLowerCase(),
          s.partyAddress.trim().toUpperCase(),
          // --- MASTER DATA ---
          saltName.trim().toUpperCase(),
          flags,
          senderState.trim()
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ===========================================================================
  // 2. EXPORT PURCHASES (RETAILER SIDE) - Case Sensitive Batch Fix
  // ===========================================================================
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
          i.batch.trim(), // FIXED: Removed .toUpperCase()
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
          senderState.trim()
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter(
      shouldParseNumbers: true, 
      allowInvalid: true
    ).convert(content);
  }
}
