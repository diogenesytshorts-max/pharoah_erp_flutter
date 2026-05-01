// FILE: lib/pharoah_manager.dart (FULLY UPDATED & FIXED)

import 'dart:convert';
import 'dart:io';
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
    ModuleAction(title: "DATA HUB", icon: Icons.cloud_sync_rounded, color: Colors.teal.shade700, navModule: "GO_DATA_HUB"),
  ];

  List<ModuleAction> get billingActions => [
    ModuleAction(title: "New Sale", icon: Icons.add_shopping_cart, color: Colors.blue, navModule: "GO_SALE"),
    ModuleAction(title: "Purchase", icon: Icons.downloading, color: Colors.orange, navModule: "GO_PURCHASE"),
    ModuleAction(title: "CONVERT CHALLAN TO BILL", icon: Icons.auto_fix_high_rounded, color: Colors.teal, navModule: "GO_STITCHER_WIZARD"),
    ModuleAction(title: "Sale Register", icon: Icons.description_outlined, color: Colors.blue, navModule: "GO_SALE_REG"),
    ModuleAction(title: "Pur Register", icon: Icons.history_rounded, color: Colors.brown, navModule: "GO_PUR_REG"),
  ];

  List<ModuleAction> get challanActions => [
    ModuleAction(title: "Sale Challan", icon: Icons.local_shipping, color: Colors.teal, navModule: "GO_CHALLAN_SALE"),
    ModuleAction(title: "Purchase Challan", icon: Icons.inventory_2, color: Colors.amber.shade800, navModule: "GO_CHALLAN_PUR"),
    ModuleAction(title: "Sale Register", icon: Icons.format_list_bulleted_rounded, color: Colors.indigo, navModule: "GO_CHALLAN_SALE_REG"),
    ModuleAction(title: "Pur Register", icon: Icons.history_edu_rounded, color: Colors.amber.shade900, navModule: "GO_CHALLAN_PUR_REG"),
  ];

  List<ModuleAction> get returnActions => [
    ModuleAction(title: "Credit Note", icon: Icons.assignment_return, color: Colors.red, navModule: "GO_RETURN_SALE"),
    ModuleAction(title: "Debit Note", icon: Icons.remove_shopping_cart, color: Colors.brown, navModule: "GO_RETURN_PUR"),
    ModuleAction(title: "Breakage Return", icon: Icons.delete_sweep, color: Colors.deepOrange, navModule: "GO_RETURN_BREAKAGE"),
    ModuleAction(title: "Pur. Register", icon: Icons.history_edu_rounded, color: Colors.brown.shade800, navModule: "GO_RETURN_PUR_REG"),
  ];

  List<ModuleAction> get inventoryActions => [
    ModuleAction(title: "Stock View", icon: Icons.view_in_ar, color: Colors.purple, navModule: "GO_STOCK"),
    ModuleAction(title: "Shortage", icon: Icons.trending_down, color: Colors.red, navModule: "GO_SHORTAGE"),
    ModuleAction(title: "Item Ledger", icon: Icons.menu_book, color: Colors.blueGrey, navModule: "GO_ITEM_LEDGER"),
    ModuleAction(title: "Dump Stock", icon: Icons.delete_sweep, color: Colors.brown, navModule: "GO_DUMP"),
  ];

  List<ModuleAction> get accountsActions => [
    ModuleAction(title: "Daybook", icon: Icons.event_note, color: Colors.blueGrey, navModule: "GO_DAYBOOK"),
    ModuleAction(title: "Ledgers", icon: Icons.people_alt, color: Colors.indigo, navModule: "GO_LEDGERS"),
    ModuleAction(title: "Receipts", icon: Icons.add_chart, color: Colors.green, navModule: "GO_RECEIPT"),
    ModuleAction(title: "Payments", icon: Icons.analytics, color: Colors.red, navModule: "GO_PAYMENT"),
  ];

  List<ModuleAction> get mastersActions => [
    ModuleAction(title: "Parties", icon: Icons.group_add, color: Colors.indigo, navModule: "GO_M_PARTY"),
    ModuleAction(title: "Items", icon: Icons.medication, color: Colors.purple, navModule: "GO_M_ITEM"),
    ModuleAction(title: "Series Master", icon: Icons.format_list_numbered, color: Colors.blue, navModule: "GO_M_SERIES"),
    ModuleAction(title: "Staff & Security", icon: Icons.admin_panel_settings, color: Colors.red, navModule: "GO_M_STAFF"),
    ModuleAction(title: "Batches", icon: Icons.layers, color: Colors.blueGrey, navModule: "GO_M_BATCH"),
    ModuleAction(title: "Routes", icon: Icons.map, color: Colors.teal, navModule: "GO_M_ROUTE"),
    ModuleAction(title: "Company", icon: Icons.business, color: Colors.brown, navModule: "GO_M_COMP"),
    ModuleAction(title: "Salt Master", icon: Icons.science, color: Colors.deepOrange, navModule: "GO_M_SALT"),
  ];

  List<ModuleAction> get gstActions => [
    ModuleAction(title: "GSTR-1", icon: Icons.assignment, color: Colors.green, navModule: "GO_GST_1"),
    ModuleAction(title: "GSTR-3B", icon: Icons.summarize, color: Colors.blue, navModule: "GO_GST_3B"),
    ModuleAction(title: "Portal Match", icon: Icons.fact_check, color: Colors.teal, navModule: "GO_GST_RECON"),
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

  // ===========================================================================
  // SESSION & REGISTRY
  // ===========================================================================

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

  // ===========================================================================
  // PERSISTENCE (SAVE / LOAD)
  // ===========================================================================

  Future<void> save() async {
    final dir = await getWorkingPath(); if (dir.isEmpty) return;
    Future _write(String n, List data) async => await File('$dir/$n').writeAsString(jsonEncode(data.map((e) => e.toMap()).toList()));
    await _write('meds.json', medicines);
    await _write('parts.json', parties);
    await _write('sales.json', sales);
    await _write('purc.json', purchases);
    await _write('vouc.json', vouchers);
    await _write('sys_users.json', systemUsers);
    await _write('series.json', numberingSeries);
    await _write('s_challan.json', saleChallans);
    await _write('p_challan.json', purchaseChallans);
    await _write('s_return.json', saleReturns);
    await _write('p_return.json', purchaseReturns);
    await _write('cheques.json', cheques);
    await _write('shortage.json', shortages);
    await _write('logs.json', logs);
    await _write('routs.json', routes);
    await _write('comps.json', companies);
    await _write('salts.json', salts);
    await _write('dtypes.json', drugTypes);
    await _write('banks.json', banks);
    await File('$dir/bats.json').writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    notifyListeners();
  }

  Future<void> loadAllData() async {
    final dir = await getWorkingPath(); if (dir.isEmpty) return;
    dynamic load(String n) { final f = File('$dir/$n'); return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null; }
    medicines = (load('meds.json') as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? DemoData.getMedicines();
    parties = (load('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
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
    var sData = load('series.json'); if (sData != null) numberingSeries = (sData as List).map((e) => NumberingSeries.fromMap(e)).toList();
    var uData = load('sys_users.json'); if (uData != null) systemUsers = (uData as List).map((e) => SystemUser.fromMap(e)).toList();
    var bData = load('bats.json'); if (bData != null) { batchHistory.clear(); (bData as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList()); }
    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners();
  }

  // ===========================================================================
  // ⚡ FINALIZATION LOGIC (UPDATED FOR MERGED BILLS)
  // ===========================================================================

  Future<void> finalizeSale({
    required String billNo, 
    required DateTime date, 
    required Party party, 
    required List<BillItem> items, 
    required double total, 
    required String mode, 
    List<String>? linkedIds
  }) async { 
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode, linkedChallanIds: linkedIds ?? [])); 

    if (linkedIds != null && linkedIds.isNotEmpty) {
      for (var id in linkedIds) {
        int idx = saleChallans.indexWhere((c) => c.id == id);
        if (idx != -1) saleChallans[idx].status = "Billed";
      }
    }

    if (activeCompany != null) {
      String prefix = billNo.split(RegExp(r'\d')).first;
      await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: billNo, prefix: prefix);
    }
    await save();
    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners(); 
  }

  Future<void> finalizeBatchSales(List<Sale> batch) async {
    sales.addAll(batch);
    for (var sale in batch) {
      if (sale.linkedChallanIds.isNotEmpty) {
        for (var id in sale.linkedChallanIds) {
          int idx = saleChallans.indexWhere((c) => c.id == id);
          if (idx != -1) saleChallans[idx].status = "Billed";
        }
      }
    }
    if (batch.isNotEmpty && activeCompany != null) {
      String lastNo = batch.last.billNo;
      String prefix = lastNo.split(RegExp(r'\d')).first;
      await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: lastNo, prefix: prefix);
    }
    await save();
    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners();
  }

  void finalizePurchase({
    required String internalNo, required String billNo, required DateTime date, 
    DateTime? entryDate, required Party party, required List<PurchaseItem> items, 
    required double total, required String mode, List<String>? linkedChallanIds
  }) { 
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode, linkedChallanIds: linkedChallanIds ?? [])); 
    
    if (linkedChallanIds != null) {
      for (var id in linkedChallanIds) {
        int idx = purchaseChallans.indexWhere((c) => c.id == id);
        if (idx != -1) purchaseChallans[idx].status = "Billed";
      }
    }
    if (activeCompany != null) PharoahNumberingEngine.updateSeriesCounter(type: "PURCHASE", companyID: activeCompany!.id, usedNumber: internalNo, prefix: "PUR-"); 
    save().then((_) => loadAllData()); 
  }

  Future<void> finalizeBatchPurchases(List<Purchase> batch) async {
    purchases.addAll(batch);
    for (var p in batch) {
      if (p.linkedChallanIds.isNotEmpty) {
        for (var id in p.linkedChallanIds) {
          int idx = purchaseChallans.indexWhere((c) => c.id == id);
          if (idx != -1) purchaseChallans[idx].status = "Billed";
        }
      }
    }
    await save();
    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners();
  }

  // ===========================================================================
  // DELETE & MASTERS
  // ===========================================================================

  void deleteBill(String id) {
    try {
      final sale = sales.firstWhere((s) => s.id == id);
      if (sale.linkedChallanIds.isNotEmpty) { for (var cId in sale.linkedChallanIds) { int idx = saleChallans.indexWhere((c) => c.id == cId); if (idx != -1) saleChallans[idx].status = "Pending"; } }
      sales.removeWhere((s) => s.id == id);
      save().then((_) => loadAllData());
    } catch (e) {}
  }

  void deletePurchase(String id) { purchases.removeWhere((p) => p.id == id); save().then((_) => loadAllData()); }
  void deleteSaleChallan(String id) { saleChallans.removeWhere((c) => c.id == id); save(); }
  void deletePurchaseChallan(String id) { purchaseChallans.removeWhere((c) => c.id == id); save(); }
  void deleteSaleReturn(String id) { saleReturns.removeWhere((r) => r.id == id); save(); }
  void deletePurchaseReturn(String id) { purchaseReturns.removeWhere((r) => r.id == id); save(); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void addLog(String action, String details) { logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void addMedicine(Medicine m) { medicines.add(m); if (!batchHistory.containsKey(m.identityKey)) batchHistory[m.identityKey] = []; save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addSystemUser(SystemUser u) { systemUsers.add(u); save(); }
  void updateSystemUser(SystemUser u) { int i = systemUsers.indexWhere((x) => x.id == u.id); if(i != -1) { systemUsers[i] = u; save(); } }
  void deleteSystemUser(String id) { systemUsers.removeWhere((x) => x.id == id); save(); }
  void addNumberingSeries(NumberingSeries ns) { numberingSeries.add(ns); save(); }
  void updateNumberingSeries(NumberingSeries ns) { int i = numberingSeries.indexWhere((x) => x.id == ns.id); if(i != -1) { numberingSeries[i] = ns; save(); } }
  void updateAppConfig(AppConfig c) { config = c; notifyListeners(); }
  void resetCounter(String type) { addLog("SYSTEM", "Reset requested for $type"); notifyListeners(); }
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addBank(Bank b) { banks.add(b); save(); }
  void deleteBank(String id) { banks.removeWhere((b) => b.id == id); save(); }
  void addCheque(ChequeEntry c) { cheques.add(c); save(); }
  void adjustBatchStock({required String medId, required String batchNo, required double adjQty, required String reason}) { if (batchHistory.containsKey(medId)) { try { var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo); b.adjustmentQty += adjQty; b.adjReason = reason; save().then((_) => loadAllData()); } catch (e) {} } }
  void updateBatchMetadata({required String medId, required String batchNo, required String newExp, required double newMrp, required double newRate}) { if (batchHistory.containsKey(medId)) { try { var b = batchHistory[medId]!.firstWhere((x) => x.batch == batchNo); b.exp = newExp; b.mrp = newMrp; b.rate = newRate; save().then((_) => loadAllData()); } catch (e) {} } }
  void deleteShortage(String id) { shortages.removeWhere((s) => s.id == id); save(); }
  void addManualShortage({required Medicine med, required double qty, String cust = ""}) { shortages.add(ShortageItem(id: DateTime.now().toString(), medicineId: med.id, medicineName: med.name, companyName: med.companyId, qtyRequired: qty, currentStock: med.stock, date: DateTime.now(), customerName: cust)); save(); }
  void updateChequeStatus(String id, String status, String reason) { int i = cheques.indexWhere((c) => c.id == id); if(i != -1) { cheques[i].status = status; cheques[i].remark = reason; save(); } }

  void finalizeSaleChallan({required String challanNo, required DateTime date, required Party party, required List<BillItem> items, required double total, String remarks = ""}) async { 
    saleChallans.add(SaleChallan(id: DateTime.now().toString(), billNo: challanNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, remarks: remarks)); 
    save(); 
  }

  void finalizePurchaseChallan({required String challanNo, required String internalNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String remarks = ""}) async { 
    purchaseChallans.add(PurchaseChallan(id: DateTime.now().toString(), internalNo: internalNo, billNo: challanNo, date: date, distributorName: party.name, items: items, totalAmount: total, remarks: remarks)); 
    if (activeCompany != null) await PharoahNumberingEngine.updateSeriesCounter(type: "CHALLAN_PUR", companyID: activeCompany!.id, usedNumber: internalNo, prefix: "PCH-");
    save(); 
  }

  void finalizeSaleReturn({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, String type = "Sellable"}) async { 
    saleReturns.add(SaleReturn(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, returnType: type)); 
    save(); 
  }

  void finalizePurchaseReturn({required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, String type = "Breakage"}) { 
    purchaseReturns.add(PurchaseReturn(id: DateTime.now().toString(), billNo: billNo, distributorName: party.name, date: date, items: items, totalAmount: total, status: "Active", returnType: type)); 
    save(); 
  }

  // ===========================================================================
  // SYSTEM SETUP & YEAR END
  // ===========================================================================

  Future<void> setupNewCompanyEnvironment(CompanyProfile profile, String initialFY) async {
    activeCompany = profile; 
    currentFY = initialFY;
    numberingSeries = [NumberingSeries(id: 's1', name: "Standard Retail", type: "SALE", prefix: "INV-", isDefault: true)];
    medicines = DemoData.getMedicines();
    companies = MasterDataLibrary.getTopCompanies();
    salts = MasterDataLibrary.getTopSalts();
    drugTypes = MasterDataLibrary.getDrugTypes();
    parties = [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    await save();
    if (!companiesRegistry.any((c) => c.id == profile.id)) { 
      companiesRegistry.add(profile); 
      await saveRegistry(); 
    }
    notifyListeners();
  }

  Future<bool> startNewFinancialYear(String nextFY) async { 
    await save(); 
    bool ok = await FYTransferEngine.transferData(companyID: activeCompany!.id, businessType: activeCompany!.businessType, sourceFY: currentFY, targetFY: nextFY); 
    if(ok) { currentFY = nextFY; await loadAllData(); } 
    return ok; 
  }

  Future<void> masterReset() async { final dir = await getWorkingPath(); if(dir.isNotEmpty) { final d = Directory(dir); if(d.existsSync()) d.deleteSync(recursive: true); } await loadAllData(); }
  List<NumberingSeries> getSeriesByType(String type) => numberingSeries.where((s) => s.type == type).toList();
  NumberingSeries getDefaultSeries(String type) => numberingSeries.firstWhere((s) => s.type == type && s.isDefault, orElse: () => numberingSeries.firstWhere((s) => s.type == type, orElse: () => NumberingSeries(id: 'tmp', name: 'Default', type: type, prefix: 'TXN-', isDefault: true)));
}
