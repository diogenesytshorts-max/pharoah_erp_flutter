import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class CsvEngine {
  // ==========================================
  // 1. SALES EXPORT LOGIC
  // ==========================================
  static String convertSalesToCsv(List<Sale> sales) {
    List<List<dynamic>> rows = [];

    // Header Row (Standard Columns)
    rows.add([
      "DATE", 
      "INVOICE_NO", 
      "PARTY_NAME", 
      "GSTIN", 
      "STATE", 
      "ITEM_NAME", 
      "BATCH", 
      "EXP", 
      "HSN", 
      "QTY", 
      "RATE", 
      "GST_RATE", 
      "NET_AMOUNT"
    ]);

    for (var sale in sales) {
      for (var item in sale.items) {
        rows.add([
          DateFormat('dd/MM/yyyy').format(sale.date),
          sale.billNo,
          sale.partyName,
          sale.partyGstin,
          sale.partyState,
          item.name,
          item.batch,
          item.exp,
          item.hsn,
          item.qty,
          item.rate,
          item.gstRate,
          item.total,
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ==========================================
  // 2. PURCHASE EXPORT LOGIC
  // ==========================================
  static String convertPurchasesToCsv(List<Purchase> purchases) {
    List<List<dynamic>> rows = [];

    // Header Row
    rows.add([
      "DATE", 
      "BILL_NO", 
      "INTERNAL_NO", 
      "SUPPLIER_NAME", 
      "ITEM_NAME", 
      "BATCH", 
      "EXP", 
      "QTY", 
      "FREE_QTY", 
      "PUR_RATE", 
      "GST_RATE", 
      "NET_AMOUNT"
    ]);

    for (var pur in purchases) {
      for (var item in pur.items) {
        rows.add([
          DateFormat('dd/MM/yyyy').format(pur.date),
          pur.billNo,
          pur.internalNo,
          pur.distributorName,
          item.name,
          item.batch,
          item.exp,
          item.qty,
          item.freeQty,
          item.purchaseRate,
          item.gstRate,
          item.total,
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ==========================================
  // 3. CSV PARSER (Read file content)
  // ==========================================
  static List<List<dynamic>> parseCsv(String csvContent) {
    // Isse humein rows ki list mil jayegi verification screen ke liye
    return const CsvToListConverter().convert(csvContent);
  }
}
