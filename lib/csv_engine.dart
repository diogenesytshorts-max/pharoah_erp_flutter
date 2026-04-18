import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class CsvEngine {
  // --- 1. PROFESSIONAL SALES CSV ---
  static String convertSalesToCsv(List<Sale> sales) {
    List<List<dynamic>> rows = [
      [
        "DATE", "INVOICE_NO", "TYPE", "PAYMENT_MODE", 
        "PARTY_NAME", "PARTY_GSTIN", "PARTY_STATE", "PARTY_ADDRESS",
        "ITEM_NAME", "PACKING", "BATCH", "EXPIRY", "HSN", 
        "QTY", "RATE", "TAXABLE_VAL", "GST_RATE", "GST_AMT", "NET_TOTAL"
      ]
    ];

    for (var s in sales) {
      for (var i in s.items) {
        double taxable = i.rate * i.qty;
        double gstAmt = i.total - taxable;

        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date),
          s.billNo,
          s.invoiceType,
          s.paymentMode,
          s.partyName,
          s.partyGstin,
          s.partyState,
          s.partyAddress,
          i.name,
          i.packing,
          i.batch,
          i.exp,
          i.hsn,
          i.qty,
          i.rate.toStringAsFixed(2),
          taxable.toStringAsFixed(2),
          "${i.gstRate}%",
          gstAmt.toStringAsFixed(2),
          i.total.toStringAsFixed(2)
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // --- 2. PROFESSIONAL PURCHASE CSV ---
  static String convertPurchasesToCsv(List<Purchase> purchases) {
    List<List<dynamic>> rows = [
      [
        "DATE", "BILL_NO", "INTERNAL_ID", "PAYMENT_MODE", "STATUS",
        "SUPPLIER_NAME", "SUPPLIER_GSTIN",
        "ITEM_NAME", "PACKING", "BATCH", "EXPIRY", "HSN", 
        "QTY", "FREE", "PUR_RATE", "TAXABLE_VAL", "GST_RATE", "GST_AMT", "NET_TOTAL"
      ]
    ];

    for (var p in purchases) {
      for (var i in p.items) {
        double taxable = i.purchaseRate * i.qty;
        double gstAmt = i.total - taxable;

        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date),
          p.billNo,
          p.internalNo,
          p.paymentMode,
          p.gstStatus,
          p.distributorName,
          "N/A", 
          i.name,
          i.packing,
          i.batch,
          i.exp,
          i.hsn,
          i.qty,
          i.freeQty,
          i.purchaseRate.toStringAsFixed(2),
          taxable.toStringAsFixed(2),
          "${i.gstRate}%",
          gstAmt.toStringAsFixed(2),
          i.total.toStringAsFixed(2)
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter().convert(content);
  }
}
