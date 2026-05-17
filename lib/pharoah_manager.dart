// FILE: lib/pharoah_manager.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:local_auth/local_auth.dart'; 
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; 

import 'models.dart';
import 'administration/system_user_model.dart';
import 'finance/bank_transaction_model.dart';
import 'demo_data.dart';
import 'inventory_logic_center.dart';
import 'fy_transfer_engine.dart';
import 'gateway/company_registry_model.dart';
import 'logic/app_settings_model.dart';
import 'logic/pharoah_numbering_engine.dart';
import 'master_data_library.dart';

class PharoahManager with ChangeNotifier {
  // ===========================================================================
  // 1. GLOBAL STATE & SECURITY VARIABLES (CLASS LEVEL)
  // ===========================================================================
  
  String activeModule = "HOME"; 
  
  // --- 🛡️ NEW SECURITY & AUTO-LOCK STATE ---
  bool isAppLocked = false;           
  Timer? _inactivityTimer;            
  final _auth = LocalAuthentication(); 
  final _secureStorage = const FlutterSecureStorage(); 

  // --- DATA LISTS ---
  List<Medicine> medicines = []; 
  List<SystemUser> systemUsers = []; 
  SystemUser? loggedInStaff;
  List<Party> parties = []; 
  List<RouteArea> routes = []; 
  List<Company> companies = [];
  List<Salt> salts = []; 
  List<DrugType> drugTypes = []; 
  List<Bank> banks = [];
  List<ChequeEntry> cheques = []; 
  List<ShortageItem> shortages = [];
  List<NumberingSeries> numberingSeries = []; 
  List<Sale> sales = []; 
  List<Purchase> purchases = [];
  List<SaleChallan> saleChallans = []; 
  List<PurchaseChallan> purchaseChallans = [];
  List<SaleReturn> saleReturns = []; 
  List<PurchaseReturn> purchaseReturns = [];
  List<Voucher> vouchers = []; 
  List<LogEntry> logs = []; 
  Map<String, List<BatchInfo>> batchHistory = {};
  AppConfig config = AppConfig(); 
  List<CompanyProfile> companiesRegistry = [];
  CompanyProfile? activeCompany; 
  String currentFY = ""; 
  bool isAdminAuthenticated = false;

  PharoahManager() { initRegistry(); }

  // ===========================================================================
  // 2. NAVIGATION & DYNAMIC MENU GETTERS
  // ===========================================================================

  void updateModule(String newModule) {
    activeModule = newModule;
    notifyListeners();
  }

  List<ModuleAction> get mainMenuActions => [
    ModuleAction(title: "BILLING", icon: Icons.receipt_long, color: Colors.blue, navModule: "BILLING"),
    ModuleAction(title: "CHALLANS", icon: Icons.local_shipping, color: Colors.teal, navModule: "CHALLANS"),
    ModuleAction(title: "RETURNS", icon: Icons.assignment_return, color: Colors.red, navModule: "RETURNS"),
    ModuleAction(title: "INVENTORY", icon: Icons.inventory, color: Colors.purple, navModule: "INVENTORY"),
    ModuleAction(title: "ACCOUNTS", icon: Icons.account_balance_wallet, color: Colors.indigo, navModule: "ACCOUNTS"),
    ModuleAction(title: "MASTERS", icon: Icons.stars, color: Colors.orange, navModule: "MASTERS"),
    ModuleAction(title: "MODIFICATIONS", icon: Icons.edit_note_rounded, color: Colors.blueGrey, navModule: "GO_MODIFICATION"),
    ModuleAction(title: "GST", icon: Icons.verified, color: Colors.green, navModule: "GST"),
    ModuleAction(title: "DATA HUB", icon: Icons.cloud_sync, color: Colors.teal, navModule: "GO_DATA_HUB"),
  ];

