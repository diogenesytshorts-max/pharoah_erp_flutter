// FILE: lib/pharoah_manager.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'administration/system_user_model.dart';
import 'finance/bank_transaction_model.dart';
import 'demo_data.dart';
import 'inventory_logic_center.dart';
import 'fy_transfer_engine.dart';
import 'gateway/company_registry_model.dart';
import 'logic/app_settings_model.dart';
import 'logic/pharoah_numbering_engine.dart';

class PharoahManager with ChangeNotifier {
  List<Medicine> medicines = [];
  List<SystemUser> systemUsers = [];
  SystemUser? loggedInStaff;
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<SaleChallan> saleChallans = [];
  List<PurchaseChallan> purchaseChallans = [];
  List<SaleReturn> saleReturns = [];
  List<PurchaseReturn> purchaseReturns = [];
  List<Voucher> vouchers = [];
  List<LogEntry> logs = [];
  List<RouteArea> routes = [];
  List<Company> companies = [];
  List<Salt> salts = [];
  List<DrugType> drugTypes = [];
  List<Bank> banks = [];
  List<ChequeEntry> cheques = []; // Missing in error
  List<ShortageItem> shortages = []; // Missing in error
  
  List<NumberingSeries> numberingSeries = [];
  Map<String, List<BatchInfo>> batchHistory = {};
  AppConfig config = AppConfig();
  
  List<CompanyProfile> companiesRegistry = [];
  CompanyProfile? activeCompany;
  String currentFY = "";
  bool isAdminAuthenticated = false;

  PharoahManager() { initRegistry(); }

