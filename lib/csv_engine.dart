// FILE: lib/csv_engine.dart

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'gateway/company_registry_model.dart';

class CsvEngine {
  // ===========================================================================
  // 1. THE UNIVERSAL 36-COLUMN HEADER (SALE & PURCHASE COMPATIBLE)
  // ===========================================================================
  static List<String> get _universalHeader => [
    "DATE", "BILL_NO", 
    "SENDER_NAME", "SENDER_GST", "SENDER_DL", "SENDER_PAN", "SENDER_MOBILE", "SENDER_EMAIL", "SENDER_ADDRESS", "SENDER_CITY", "SENDER_STATE",
    "PARTY_NAME", "PARTY_GST", "PARTY_DL", "PARTY_PAN", "PARTY_MOBILE", "PARTY_EMAIL", "PARTY_ADDRESS",
    "ITEM_NAME", "ITEM_PACKING", "ITEM_HSN", "ITEM_MFG", "ITEM_SALT", "ITEM_FORM", "IS_NARCOTIC", "IS_H1",
    "ITEM_BATCH", "ITEM_EXP", "QTY", "FREE", "MRP", "PUR_RATE", "SALE_RATE", "GST_PER",
    "BILL_DISC", "BILL_ROUNDOFF"
  ];

  // ===========================================================================
  // 2. EXPORT FROM SALE (USER A SENDS TO USER B)
  // ===========================================================================
  static String convertSalesToCsv({
    required List<Sale> sales,
    required CompanyProfile shop,
    required List<Medicine> allMeds,
    required List<Company> allComps,
    required List<Salt> allSalts,
  }) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var s in sales) {
      for (var i in s.items) {
        // Fetch Pharma Details from Master for this item
        Medicine med = allMeds.firstWhere((m) => m.id == i.medicineID, orElse: () => Medicine(id: '', name: i.name, packing: i.packing));
        String mfg = allComps.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'N/A')).name;
        String salt = allSalts.firstWhere((sl) => sl.id == med.saltId, orElse: () => Salt(id: '', name: 'N/A')).name;

        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date), s.billNo,
          // Sender (Shop) Details
          shop.name, shop.gstin, shop.dlNo, "N/A", shop.phone, shop.email, shop.address, "N/A", shop.state,
          // Receiver (Party) Details from Snapshot
          s.partyName, s.partyGstin, s.partyDl, s.partyPan, s.partyPhone, s.partyEmail, s.partyAddress,
          // Item Master Info
          i.name, i.packing, i.hsn, mfg, salt, med.drugForm, med.isNarcotic ? "YES" : "NO", med.isScheduleH1 ? "YES" : "NO",
          // Transaction & Pricing
          i.batch, i.exp, i.qty, i.freeQty, i.mrp, med.purRate, i.rate, i.gstRate,
          s.extraDiscount, s.roundOff
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ===========================================================================
  // 3. EXPORT FROM PURCHASE (USER B BACKUP OR FORWARD)
  // ===========================================================================
  static String convertPurchasesToCsv({
    required List<Purchase> purchases,
    required CompanyProfile shop,
    required List<Medicine> allMeds,
    required List<Company> allComps,
    required List<Salt> allSalts,
    required List<Party> allParties, // NAYA: Master list pass karna zaroori hai
  }) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var p in purchases) {
      // NAYA: "N/A" khatam karne ke liye Master se Distributor ki details fetch karna
      Party distributor = allParties.firstWhere((pt) => pt.id == p.partyId || pt.name == p.distributorName, 
          orElse: () => Party(id: '', name: p.distributorName));

      for (var i in p.items) {
        Medicine med = allMeds.firstWhere((m) => m.id == i.medicineID, orElse: () => Medicine(id: '', name: i.name, packing: i.packing));
        String mfg = allComps.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'N/A')).name;
        String salt = allSalts.firstWhere((sl) => sl.id == med.saltId, orElse: () => Salt(id: '', name: 'N/A')).name;

        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date), p.billNo,
          // Sender Details (In Purchase, Shop is the Receiver, so Sender is Distributor)
          distributor.name, distributor.gst, distributor.dl, distributor.pan, distributor.phone, distributor.email, distributor.address, distributor.city, distributor.state,
          // Receiver (Aapki Shop)
          shop.name, shop.gstin, shop.dlNo, "N/A", shop.phone, shop.email, shop.address,
          // Item Info
          i.name, i.packing, i.hsn, mfg, salt, med.drugForm, med.isNarcotic ? "YES" : "NO", med.isScheduleH1 ? "YES" : "NO",
          // Transaction
          i.batch, i.exp, i.qty, i.freeQty, i.mrp, i.purchaseRate, i.rateA, i.gstRate,
          0.0, 0.0 // Purchase level discount snapshot placeholders
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter(shouldParseNumbers: true, allowInvalid: true).convert(content);
  }
}
