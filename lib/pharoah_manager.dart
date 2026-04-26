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

class PharoahManager with ChangeNotifier {
  // --- MEMORY STORAGE ---
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
  List<ChequeEntry> cheques = [];
  List<ShortageItem> shortages = [];
  
  Map<String, List<BatchInfo>> batchHistory = {};
  AppConfig config = AppConfig();
  
  // --- GATEWAY & SESSION ---
  List<CompanyProfile> companiesRegistry = [];
  CompanyProfile? activeCompany;
  String currentFY = "";
  bool isAdminAuthenticated = false;

  PharoahManager() {
    initRegistry();
  }

  // ===========================================================================
  // 1. SYSTEM REGISTRY & SESSION MANAGEMENT
  // ===========================================================================

  Future<void> initRegistry() async {
    final root = await getApplicationDocumentsDirectory();
    final file = File('${root.path}/pharoah_registry.json');
    if (await file.exists()) {
      try {
        List<dynamic> list = jsonDecode(await file.readAsString());
        companiesRegistry = list.map((e) => CompanyProfile.fromMap(e)).toList();
      } catch (e) {
        debugPrint("Registry Load Error: $e");
      }
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

  void clearSession() { 
    activeCompany = null; 
    currentFY = ""; 
    isAdminAuthenticated = false; 
    loggedInStaff = null; 
    notifyListeners(); 
  }

  void authenticateAdmin(bool status) { 
    isAdminAuthenticated = status; 
    notifyListeners(); 
  }

  Future<String> getWorkingPath() async {
    if (activeCompany == null || currentFY.isEmpty) return "";
    final root = await getApplicationDocumentsDirectory();
    // Path: Documents/Pharoah_Data/COMPANY_ID/BUSINESS_TYPE/FY/
    final dir = Directory('${root.path}/Pharoah_Data/${activeCompany!.id}/${activeCompany!.businessType}/$currentFY');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  // ===========================================================================
  // 2. NEW COMPANY FRESH SETUP LOGIC
  // ===========================================================================

  /// Jab user "Create & Register" karega, tab ye call hoga.
  /// Iska kaam memory saaf karna aur naye folder mein default data bharna hai.
  Future<void> setupNewCompanyEnvironment(CompanyProfile profile, String initialFY) async {
    // A. Memory Refresh (Saara purana data khatam)
    sales = [];
    purchases = [];
    saleChallans = [];
    purchaseChallans = [];
    saleReturns = [];
    purchaseReturns = [];
    vouchers = [];
    logs = [];
    cheques = [];
    shortages = [];
    batchHistory = {};
    systemUsers = [];
    
    // B. Inject Demo Data only (As requested)
    medicines = DemoData.getMedicines();
    parties = [
      DemoData.getDemoParty(), 
      Party(id: 'cash', name: "CASH", group: "Cash in Hand")
    ];
    
    // C. Physical Directory Prep
    final root = await getApplicationDocumentsDirectory();
    final dirPath = '${root.path}/Pharoah_Data/${profile.id}/${profile.businessType}/$initialFY';
    final dir = await Directory(dirPath).create(recursive: true);

    // D. Initial File Creation (Empty Shells)
    Future _write(String name, dynamic data) async {
      await File('${dir.path}/$name').writeAsString(jsonEncode(data));
    }

    await _write('meds.json', medicines.map((e) => e.toMap()).toList());
    await _write('parts.json', parties.map((e) => e.toMap()).toList());
    await _write('sales.json', []);
    await _write('purc.json', []);
    await _write('vouc.json', []);
    await _write('bats.json', {});
    await _write('sys_users.json', []);
    await _write('logs.json', [
      LogEntry(id: '1', action: 'SYSTEM', details: 'Company Registered & Setup Complete', time: DateTime.now()).toMap()
    ]);

    // E. Registry mein add karke save karein
    if (!companiesRegistry.any((c) => c.id == profile.id)) {
      companiesRegistry.add(profile);
      await saveRegistry();
    }

    notifyListeners();
  }

  // ===========================================================================
  // 3. CORE SAVE & LOAD
  // ===========================================================================

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
    parties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    
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

  // --- ACTIONS ---
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addLog(String action, String details) { logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addCheque(ChequeEntry c) { cheques.add(c); save(); }

  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void deleteBill(String id) { sales.removeWhere((s) => s.id == id); save().then((_) => loadAllData()); }
  void deletePurchase(String id) { purchases.removeWhere((p) => p.id == id); save().then((_) => loadAllData()); }
  void deleteSaleChallan(String id) { saleChallans.removeWhere((c) => c.id == id); save(); }
  void deletePurchaseChallan(String id) { purchaseChallans.removeWhere((c) => c.id == id); save(); }
  void deleteSaleReturn(String id) { saleReturns.removeWhere((r) => r.id == id); save(); }
  void deletePurchaseReturn(String id) { purchaseReturns.removeWhere((r) => r.id == id); save(); }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode, bool isEdit = false}) {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode));
    save().then((_) => loadAllData());
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    save().then((_) => loadAllData());
  }

  void adjustBatchStock({required String medId, required String batchNo, required double adjQty, required String reason}) {
    if (batchHistory.containsKey(medId)) {
      var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo);
      b.adjustmentQty += adjQty; save().then((_) => loadAllData());
    }
  }

  Future<bool> startNewFinancialYear(String nextFY) async {
    bool success = await FYTransferEngine.transferData(companyID: activeCompany!.id, businessType: activeCompany!.businessType, sourceFY: currentFY, targetFY: nextFY);
    if (success) { currentFY = nextFY; await loadAllData(); }
    return success;
  }

  void addSystemUser(SystemUser u) { systemUsers.add(u); save(); }
  void updateSystemUser(SystemUser u) { int i = systemUsers.indexWhere((x) => x.id == u.id); if(i != -1) { systemUsers[i] = u; save(); } }
  void deleteSystemUser(String id) { systemUsers.removeWhere((x) => x.id == id); save(); }

  Future<void> runAutoBackup() async { await save(); }

  Future<void> masterReset() async { 
    final dir = await getWorkingPath(); 
    if(dir.isNotEmpty) {
      final d = Directory(dir); 
      if(d.existsSync()) d.deleteSync(recursive: true); 
    }
    await loadAllData(); 
  }

  Future<void> switchYear(String year) async { 
    currentFY = year; 
    await loadAllData(); 
    notifyListeners(); 
  }
}
