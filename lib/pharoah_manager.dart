import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'master_data_library.dart'; // Naya Library Import

class PharoahManager with ChangeNotifier {
  // --- MASTER DATA LISTS ---
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

  // --- DIRECTORY LOGIC ---
  Future<String> getFYDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/DATA_FY_$currentFY');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  // --- SAVE LOGIC ---
  Future<void> save() async {
    final dir = await getFYDirectory();
    
    // Sabhi lists ko JSON mein save karna
    Map<String, List> dataMap = {
      'meds.json': medicines.map((e) => e.toMap()).toList(),
      'parts.json': parties.map((e) => e.toMap()).toList(),
      'sales.json': sales.map((e) => e.toMap()).toList(),
      'purc.json': purchases.map((e) => e.toMap()).toList(),
      'routs.json': routes.map((e) => e.toMap()).toList(),
      'comps.json': companies.map((e) => e.toMap()).toList(),
      'salts.json': salts.map((e) => e.toMap()).toList(),
      'dtypes.json': drugTypes.map((e) => e.toMap()).toList(),
      'logs.json': logs.map((e) => e.toMap()).toList(),
      'vouc.json': vouchers.map((e) => e.toMap()).toList(),
    };

    for (var entry in dataMap.entries) {
      await File('$dir/${entry.key}').writeAsString(jsonEncode(entry.value));
    }

    // Batch history alag se
    await File('$dir/bats.json').writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    
    notifyListeners();
  }

  // --- LOAD LOGIC (With Default Library Loading) ---
  Future<void> loadAllData() async {
    final dir = await getFYDirectory();
    dynamic loadJson(String name) {
      final f = File('$dir/$name');
      return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
    }

    // 1. Load Standard Lists
    medicines = (loadJson('meds.json') as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? [];
    parties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    logs = (loadJson('logs.json') as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [];

    // 2. Load or Initialize Masters (Companies, Salts, DrugTypes, Routes)
    
    // Companies Initialization
    var cD = loadJson('comps.json');
    if (cD != null) {
      companies = (cD as List).map((e) => Company.fromMap(e)).toList();
    } else {
      companies = MasterDataLibrary.topCompanies.map((name) => Company(id: DateTime.now().millisecondsSinceEpoch.toString() + name, name: name)).toList();
    }

    // Salts Initialization
    var sD = loadJson('salts.json');
    if (sD != null) {
      salts = (sD as List).map((e) => Salt.fromMap(e)).toList();
    } else {
      salts = MasterDataLibrary.topSalts.map((s) => Salt(id: DateTime.now().millisecondsSinceEpoch.toString() + s['name']!, name: s['name']!, type: s['type']!)).toList();
    }

    // DrugTypes Initialization
    var dT = loadJson('dtypes.json');
    if (dT != null) {
      drugTypes = (dT as List).map((e) => DrugType.fromMap(e)).toList();
    } else {
      drugTypes = MasterDataLibrary.drugTypes.map((name) => DrugType(id: DateTime.now().millisecondsSinceEpoch.toString() + name, name: name)).toList();
    }

    // Routes Initialization
    var rD = loadJson('routs.json');
    routes = (rD as List?)?.map((e) => RouteArea.fromMap(e)).toList() ?? [RouteArea(id: '1', name: "Local City")];

    // 3. Load Batch History
    var bD = loadJson('bats.json');
    if (bD != null) {
      batchHistory.clear();
      (bD as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
    }
    
    notifyListeners();
  }

  // --- MASTER CRUD OPERATIONS ---

  void addCompany(Company c) { companies.add(c); save(); }
  void deleteCompany(String id) { companies.removeWhere((e) => e.id == id); save(); }

  void addSalt(Salt s) { salts.add(s); save(); }
  void deleteSalt(String id) { salts.removeWhere((e) => e.id == id); save(); }

  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void deleteDrugType(String id) { drugTypes.removeWhere((e) => e.id == id); save(); }

  void addRoute(RouteArea r) { routes.add(r); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }

  void deleteParty(String id) {
    if (parties.firstWhere((p) => p.id == id).name != "CASH") {
      parties.removeWhere((p) => p.id == id);
      save();
    }
  }

  // --- CORE BUSINESS LOGIC (Stock & Rates) ---

  void saveBatchCentrally(String medId, BatchInfo newBatch) {
    if (!batchHistory.containsKey(medId)) batchHistory[medId] = [];
    int idx = batchHistory[medId]!.indexWhere((b) => b.batch.toUpperCase() == newBatch.batch.toUpperCase());
    if (idx != -1) {
      batchHistory[medId]![idx] = newBatch;
    } else {
      batchHistory[medId]!.add(newBatch);
    }
    save();
  }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(
      id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, 
      partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, 
      paymentMode: mode, invoiceType: party.isB2B ? "B2B" : "B2C"
    ));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= (it.qty + it.freeQty);
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.rate));
      }
    }
    save();
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(
      id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, 
      date: date, distributorName: party.name, items: items, totalAmount: total, paymentMode: mode
    ));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock += (it.qty + it.freeQty);
        // Rates update from purchase
        medicines[idx].purRate = it.purchaseRate;
        medicines[idx].mrp = it.mrp;
        medicines[idx].gst = it.gstRate;
        if(it.rateA > 0) medicines[idx].rateA = it.rateA;
        if(it.rateB > 0) medicines[idx].rateB = it.rateB;
        if(it.rateC > 0) medicines[idx].rateC = it.rateC;
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.purchaseRate));
      }
    }
    save();
  }

  // --- SYSTEM TOOLS ---
  Future<void> masterReset() async {
    final dir = await getFYDirectory();
    final directory = Directory(dir);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    await loadAllData();
  }

  void addLog(String action, String details) {
    logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now()));
  }
}
