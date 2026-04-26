// lib/pharoah_manager.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'administration/system_user_model.dart';
import 'finance/bank_transaction_model.dart';
import 'master_data_library.dart';
import 'demo_data.dart';
import 'pharoah_smart_logic.dart';
import 'inventory_logic_center.dart';
import 'fy_transfer_engine.dart';
import 'app_date_logic.dart';
import 'gateway/company_registry_model.dart';
import 'logic/pharoah_numbering_engine.dart';
import 'logic/app_settings_model.dart';

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
  List<ShortageItem> shortages = []; 
  List<Bank> banks = []; 
  List<Salesman> salesmen = [];
  List<ChequeEntry> cheques = []; 
  AppConfig config = AppConfig();

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

  Future<void> loginToCompany(CompanyProfile comp, String fy) async { activeCompany = comp; currentFY = fy; await loadAllData(); }
  void authenticateAdmin(bool status) { isAdminAuthenticated = status; notifyListeners(); }
  void clearSession() { activeCompany = null; currentFY = ""; isAdminAuthenticated = false; loggedInStaff = null; notifyListeners(); }

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
    await File('$dir/challans.json').writeAsString(jsonEncode(saleChallans.map((e) => e.toMap()).toList()));
    await File('$dir/config.json').writeAsString(jsonEncode(config.toMap()));
    await File('$dir/sys_users.json').writeAsString(jsonEncode(systemUsers.map((e) => e.toMap()).toList()));
    await File('$dir/bats.json').writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    notifyListeners();
  }

  Future<void> loadAllData() async {
    final dir = await getWorkingPath();
    if (dir.isEmpty) return;
    dynamic loadJson(String name) { final f = File('$dir/$name'); return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null; }
    
    medicines = (loadJson('meds.json') as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? DemoData.getMedicines();
    parties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    var cnf = loadJson('config.json'); if(cnf!=null) config = AppConfig.fromMap(cnf);
    var users = loadJson('sys_users.json'); if(users!=null) systemUsers = (users as List).map((e)=>SystemUser.fromMap(e)).toList();
    _rebuildInventoryRegistry();
    notifyListeners();
  }

  void _rebuildInventoryRegistry() {
    batchHistory.forEach((medId, list) { for (var b in list) { b.qty = b.openingQty + b.adjustmentQty; b.breakageQty = 0; } });
    for (var pur in purchases) { for (var item in pur.items) { String key = _getMedIdentityKey(item.medicineID, item.name); _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.purchaseRate); var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch); b.qty += (item.qty + item.freeQty); b.isShell = false; } }
    for (var sale in sales.where((s) => s.status == "Active")) { for (var item in sale.items) { String key = _getMedIdentityKey(item.medicineID, item.name); _ensureBatchExists(key, item.batch, item.exp, item.packing, item.mrp, item.rate); var b = batchHistory[key]!.firstWhere((x) => x.batch == item.batch); b.qty -= (item.qty + item.freeQty); } }
    for (var med in medicines) { double total = 0; if (batchHistory.containsKey(med.identityKey)) { for (var b in batchHistory[med.identityKey]!) { total += b.qty; } } med.stock = total; }
  }

  String _getMedIdentityKey(String id, String name) { try { return medicines.firstWhere((m) => m.id == id || m.name == name).identityKey; } catch (e) { return id; } }
  void _ensureBatchExists(String medKey, String batchNo, String exp, String pack, double mrp, double rate) { if (!batchHistory.containsKey(medKey)) batchHistory[medKey] = []; if (!batchHistory[medKey]!.any((b) => b.batch == batchNo)) { batchHistory[medKey]!.add(BatchInfo(batch: batchNo, exp: exp, packing: pack, mrp: mrp, rate: rate, isShell: true)); } }

  void deletePurchase(String id) { purchases.removeWhere((p) => p.id == id); save().then((_) => loadAllData()); }
  void deleteBill(String id) { sales.removeWhere((s) => s.id == id); save().then((_) => loadAllData()); }
  void deleteSaleChallan(String id) { saleChallans.removeWhere((c) => c.id == id); save().then((_) => loadAllData()); }
  void deletePurchaseChallan(String id) { purchaseChallans.removeWhere((c) => c.id == id); save().then((_) => loadAllData()); }
  void deleteSaleReturn(String id) { saleReturns.removeWhere((r) => r.id == id); save().then((_) => loadAllData()); }
  void deletePurchaseReturn(String id) { purchaseReturns.removeWhere((r) => r.id == id); save().then((_) => loadAllData()); }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    save().then((_) => loadAllData());
  }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode, bool isEdit = false}) {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode));
    save().then((_) => loadAllData());
  }

  void finalizeSaleChallan({required String challanNo, required DateTime date, required Party party, required List<BillItem> items, required double total}) {
    saleChallans.add(SaleChallan(id: DateTime.now().toString(), billNo: challanNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, status: "Pending"));
    save().then((_) => loadAllData());
  }

  void finalizePurchaseChallan({required String challanNo, required String internalNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total}) {
    purchaseChallans.add(PurchaseChallan(id: DateTime.now().toString(), internalNo: internalNo, billNo: challanNo, date: date, distributorName: party.name, items: items, totalAmount: total, status: "Pending"));
    save().then((_) => loadAllData());
  }

  void finalizeSaleReturn({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String type}) {
    saleReturns.add(SaleReturn(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, returnType: type));
    save().then((_) => loadAllData());
  }

  void finalizePurchaseReturn({required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String type = "Sellable"}) {
    purchaseReturns.add(PurchaseReturn(id: DateTime.now().toString(), billNo: billNo, distributorName: party.name, date: date, items: items, totalAmount: total, status: "Active", returnType: type));
    save().then((_) => loadAllData());
  }

  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void updateAppConfig(AppConfig c) { config = c; save(); }
  void addSystemUser(SystemUser u) { systemUsers.add(u); save(); }
  void updateSystemUser(SystemUser u) { int i = systemUsers.indexWhere((x) => x.id == u.id); if(i != -1) { systemUsers[i] = u; save(); } }
  void deleteSystemUser(String id) { systemUsers.removeWhere((x) => x.id == id); save(); }

  List<BankTransaction> getBankStatement(String bankName, DateTime from, DateTime to) {
    List<BankTransaction> statement = [];
    for (var v in vouchers.where((x) => x.paymentMode == bankName)) {
      statement.add(BankTransaction(id: v.id, date: v.date, particulars: v.partyName, reference: "VOUCHER", amountIn: v.type == "Receipt" ? v.amount : 0, amountOut: v.type == "Payment" ? v.amount : 0, type: "VOUCHER"));
    }
    statement.sort((a, b) => a.date.compareTo(b.date));
    return statement;
  }

  Future<bool> startNewFinancialYear(String nextFY) async {
    if (activeCompany == null) return false;
    bool success = await FYTransferEngine.transferData(companyID: activeCompany!.id, businessType: activeCompany!.businessType, sourceFY: currentFY, targetFY: nextFY);
    if (success) { currentFY = nextFY; await loadAllData(); }
    return success;
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

  // --- LOGIC ---
  double calculateAvgMonthlySale(String medId) => 0.0;
  void runAutoShortageScan() {}
  void addManualShortage({required Medicine med, required double qty, String cust = ""}) {}
  void deleteShortage(String id) {}
  void addLog(String a, String d) {}
  void deleteParty(String id) {}
  void deleteRoute(String id) {}
  void deleteBank(String id) {}
  void deleteSalesman(String id) {}
  void addBank(Bank b) {}
  void addSalesman(Salesman s) {}
  void addCheque(ChequeEntry c) {}
  void updateChequeStatus(String id, String s, String r) {}
  Future<void> runAutoBackup() async {}
  Future<void> masterReset() async {}
  Future<void> resetCounter(String t) async {}
}
