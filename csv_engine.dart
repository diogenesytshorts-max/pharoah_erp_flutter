import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class CsvEngine {
  /* 
     =========================================================
     PHAROAH UNIVERSAL CSV STRUCTURE (18 COLUMNS)
     Used for both Sale Export and Purchase Export/Import
     =========================================================
     0: DATE            | 1: BILL_NO       | 2: PARTY_NAME
     3: PARTY_GSTIN     | 4: PARTY_STATE    | 5: ITEM_NAME
     6: MANUFACTURER    | 7: PACKING        | 8: BATCH
     9: EXPIRY          | 10: HSN           | 11: QTY
     12: FREE_QTY       | 13: MRP           | 14: UNIT_RATE (Taxable)
     15: DISCOUNT_PER   | 16: GST_PERCENT   | 17: NET_TOTAL
  */

  static List<String> get _universalHeader => [
    "DATE", "BILL_NO", "PARTY_NAME", "PARTY_GSTIN", "PARTY_STATE",
    "ITEM_NAME", "MANUFACTURER", "PACKING", "BATCH", "EXPIRY",
    "HSN", "QTY", "FREE_QTY", "MRP", "UNIT_RATE",
    "DISCOUNT_PER", "GST_PERCENT", "NET_TOTAL"
  ];

  /// User A jab SALE export karega
  static String convertSalesToCsv(List<Sale> sales) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var s in sales) {
      for (var i in s.items) {
        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date), 
          s.billNo, 
          s.partyName, 
          s.partyGstin, 
          s.partyState,
          i.name, 
          "N/A", // Manufacturer (Not in Sale model yet, so N/A)
          i.packing, 
          i.batch, 
          i.exp, 
          i.hsn,
          i.qty, 
          i.freeQty, 
          i.mrp.toStringAsFixed(2), 
          i.rate.toStringAsFixed(2),
          "0.0", // Discount % (Placeholder)
          "${i.gstRate}%", 
          i.total.toStringAsFixed(2)
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  /// User B jab PURCHASE export karega
  static String convertPurchasesToCsv(List<Purchase> purchases) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var p in purchases) {
      for (var i in p.items) {
        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date), 
          p.billNo, 
          p.distributorName, 
          "N/A", // Supplier GSTIN (Currently not in Purchase header model)
          "N/A", // Supplier State
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
          i.total.toStringAsFixed(2)
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  /// Generic CSV Parsing
  static List<List<dynamic>> parseCsv(String content) {
    // We use a smart converter to handle commas inside quotes
    return const CsvToListConverter(
      shouldParseNumbers: true, 
      allowInvalid: true
    ).convert(content);
  }
}
