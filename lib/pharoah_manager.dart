// FILE: lib/pharoah_manager.dart (Corrected & Final)

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'master_data_library.dart';
import 'demo_data.dart';
import 'pharoah_smart_logic.dart';
import 'inventory_logic_center.dart';
import 'fy_transfer_engine.dart';
import 'app_date_logic.dart';
import 'gateway/company_registry_model.dart';
import 'logic/pharoah_numbering_engine.dart';

class PharoahManager with ChangeNotifier {
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<SaleChallan> saleChallans = [];
  List<PurchaseChallan> purchaseChallans = [];
  List<SaleReturn> saleReturns = [];
  List<PurchaseReturn> purchaseReturns = [];
  
  List<Bank> banks = []; 
  List<Salesman> salesmen = [];
  List<ChequeEntry> cheques = []; 

  List<RouteArea> routes = [];
  List<Company> companies = [];
  List<Salt> salts = [];
  List<DrugType> drugTypes = [];
  List<LogEntry> logs = [];
  List<Voucher> vouchers = [];
  Map<String, List<BatchInfo>> batchHistory = {};

  List<CompanyProfile> companiesRegistry = [];
  CompanyProfile? activeCompany;
  String currentFY = "";
  bool isAdminAuthenticated = false;

  PharoahManager() { initRegistry(); }

  // --- REGISTRY & SESSION ---
  Future<void> initRegistry() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File('${root.path}/pharoah_registry.json');
    if (await file.exists()) {
      List<dynamic> list = jsonDecode(await file.readAsString());
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
    activeCompany = comp; currentFY = fy; await loadAllData(); 
  }

  void authenticateAdmin(bool status) { isAdminAuthenticated = status; notifyListeners(); }
  void clearSession() {
    activeCompany = null; currentFY = ""; isAdminAuthenticated = false;
    medicines.clear(); parties.clear(); sales.clear(); purchases.clear();
    saleChallans.clear(); purchaseChallans.clear(); saleReturns.clear(); purchaseReturns.clear();
    banks.clear(); salesmen.clear(); cheques.clear();
    vouchers.clear(); batchHistory.clear(); notifyListeners();
  }

