// FILE: lib/pharoah_manager.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // --- NAVIGATION STATE ---
  String activeModule = "HOME"; 
  void updateModule(String newModule) {
    activeModule = newModule;
    notifyListeners();
  }

  // --- DYNAMIC MENU ACTIONS ---
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

  // --- REGISTRY & SESSION ---
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
    loggedInStaff = null; 
    notifyListeners(); 
  }

  void authenticateAdmin(bool s) { 
    isAdminAuthenticated = s; 
    notifyListeners(); 
  }

  Future<String> getWorkingPath() async {
    if (activeCompany == null || currentFY.isEmpty) return "";
    final root = await getApplicationDocumentsDirectory();
    final dir = Directory('${root.path}/Pharoah_Data/${activeCompany!.id}/${activeCompany!.businessType}/$currentFY');
    if (!await dir.exists()) await dir.create(recursive: true); 
    return dir.path;
  }

  // --- PERSISTENCE ---
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
  // MASTER AUTO-GENERATION HELPERS (FOR P2P SYNC)
  // ===========================================================================
  
  String getOrCreateCompany(String name) {
    if (name == "N/A" || name.isEmpty) return "";
    try {
      return companies.firstWhere((c) => c.name.toUpperCase() == name.trim().toUpperCase()).id;
    } catch (e) {
      String newId = "CP-${1000 + companies.length + 1}";
      companies.add(Company(id: newId, name: name.trim().toUpperCase()));
      save();
      return newId;
    }
  }

  String getOrCreateSalt(String name) {
    if (name == "N/A" || name.isEmpty) return "";
    try {
      return salts.firstWhere((s) => s.name.toUpperCase() == name.trim().toUpperCase()).id;
    } catch (e) {
      String newId = "SL-${1000 + salts.length + 1}";
      salts.add(Salt(id: newId, name: name.trim().toUpperCase(), type: "Mono"));
      save();
      return newId;
    }
  }

  // ===========================================================================
  // TRANSACTIONS
  // ===========================================================================

  Future<void> finalizeSale({
    required String billNo, required DateTime date, required Party party, 
    required List<BillItem> items, required double total, required String mode, 
    List<String>? linkedIds, double extraDiscount = 0.0, double roundOff = 0.0
  }) async { 
    Party masterParty = parties.firstWhere((p) => p.name == party.name, orElse: () => party);
    sales.add(Sale(
      id: DateTime.now().toString(), billNo: billNo, date: date, partyName: masterParty.name, 
      partyGstin: masterParty.gst, partyState: masterParty.state, items: items, totalAmount: total, 
      paymentMode: mode, linkedChallanIds: linkedIds ?? [], extraDiscount: extraDiscount, roundOff: roundOff,
      partyAddress: masterParty.address, partyPhone: masterParty.phone, partyEmail: masterParty.email,
      partyDl: masterParty.dl, partyPan: masterParty.pan, partyCity: masterParty.city,
    )); 
    if (linkedIds != null) { for (var id in linkedIds) { int idx = saleChallans.indexWhere((c) => c.id == id); if (idx != -1) saleChallans[idx].status = "Billed"; } }
    if (activeCompany != null) { String p = billNo.split(RegExp(r'\d')).first; await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: billNo, prefix: p); }
    await save(); InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners(); 
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode, List<String>? linkedChallanIds}) { 
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode, linkedChallanIds: linkedChallanIds ?? [])); 
    if (linkedChallanIds != null) { for (var id in linkedChallanIds) { int i = purchaseChallans.indexWhere((c) => c.id == id); if (i != -1) purchaseChallans[i].status = "Billed"; } }
    if (activeCompany != null) PharoahNumberingEngine.updateSeriesCounter(type: "PURCHASE", companyID: activeCompany!.id, usedNumber: internalNo, prefix: "PUR-"); 
    save().then((_) => loadAllData()); 
  }

  Future<void> finalizeBatchSales(List<Sale> b) async {
    sales.addAll(b);
    for (var s in b) { if (s.linkedChallanIds.isNotEmpty) { for (var id in s.linkedChallanIds) { int i = saleChallans.indexWhere((c) => c.id == id); if (i != -1) saleChallans[i].status = "Billed"; } } }
    if (b.isNotEmpty && activeCompany != null) { String l = b.last.billNo; String p = l.split(RegExp(r'\d')).first; await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: l, prefix: p); }
    await save(); InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners();
  }

  Future<void> finalizeBatchPurchases(List<Purchase> b) async {
    purchases.addAll(b);
    for (var p in b) { if (p.linkedChallanIds.isNotEmpty) { for (var id in p.linkedChallanIds) { int i = purchaseChallans.indexWhere((c) => c.id == id); if (i != -1) purchaseChallans[i].status = "Billed"; } } }
    await save(); InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners();
  }

  // --- UPDATES ---
  void updatePurchase({required String id, required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode, required List<String> linkedChallanIds}) {
    int idx = purchases.indexWhere((p) => p.id == id); if (idx == -1) return;
    purchases[idx] = Purchase(id: id, internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode, linkedChallanIds: linkedChallanIds);
    save().then((_) => loadAllData());
  }

  void updateSale({required String id, required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode, required List<String> linkedChallanIds, double extraDiscount = 0.0, double roundOff = 0.0}) {
    int idx = sales.indexWhere((s) => s.id == id); if (idx == -1) return;
    sales[idx] = Sale(id: id, billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode, linkedChallanIds: linkedChallanIds, extraDiscount: extraDiscount, roundOff: roundOff);
    save().then((_) => loadAllData());
  }

  void updateSystemUser(SystemUser u) { 
    int i = systemUsers.indexWhere((x) => x.id == u.id); 
    if(i != -1) { systemUsers[i] = u; save(); } 
  }

  void updateNumberingSeries(NumberingSeries ns) { 
    int i = numberingSeries.indexWhere((x) => x.id == ns.id); 
    if(i != -1) { numberingSeries[i] = ns; save(); } 
  }

  // --- RETURNS & CHALLANS ---
  void finalizeSaleReturn({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, String type = "Sellable"}) { 
    saleReturns.add(SaleReturn(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, returnType: type)); 
    save().then((_) => loadAllData()); 
  }

  void finalizePurchaseReturn({required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String type = "Breakage"}) { 
    purchaseReturns.add(PurchaseReturn(id: DateTime.now().toString(), billNo: billNo, distributorName: party.name, date: date, items: items, totalAmount: total, status: "Active", returnType: type)); 
    save().then((_) => loadAllData()); 
  }

  void finalizeSaleChallan({required String challanNo, required DateTime date, required Party party, required List<BillItem> items, required double total, String remarks = ""}) async { 
    saleChallans.add(SaleChallan(id: DateTime.now().toString(), billNo: challanNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, remarks: remarks)); 
    save(); 
  }

  void finalizePurchaseChallan({required String challanNo, required String internalNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String remarks = ""}) async { purchaseChallans.add(PurchaseChallan(id: DateTime.now().toString(), internalNo: internalNo, billNo: challanNo, date: date, distributorName: party.name, items: items, totalAmount: total, remarks: remarks)); if (activeCompany != null) await PharoahNumberingEngine.updateSeriesCounter(type: "CHALLAN_PUR", companyID: activeCompany!.id, usedNumber: internalNo, prefix: "PCH-"); save(); }

  // ===========================================================================
  // SECURE-SIGN & DELETES
  // ===========================================================================

  Future<void> addSignatureToChallan({required String challanId, required String imagePath, required String code, required double amount, required double qty, required double x, required double y}) async {
    int idx = saleChallans.indexWhere((c) => c.id == challanId);
    if (idx != -1) {
      final newSig = ChallanSignature(id: DateTime.now().toString(), imagePath: imagePath, verificationCode: code, signedAmount: amount, signedQty: qty, signDate: DateTime.now(), signX: x, signY: y);
      List<ChallanSignature> currentHistory = List.from(saleChallans[idx].sigHistory);
      currentHistory.add(newSig);
      saleChallans[idx].sigHistory = currentHistory;
      saleChallans[idx].isSigned = true;
      addLog("SECURITY", "Challan #${saleChallans[idx].billNo} SEALED. Code: $code");
      await save();
    }
  }

  Future<String> saveSignatureFile(String challanNo, Uint8List imageBytes) async {
    final root = await getApplicationDocumentsDirectory();
    final signDir = Directory('${root.path}/Pharoah_Data/${activeCompany!.id}/Signatures');
    if (!await signDir.exists()) await signDir.create(recursive: true);
    final file = File('${signDir.path}/Sign_${challanNo}_${DateTime.now().millisecondsSinceEpoch}.png');
    await file.writeAsBytes(imageBytes);
    return file.path;
  }

  void deleteBill(String id) { try { final s = sales.firstWhere((s) => s.id == id); if (s.linkedChallanIds.isNotEmpty) { for (var cId in s.linkedChallanIds) { int i = saleChallans.indexWhere((c) => c.id == cId); if (i != -1) saleChallans[i].status = "Pending"; } } sales.removeWhere((s) => s.id == id); save().then((_) => loadAllData()); } catch (e) {} }
  void deletePurchase(String id) { try { final b = purchases.firstWhere((p) => p.id == id); if (b.linkedChallanIds.isNotEmpty) { for (var cId in b.linkedChallanIds) { int i = purchaseChallans.indexWhere((c) => c.id == cId); if (i != -1) purchaseChallans[i].status = "Pending"; } } purchases.removeWhere((p) => p.id == id); save().then((_) => loadAllData()); } catch (e) {} }
  void deleteSaleChallan(String id) { saleChallans.removeWhere((c) => c.id == id); save(); }
  void deletePurchaseChallan(String id) { purchaseChallans.removeWhere((c) => c.id == id); save(); }
  void deleteSaleReturn(String id) { saleReturns.removeWhere((r) => r.id == id); save().then((_) => loadAllData()); }
  void deletePurchaseReturn(String id) { purchaseReturns.removeWhere((r) => r.id == id); save().then((_) => loadAllData()); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void deleteSystemUser(String id) { systemUsers.removeWhere((x) => x.id == id); save(); }
  void deleteShortage(String id) { shortages.removeWhere((s) => s.id == id); save(); }

  // ===========================================================================
  // HELPERS & CONFIG
  // ===========================================================================
  void updateAppConfig(AppConfig c) { config = c; save(); notifyListeners(); }
  void resetCounter(String t) { addLog("SYSTEM", "Reset for $t"); notifyListeners(); }
  void addManualShortage({required Medicine med, required double qty, String cust = ""}) { shortages.add(ShortageItem(id: DateTime.now().toString(), medicineId: med.id, medicineName: med.name, companyName: med.companyId, qtyRequired: qty, currentStock: med.stock, date: DateTime.now(), customerName: cust)); save(); }
  void runAutoShortageScan() { shortages.removeWhere((s) => s.source == "Auto"); for (var m in medicines) { double a = calculateAvgMonthlySale(m.id); double r = a * 1.5; if (m.stock < r && r > 0) { shortages.add(ShortageItem(id: "auto_${m.id}", medicineId: m.id, medicineName: m.name, companyName: m.companyId, qtyRequired: r - m.stock, currentStock: m.stock, date: DateTime.now(), source: "Auto")); } } save(); }
  double calculateAvgMonthlySale(String mId) { DateTime d = DateTime.now().subtract(const Duration(days: 30)); double q = 0; for (var s in sales.where((s) => s.status == "Active" && s.date.isAfter(d))) { for (var it in s.items.where((it) => it.medicineID == mId)) { q += (it.qty + it.freeQty); } } return q; }
  void adjustBatchStock({required String medId, required String batchNo, required double adjQty, required String reason}) { if (batchHistory.containsKey(medId)) { try { var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo); b.adjustmentQty += adjQty; b.adjReason = reason; save().then((_) => loadAllData()); } catch (e) {} } }
  void updateBatchMetadata({required String medId, required String batchNo, required String newExp, required double newMrp, required double newRate}) { if (batchHistory.containsKey(medId)) { try { var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo); b.exp = newExp; b.mrp = newMrp; b.rate = newRate; save().then((_) => loadAllData()); } catch (e) {} } }

  void addLog(String a, String d) { logs.add(LogEntry(id: DateTime.now().toString(), action: a, details: d, time: DateTime.now())); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void addMedicine(Medicine m) { medicines.add(m); if (!batchHistory.containsKey(m.identityKey)) batchHistory[m.identityKey] = []; save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addSystemUser(SystemUser u) { systemUsers.add(u); save(); }
  void addNumberingSeries(NumberingSeries ns) { numberingSeries.add(ns); save(); }
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addBank(Bank b) { banks.add(b); save(); }
  void addCheque(ChequeEntry c) { cheques.add(c); save(); }
  void updateChequeStatus(String id, String s, String r) { int i = cheques.indexWhere((c) => c.id == id); if(i != -1) { cheques[i].status = s; cheques[i].remark = r; save(); } }

  // --- SYSTEM ---
  Future<void> setupNewCompanyEnvironment(CompanyProfile p, String f) async {
    activeCompany = p; currentFY = f;
    numberingSeries = [NumberingSeries(id: 's1', name: "Standard Retail", type: "SALE", prefix: "INV-", isDefault: true)];
    medicines = DemoData.getMedicines(); companies = MasterDataLibrary.getTopCompanies(); salts = MasterDataLibrary.getTopSalts(); drugTypes = MasterDataLibrary.getDrugTypes();
    parties = [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    await save(); if (!companiesRegistry.any((c) => c.id == p.id)) { companiesRegistry.add(p); await saveRegistry(); }
    notifyListeners();
  }

  Future<bool> startNewFinancialYear(String n) async {
    await save(); bool ok = await FYTransferEngine.transferData(companyID: activeCompany!.id, businessType: activeCompany!.businessType, sourceFY: currentFY, targetFY: n);
    if(ok) { currentFY = n; await loadAllData(); } return ok;
  }

  Future<void> masterReset() async { 
    final p = await getWorkingPath(); 
    if(p.isNotEmpty) { final dir = Directory(p); if(dir.existsSync()) dir.deleteSync(recursive: true); } 
    await loadAllData(); 
  }

  List<String> getSortedStates() {
    final allStates = ["Andhra Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal", "Delhi", "Jammu and Kashmir", "Ladakh", "Puducherry", "Chandigarh"];
    Map<String, int> counts = {};
    for (var p in parties) { counts[p.state] = (counts[p.state] ?? 0) + 1; }
    List<String> sorted = List.from(allStates);
    sorted.sort((a, b) { int countA = counts[a] ?? 0; int countB = counts[b] ?? 0; return countB.compareTo(countA); });
    return sorted;
  }

  List<NumberingSeries> getSeriesByType(String t) => numberingSeries.where((s) => s.type == t).toList();
  NumberingSeries getDefaultSeries(String t) => numberingSeries.firstWhere((s) => s.type == t && s.isDefault, orElse: () => numberingSeries.firstWhere((s) => s.type == t, orElse: () => NumberingSeries(id: 'tmp', name: 'Default', type: t, prefix: 'TXN-', isDefault: true)));
}

