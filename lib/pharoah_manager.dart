import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'master_data_library.dart';
import 'demo_data.dart';

class PharoahManager with ChangeNotifier {
  // --- DATA LISTS ---
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<RouteArea> routes = [];
  List<Company> companies = [];
  List<Salt> salts = [];
  List<DrugType> drugTypes = [];
  List<LogEntry> logs = [];
  List<Voucher> vouchers = [];
  Map<String, List<BatchInfo>> batchHistory = {};
  
  String currentFY = "2025-26";
  String companyState = "Rajasthan";

  PharoahManager() {
    initManager();
  }

  // --- INITIALIZATION ---
  Future<void> initManager() async {
    final prefs = await SharedPreferences.getInstance();
    currentFY = prefs.getString('fy') ?? "2025-26";
    companyState = prefs.getString('compState') ?? "Rajasthan";
    await loadAllData();
  }

  // --- FOLDER & PATH LOGIC ---
  Future<String> getFYDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/DATA_FY_$currentFY');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  // --- SAVE ALL DATA ---
  Future<void> save() async {
    final dir = await getFYDirectory();
    
    await File('$dir/meds.json').writeAsString(jsonEncode(medicines.map((e) => e.toMap()).toList()));
    await File('$dir/parts.json').writeAsString(jsonEncode(parties.map((e) => e.toMap()).toList()));
    await File('$dir/sales.json').writeAsString(jsonEncode(sales.map((e) => e.toMap()).toList()));
    await File('$dir/purc.json').writeAsString(jsonEncode(purchases.map((e) => e.toMap()).toList()));
    await File('$dir/routs.json').writeAsString(jsonEncode(routes.map((e) => e.toMap()).toList()));
    await File('$dir/comps.json').writeAsString(jsonEncode(companies.map((e) => e.toMap()).toList()));
    await File('$dir/salts.json').writeAsString(jsonEncode(salts.map((e) => e.toMap()).toList()));
    await File('$dir/dtypes.json').writeAsString(jsonEncode(drugTypes.map((e) => e.toMap()).toList()));
    await File('$dir/logs.json').writeAsString(jsonEncode(logs.map((e) => e.toMap()).toList()));
    await File('$dir/vouc.json').writeAsString(jsonEncode(vouchers.map((e) => e.toMap()).toList()));
    await File('$dir/bats.json').writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    
    notifyListeners();
  }