  Future<String> getWorkingPath() async {
    if (activeCompany == null || currentFY.isEmpty) return "";
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/Pharoah_Data/${activeCompany!.id}/${activeCompany!.businessType}/$currentFY');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  // --- DATA STORAGE ---
  Future<void> save() async {
    final dir = await getWorkingPath();
    if (dir.isEmpty) return;
    await File('$dir/meds.json').writeAsString(jsonEncode(medicines.map((e) => e.toMap()).toList()));
    await File('$dir/parts.json').writeAsString(jsonEncode(parties.map((e) => e.toMap()).toList()));
    await File('$dir/sales.json').writeAsString(jsonEncode(sales.map((e) => e.toMap()).toList()));
    await File('$dir/purc.json').writeAsString(jsonEncode(purchases.map((e) => e.toMap()).toList()));
    await File('$dir/sale_challans.json').writeAsString(jsonEncode(saleChallans.map((e) => e.toMap()).toList()));
    await File('$dir/pur_challans.json').writeAsString(jsonEncode(purchaseChallans.map((e) => e.toMap()).toList()));
    await File('$dir/sale_returns.json').writeAsString(jsonEncode(saleReturns.map((e) => e.toMap()).toList()));
    await File('$dir/pur_returns.json').writeAsString(jsonEncode(purchaseReturns.map((e) => e.toMap()).toList()));
    await File('$dir/banks.json').writeAsString(jsonEncode(banks.map((e) => e.toMap()).toList()));
    await File('$dir/salesmen.json').writeAsString(jsonEncode(salesmen.map((e) => e.toMap()).toList()));
    await File('$dir/cheques.json').writeAsString(jsonEncode(cheques.map((e) => e.toMap()).toList()));
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
    medicines = (loadJson('meds.json') as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? DemoData.getMedicines();
    parties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    banks = (loadJson('banks.json') as List?)?.map((e) => Bank.fromMap(e)).toList() ?? [];
    salesmen = (loadJson('salesmen.json') as List?)?.map((e) => Salesman.fromMap(e)).toList() ?? [];
    cheques = (loadJson('cheques.json') as List?)?.map((e) => ChequeEntry.fromMap(e)).toList() ?? [];
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    saleChallans = (loadJson('sale_challans.json') as List?)?.map((e) => SaleChallan.fromMap(e)).toList() ?? [];
    purchaseChallans = (loadJson('pur_challans.json') as List?)?.map((e) => PurchaseChallan.fromMap(e)).toList() ?? [];
    saleReturns = (loadJson('sale_returns.json') as List?)?.map((e) => SaleReturn.fromMap(e)).toList() ?? [];
    purchaseReturns = (loadJson('pur_returns.json') as List?)?.map((e) => PurchaseReturn.fromMap(e)).toList() ?? [];
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
    batchHistory.forEach((medId, list) { for (var b in list) { b.qty = b.openingQty + b.adjustmentQty; b.breakageQty = 0; } });
    for (var pur in purchases) { for (var item in pur.items) { String key = _getMedIdentityKey(item.medicineID, item.name); _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.purchaseRate); var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch); b.qty += (item.qty + item.freeQty); b.isShell = false; } }
    for (var pch in purchaseChallans.where((c) => c.status == "Pending")) { for (var item in pch.items) { String key = _getMedIdentityKey(item.medicineID, item.name); _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.purchaseRate); var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch); b.qty += (item.qty + item.freeQty); } }
    for (var sale in sales.where((s) => s.status == "Active")) { for (var item in sale.items) { String key = _getMedIdentityKey(item.medicineID, item.name); _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.rate); var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch); b.qty -= (item.qty + item.freeQty); } }
    for (var ch in saleChallans.where((c) => c.status == "Pending")) { for (var item in ch.items) { String key = _getMedIdentityKey(item.medicineID, item.name); _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.rate); var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch); b.qty -= (item.qty + item.freeQty); } }
    for (var ret in saleReturns.where((r) => r.status == "Active")) { for (var item in ret.items) { String key = _getMedIdentityKey(item.medicineID, item.name); _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.rate); var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch); if (ret.returnType == "Sellable") b.qty += (item.qty + item.freeQty); else b.breakageQty += (item.qty + item.freeQty); } }
    for (var pret in purchaseReturns.where((r) => r.status == "Active")) { for (var item in pret.items) { String key = _getMedIdentityKey(item.medicineID, item.name); _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.purchaseRate); var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch); if (pret.returnType == "Sellable") b.qty -= (item.qty + item.freeQty); else b.breakageQty -= (item.qty + item.freeQty); } }
    for (var med in medicines) { double total = 0; if (batchHistory.containsKey(med.identityKey)) { for (var b in batchHistory[med.identityKey]!) { total += b.qty; } } med.stock = total; }
  }

  String _getMedIdentityKey(String id, String name) { try { return medicines.firstWhere((m) => m.id == id || m.name == name).identityKey; } catch (e) { return id; } }
  void _ensureBatchExists(String medKey, String batchNo, String exp, String pack, double mrp, double rate) { if (!batchHistory.containsKey(medKey)) batchHistory[medKey] = []; if (!batchHistory[medKey]!.any((b) => b.batch == batchNo)) { batchHistory[medKey]!.add(BatchInfo(batch: batchNo, exp: exp, packing: pack, mrp: mrp, rate: rate, isShell: true)); } }

  // --- NAYA SMART LOGIC: AUTO SALESMAN TAGGING ---
  String _getAutoSalesman(Party party) {
    if (salesmen.isEmpty) return "DIRECT";
    try {
      final matchedSman = salesmen.firstWhere((s) => s.route == party.route);
      return matchedSman.name;
    } catch (e) { return "DIRECT"; }
  }

  // --- ACTIONS (WITH SALESMAN TAGGING) ---
  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) { 
    String sName = _getAutoSalesman(party);
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode, salesmanName: sName)); 
    PharoahNumberingEngine.updateCounter(type: "SALE_BILL", usedNumber: billNo, companyID: activeCompany!.id); save().then((_) => loadAllData()); 
  }

  void finalizeSaleChallan({required String challanNo, required DateTime date, required Party party, required List<BillItem> items, required double total}) { 
    String sName = _getAutoSalesman(party);
    saleChallans.add(SaleChallan(id: DateTime.now().toString(), billNo: challanNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, status: "Pending", salesmanName: sName)); 
    PharoahNumberingEngine.updateCounter(type: "SALE_CHALLAN", usedNumber: challanNo, companyID: activeCompany!.id); save().then((_) => loadAllData()); 
  }

  // --- BAKI ACTIONS ---
  void addBank(Bank b) { banks.add(b); save(); }
  void deleteBank(String id) { banks.removeWhere((x) => x.id == id); save(); }
  void addSalesman(Salesman s) { salesmen.add(s); save(); }
  void deleteSalesman(String id) { salesmen.removeWhere((x) => x.id == id); save(); }
  void addCheque(ChequeEntry c) { cheques.add(c); save(); }
  void updateChequeStatus(String id, String newStatus, String remark) { int i = cheques.indexWhere((x) => x.id == id); if(i != -1) { cheques[i].status = newStatus; cheques[i].remark = remark; save(); } }
  void finalizeSaleReturn({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String type}) { saleReturns.add(SaleReturn(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, returnType: type)); PharoahNumberingEngine.updateCounter(type: "SALE_RETURN", usedNumber: billNo, companyID: activeCompany!.id); save().then((_) => loadAllData()); }
  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) { purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode)); PharoahNumberingEngine.updateCounter(type: "PUR_BILL", usedNumber: internalNo, companyID: activeCompany!.id); save().then((_) => loadAllData()); }
  void finalizePurchaseChallan({required String challanNo, required String internalNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total}) { purchaseChallans.add(PurchaseChallan(id: DateTime.now().toString(), internalNo: internalNo, billNo: challanNo, date: date, distributorName: party.name, items: items, totalAmount: total, status: "Pending")); PharoahNumberingEngine.updateCounter(type: "PUR_CHALLAN", usedNumber: internalNo, companyID: activeCompany!.id); save().then((_) => loadAllData()); }
  void finalizePurchaseReturn({required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String type = "Sellable"}) { purchaseReturns.add(PurchaseReturn(id: DateTime.now().toString(), billNo: billNo, distributorName: party.name, date: date, items: items, totalAmount: total, status: "Active", returnType: type)); PharoahNumberingEngine.updateCounter(type: "PUR_RETURN", usedNumber: billNo, companyID: activeCompany!.id); save().then((_) => loadAllData()); }

  // --- MODIFICATION & UTILS ---
  void deleteBill(String id) { sales.removeWhere((s) => s.id == id); save().then((_) => loadAllData()); }
  void cancelBill(String id) { int i = sales.indexWhere((s) => s.id == id); if(i != -1) { sales[i].status = "Cancelled"; save().then((_) => loadAllData()); } }
  void deleteSaleChallan(String id) { saleChallans.removeWhere((c) => c.id == id); save().then((_) => loadAllData()); }
  void deletePurchaseChallan(String id) { purchaseChallans.removeWhere((c) => c.id == id); save().then((_) => loadAllData()); }
  void deleteSaleReturn(String id) { saleReturns.removeWhere((r) => r.id == id); save().then((_) => loadAllData()); }
  void deletePurchaseReturn(String id) { purchaseReturns.removeWhere((r) => r.id == id); save().then((_) => loadAllData()); }
  void deleteVoucher(String id) { vouchers.removeWhere((v) => v.id == id); save().then((_) => loadAllData()); }
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void addLog(String action, String details) { logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); save(); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  Future<void> runAutoBackup() async { await save(); }
  Future<void> masterReset() async { final dir = await getWorkingPath(); final d = Directory(dir); if(d.existsSync()) d.deleteSync(recursive: true); await loadAllData(); }
}
