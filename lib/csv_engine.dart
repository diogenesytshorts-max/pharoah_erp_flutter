// FILE: lib/csv_engine.dart

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'gateway/company_registry_model.dart';

class CsvEngine {
  // ===========================================================================
  // 1. THE UNIVERSAL 36-COLUMN HEADER (C2C & C2V COMPATIBLE)
  // ===========================================================================
  static List<String> get _universalHeader => [
    "DATE", "BILL_NO", 
    "SENDER_NAME", "SENDER_GST", "SENDER_DL", "SENDER_PAN", "SENDER_MOBILE", "SENDER_EMAIL", "SENDER_ADDRESS", "SENDER_CITY", "SENDER_STATE",
    "RECEIVER_NAME", "RECEIVER_GST", "RECEIVER_DL", "RECEIVER_PAN", "RECEIVER_MOBILE", "RECEIVER_EMAIL", "RECEIVER_ADDRESS",
    "ITEM_NAME", "ITEM_PACKING", "ITEM_HSN", "ITEM_MFG", "ITEM_SALT", "ITEM_FORM", "IS_NARCOTIC", "IS_H1",
    "ITEM_BATCH", "ITEM_EXP", "QTY", "FREE", "MRP", "PUR_RATE", "SALE_RATE", "GST_PER",
    "BILL_DISC", "BILL_ROUNDOFF"
  ];

  // ===========================================================================
  // 2. SALE EXPORT (With Privacy Masking Option)
  // ===========================================================================
  static String convertSalesToCsv({
    required List<Sale> sales,
    required CompanyProfile shop,
    required List<Medicine> allMeds,
    required List<Company> allComps,
    required List<Salt> allSalts,
    required List<Party> allParties,
    bool maskPurchaseRate = false, // C2V ke liye true hoga
  }) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var s in sales) {
      // Find receiver party details from Master (If snapshot is incomplete)
      Party receiver = allParties.firstWhere((p) => p.name == s.partyName, 
          orElse: () => Party(id: '', name: s.partyName, gst: s.partyGstin, state: s.partyState));

      for (var i in s.items) {
        // Fetch Master info for Pharma Details (MFG, Salt, Flags)
        Medicine med = allMeds.firstWhere((m) => m.id == i.medicineID, 
            orElse: () => Medicine(id: '', name: i.name, packing: i.packing));
        
        String mfgName = allComps.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'N/A')).name;
        String saltName = allSalts.firstWhere((sl) => sl.id == med.saltId, orElse: () => Salt(id: '', name: 'N/A')).name;

        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date), s.billNo,
          // SENDER (Our Shop)
          shop.name, shop.gstin, shop.dlNo, "N/A", shop.phone, shop.email, shop.address, "N/A", shop.state,
          // RECEIVER (The Customer)
          receiver.name, receiver.gst, receiver.dl, receiver.pan, receiver.phone, receiver.email, receiver.address,
          // ITEM BRAIN
          i.name, i.packing, i.hsn, mfgName, saltName, med.drugForm, med.isNarcotic ? "YES" : "NO", med.isScheduleH1 ? "YES" : "NO",
          // TRANSACTION (As per Bill)
          i.batch, i.exp, i.qty, i.freeQty, i.mrp, 
          maskPurchaseRate ? 0.0 : med.purRate, // PRIVACY GUARD
          i.rate, i.gstRate,
          s.extraDiscount, s.roundOff
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ===========================================================================
  // 3. PURCHASE EXPORT (No More "N/A")
  // ===========================================================================
  static String convertPurchasesToCsv({
    required List<Purchase> purchases,
    required CompanyProfile shop,
    required List<Medicine> allMeds,
    required List<Company> allComps,
    required List<Salt> allSalts,
    required List<Party> allParties,
  }) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var p in purchases) {
      // Find SENDER (The Distributor) from Master using partyId or Name
      Party distributor = allParties.firstWhere((pt) => pt.id == p.partyId || pt.name == p.distributorName, 
          orElse: () => Party(id: '', name: p.distributorName));

      for (var i in p.items) {
        Medicine med = allMeds.firstWhere((m) => m.id == i.medicineID, 
            orElse: () => Medicine(id: '', name: i.name, packing: i.packing));
            
        String mfgName = allComps.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'N/A')).name;
        String saltName = allSalts.firstWhere((sl) => sl.id == med.saltId, orElse: () => Salt(id: '', name: 'N/A')).name;

        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date), p.billNo,
          // SENDER (Distributor)
          distributor.name, distributor.gst, distributor.dl, distributor.pan, distributor.phone, distributor.email, distributor.address, distributor.city, distributor.state,
          // RECEIVER (Our Shop)
          shop.name, shop.gstin, shop.dlNo, "N/A", shop.phone, shop.email, shop.address,
          // ITEM BRAIN
          i.name, i.packing, i.hsn, mfgName, saltName, med.drugForm, med.isNarcotic ? "YES" : "NO", med.isScheduleH1 ? "YES" : "NO",
          // TRANSACTION
          i.batch, i.exp, i.qty, i.freeQty, i.mrp, i.purchaseRate, i.rateA, i.gstRate,
          0.0, 0.0 // Discount placeholders
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter(shouldParseNumbers: true, allowInvalid: true).convert(content);
  }
}
