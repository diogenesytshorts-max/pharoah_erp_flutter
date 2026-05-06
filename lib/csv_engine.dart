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
    "PARTY_DL", "PARTY_PAN", "PARTY_CITY", "ITEM_SALT", "ITEM_FLAGS", "SENDER_STATE"
  ];

  static String convertSalesToCsv(List<Sale> sales, List<Medicine> allMeds, String senderState) {
    List<List<dynamic>> rows = [_universalHeader];
    for (var s in sales) {
      for (var i in s.items) {
        Medicine? med;
        try { med = allMeds.firstWhere((m) => m.id == i.medicineID); } catch(e) { med = null; }
        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date), s.billNo, s.partyName, s.partyGstin, s.partyState,
          i.name, med?.companyId ?? "N/A", i.packing, i.batch, i.exp, i.hsn, i.qty, i.freeQty,
          i.mrp.toStringAsFixed(2), i.rate.toStringAsFixed(2), "0.0", "${i.gstRate}%", i.total.toStringAsFixed(2),
          "N/A", "N/A", "N/A", med?.saltId ?? "N/A",
          "${med?.isNarcotic == true ? 'NRX' : ''}|${med?.isScheduleH1 == true ? 'H1' : ''}", senderState
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static String convertPurchasesToCsv(List<Purchase> purchases, List<Medicine> allMeds, String senderState) {
    List<List<dynamic>> rows = [_universalHeader];
    for (var p in purchases) {
      for (var i in p.items) {
        Medicine? med;
        try { med = allMeds.firstWhere((m) => m.id == i.medicineID); } catch(e) { med = null; }
        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date), p.billNo, p.distributorName, "N/A", "N/A",
          i.name, "N/A", i.packing, i.batch, i.exp, i.hsn, i.qty, i.freeQty,
          i.mrp.toStringAsFixed(2), i.purchaseRate.toStringAsFixed(2), "0.0", "${i.gstRate}%", i.total.toStringAsFixed(2),
          "N/A", "N/A", "N/A", med?.saltId ?? "N/A", "N/A", senderState
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter(shouldParseNumbers: true, allowInvalid: true).convert(content);
  }
}
