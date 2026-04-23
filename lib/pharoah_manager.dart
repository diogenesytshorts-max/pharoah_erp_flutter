import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'master_data_library.dart';
import 'demo_data.dart';
import 'sale_bill_number.dart';
import 'inventory_logic_center.dart';
import 'fy_transfer_engine.dart';
import 'app_date_logic.dart'; // NAYA: Date Master connection

class PharoahManager with ChangeNotifier {
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
  
  // NAYA: Hardcoding hatayi gayi hai. Default saal ab dynamic detect hoga.
  String currentFY = AppDateLogic.getCurrentFYString();

  PharoahManager() { 
    initManager(); 
  }

  /// App shuru hote hi logic check karta hai
  Future<void> initManager() async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Check karo kya pehle se koi saal save hai?
    // 2. Agar nahi (Fresh Install), toh Date Master se current saal uthao.
    currentFY = prefs.getString('fy') ?? AppDateLogic.getCurrentFYString();
    
    await loadAllData();
  }

  /// Har saal ka data alag folder mein save karne ke liye path
  Future<String> getFYDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/DATA_FY_$currentFY');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory.path;
  }

  // ===========================================================================
  // DATA PERSISTENCE (SAVE & LOAD)
  // ===========================================================================

  Future<void> save() async {
    final dir = await getFYDirectory();
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
    final dir = await getFYDirectory();
    dynamic loadJson(String name) {
      final f = File('$dir/$name');
      return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
    }

    // Medicines load logic
    if (File('$dir/meds.json').existsSync()) {
      medicines = (loadJson('meds.json') as List).map((e) => Medicine.fromMap(e)).toList();
    } else {
      medicines = DemoData.getMedicines();
    }

    // Parties load logic (Default CASH party inclusion)
    parties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? 
              [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];

    // Other Transactional & Master data
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    logs = (loadJson('logs.json') as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [];
    
    // Static Libraries
    companies = (loadJson('comps.json') as List?)?.map((e) => Company.fromMap(e)).toList() ?? 
                MasterDataLibrary.topCompanies.map((n) => Company(id: n, name: n)).toList();
    salts = (loadJson('salts.json') as List?)?.map((e) => Salt.fromMap(e)).toList() ?? 
            MasterDataLibrary.topSalts.map((s) => Salt(id: s['name']!, name: s['name']!, type: s['type']!)).toList();
    drugTypes = (loadJson('dtypes.json') as List?)?.map((e) => DrugType.fromMap(e)).toList() ?? 
                MasterDataLibrary.drugTypes.map((n) => DrugType(id: n, name: n)).toList();
    routes = (loadJson('routs.json') as List?)?.map((e) => RouteArea.fromMap(e)).toList() ?? 
             [RouteArea(id: '1', name: "LOCAL AREA")];

    // Batch History load
    var bD = loadJson('bats.json');
    if (bD != null) {
      batchHistory.clear();
      (bD as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
    }

    // Auto-Rebuild stock after loading to ensure accuracy
    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales);
    notifyListeners();
  }

  // ===========================================================================
  // YEAR MANAGEMENT (SYSTEM ADMIN)
  // ===========================================================================

  /// NAYA: Naye saal mein switch karne ka logic
  Future<bool> startNewFinancialYear(String nextFY) async {
    await save(); // Purana data pehle save karein
    
    // FYTransferEngine ko call karke stock aur balance naye saal ke folder mein le jayein
    bool success = await FYTransferEngine.transferData(sourceFY: currentFY, targetFY: nextFY);
    
    if (success) {
      currentFY = nextFY;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fy', nextFY);
      await prefs.setInt('lastBillID', 0); // Bill numbering reset karein
      
      await loadAllData(); // Naya folder load karein
      addLog("SYSTEM", "Transitioned to New Financial Year: $nextFY");
    }
    return success;
  }

  /// System settings mein saal badalne ke liye
  Future<void> switchYear(String year) async { 
    currentFY = year; 
    await loadAllData(); 
    notifyListeners(); 
  }

  // ===========================================================================
  // MASTER DATA MODIFIERS
  // ===========================================================================
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void addLog(String action, String details) { 
    logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); 
    save(); 
  }

  // ===========================================================================
  // TRANSACTIONAL LOGIC
  // ===========================================================================

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    SaleBillNumber.incrementIfNecessary(billNo);
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode));
    save().then((_) => loadAllData()); 
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    save().then((_) => loadAllData()); 
  }

  void deleteBill(String id) { sales.removeWhere((s) => s.id == id); save().then((_) => loadAllData()); }
  void cancelBill(String id) {
    int i = sales.indexWhere((s) => s.id == id);
    if(i != -1) { sales[i].status = "Cancelled"; save().then((_) => loadAllData()); }
  }
  void deletePurchase(String id) { purchases.removeWhere((p) => p.id == id); save().then((_) => loadAllData()); }
  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  
  Future<void> runAutoBackup() async { await save(); }
  
  Future<void> masterReset() async { 
    final dir = await getFYDirectory(); 
    final d = Directory(dir); 
    if(d.existsSync()) d.deleteSync(recursive: true); 
    await loadAllData(); 
  }
}
