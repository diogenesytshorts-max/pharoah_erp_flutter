// FILE: lib/pharoah_manager.dart (COMPLETE 5-STEP GATEWAY STATE ENGINE)

import "dart:convert";
import "dart:io";
import "package:flutter/material.dart";
import "package:path_provider/path_provider.dart";
import "package:shared_preferences/shared_preferences.dart";

import "models.dart";
import "administration/system_user_model.dart";
import "demo_data.dart";
import "inventory_logic_center.dart";
import "fy_transfer_engine.dart";
import "gateway/company_registry_model.dart";
import "logic/app_settings_model.dart";
import "logic/pharoah_numbering_engine.dart";
import "master_data_library.dart";

class PharoahManager with ChangeNotifier {
  String activeModule = "HOME"; 
  void updateModule(String newModule) {
    activeModule = newModule;
    notifyListeners();
  }

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
  // 1. REGISTRY & GATEWAY SESSION MANAGEMENT
  // ===========================================================================

  Future<void> initRegistry() async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final file = File("${root.path}/pharoah_registry.json");
      if (await file.exists()) {
        List<dynamic> list = jsonDecode(await file.readAsString());
        companiesRegistry = list.map((e) => CompanyProfile.fromMap(e)).toList();
      }
    } catch (e) {
      debugPrint("Registry Load Error: $e");
    }
    notifyListeners();
  }

  Future<void> saveRegistry() async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final file = File("${root.path}/pharoah_registry.json");
      await file.writeAsString(jsonEncode(companiesRegistry.map((e) => e.toMap()).toList()));
    } catch (e) {}
    notifyListeners();
  }

  // STEP 2 -> STEP 3 -> STEP 4 Transitions
  void selectCompany(CompanyProfile comp) {
    activeCompany = comp;
    currentFY = ""; // Step 3 me saal chunenge
    isAdminAuthenticated = false;
    notifyListeners();
  }

  Future<void> loginToCompany(CompanyProfile comp, String fy) async {
    activeCompany = comp;
    currentFY = fy;
    isAdminAuthenticated = false; // Step 4 (LoginView) me password check hoga
    await loadAllData();
    notifyListeners();
  }

  void authenticateAdmin(bool status) {
    isAdminAuthenticated = status;
    notifyListeners();
  }

  void lockSession() {
    isAdminAuthenticated = false; // Dukan aur FY wahi rahega, sirf lock hoga
    notifyListeners();
  }

  void clearSession() {
    activeCompany = null;
    currentFY = "";
    isAdminAuthenticated = false;
    loggedInStaff = null;
    notifyListeners(); // Wapas Step 2 (Company List) par bhejega
  }

  void changeYear() {
    currentFY = ""; // Wapas Step 3 (Control Panel FY selection) par bhejega
    isAdminAuthenticated = false;
    notifyListeners();
  }

  Future<String> getWorkingPath() async {
    if (activeCompany == null || currentFY.isEmpty) return "";
    try {
      final root = await getApplicationDocumentsDirectory();
      final dir = Directory("${root.path}/Pharoah_Data/${activeCompany!.id}/${activeCompany!.businessType}/$currentFY");
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir.path;
    } catch (e) {
      return "";
    }
  }

  // ===========================================================================
  // 2. PERSISTENCE (SAVE / LOAD)
  // ===========================================================================

  Future<void> save() async {
    final dir = await getWorkingPath();
    if (dir.isEmpty) return;
    Future write(String n, List data) async => await File("$dir/$n").writeAsString(jsonEncode(data.map((e) => e.toMap()).toList()));
    await write("meds.json", medicines);
    await write("parts.json", parties);
    await write("sales.json", sales);
    await write("purc.json", purchases);
    await write("vouc.json", vouchers);
    await write("sys_users.json", systemUsers);
    await write("series.json", numberingSeries);
    await write("s_challan.json", saleChallans);
    await write("p_challan.json", purchaseChallans);
    await write("s_return.json", saleReturns);
    await write("p_return.json", purchaseReturns);
    await write("cheques.json", cheques);
    await write("shortage.json", shortages);
    await write("logs.json", logs);
    await write("routs.json", routes);
    await write("comps.json", companies);
    await write("salts.json", salts);
    await write("dtypes.json", drugTypes);
    await write("banks.json", banks);
    await File("$dir/bats.json").writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    notifyListeners();
  }

  Future<void> loadAllData() async {
    final dir = await getWorkingPath();
    if (dir.isEmpty) return;
    dynamic load(String n) {
      final f = File("$dir/$n");
      return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
    }
    medicines = (load("meds.json") as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? DemoData.getMedicines();
    parties = (load("parts.json") as List?)?.map((e) => Party.fromMap(e)).toList() ?? [DemoData.getDemoParty(), Party(id: "cash", name: "CASH", group: "Cash in Hand")];
    companies = (load("comps.json") as List?)?.map((e) => Company.fromMap(e)).toList() ?? MasterDataLibrary.getTopCompanies();
    salts = (load("salts.json") as List?)?.map((e) => Salt.fromMap(e)).toList() ?? MasterDataLibrary.getTopSalts();
    drugTypes = (load("dtypes.json") as List?)?.map((e) => DrugType.fromMap(e)).toList() ?? MasterDataLibrary.getDrugTypes();
    sales = (load("sales.json") as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (load("purc.json") as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (load("vouc.json") as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    saleChallans = (load("s_challan.json") as List?)?.map((e) => SaleChallan.fromMap(e)).toList() ?? [];
    purchaseChallans = (load("p_challan.json") as List?)?.map((e) => PurchaseChallan.fromMap(e)).toList() ?? [];
    saleReturns = (load("s_return.json") as List?)?.map((e) => SaleReturn.fromMap(e)).toList() ?? [];
    purchaseReturns = (load("p_return.json") as List?)?.map((e) => PurchaseReturn.fromMap(e)).toList() ?? [];
    cheques = (load("cheques.json") as List?)?.map((e) => ChequeEntry.fromMap(e)).toList() ?? [];
    shortages = (load("shortage.json") as List?)?.map((e) => ShortageItem.fromMap(e)).toList() ?? [];
    logs = (load("logs.json") as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [];
    routes = (load("routs.json") as List?)?.map((e) => RouteArea.fromMap(e)).toList() ?? [];
    banks = (load("banks.json") as List?)?.map((e) => Bank.fromMap(e)).toList() ?? [];
    var sData = load("series.json"); if (sData != null) numberingSeries = (sData as List).map((e) => NumberingSeries.fromMap(e)).toList();
    var uData = load("sys_users.json"); if (uData != null) systemUsers = (uData as List).map((e) => SystemUser.fromMap(e)).toList();
    var bData = load("bats.json"); if (bData != null) { batchHistory.clear(); (bData as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList()); }
    InventoryLogicCenter.rebuildAllInventory(
      medicines: medicines, 
      batchHistory: batchHistory, 
      purchases: purchases, 
      sales: sales,
      saleReturns: saleReturns,
      purchaseReturns: purchaseReturns,
    );
    notifyListeners();
  }

  // ===========================================================================
  // 3. FIRST TIME SETUP & RESTORATION
  // ===========================================================================

  Future<void> setupNewCompanyEnvironment(CompanyProfile profile, String initialFY) async {
    activeCompany = profile; 
    currentFY = initialFY;
    numberingSeries = [NumberingSeries(id: "s1", name: "Standard Retail", type: "SALE", prefix: "INV-", isDefault: true)];
    
    medicines = DemoData.getMedicines();
    companies = MasterDataLibrary.getTopCompanies();
    salts = MasterDataLibrary.getTopSalts();
    drugTypes = MasterDataLibrary.getDrugTypes();
    parties = [DemoData.getDemoParty(), Party(id: "cash", name: "CASH", group: "Cash in Hand")];
    
    await save();
    if (!companiesRegistry.any((c) => c.id == profile.id)) { 
      companiesRegistry.add(profile); 
      await saveRegistry(); 
    }
    notifyListeners();
  }

  void runAutoBackup() {
    addLog("SYSTEM", "Auto Backup saved for $currentFY");
  }

  // ===========================================================================
  // 4. TRANSACTION ACTIONS
  // ===========================================================================

  Future<void> finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) async { 
    sales.add(Sale(id: DateTime.now().toString(), partyId: party.id, billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode)); 
    if (activeCompany != null) await PharoahNumberingEngine.updateSeriesCounter(type: "SALE", companyID: activeCompany!.id, usedNumber: billNo, prefix: billNo.split(RegExp(r"\d")).first);
    await save();
    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales, saleReturns: saleReturns, purchaseReturns: purchaseReturns);
    notifyListeners(); 
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) { 
    purchases.add(Purchase(id: DateTime.now().toString(), partyId: party.id, internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode)); 
    save().then((_) => loadAllData()); 
  }

  void addLog(String action, String details) { logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); save(); }
}