  List<ModuleAction> get billingActions => [
    ModuleAction(title: "New Sale", icon: Icons.add_shopping_cart, color: Colors.blue, navModule: "GO_SALE"),
    ModuleAction(title: "Purchase", icon: Icons.downloading, color: Colors.orange, navModule: "GO_PURCHASE"),
    ModuleAction(title: "STITCHER", icon: Icons.auto_fix_high, color: Colors.teal, navModule: "GO_STITCHER_WIZARD"),
    ModuleAction(title: "Sale Reg", icon: Icons.description, color: Colors.blue, navModule: "GO_SALE_REG"),
    ModuleAction(title: "Pur Reg", icon: Icons.history, color: Colors.brown, navModule: "GO_PUR_REG"),
  ];

  List<ModuleAction> get challanActions => [
    ModuleAction(title: "Sale Challan", icon: Icons.local_shipping, color: Colors.teal, navModule: "GO_CHALLAN_SALE"),
    ModuleAction(title: "Pur Challan", icon: Icons.inventory_2, color: Colors.orange, navModule: "GO_CHALLAN_PUR"),
    ModuleAction(title: "Sale Reg", icon: Icons.list, color: Colors.indigo, navModule: "GO_CHALLAN_SALE_REG"),
    ModuleAction(title: "Pur Reg", icon: Icons.history_edu, color: Colors.amber, navModule: "GO_CHALLAN_PUR_REG"),
  ];

  List<ModuleAction> get returnActions => [
    ModuleAction(title: "Credit Note", icon: Icons.assignment_return, color: Colors.red, navModule: "GO_RETURN_SALE"),
    ModuleAction(title: "Debit Note", icon: Icons.remove_shopping_cart, color: Colors.brown, navModule: "GO_RETURN_PUR"),
    ModuleAction(title: "Breakage", icon: Icons.delete_sweep, color: Colors.deepOrange, navModule: "GO_RETURN_BREAKAGE"),
    ModuleAction(title: "Return Reg", icon: Icons.format_list_bulleted, color: Colors.red.shade900, navModule: "GO_RETURN_SALE_REG"),
  ];

  List<ModuleAction> get inventoryActions => [
    ModuleAction(title: "Stock", icon: Icons.view_in_ar, color: Colors.purple, navModule: "GO_STOCK"),
    ModuleAction(title: "Shortage", icon: Icons.trending_down, color: Colors.red, navModule: "GO_SHORTAGE"),
    ModuleAction(title: "Ledger", icon: Icons.menu_book, color: Colors.blueGrey, navModule: "GO_ITEM_LEDGER"),
  ];

  List<ModuleAction> get accountsActions => [
    ModuleAction(title: "Daybook", icon: Icons.event_note, color: Colors.blueGrey, navModule: "GO_DAYBOOK"),
    ModuleAction(title: "Ledgers", icon: Icons.people, color: Colors.indigo, navModule: "GO_LEDGERS"),
    ModuleAction(title: "Receipts", icon: Icons.add_chart, color: Colors.green, navModule: "GO_RECEIPT"),
    ModuleAction(title: "Payments", icon: Icons.analytics, color: Colors.red, navModule: "GO_PAYMENT"),
  ];

  List<ModuleAction> get mastersActions => [
    ModuleAction(title: "Parties", icon: Icons.group_add, color: Colors.indigo, navModule: "GO_M_PARTY"),
    ModuleAction(title: "Items", icon: Icons.medication, color: Colors.purple, navModule: "GO_M_ITEM"),
    ModuleAction(title: "Series", icon: Icons.format_list_numbered, color: Colors.blue, navModule: "GO_M_SERIES"),
    ModuleAction(title: "Staff", icon: Icons.admin_panel_settings, color: Colors.red, navModule: "GO_M_STAFF"),
    ModuleAction(title: "Batches", icon: Icons.layers, color: Colors.blueGrey, navModule: "GO_M_BATCH"),
    ModuleAction(title: "Routes", icon: Icons.map, color: Colors.teal, navModule: "GO_M_ROUTE"),
    ModuleAction(title: "Company", icon: Icons.business, color: Colors.brown, navModule: "GO_M_COMP"),
    ModuleAction(title: "Salt Master", icon: Icons.science, color: Colors.deepOrange, navModule: "GO_M_SALT"),
  ];