  // --- LOAD ALL DATA (With Demo & Library Logic) ---
  Future<void> loadAllData() async {
    final dir = await getFYDirectory();
    dynamic loadJson(String name) {
      final f = File('$dir/$name');
      return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
    }

    // 1. Medicines (Load Demo if Empty)
    var mD = loadJson('meds.json');
    medicines = mD != null ? (mD as List).map((e) => Medicine.fromMap(e)).toList() : DemoData.getMedicines();
    
    // 2. Parties (Load Demo if Empty)
    var pD = loadJson('parts.json');
    parties = pD != null ? (pD as List).map((e) => Party.fromMap(e)).toList() : [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];

    // 3. Transactions & Vouchers
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    logs = (loadJson('logs.json') as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [];

    // 4. Masters Loading with Defaults from Library
    var cD = loadJson('comps.json');
    companies = cD != null ? (cD as List).map((e) => Company.fromMap(e)).toList() : MasterDataLibrary.topCompanies.map((n) => Company(id: n, name: n)).toList();

    var sD = loadJson('salts.json');
    salts = sD != null ? (sD as List).map((e) => Salt.fromMap(e)).toList() : MasterDataLibrary.topSalts.map((s) => Salt(id: s['name']!, name: s['name']!, type: s['type']!)).toList();

    var dD = loadJson('dtypes.json');
    drugTypes = dD != null ? (dD as List).map((e) => DrugType.fromMap(e)).toList() : MasterDataLibrary.drugTypes.map((n) => DrugType(id: n, name: n)).toList();

    routes = (loadJson('routs.json') as List?)?.map((e) => RouteArea.fromMap(e)).toList() ?? [RouteArea(id: '1', name: "LOCAL AREA")];

    // 5. Batch History
    var bD = loadJson('bats.json');
    if (bD != null) {
      batchHistory.clear();
      (bD as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
    }
    
    notifyListeners();
  }

  // --- BUSINESS LOGIC: SALES (Stock (-) & History) ---
  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode));
    
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= (it.qty + it.freeQty);
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.rate));
      }
    }
    addLog("SALE", "Bill #$billNo for ${party.name}");
    save();
  }

  void cancelBill(String id) {
    int i = sales.indexWhere((s) => s.id == id);
    if (i != -1 && sales[i].status != "Cancelled") {
      for (var it in sales[i].items) {
        int mi = medicines.indexWhere((m) => m.id == it.medicineID);
        if (mi != -1) medicines[mi].stock += (it.qty + it.freeQty);
      }
      sales[i].status = "Cancelled";
      addLog("CANCEL", "Sale Bill #${sales[i].billNo} Cancelled");
      save();
    }
  }

  void deleteBill(String id) {
    int i = sales.indexWhere((s) => s.id == id);
    if (i != -1) {
      if (sales[i].status == "Active") {
        for (var it in sales[i].items) {
          int mi = medicines.indexWhere((m) => m.id == it.medicineID);
          if (mi != -1) medicines[mi].stock += (it.qty + it.freeQty);
        }
      }
      sales.removeAt(i);
      save();
    }
  }

  // --- BUSINESS LOGIC: PURCHASE (Stock (+) & Price Update) ---
  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock += (it.qty + it.freeQty);
        medicines[idx].purRate = it.purchaseRate;
        medicines[idx].mrp = it.mrp;
        medicines[idx].gst = it.gstRate;
        // Rates update based on purchase entry
        if(it.rateA > 0) medicines[idx].rateA = it.rateA;
        if(it.rateB > 0) medicines[idx].rateB = it.rateB;
        if(it.rateC > 0) medicines[idx].rateC = it.rateC;
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.purchaseRate));
      }
    }
    addLog("PURCHASE", "Purchase Bill #$billNo from ${party.name}");
    save();
  }

  void deletePurchase(String id) {
    int i = purchases.indexWhere((p) => p.id == id);
    if (i != -1) {
      for (var it in purchases[i].items) {
        int mi = medicines.indexWhere((m) => m.id == it.medicineID);
        if (mi != -1) medicines[mi].stock -= (it.qty + it.freeQty);
      }
      purchases.removeAt(i);
      save();
    }
  }

  // --- MAINTENANCE & REPAIR ---
  Future<void> runFullMaintenance() async {
    for (var med in medicines) {
      double st = 0.0;
      for (var p in purchases) {
        for (var it in p.items) if (it.medicineID == med.id) st += (it.qty + it.freeQty);
      }
      for (var s in sales) {
        if (s.status == "Active") {
          for (var it in s.items) if (it.medicineID == med.id) st -= (it.qty + it.freeQty);
        }
      }
      med.stock = st;
    }
    addLog("SYSTEM", "Maintenance & Stock Repair Complete");
    await save();
  }

  // --- SYSTEM TOOLS ---
  void addLog(String action, String details) {
    logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now()));
    save();
  }

  Future<void> masterReset() async {
    final dir = await getFYDirectory();
    final d = Directory(dir);
    if (d.existsSync()) d.deleteSync(recursive: true);
    await loadAllData();
  }

  Future<void> switchYear(String year) async {
    currentFY = year;
    await loadAllData();
    notifyListeners();
  }

  // --- MASTER UPDATES ---
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void saveBatchCentrally(String medId, BatchInfo b) {
    if(!batchHistory.containsKey(medId)) batchHistory[medId] = [];
    batchHistory[medId]!.add(b);
    save();
  }

  // --- GETTERS ---
  DateTime get fyStartDate {
    try { return DateTime(int.parse(currentFY.split('-')[0]), 4, 1); }
    catch(e) { return DateTime(DateTime.now().year, 4, 1); }
  }
  DateTime get fyEndDate {
    try { return DateTime(int.parse(currentFY.split('-')[0]) + 1, 3, 31); }
    catch(e) { return DateTime(DateTime.now().year + 1, 3, 31); }
  }
}
