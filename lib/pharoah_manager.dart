// FILE: lib/pharoah_manager.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'master_data_library.dart';
import 'demo_data.dart';
import 'pharoah_smart_logic.dart'; // NAYA: Logic Master Import
import 'inventory_logic_center.dart';
import 'fy_transfer_engine.dart';
import 'app_date_logic.dart';
import 'gateway/company_registry_model.dart';

class PharoahManager with ChangeNotifier {
  // --- CORE DATA LISTS ---
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

  // --- MULTI-COMPANY REGISTRY & SESSION ---
  List<CompanyProfile> companiesRegistry = [];
  CompanyProfile? activeCompany;
  String currentFY = "";
  bool isAdminAuthenticated = false;

  PharoahManager() {
    initRegistry();
  }

  // ===========================================================================
  // 1. REGISTRY & SESSION CONTROL
  // ===========================================================================

  Future<void> initRegistry() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File('${root.path}/pharoah_registry.json');
    if (await file.exists()) {
      String content = await file.readAsString();
      List<dynamic> list = jsonDecode(content);
      companiesRegistry = list.map((e) => CompanyProfile.fromMap(e)).toList();
    }
    notifyListeners();
  }

  Future<void> saveRegistry() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File('${root.path}/pharoah_registry.json');
    await file.writeAsString(jsonEncode(companiesRegistry.map((e) => e.toMap()).toList()));
    notifyListeners();
  }

  Future<void> loginToCompany(CompanyProfile comp, String fy) async {
    activeCompany = comp;
    currentFY = fy;
    await loadAllData(); 
  }

  void authenticateAdmin(bool status) {
    isAdminAuthenticated = status;
    notifyListeners();
  }

  void clearSession() {
    activeCompany = null;
    currentFY = "";
    isAdminAuthenticated = false;
    medicines.clear();
    parties.clear();
    sales.clear();
    purchases.clear();
    vouchers.clear();
    batchHistory.clear();
    notifyListeners();
  }

  // ===========================================================================
  // 2. DATA PERSISTENCE & INVENTORY
  // ===========================================================================

  Future<String> getWorkingPath() async {
    if (activeCompany == null || currentFY.isEmpty) return "";
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/Pharoah_Data/${activeCompany!.id}/${activeCompany!.businessType}/$currentFY');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> save() async {
    final dir = await getWorkingPath();
    if (dir.isEmpty) return;
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

  Future<void> loadAllData() async {
    final dir = await getWorkingPath();
    if (dir.isEmpty) return;
    dynamic loadJson(String name) {
      final f = File('$dir/$name');
      return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
    }
    if (File('$dir/meds.json').existsSync()) {
      medicines = (loadJson('meds.json') as List).map((e) => Medicine.fromMap(e)).toList();
    } else {
      medicines = DemoData.getMedicines(); 
    }
    parties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? 
              [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    logs = (loadJson('logs.json') as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [];
    companies = (loadJson('comps.json') as List?)?.map((e) => Company.fromMap(e)).toList() ?? MasterDataLibrary.topCompanies.map((n) => Company(id: n, name: n)).toList();
    salts = (loadJson('salts.json') as List?)?.map((e) => Salt.fromMap(e)).toList() ?? MasterDataLibrary.topSalts.map((s) => Salt(id: s['name']!, name: s['name']!, type: s['type']!)).toList();
    drugTypes = (loadJson('dtypes.json') as List?)?.map((e) => DrugType.fromMap(e)).toList() ?? MasterDataLibrary.drugTypes.map((n) => DrugType(id: n, name: n)).toList();
    routes = (loadJson('routs.json') as List?)?.map((e) => RouteArea.fromMap(e)).toList() ?? [RouteArea(id: '1', name: "LOCAL AREA")];
    var bD = loadJson('bats.json');
    if (bD != null) {
      batchHistory.clear();
      (bD as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
    }
    _rebuildInventoryRegistry();
    notifyListeners();
  }

  void _rebuildInventoryRegistry() {
    batchHistory.forEach((medId, list) { for (var b in list) { b.qty = b.openingQty + b.adjustmentQty; } });
    for (var pur in purchases) {
      for (var item in pur.items) {
        String key = _getMedIdentityKey(item.medicineID, item.name);
        _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.purchaseRate);
        var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch);
        b.qty += (item.qty + item.freeQty); b.isShell = false;
      }
    }
    for (var sale in sales.where((s) => s.status == "Active")) {
      for (var item in sale.items) {
        String key = _getMedIdentityKey(item.medicineID, item.name);
        _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.rate);
        var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch);
        b.qty -= (item.qty + item.freeQty);
      }
    }
    for (var med in medicines) {
      double total = 0;
      if (batchHistory.containsKey(med.identityKey)) {
        for (var b in batchHistory[med.identityKey]!) { total += b.qty; }
      }
      med.stock = total;
    }
  }

  String _getMedIdentityKey(String id, String name) {
    try { return medicines.firstWhere((m) => m.id == id || m.name == name).identityKey; } catch (e) { return id; }
  }

  void _ensureBatchExists(String medKey, String batchNo, String exp, String pack, double mrp, double rate) {
    if (!batchHistory.containsKey(medKey)) batchHistory[medKey] = [];
    bool exists = batchHistory[medKey]!.any((b) => b.batch == batchNo);
    if (!exists) {
      batchHistory[medKey]!.add(BatchInfo(batch: batchNo, exp: exp, packing: pack, mrp: mrp, rate: rate, isShell: true));
    }
  }

  // ===========================================================================
  // 3. TRANSACTIONS (Using Smart Logic Master)
  // ===========================================================================

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    // 1. Register Sale
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode));
    
    // 2. NAYA: Update Smart Counter in Logic Master
    if (activeCompany != null) {
      PharoahSmartLogic.updateCountersAfterSave(type: "SALE", usedID: billNo, companyID: activeCompany!.id);
    }

    save().then((_) => loadAllData()); 
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    // 1. Register Purchase
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    
    // 2. NAYA: Update Smart Counter in Logic Master
    if (activeCompany != null) {
      PharoahSmartLogic.updateCountersAfterSave(type: "PURCHASE", usedID: internalNo, companyID: activeCompany!.id);
    }

    save().then((_) => loadAllData()); 
  }

  // ===========================================================================
  // 4. OTHERS
  // ===========================================================================

  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void addLog(String action, String details) { logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); save(); }
  void deleteBill(String id) { sales.removeWhere((s) => s.id == id); loadAllData().then((_) => save()); }
  void cancelBill(String id) { int i = sales.indexWhere((s) => s.id == id); if(i != -1) { sales[i].status = "Cancelled"; loadAllData().then((_) => save()); } }
  void deletePurchase(String id) { purchases.removeWhere((p) => p.id == id); loadAllData().then((_) => save()); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  
  Future<void> runAutoBackup() async { await save(); }
  Future<void> masterReset() async { final dir = await getWorkingPath(); final d = Directory(dir); if(d.existsSync()) d.deleteSync(recursive: true); await loadAllData(); }
}