  List<ModuleAction> get gstActions => [
    ModuleAction(title: "GSTR-1", icon: Icons.assignment, color: Colors.green, navModule: "GO_GST_1"),
    ModuleAction(title: "GSTR-3B", icon: Icons.summarize, color: Colors.blue, navModule: "GO_GST_3B"),
    ModuleAction(title: "Portal", icon: Icons.fact_check, color: Colors.teal, navModule: "GO_GST_RECON"),
  ];

  // ===========================================================================
  // 3. SECURITY & AUTH LOGIC
  // ===========================================================================

  void authenticateAdmin(bool status) { 
    isAdminAuthenticated = status; 
    if (status) {
      isAppLocked = false;
      resetInactivityTimer();
    }
    notifyListeners(); 
  }

  void resetInactivityTimer() {
    if (activeCompany == null || activeCompany!.autoLockMinutes == 0) return;
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: activeCompany!.autoLockMinutes), () {
      lockApp(); 
    });
  }

  void lockApp() {
    if (isAppLocked || activeCompany == null) return;
    isAppLocked = true;
    notifyListeners();
  }

  Future<bool> authenticateBiometric() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) return false;
      bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Scan fingerprint to unlock ERP',
        options: const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (didAuthenticate) {
        isAppLocked = false;
        resetInactivityTimer();
        notifyListeners();
      }
      return didAuthenticate;
    } catch (e) { return false; }
  }

  Future<void> saveSecureToken(String password) async {
    if (activeCompany == null) return;
    await _secureStorage.write(key: 'auth_${activeCompany!.id}', value: password);
  }

  Future<String?> getSecureToken() async {
    if (activeCompany == null) return null;
    return await _secureStorage.read(key: 'auth_${activeCompany!.id}');
  }

  void handleAppLifecycle(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      if (activeCompany != null && activeCompany!.autoLockMinutes > 0) lockApp();
    }
  }

  // ===========================================================================
  // 4. REGISTRY & PERSISTENCE
  // ===========================================================================

  Future<void> initRegistry() async {
    final root = await getApplicationDocumentsDirectory(); 
    final file = File('${root.path}/pharoah_registry.json');
    if (await file.exists()) { 
      try { 
        List l = jsonDecode(await file.readAsString()); 
        companiesRegistry = l.map((e) => CompanyProfile.fromMap(e)).toList(); 
      } catch (e) { debugPrint("Registry error: $e"); } 
    }
    notifyListeners();
  }

  Future<void> saveRegistry() async {
    final root = await getApplicationDocumentsDirectory();
    await File('${root.path}/pharoah_registry.json').writeAsString(jsonEncode(companiesRegistry.map((e) => e.toMap()).toList()));
    notifyListeners();
  }

  Future<void> loginToCompany(CompanyProfile c, String fy) async { 
    activeCompany = c; 
    currentFY = fy; 
    await loadAllData(); 
  }

  void clearSession() { 
    activeCompany = null; 
    currentFY = ""; 
    isAdminAuthenticated = false; 
    isAppLocked = false;
    _inactivityTimer?.cancel();
    loggedInStaff = null; 
    notifyListeners(); 
  }

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
    Future _w(String n, List data) async => await File('$dir/$n').writeAsString(jsonEncode(data.map((e) => e.toMap()).toList()));
    
    await _w('meds.json', medicines); 
    await _w('parts.json', parties); 
    await _w('sales.json', sales);
    await _w('purc.json', purchases); 
    await _w('vouc.json', vouchers); 
    await _w('sys_users.json', systemUsers);
    await _w('series.json', numberingSeries); 
    await _w('s_challan.json', saleChallans); 
    await _w('p_challan.json', purchaseChallans);
    await _w('s_return.json', saleReturns); 
    await _w('p_return.json', purchaseReturns); 
    await _w('cheques.json', cheques);
    await _w('shortage.json', shortages); 
    await _w('logs.json', logs); 
    await _w('routs.json', routes);
    await _w('comps.json', companies); 
    await _w('salts.json', salts); 
    await _w('dtypes.json', drugTypes); 
    await _w('banks.json', banks);
    
    await File('$dir/bats.json').writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    await File('$dir/config.json').writeAsString(jsonEncode(config.toMap()));
    notifyListeners();
  }

  Future<void> loadAllData() async {
    final dir = await getWorkingPath(); 
    if (dir.isEmpty) return;
    dynamic load(String n) { final f = File('$dir/$n'); return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null; }
    
    var cData = load('config.json');
    if (cData != null) config = AppConfig.fromMap(cData);
    else config = AppConfig();
    
    medicines = (load('meds.json') as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? DemoData.getMedicines();
    parties = (load('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [Party(id:'cash',name:"CASH",group:"Cash in Hand")];
    companies = (load('comps.json') as List?)?.map((e) => Company.fromMap(e)).toList() ?? MasterDataLibrary.getTopCompanies();
    salts = (load('salts.json') as List?)?.map((e) => Salt.fromMap(e)).toList() ?? MasterDataLibrary.getTopSalts();
    drugTypes = (load('dtypes.json') as List?)?.map((e) => DrugType.fromMap(e)).toList() ?? MasterDataLibrary.getDrugTypes();
    sales = (load('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (load('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (load('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    saleChallans = (load('s_challan.json') as List?)?.map((e) => SaleChallan.fromMap(e)).toList() ?? [];
    purchaseChallans = (load('p_challan.json') as List?)?.map((e) => PurchaseChallan.fromMap(e)).toList() ?? [];
    saleReturns = (load('s_return.json') as List?)?.map((e) => SaleReturn.fromMap(e)).toList() ?? [];
    purchaseReturns = (load('p_return.json') as List?)?.map((e) => PurchaseReturn.fromMap(e)).toList() ?? [];
    cheques = (load('cheques.json') as List?)?.map((e) => ChequeEntry.fromMap(e)).toList() ?? [];
    shortages = (load('shortage.json') as List?)?.map((e) => ShortageItem.fromMap(e)).toList() ?? [];
    logs = (load('logs.json') as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [];
    routes = (load('routs.json') as List?)?.map((e) => RouteArea.fromMap(e)).toList() ?? [];
    banks = (load('banks.json') as List?)?.map((e) => Bank.fromMap(e)).toList() ?? [];
    
    var sD = load('series.json'); if (sD!=null) numberingSeries = (sD as List).map((e)=>NumberingSeries.fromMap(e)).toList();
    var uD = load('sys_users.json'); if (uD!=null) systemUsers = (uD as List).map((e)=>SystemUser.fromMap(e)).toList();
    var bD = load('bats.json'); if (bD!=null) { batchHistory.clear(); (bD as Map).forEach((k,v)=>batchHistory[k]=(v as List).map((b)=>BatchInfo.fromMap(b)).toList()); }
    
    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners();
  }

  // ===========================================================================
  // 6. BUSINESS LOGIC (SALES, PURCHASES, STITCHER)
  // ===========================================================================

  Future<void> finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode, List<String>? linkedIds, double extraDiscount = 0.0, double roundOff = 0.0, String sourceTag = ""}) async { 
    final p = parties.firstWhere((pt) => pt.id == party.id, orElse: () => party);
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, partyId: p.id, date: date, partyName: p.name, partyGstin: p.gst, partyState: p.state, items: items, totalAmount: total, paymentMode: mode, linkedChallanIds: linkedIds ?? [], extraDiscount: extraDiscount, roundOff: roundOff, partyAddress: p.address, partyPhone: p.phone, partyEmail: p.email, partyDl: p.dl, partyPan: p.pan, partyCity: p.city, sourceTag: sourceTag)); 
    if (linkedIds != null) { for (var id in linkedIds) { int i = saleChallans.indexWhere((c) => c.id == id); if (i != -1) saleChallans[i].status = "Billed"; } }
    if (sourceTag.isEmpty && activeCompany != null) { String pfx = billNo.split(RegExp(r'\d')).first; await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: billNo, prefix: pfx); }
    await save(); InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales); notifyListeners();
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode, List<String>? linkedChallanIds, String sourceTag = ""}) { 
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, partyId: party.id, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode, linkedChallanIds: linkedChallanIds ?? [], sourceTag: sourceTag)); 
    if (linkedChallanIds != null) { for (var id in linkedChallanIds) { int i = purchaseChallans.indexWhere((c) => c.id == id); if (i != -1) purchaseChallans[i].status = "Billed"; } }
    if (sourceTag.isEmpty && activeCompany != null) { PharoahNumberingEngine.updateSeriesCounter(type: "PURCHASE", companyID: activeCompany!.id, usedNumber: internalNo, prefix: "PUR-"); }
    save().then((_) => loadAllData()); 
  }

  Future<void> finalizeBatchSales(List<Sale> batch) async { 
    sales.addAll(batch); 
    for (var s in batch) { if (s.linkedChallanIds.isNotEmpty) { for (var id in s.linkedChallanIds) { int i = saleChallans.indexWhere((c) => c.id == id); if (i != -1) saleChallans[i].status = "Billed"; } } } 
    if (batch.isNotEmpty && activeCompany != null) { String l = batch.last.billNo; String p = l.split(RegExp(r'\d')).first; await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: l, prefix: p); } 
    await save(); InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales); notifyListeners(); 
  }

  Future<void> finalizeBatchPurchases(List<Purchase> batch) async { 
    purchases.addAll(batch); 
    for (var p in batch) { if (p.linkedChallanIds.isNotEmpty) { for (var id in p.linkedChallanIds) { int i = purchaseChallans.indexWhere((c) => c.id == id); if (i != -1) purchaseChallans[i].status = "Billed"; } } } 
    await save(); InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales); notifyListeners(); 
  }

  // --- CHALLANS & RETURNS ---
  void finalizeSaleChallan({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, String remarks = "", required String partyId}) { saleChallans.add(SaleChallan(id: DateTime.now().toString(), billNo: billNo, partyId: partyId, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, remarks: remarks)); save(); }
  void finalizePurchaseChallan({required String billNo, required String internalNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String remarks = "", required String partyId}) { purchaseChallans.add(PurchaseChallan(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, partyId: partyId, date: date, distributorName: party.name, items: items, totalAmount: total, remarks: remarks)); save(); }
  void finalizeSaleReturn({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, String type = "Sellable"}) { saleReturns.add(SaleReturn(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, returnType: type)); save().then((_) => loadAllData()); }
  void finalizePurchaseReturn({required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String type = "Breakage"}) { purchaseReturns.add(PurchaseReturn(id: DateTime.now().toString(), billNo: billNo, distributorName: party.name, date: date, items: items, totalAmount: total, status: "Active", returnType: type)); save().then((_) => loadAllData()); }

  // ===========================================================================
  // 7. BATCH TOOLS & INVENTORY INTEL
  // ===========================================================================

  void registerBatchActivity({required String productKey, required String batchNo, required String exp, required String packing, required double mrp, required double rate}) {
    if (activeCompany == null) return;
    if (!batchHistory.containsKey(productKey)) batchHistory[productKey] = [];
    List<BatchInfo> history = batchHistory[productKey]!;
    int existingIdx = history.indexWhere((b) => b.batch.trim() == batchNo.trim());
    if (existingIdx != -1) {
      history[existingIdx].exp = exp; history[existingIdx].mrp = mrp; history[existingIdx].rate = rate; history[existingIdx].packing = packing;
    } else {
      history.add(BatchInfo(batch: batchNo.trim(), exp: exp, packing: packing, mrp: mrp, rate: rate, qty: 0.0, isShell: false));
    }
    save();
  }

  void runAutoShortageScan() { shortages.removeWhere((s) => s.source == "Auto"); for (var m in medicines) { double a = calculateAvgMonthlySale(m.id); double r = a * 1.5; if (m.stock < r && r > 0) { shortages.add(ShortageItem(id: "auto_${m.id}", medicineId: m.id, medicineName: m.name, companyName: m.companyId, qtyRequired: r - m.stock, currentStock: m.stock, date: DateTime.now(), source: "Auto")); } } save(); }
  double calculateAvgMonthlySale(String mid) { DateTime d = DateTime.now().subtract(const Duration(days: 30)); double q = 0; for (var s in sales.where((x) => x.status == "Active" && x.date.isAfter(d))) { for (var it in s.items.where((it) => it.medicineID == mid)) { q += (it.qty + it.freeQty); } } return q; }

  void adjustBatchStock({required String medId, required String batchNo, required double adjQty, required String reason}) { if (batchHistory.containsKey(medId)) { try { var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo); b.adjustmentQty += adjQty; b.adjReason = reason; save().then((_) => loadAllData()); } catch (e) {} } }
  void updateBatchMetadata({required String medId, required String batchNo, required String newExp, required double newMrp, required double newRate}) { if (batchHistory.containsKey(medId)) { try { var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo); b.exp = newExp; b.mrp = newMrp; b.rate = newRate; save().then((_) => loadAllData()); } catch (e) {} } }

  // ===========================================================================
  // 8. MASTERS CRUD (ADD/UPDATE/DELETE)
  // ===========================================================================

  String getOrCreateCompany(String n) { try { return companies.firstWhere((c) => c.name.toUpperCase() == n.trim().toUpperCase()).id; } catch (e) { String id = "CP-${1000 + companies.length + 1}"; companies.add(Company(id: id, name: n.trim().toUpperCase())); save(); return id; } }
  String getOrCreateSalt(String n) { try { return salts.firstWhere((s) => s.name.toUpperCase() == n.trim().toUpperCase()).id; } catch (e) { String id = "SL-${1000 + salts.length + 1}"; salts.add(Salt(id: id, name: n.trim().toUpperCase())); save(); return id; } }

  void addMedicine(Medicine m, {bool doSave = true}) { medicines.add(m); if (!batchHistory.containsKey(m.identityKey)) batchHistory[m.identityKey] = []; if (doSave) save(); notifyListeners(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addSystemUser(SystemUser u) { systemUsers.add(u); save(); }
  void addNumberingSeries(NumberingSeries ns) { numberingSeries.add(ns); save(); }
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addBank(Bank b) { banks.add(b); save(); }
  void addCheque(ChequeEntry c) { cheques.add(c); save(); }
  void addLog(String a, String d) { logs.add(LogEntry(id: DateTime.now().toString(), action: a, details: d, time: DateTime.now())); save(); }
  void addManualShortage({required Medicine med, required double qty, String cust = ""}) { shortages.add(ShortageItem(id: DateTime.now().toString(), medicineId: med.id, medicineName: med.name, companyName: med.companyId, qtyRequired: qty, currentStock: med.stock, date: DateTime.now(), customerName: cust)); save(); }

  void updateSystemUser(SystemUser u) { int i = systemUsers.indexWhere((x) => x.id == u.id); if(i != -1) { systemUsers[i] = u; save(); } }
  void updateNumberingSeries(NumberingSeries ns) { int i = numberingSeries.indexWhere((x) => x.id == ns.id); if(i != -1) { numberingSeries[i] = ns; save(); } }
  void updateAppConfig(AppConfig c) { config = c; save(); notifyListeners(); }
  void updateChequeStatus(String id, String s, String r) { int i = cheques.indexWhere((c) => c.id == id); if(i != -1) { cheques[i].status = s; cheques[i].remark = r; save(); } }

  void deleteBill(String id) { try { final s = sales.firstWhere((x) => x.id == id); if (s.linkedChallanIds.isNotEmpty) { for (var cid in s.linkedChallanIds) { int i = saleChallans.indexWhere((c) => c.id == cid); if (i != -1) saleChallans[i].status = "Pending"; } } sales.removeWhere((x) => x.id == id); save().then((_) => loadAllData()); } catch (e) {} }
  void deletePurchase(String id) { purchases.removeWhere((p) => p.id == id); save().then((_) => loadAllData()); }
  void deleteSaleChallan(String id) { saleChallans.removeWhere((c) => c.id == id); save(); }
  void deletePurchaseChallan(String id) { purchaseChallans.removeWhere((c) => c.id == id); save(); }
  void deleteSaleReturn(String id) { saleReturns.removeWhere((r) => r.id == id); save().then((_) => loadAllData()); }
  void deletePurchaseReturn(String id) { purchaseReturns.removeWhere((r) => r.id == id); save().then((_) => loadAllData()); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void deleteSystemUser(String id) { systemUsers.removeWhere((x) => x.id == id); save(); }
  void deleteShortage(String id) { shortages.removeWhere((s) => s.id == id); save(); }
  void deleteBank(String id) { banks.removeWhere((b) => b.id == id); save(); }

  // --- 🔥 RESTORED COUNTER RESET ---
  void resetCounter(String t) { if (activeCompany != null) { String pfx = (t == "SALE_BILL") ? "INV-" : (t == "PUR_BILL" ? "PUR-" : "SCH-"); PharoahNumberingEngine.resetSeries(type: t.contains("SALE") ? "SALE" : "PURCHASE", companyID: activeCompany!.id, prefix: pfx); } notifyListeners(); }

  // ===========================================================================
  // 9. DATA REGISTRY & YEAR-END
  // ===========================================================================

  Future<void> setupNewCompanyEnvironment(CompanyProfile p, String f) async { activeCompany = p; currentFY = f; numberingSeries = [NumberingSeries(id: 's1', name: "Standard Retail", type: "SALE", prefix: "INV-", isDefault: true)]; medicines = DemoData.getMedicines(); companies = MasterDataLibrary.getTopCompanies(); salts = MasterDataLibrary.getTopSalts(); drugTypes = MasterDataLibrary.getDrugTypes(); parties = [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")]; await save(); if (!companiesRegistry.any((c) => c.id == p.id)) { companiesRegistry.add(p); await saveRegistry(); } notifyListeners(); }
  Future<bool> startNewFinancialYear(String n) async { await save(); bool ok = await FYTransferEngine.transferData(companyID: activeCompany!.id, businessType: activeCompany!.businessType, sourceFY: currentFY, targetFY: n); if(ok) { currentFY = n; await loadAllData(); } return ok; }
  Future<void> masterReset() async { final p = await getWorkingPath(); if(p.isNotEmpty) { final d = Directory(p); if(d.existsSync()) d.deleteSync(recursive: true); } await loadAllData(); }

  // ===========================================================================
  // 10. GETTERS & RECOVERY
  // ===========================================================================

  NumberingSeries getDefaultSeries(String t) => numberingSeries.firstWhere((s) => s.type == t && s.isDefault, orElse: () => numberingSeries.firstWhere((s) => s.type == t, orElse: () => NumberingSeries(id: 'tmp', name: 'Default', type: t, prefix: 'TXN-', isDefault: true)));
  List<NumberingSeries> getSeriesByType(String t) => numberingSeries.where((s) => s.type == t).toList();
  List<String> getSortedStates() { final all = ["Andhra Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal", "Delhi", "Jammu and Kashmir", "Ladakh", "Puducherry", "Chandigarh"]; Map<String, int> counts = {}; for (var p in parties) { counts[p.state] = (counts[p.state] ?? 0) + 1; } List<String> sorted = List.from(all); sorted.sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0)); return sorted; }

  // --- SIGNATURES (RESTORED) ---
  Future<void> addSignatureToChallan({required String challanId, required String imagePath, required String code, required double amount, required double qty, required double x, required double y}) async { int idx = saleChallans.indexWhere((c) => c.id == challanId); if (idx != -1) { final s = ChallanSignature(id: DateTime.now().toString(), imagePath: imagePath, verificationCode: code, signedAmount: amount, signedQty: qty, signDate: DateTime.now(), signX: x, signY: y); List<ChallanSignature> h = List.from(saleChallans[idx].sigHistory); h.add(s); saleChallans[idx].sigHistory = h; saleChallans[idx].isSigned = true; save(); } }
  Future<String> saveSignatureFile(String cNo, Uint8List b) async { final r = await getApplicationDocumentsDirectory(); final d = Directory('${r.path}/Pharoah_Data/${activeCompany!.id}/Signatures'); if (!await d.exists()) await d.create(recursive: true); final f = File('${d.path}/Sign_${cNo}_${DateTime.now().millisecondsSinceEpoch}.png'); await f.writeAsBytes(b); return f.path; }
}
