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
import 'logic/pharoah_numbering_engine.dart'; // NAYA ENGINE LINK

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
  
  // NAYA: Series Management
  List<NumberingSeries> numberingSeries = [];
  
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
    final dir = Directory('${root.path}/Pharoah_Data/${activeCompany!.id}/${activeCompany!.businessType}/$currentFY');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir.path;
  }

  // ===========================================================================
  // 2. NEW COMPANY FRESH SETUP LOGIC (Now with Series)
  // ===========================================================================

  Future<void> setupNewCompanyEnvironment(CompanyProfile profile, String initialFY) async {
    // A. Memory Refresh
    sales = []; purchases = []; numberingSeries = []; vouchers = [];
    
    // B. Create Default Series for New Company
    numberingSeries = [
      NumberingSeries(id: 's1', name: "Standard Sale", type: "SALE", prefix: "INV-", isDefault: true),
      NumberingSeries(id: 'p1', name: "Standard Purchase", type: "PURCHASE", prefix: "PUR-", isDefault: true),
      NumberingSeries(id: 'c1', name: "Sale Challan", type: "CHALLAN", prefix: "SCH-", isDefault: true),
      NumberingSeries(id: 'r1', name: "Credit Note", type: "RETURN", prefix: "SRN-", isDefault: true),
      NumberingSeries(id: 'v1', name: "Voucher", type: "VOUCHER", prefix: "VOU-", isDefault: true),
    ];

    medicines = DemoData.getMedicines();
    parties = [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    
    final root = await getApplicationDocumentsDirectory();
    final dirPath = '${root.path}/Pharoah_Data/${profile.id}/${profile.businessType}/$initialFY';
    final dir = await Directory(dirPath).create(recursive: true);

    Future _write(String name, dynamic data) async {
      await File('${dir.path}/$name').writeAsString(jsonEncode(data));
    }

    // Save initial masters and default series
    await _write('meds.json', medicines.map((e) => e.toMap()).toList());
    await _write('parts.json', parties.map((e) => e.toMap()).toList());
    await _write('series.json', numberingSeries.map((e) => e.toMap()).toList());
    await _write('sales.json', []);
    await _write('purc.json', []);
    await _write('vouc.json', []);
    await _write('bats.json', {});
    await _write('sys_users.json', []);
    
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
    
    // NAYA: Series configurations save karna
    await File('$dir/series.json').writeAsString(jsonEncode(numberingSeries.map((e) => e.toMap()).toList()));
    
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
    
    // Load Series Settings
    var sData = loadJson('series.json');
    if (sData != null) {
      numberingSeries = (sData as List).map((e) => NumberingSeries.fromMap(e)).toList();
    } else {
      // Fallback defaults if file missing
      numberingSeries = [NumberingSeries(id: 's1', name: "Sale", type: "SALE", prefix: "INV-", isDefault: true)];
    }

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

  // ===========================================================================
  // 4. NUMBERING SERIES HELPERS
  // ===========================================================================
  
  List<NumberingSeries> getSeriesByType(String type) {
    return numberingSeries.where((s) => s.type == type).toList();
  }

  NumberingSeries getDefaultSeries(String type) {
    return numberingSeries.firstWhere((s) => s.type == type && s.isDefault, 
      orElse: () => numberingSeries.firstWhere((s) => s.type == type, 
      orElse: () => NumberingSeries(id: 'tmp', name: 'Default', type: type, prefix: 'TXN-', isDefault: true)));
  }

  void addNumberingSeries(NumberingSeries ns) {
    // Agar ye default set ho rahi hai, toh purani default hatao
    if (ns.isDefault) {
      for (var s in numberingSeries.where((x) => x.type == ns.type)) {
        s.isDefault = false;
      }
    }
    numberingSeries.add(ns);
    save();
  }

  // ===========================================================================
  // 5. TRANSACTIONS
  // ===========================================================================

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode, bool isEdit = false}) async {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode));
    
    // NAYA: Engine ko batana ki counter update karein (Persistence)
    // Humne prefix dhoondhna hoga jo is billNo se match kare
    for (var s in numberingSeries.where((x) => x.type == "SALE")) {
      if (billNo.startsWith(s.prefix)) {
        await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: billNo, prefix: s.prefix);
      }
    }

    save().then((_) => loadAllData());
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    save().then((_) => loadAllData());
  }

  // --- STANDARD ACTIONS ---
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void deleteBill(String id) { sales.removeWhere((s) => s.id == id); save().then((_) => loadAllData()); }
  void deletePurchase(String id) { purchases.removeWhere((p) => p.id == id); save().then((_) => loadAllData()); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  
  Future<void> runAutoBackup() async { await save(); }

  Future<void> masterReset() async { 
    final dir = await getWorkingPath(); 
    if(dir.isNotEmpty) {
      final d = Directory(dir); 
      if(d.existsSync()) d.deleteSync(recursive: true); 
    }
    await loadAllData(); 
  }
}
