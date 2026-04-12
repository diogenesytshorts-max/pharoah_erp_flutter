import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class CsvEngine {
  // --- 1. ENHANCED SALES EXPORT (With full Party & Item Master) ---
  static String convertSalesToCsv(List<Sale> sales) {
    List<List<dynamic>> rows = [
      [
        "DATE", "INVOICE_NO", "PAYMENT_MODE", 
        "PARTY_NAME", "PARTY_ADDRESS", "PARTY_CITY", "PARTY_STATE", "PARTY_GSTIN", "PARTY_DL", "PARTY_PHONE", "PARTY_EMAIL",
        "ITEM_NAME", "ITEM_PACKING", "ITEM_BATCH", "ITEM_EXP", "ITEM_HSN", "QTY", "RATE", "GST_RATE", "TOTAL"
      ]
    ];

    for (var s in sales) {
      for (var i in s.items) {
        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date),
          s.billNo,
          s.paymentMode,
          // Party Details (Packed in every row for seamless import)
          s.partyName,
          s.partyAddress,
          "N/A", // City logic can be extended if stored in Sale
          s.partyState,
          s.partyGstin,
          s.partyDl,
          "N/A", // Phone logic
          s.partyEmail,
          // Item Details
          i.name,
          i.packing,
          i.batch,
          i.exp,
          i.hsn,
          i.qty,
          i.rate,
          i.gstRate,
          i.total
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // --- 2. ENHANCED PURCHASE EXPORT (With full Supplier & Item Master) ---
  static String convertPurchasesToCsv(List<Purchase> purchases) {
    List<List<dynamic>> rows = [
      [
        "DATE", "BILL_NO", "INTERNAL_NO", "PAYMENT_MODE",
        "SUPPLIER_NAME", "SUPPLIER_GSTIN", "SUPPLIER_CITY", "SUPPLIER_ADDR",
        "ITEM_NAME", "ITEM_PACKING", "ITEM_BATCH", "ITEM_EXP", "ITEM_HSN", "QTY", "FREE", "RATE", "GST_RATE", "TOTAL"
      ]
    ];

    for (var p in purchases) {
      for (var i in p.items) {
        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date),
          p.billNo,
          p.internalNo,
          p.paymentMode,
          // Supplier Details
          p.distributorName,
          p.gstStatus, // Temporary using gstStatus, can be mapped to master
          "N/A", 
          "N/A",
          // Item Details
          i.name,
          i.packing,
          i.batch,
          i.exp,
          i.hsn,
          i.qty,
          i.freeQty,
          i.purchaseRate,
          i.gstRate,
          i.total
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // --- 3. CSV PARSER ---
  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter().convert(content);
  }
}
