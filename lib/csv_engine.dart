// FILE: lib/csv_engine.dart

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class CsvEngine {
  /* 
     ===========================================================================
     PHAROAH P2P SYNC V2 - 27 COLUMNS STRUCTURE
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
    // --- NAYE P2P MASTER COLUMNS ---
    "PARTY_DL", "PARTY_PAN", "PARTY_CITY", "PARTY_MOBILE", "PARTY_EMAIL", "PARTY_ADDRESS",
    "ITEM_SALT", "ITEM_FLAGS", "SENDER_STATE"
  ];

  // ===========================================================================
  // 1. EXPORT SALES (DISTRIBUTOR SIDE)
  // ===========================================================================
  static String convertSalesToCsv(List<Sale> sales, List<Medicine> allMeds, String senderState) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var s in sales) {
      for (var i in s.items) {
        // Item Details fetch karna Master se (Salt & Flags ke liye)
        Medicine? med;
        try { 
          med = allMeds.firstWhere((m) => m.id == i.medicineID || m.name == i.name); 
        } catch(e) { med = null; }

        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date), 
          s.billNo, 
          s.partyName, 
          s.partyGstin, 
          s.partyState,
          i.name, 
          med?.companyId ?? "N/A", // Real Manufacturer
          i.packing, 
          i.batch, 
          i.exp, 
          i.hsn,
          i.qty, 
          i.freeQty, 
          i.mrp.toStringAsFixed(2), 
          i.rate.toStringAsFixed(2),
          "0.0", // Discount placeholder
          "${i.gstRate}%", 
          i.total.toStringAsFixed(2),
          // --- P2P PARTY SNAPSHOT DATA ---
          s.partyDl.isEmpty ? "N/A" : s.partyDl,
          s.partyPan.isEmpty ? "N/A" : s.partyPan,
          s.partyCity.isEmpty ? "N/A" : s.partyCity,
          s.partyPhone.isEmpty ? "N/A" : s.partyPhone,
          s.partyEmail.isEmpty ? "N/A" : s.partyEmail,
          s.partyAddress.isEmpty ? "N/A" : s.partyAddress,
          // --- P2P ITEM DATA ---
          med?.saltId ?? "N/A",
          "${med?.isNarcotic == true ? 'NRX' : ''}|${med?.isScheduleH1 == true ? 'H1' : ''}",
          senderState
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ===========================================================================
  // 2. EXPORT PURCHASES (RETAILER SIDE)
  // ===========================================================================
  static String convertPurchasesToCsv(List<Purchase> purchases, List<Medicine> allMeds, String senderState) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var p in purchases) {
      for (var i in p.items) {
        Medicine? med;
        try { 
          med = allMeds.firstWhere((m) => m.id == i.medicineID || m.name == i.name); 
        } catch(e) { med = null; }

        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date), 
          p.billNo, 
          p.distributorName, 
          "N/A", // Supplier GSTIN Placeholder
          "N/A", // Supplier State Placeholder
          i.name, 
          "N/A", 
          i.packing, 
          i.batch, 
          i.exp, 
          i.hsn,
          i.qty, 
          i.freeQty, 
          i.mrp.toStringAsFixed(2), 
          i.purchaseRate.toStringAsFixed(2),
          "0.0", 
          "${i.gstRate}%", 
          i.total.toStringAsFixed(2),
          // --- P2P DATA (Purchase record doesn't have party snapshot yet) ---
          "N/A", "N/A", "N/A", "N/A", "N/A", "N/A",
          med?.saltId ?? "N/A",
          "N/A",
          senderState
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ===========================================================================
  // 3. GENERIC PARSER
  // ===========================================================================
  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter(
      shouldParseNumbers: true, 
      allowInvalid: true
    ).convert(content);
  }
}