  Future<void> initRegistry() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File('${root.path}/pharoah_registry.json');
    if (await file.exists()) {
      try {
        List<dynamic> list = jsonDecode(await file.readAsString());
        companiesRegistry = list.map((e) => CompanyProfile.fromMap(e)).toList();
      } catch (e) { debugPrint("Registry Load Error: $e"); }
    }
    notifyListeners();
  }

  Future<void> saveRegistry() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File('${root.path}/pharoah_registry.json');
    await file.writeAsString(jsonEncode(companiesRegistry.map((e) => e.toMap()).toList()));
    notifyListeners();
  }

  Future<void> loginToCompany(CompanyProfile comp, String fy) async { activeCompany = comp; currentFY = fy; await loadAllData(); }
  void clearSession() { activeCompany = null; currentFY = ""; isAdminAuthenticated = false; loggedInStaff = null; notifyListeners(); }
  void authenticateAdmin(bool status) { isAdminAuthenticated = status; notifyListeners(); }

  Future<String> getWorkingPath() async {
    if (activeCompany == null || currentFY.isEmpty) return "";
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/Pharoah_Data/${activeCompany!.id}/${activeCompany!.businessType}/$currentFY');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  Future<void> setupNewCompanyEnvironment(CompanyProfile profile, String initialFY) async {
    sales = []; purchases = []; numberingSeries = []; vouchers = []; saleChallans = []; purchaseChallans = []; saleReturns = []; purchaseReturns = []; cheques = []; shortages = [];
    
    numberingSeries = [
      NumberingSeries(id: 's1', name: "Standard Sale", type: "SALE", prefix: "INV-", isDefault: true),
      NumberingSeries(id: 'p1', name: "Standard Purchase", type: "PURCHASE", prefix: "PUR-", isDefault: true),
      NumberingSeries(id: 'c1', name: "Standard Challan", type: "CHALLAN", prefix: "SCH-", isDefault: true),
      NumberingSeries(id: 'r1', name: "Standard Return", type: "RETURN", prefix: "SRN-", isDefault: true),
      NumberingSeries(id: 'v1', name: "Voucher Series", type: "VOUCHER", prefix: "VOU-", isDefault: true),
    ];

    medicines = DemoData.getMedicines();
    parties = [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    
    final root = await getApplicationDocumentsDirectory();
    final dirPath = '${root.path}/Pharoah_Data/${profile.id}/${profile.businessType}/$initialFY';
    final dir = await Directory(dirPath).create(recursive: true);

    Future _write(String name, dynamic data) async {
      await File('${dir.path}/$name').writeAsString(jsonEncode(data));
    }

    await _write('meds.json', medicines.map((e) => e.toMap()).toList());
    await _write('parts.json', parties.map((e) => e.toMap()).toList());
    await _write('series.json', numberingSeries.map((e) => e.toMap()).toList());
    await _write('sales.json', []); await _write('purc.json', []); await _write('vouc.json', []);
    await _write('s_challan.json', []); await _write('p_challan.json', []);
    await _write('s_return.json', []); await _write('p_return.json', []);
    await _write('cheques.json', []); await _write('shortage.json', []);
    await _write('bats.json', {}); await _write('sys_users.json', []);
    await _write('logs.json', [LogEntry(id: '1', action: 'SYSTEM', details: 'Setup Complete', time: DateTime.now()).toMap()]);
    
    if (!companiesRegistry.any((c) => c.id == profile.id)) {
      companiesRegistry.add(profile);
      await saveRegistry();
    }
    notifyListeners();
  }

  Future<void> save() async {
    final dir = await getWorkingPath();
    if (dir.isEmpty) return;
    
    await File('$dir/meds.json').writeAsString(jsonEncode(medicines.map((e) => e.toMap()).toList()));
    await File('$dir/parts.json').writeAsString(jsonEncode(parties.map((e) => e.toMap()).toList()));
    await File('$dir/sales.json').writeAsString(jsonEncode(sales.map((e) => e.toMap()).toList()));
    await File('$dir/purc.json').writeAsString(jsonEncode(purchases.map((e) => e.toMap()).toList()));
    await File('$dir/vouc.json').writeAsString(jsonEncode(vouchers.map((e) => e.toMap()).toList()));
    await File('$dir/sys_users.json').writeAsString(jsonEncode(systemUsers.map((e) => e.toMap()).toList()));
    await File('$dir/bats.json').writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    await File('$dir/series.json').writeAsString(jsonEncode(numberingSeries.map((e) => e.toMap()).toList()));
    await File('$dir/s_challan.json').writeAsString(jsonEncode(saleChallans.map((e) => e.toMap()).toList()));
    await File('$dir/p_challan.json').writeAsString(jsonEncode(purchaseChallans.map((e) => e.toMap()).toList()));
    await File('$dir/s_return.json').writeAsString(jsonEncode(saleReturns.map((e) => e.toMap()).toList()));
    await File('$dir/p_return.json').writeAsString(jsonEncode(purchaseReturns.map((e) => e.toMap()).toList()));
    await File('$dir/cheques.json').writeAsString(jsonEncode(cheques.map((e) => e.toMap()).toList()));
    await File('$dir/shortage.json').writeAsString(jsonEncode(shortages.map((e) => e.toMap()).toList()));
    
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
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    saleChallans = (loadJson('s_challan.json') as List?)?.map((e) => SaleChallan.fromMap(e)).toList() ?? [];
    purchaseChallans = (loadJson('p_challan.json') as List?)?.map((e) => PurchaseChallan.fromMap(e)).toList() ?? [];
    saleReturns = (loadJson('s_return.json') as List?)?.map((e) => SaleReturn.fromMap(e)).toList() ?? [];
    purchaseReturns = (loadJson('p_return.json') as List?)?.map((e) => PurchaseReturn.fromMap(e)).toList() ?? [];
    cheques = (loadJson('cheques.json') as List?)?.map((e) => ChequeEntry.fromMap(e)).toList() ?? [];
    shortages = (loadJson('shortage.json') as List?)?.map((e) => ShortageItem.fromMap(e)).toList() ?? [];
    
    var sData = loadJson('series.json');
    if (sData != null) numberingSeries = (sData as List).map((e) => NumberingSeries.fromMap(e)).toList();

    var users = loadJson('sys_users.json');
    if (users != null) systemUsers = (users as List).map((e) => SystemUser.fromMap(e)).toList();

    var bats = loadJson('bats.json');
    if (bats != null) { 
      batchHistory.clear();
      (bats as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList()); 
    }

    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners();
  }

  // --- SERIES HELPERS ---
  List<NumberingSeries> getSeriesByType(String type) => numberingSeries.where((s) => s.type == type).toList();
  NumberingSeries getDefaultSeries(String type) => numberingSeries.firstWhere((s) => s.type == type && s.isDefault, orElse: () => numberingSeries.firstWhere((s) => s.type == type, orElse: () => NumberingSeries(id: 'tmp', name: 'Default', type: type, prefix: 'TXN-', isDefault: true)));
  void addNumberingSeries(NumberingSeries ns) { if (ns.isDefault) { for (var s in numberingSeries.where((x) => x.type == ns.type)) s.isDefault = false; } numberingSeries.add(ns); save(); }
  void updateNumberingSeries(NumberingSeries ns) { int idx = numberingSeries.indexWhere((s) => s.id == ns.id); if (idx != -1) { numberingSeries[idx] = ns; save(); } }

  // --- ACTIONS ---
  void addLog(String action, String details) { logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); save(); }
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addCheque(ChequeEntry c) { cheques.add(c); save(); }
  void addSystemUser(SystemUser u) { systemUsers.add(u); save(); }
  void updateSystemUser(SystemUser u) { int i = systemUsers.indexWhere((x) => x.id == u.id); if(i != -1) { systemUsers[i] = u; save(); } }
  void deleteSystemUser(String id) { systemUsers.removeWhere((x) => x.id == id); save(); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  
  // --- TRANSACTIONS ---
  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode, bool isEdit = false}) async {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode));
    for (var s in numberingSeries.where((x) => x.type == "SALE")) {
      if (billNo.startsWith(s.prefix)) await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: billNo, prefix: s.prefix);
    }
    save().then((_) => loadAllData());
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) async {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    await PharoahNumberingEngine.updateSeriesCounter(type: "PURCHASE", companyID: activeCompany!.id, usedNumber: internalNo, prefix: "PUR-");
    save().then((_) => loadAllData());
  }

  void finalizeSaleChallan({required String challanNo, required DateTime date, required Party party, required List<BillItem> items, required double total}) async {
    saleChallans.add(SaleChallan(id: DateTime.now().toString(), billNo: challanNo, date: date, partyName: party.name, partyGstin: party.gst, items: items, totalAmount: total));
    await PharoahNumberingEngine.updateSeriesCounter(type: "CHALLAN", companyID: activeCompany!.id, usedNumber: challanNo, prefix: getDefaultSeries("CHALLAN").prefix);
    save();
  }

  void finalizePurchaseChallan({required String challanNo, required String internalNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total}) async {
    purchaseChallans.add(PurchaseChallan(id: DateTime.now().toString(), internalNo: internalNo, billNo: challanNo, date: date, distributorName: party.name, items: items, totalAmount: total));
    await PharoahNumberingEngine.updateSeriesCounter(type: "CHALLAN", companyID: activeCompany!.id, usedNumber: internalNo, prefix: "PCH-");
    save();
  }

  void finalizeSaleReturn({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, String type = "Sellable"}) async {
    saleReturns.add(SaleReturn(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, returnType: type));
    await PharoahNumberingEngine.updateSeriesCounter(type: "RETURN", companyID: activeCompany!.id, usedNumber: billNo, prefix: getDefaultSeries("RETURN").prefix);
    save();
  }

  void finalizePurchaseReturn({required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String type = "Breakage"}) {
    purchaseReturns.add(PurchaseReturn(id: DateTime.now().toString(), billNo: billNo, distributorName: party.name, date: date, items: items, totalAmount: total, status: "Active", returnType: type));
    save();
  }

  // --- DELETE METHODS ---
  void deleteBill(String id) { sales.removeWhere((s) => s.id == id); save().then((_) => loadAllData()); }
  void deletePurchase(String id) { purchases.removeWhere((p) => p.id == id); save().then((_) => loadAllData()); }
  void deleteSaleChallan(String id) { saleChallans.removeWhere((c) => c.id == id); save(); }
  void deletePurchaseChallan(String id) { purchaseChallans.removeWhere((c) => c.id == id); save(); }
  void deleteSaleReturn(String id) { saleReturns.removeWhere((r) => r.id == id); save(); }
  void deletePurchaseReturn(String id) { purchaseReturns.removeWhere((r) => r.id == id); save(); }

  // --- BANK & MISC ---
  List<BankTransaction> getBankStatement(String bankName, DateTime from, DateTime to) {
    List<BankTransaction> statement = [];
    for (var v in vouchers.where((x) => x.paymentMode == bankName)) {
      statement.add(BankTransaction(id: v.id, date: v.date, particulars: v.partyName, reference: "VOUCHER", amountIn: v.type == "Receipt" ? v.amount : 0, amountOut: v.type == "Payment" ? v.amount : 0, type: "VOUCHER"));
    }
    return statement;
  }

  void adjustBatchStock({required String medId, required String batchNo, required double adjQty, required String reason}) {
    if (batchHistory.containsKey(medId)) {
      var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo);
      b.adjustmentQty += adjQty; save().then((_) => loadAllData());
    }
  }

  void updateBatchMetadata({required String medId, required String batchNo, required String newExp, required double newMrp, required double newRate}) {
    if (batchHistory.containsKey(medId)) {
      var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo);
      b.exp = newExp; b.mrp = newMrp; b.rate = newRate; save().then((_) => loadAllData());
    }
  }

  Future<bool> startNewFinancialYear(String nextFY) async {
    await save(); 
    bool success = await FYTransferEngine.transferData(companyID: activeCompany!.id, businessType: activeCompany!.businessType, sourceFY: currentFY, targetFY: nextFY);
    if (success) { currentFY = nextFY; await loadAllData(); }
    return success;
  }

  Future<void> runAutoBackup() async { await save(); }

  Future<void> masterReset() async { 
    final dir = await getWorkingPath(); 
    if(dir.isNotEmpty) { final d = Directory(dir); if(d.existsSync()) d.deleteSync(recursive: true); }
    await loadAllData(); 
  }

  Future<void> switchYear(String year) async { 
    currentFY = year; 
    await loadAllData(); 
    notifyListeners(); 
  }

  double calculateAvgMonthlySale(String medId) {
    // Basic logic: Last 3 months sale / 3
    return 10.0; // Placeholder
  }
}
