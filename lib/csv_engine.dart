import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class CsvEngine {
  static String convertSalesToCsv(List<Sale> sales) {
    List<List<dynamic>> rows = [
      ["DATE", "INVOICE_NO", "PARTY_NAME", "GSTIN", "STATE", "ITEM_NAME", "BATCH", "EXP", "HSN", "QTY", "RATE", "GST_RATE", "TOTAL"]
    ];
    for (var s in sales) {
      for (var i in s.items) {
        rows.add([DateFormat('dd/MM/yyyy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.partyState, i.name, i.batch, i.exp, i.hsn, i.qty, i.rate, i.gstRate, i.total]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static String convertPurchasesToCsv(List<Purchase> purchases) {
    List<List<dynamic>> rows = [
      ["DATE", "BILL_NO", "INTERNAL_NO", "SUPPLIER", "ITEM", "BATCH", "EXP", "QTY", "FREE", "RATE", "GST", "TOTAL"]
    ];
    for (var p in purchases) {
      for (var i in p.items) {
        rows.add([DateFormat('dd/MM/yyyy').format(p.date), p.billNo, p.internalNo, p.distributorName, i.name, i.batch, i.exp, i.qty, i.freeQty, i.purchaseRate, i.gstRate, i.total]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static List<List<dynamic>> parseCsv(String content) => const CsvToListConverter().convert(content);
}
