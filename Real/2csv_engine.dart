// FILE: lib/csv_engine.dart

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'gateway/company_registry_model.dart';

class CsvEngine {
  // ===========================================================================
  // 1. THE UNIVERSAL 36-COLUMN HEADER (C2C MIRROR COMPATIBLE)
  // ===========================================================================
  // Col 0-1: Header | Col 2-10: EXTERNAL PARTY (Dwarika) | Col 11-17: Sender Info
  // Col 18-25: Pharma Brain | Col 26-33: Transaction | Col 34-35: Footer
  static List<String> get _universalHeader => [
    "DATE", "BILL_NO", 
    "PARTY_NAME", "PARTY_GST", "PARTY_DL", "PARTY_PAN", "PARTY_MOBILE", "PARTY_EMAIL", "PARTY_ADDRESS", "PARTY_CITY", "PARTY_STATE",
    "SENDER_NAME", "SENDER_GST", "SENDER_DL", "SENDER_PAN", "SENDER_MOBILE", "SENDER_EMAIL", "SENDER_ADDRESS",
    "ITEM_NAME", "ITEM_PACKING", "ITEM_HSN", "ITEM_MFG", "ITEM_SALT", "ITEM_FORM", "IS_NARCOTIC", "IS_H1",
    "ITEM_BATCH", "ITEM_EXP", "QTY", "FREE", "MRP", "PUR_RATE", "SALE_RATE", "GST_PER",
    "BILL_DISC", "BILL_ROUNDOFF"
  ];

  // ===========================================================================
  // 2. SALE EXPORT (C2C MIRROR MODE)
  // ===========================================================================
  static String convertSalesToCsv({
    required List<Sale> sales,
    required CompanyProfile shop,
    required List<Medicine> allMeds,
    required List<Company> allComps,
    required List<Salt> allSalts,
    required List<Party> allParties,
    bool maskPurchaseRate = false, 
  }) {
    List<List<dynamic>> rows = [_universalHeader];

    for (var s in sales) {
      // Find External Party (Dwarika) details from Master
      Party party = allParties.firstWhere((p) => p.name == s.partyName, 
          orElse: () => Party(id: '', name: s.partyName, gst: s.partyGstin, state: s.partyState, city: s.partyCity, address: s.partyAddress, phone: s.partyPhone, email: s.partyEmail, dl: s.partyDl, pan: s.partyPan));

      for (var i in s.items) {
        // Find Pharma Metadata
        Medicine med = allMeds.firstWhere((m) => m.id == i.medicineID, 
            orElse: () => Medicine(id: '', name: i.name, packing: i.packing));
        
        String mfgName = allComps.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'N/A')).name;
        String saltName = allSalts.firstWhere((sl) => sl.id == med.saltId, orElse: () => Salt(id: '', name: 'N/A')).name;

        rows.add([
          DateFormat('dd/MM/yyyy').format(s.date), s.billNo,
          // EXTERNAL PARTY (Columns 2-10) - ALWAYS DWARIKA
          party.name, party.gst, party.dl, party.pan, party.phone, party.email, party.address, party.city, party.state,
          // SENDER/SHOP INFO (Columns 11-17)
          shop.name, shop.gstin, shop.dlNo, "N/A", shop.phone, shop.email, shop.address,
          // PHARMA BRAIN (Columns 18-25)
          i.name, i.packing, i.hsn, mfgName, saltName, med.drugForm, med.isNarcotic ? "YES" : "NO", med.isScheduleH1 ? "YES" : "NO",
          // TRANSACTION DATA (Columns 26-33) - BATCH CASE PRESERVED
          i.batch, i.exp, i.qty, i.freeQty, i.mrp, 
          maskPurchaseRate ? 0.0 : med.purRate, 
          i.rate, i.gstRate,
          // FOOTER (Columns 34-35)
          s.extraDiscount, s.roundOff
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ===========================================================================
  // 3. PURCHASE EXPORT (C2C MIRROR MODE)
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
      // Find External Party (Dwarika/Supplier) from Master
      Party party = allParties.firstWhere((pt) => pt.id == p.partyId || pt.name == p.distributorName, 
          orElse: () => Party(id: '', name: p.distributorName));

      for (var i in p.items) {
        // Find Pharma Metadata
        Medicine med = allMeds.firstWhere((m) => m.id == i.medicineID, 
            orElse: () => Medicine(id: '', name: i.name, packing: i.packing));
            
        String mfgName = allComps.firstWhere((c) => c.id == med.companyId, orElse: () => Company(id: '', name: 'N/A')).name;
        String saltName = allSalts.firstWhere((sl) => sl.id == med.saltId, orElse: () => Salt(id: '', name: 'N/A')).name;

        rows.add([
          DateFormat('dd/MM/yyyy').format(p.date), p.billNo,
          // EXTERNAL PARTY (Columns 2-10) - ALWAYS DWARIKA (Supplier in this case)
          party.name, party.gst, party.dl, party.pan, party.phone, party.email, party.address, party.city, party.state,
          // SENDER/SHOP INFO (Columns 11-17) - Our Shop is Receiver here but we keep structure
          shop.name, shop.gstin, shop.dlNo, "N/A", shop.phone, shop.email, shop.address,
          // PHARMA BRAIN (Columns 18-25)
          i.name, i.packing, i.hsn, mfgName, saltName, med.drugForm, med.isNarcotic ? "YES" : "NO", med.isScheduleH1 ? "YES" : "NO",
          // TRANSACTION DATA (Columns 26-33) - BATCH CASE PRESERVED
          i.batch, i.exp, i.qty, i.freeQty, i.mrp, 
          i.purchaseRate, i.rateA, i.gstRate,
          // FOOTER (Columns 34-35)
          0.0, 0.0 // Purchase extra discount placeholders
        ]);
      }
    }
    return const ListToCsvConverter().convert(rows);
  }

  // ===========================================================================
  // 4. GENERIC PARSER
  // ===========================================================================
  static List<List<dynamic>> parseCsv(String content) {
    return const CsvToListConverter(shouldParseNumbers: true, allowInvalid: true).convert(content);
  }
}
