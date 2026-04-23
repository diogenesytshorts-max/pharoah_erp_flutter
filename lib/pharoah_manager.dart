import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'master_data_library.dart';
import 'demo_data.dart';
import 'sale_bill_number.dart';
import 'inventory_logic_center.dart'; // NAYA
import 'fy_transfer_engine.dart';

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
  
  String currentFY = "2025-26";

  PharoahManager() { initManager(); }

  Future<void> initManager() async {
    final prefs = await SharedPreferences.getInstance();
    currentFY = prefs.getString('fy') ?? "2025-26";
    await loadAllData();
  }

  Future<String> getFYDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/DATA_FY_$currentFY');
    if (!await directory.exists()) await directory.create(recursive: true);
    return directory.path;
  }

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

    if (File('$dir/meds.json').existsSync()) {
      medicines = (loadJson('meds.json') as List).map((e) => Medicine.fromMap(e)).toList();
    } else {
      medicines = DemoData.getMedicines();
    }

    parties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
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
    notifyListeners();
  }

  // NAYA: FY Transfer Trigger
  Future<bool> startNewFinancialYear(String nextFY) async {
    await save(); 
    bool success = await FYTransferEngine.transferData(sourceFY: currentFY, targetFY: nextFY);
    if (success) {
      currentFY = nextFY;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fy', nextFY);
      await prefs.setInt('lastBillID', 0); 
      await loadAllData();
    }
    return success;
  }

  // NAYA: Purani zero quantities ko recover karne ke liye ek call
  Future<void> runFullMaintenance() async { 
    await loadAllData(); 
    InventoryLogicCenter.rebuildAllInventory(
      medicines: medicines, 
      batchHistory: batchHistory, 
      purchases: purchases, 
      sales: sales
    );
    await save();
  }

  // --- CORE METHODS ---
  void addVoucher(Voucher v) { vouchers.add(v); save(); }
  void addCompany(Company c) { companies.add(c); save(); }
  void addSalt(Salt s) { salts.add(s); save(); }
  void addDrugType(DrugType d) { drugTypes.add(d); save(); }
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }

  void addLog(String action, String details) { logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); save(); }
  
  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    SaleBillNumber.incrementIfNecessary(billNo);
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode));
    
    for (var it in items) {
      Medicine m = medicines.firstWhere((med) => med.id == it.medicineID);
      m.stock -= (it.qty + it.freeQty);
      
      // NAYA: Batch wise stock OUT
      if (!batchHistory.containsKey(m.identityKey)) batchHistory[m.identityKey] = [];
      InventoryLogicCenter.updateBatchOnSale(batchHistory[m.identityKey]!, it.batch, (it.qty + it.freeQty));
    }
    
    addLog("SALE", "New Bill: #$billNo for ${party.name}");
    save();
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, DateTime? entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, entryDate: entryDate ?? DateTime.now(), distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    
    for (var it in items) {
      Medicine m = medicines.firstWhere((med) => med.id == it.medicineID);
      m.stock += (it.qty + it.freeQty);
      m.purRate = it.purchaseRate;
      m.mrp = it.mrp;
      
      // NAYA: Batch wise stock IN
      if (!batchHistory.containsKey(m.identityKey)) batchHistory[m.identityKey] = [];
      InventoryLogicCenter.updateBatchOnPurchase(
        batchHistory[m.identityKey]!, 
        BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.purchaseRate, qty: (it.qty + it.freeQty))
      );
    }
    
    addLog("PURCHASE", "New Purchase: #$billNo from ${party.name}");
    save();
  }

  void deleteBill(String id) {
    try {
      final sale = sales.firstWhere((s) => s.id == id);
      if (sale.status == "Active") {
         for (var it in sale.items) {
           Medicine m = medicines.firstWhere((med) => med.id == it.medicineID);
           m.stock += (it.qty + it.freeQty);
           // NAYA: Reverse Batch stock (Sale delete hui toh stock wapas aaya)
           InventoryLogicCenter.updateBatchOnPurchase(batchHistory[m.identityKey]!, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.rate, qty: (it.qty + it.freeQty)));
         }
      }
      sales.removeWhere((s) => s.id == id);
      addLog("DELETE", "Bill #${sale.billNo} deleted.");
      save();
    } catch (e) {}
  }

  void cancelBill(String id) {
    try {
      int i = sales.indexWhere((s) => s.id == id);
      if(i != -1 && sales[i].status == "Active") {
         for (var it in sales[i].items) {
           Medicine m = medicines.firstWhere((med) => med.id == it.medicineID);
           m.stock += (it.qty + it.freeQty);
           // NAYA: Reverse Batch stock
           InventoryLogicCenter.updateBatchOnPurchase(batchHistory[m.identityKey]!, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.rate, qty: (it.qty + it.freeQty)));
         }
        sales[i].status = "Cancelled";
        addLog("CANCEL", "Bill #${sales[i].billNo} Cancelled.");
        save();
      }
    } catch (e) {}
  }

  void deletePurchase(String id) {
    try {
      final pur = purchases.firstWhere((p) => p.id == id);
      for (var it in pur.items) {
         Medicine m = medicines.firstWhere((med) => med.id == it.medicineID);
         m.stock -= (it.qty + it.freeQty);
         // NAYA: Reverse Batch stock (Purchase delete hui toh stock kam hua)
         InventoryLogicCenter.updateBatchOnSale(batchHistory[m.identityKey]!, it.batch, (it.qty + it.freeQty));
      }
      purchases.removeWhere((p) => p.id == id);
      addLog("DELETE", "Purchase #${pur.billNo} deleted.");
      save();
    } catch (e) {}
  }

  void deleteParty(String id) { parties.removeWhere((p) => p.id == id); save(); }
  Future<void> runAutoBackup() async { addLog("SYSTEM", "Backup taken"); await save(); }
  Future<void> masterReset() async { 
    final dir = await getFYDirectory(); 
    final d = Directory(dir); 
    if(d.existsSync()) d.deleteSync(recursive: true); 
    await loadAllData(); 
  }
  Future<void> switchYear(String year) async { currentFY = year; await loadAllData(); notifyListeners(); }
}
