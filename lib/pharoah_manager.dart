import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class PharoahManager with ChangeNotifier {
  // --- CORE DATA LISTS ---
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<RouteArea> routes = [];
  List<LogEntry> logs = [];
  List<Voucher> vouchers = [];
  Map<String, List<BatchInfo>> batchHistory = {};
  
  String currentFY = "2025-26";
  String companyState = "Rajasthan";

  PharoahManager() {
    initManager();
  }

  // --- INITIALIZATION & YEAR SWITCHING ---
  Future<void> initManager() async {
    final prefs = await SharedPreferences.getInstance();
    currentFY = prefs.getString('fy') ?? "2025-26";
    companyState = prefs.getString('compState') ?? "Rajasthan";
    await loadAllData();
  }

  Future<void> switchYear(String newYear) async {
    medicines.clear();
    parties.clear();
    sales.clear();
    purchases.clear();
    logs.clear();
    vouchers.clear();
    routes.clear();
    batchHistory.clear();
    currentFY = newYear;
    notifyListeners();
    await loadAllData();
  }

  // --- DIRECTORY MANAGEMENT ---
  Future<String> getFYDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/DATA_FY_$currentFY');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  // --- SAVE & LOAD LOGIC ---
  Future<void> save() async {
    final dir = await getFYDirectory();
    await File('$dir/meds.json').writeAsString(jsonEncode(medicines.map((e) => e.toMap()).toList()));
    await File('$dir/parts.json').writeAsString(jsonEncode(parties.map((e) => e.toMap()).toList()));
    await File('$dir/sales.json').writeAsString(jsonEncode(sales.map((e) => e.toMap()).toList()));
    await File('$dir/purc.json').writeAsString(jsonEncode(purchases.map((e) => e.toMap()).toList()));
    await File('$dir/logs.json').writeAsString(jsonEncode(logs.map((e) => e.toMap()).toList()));
    await File('$dir/vouc.json').writeAsString(jsonEncode(vouchers.map((e) => e.toMap()).toList()));
    await File('$dir/routs.json').writeAsString(jsonEncode(routes.map((e) => e.toMap()).toList()));
    await File('$dir/bats.json').writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    notifyListeners();
  }

  Future<void> loadAllData() async {
    final dir = await getFYDirectory();
    dynamic loadJson(String name) {
      final f = File('$dir/$name');
      return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
    }

    medicines = (loadJson('meds.json') as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? [];
    parties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [Party(id: 'cash', name: "CASH", group: "Cash in Hand")];
    sales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    routes = (loadJson('routs.json') as List?)?.map((e) => RouteArea.fromMap(e)).toList() ?? [RouteArea(id: '1', name: "Local City")];
    logs = (loadJson('logs.json') as List?)?.map((e) => LogEntry.fromMap(e)).toList() ?? [];
    vouchers = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];

    var bD = loadJson('bats.json');
    if (bD != null) {
      batchHistory.clear();
      (bD as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
    }
    notifyListeners();
  }

  // --- BATCH MANAGEMENT ---
  void saveBatchCentrally(String medId, BatchInfo newBatch) {
    if (!batchHistory.containsKey(medId)) batchHistory[medId] = [];
    int idx = batchHistory[medId]!.indexWhere((b) => b.batch.toUpperCase() == newBatch.batch.toUpperCase());
    if (idx != -1) {
      batchHistory[medId]![idx] = newBatch;
    } else {
      batchHistory[medId]!.add(newBatch);
    }
    save();
  }

  // --- SALES LOGIC (Stock Deduction) ---
  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(
      id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, 
      partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, 
      paymentMode: mode, invoiceType: party.isB2B ? "B2B" : "B2C"
    ));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= (it.qty + it.freeQty);
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.rate));
      }
    }
    addLog("SALE", "Bill #$billNo generated for ${party.name}");
    save();
  }

  // --- PURCHASE LOGIC (Stock Addition & Rate Update) ---
  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(
      id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, 
      date: date, distributorName: party.name, items: items, totalAmount: total, paymentMode: mode
    ));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock += (it.qty + it.freeQty);
        medicines[idx].purRate = it.purchaseRate;
        medicines[idx].mrp = it.mrp;
        medicines[idx].gst = it.gstRate;
        // Purchase se Product Master ke rates bhi update hote hain
        medicines[idx].rateA = it.rateA;
        medicines[idx].rateB = it.rateB;
        medicines[idx].rateC = it.rateC;
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.purchaseRate));
      }
    }
    addLog("PURCHASE", "Bill #$billNo recorded from ${party.name}");
    save();
  }

  // --- VOID & DELETE OPERATIONS ---
  void cancelBill(String id) {
    int i = sales.indexWhere((s) => s.id == id);
    if (i != -1 && sales[i].status != "Cancelled") {
      for (var it in sales[i].items) {
        int mi = medicines.indexWhere((m) => m.id == it.medicineID);
        if (mi != -1) medicines[mi].stock += (it.qty + it.freeQty);
      }
      sales[i].status = "Cancelled";
      addLog("CANCEL", "Sale Bill #${sales[i].billNo} Cancelled");
      save();
    }
  }

  void deleteBill(String id) {
    int i = sales.indexWhere((s) => s.id == id);
    if (i != -1) {
      if (sales[i].status == "Active") {
        for (var it in sales[i].items) {
          int mi = medicines.indexWhere((m) => m.id == it.medicineID);
          if (mi != -1) medicines[mi].stock += (it.qty + it.freeQty);
        }
      }
      sales.removeAt(i);
      save();
    }
  }

  void deletePurchase(String id) {
    int i = purchases.indexWhere((p) => p.id == id);
    if (i != -1) {
      for (var it in purchases[i].items) {
        int mi = medicines.indexWhere((m) => m.id == it.medicineID);
        if (mi != -1) medicines[mi].stock -= (it.qty + it.freeQty);
      }
      purchases.removeAt(i);
      save();
    }
  }

  // --- ACCOUNTING VOUCHERS ---
  void addVoucher(Voucher v) {
    vouchers.add(v);
    save();
  }

  // --- MASTER UPDATES ---
  void addRoute(RouteArea r) { routes.add(r); save(); }
  void deleteRoute(String id) { routes.removeWhere((r) => r.id == id); save(); }
  void deleteParty(String id) {
    if (parties.firstWhere((p) => p.id == id).name != "CASH") {
      parties.removeWhere((p) => p.id == id);
      save();
    }
  }

  // --- SYSTEM MAINTENANCE ---
  Future<void> runFullMaintenance() async {
    for (var med in medicines) {
      double st = 0.0;
      for (var p in purchases) {
        for (var it in p.items) if (it.medicineID == med.id) st += (it.qty + it.freeQty);
      }
      for (var s in sales) {
        if (s.status == "Active") {
          for (var it in s.items) if (it.medicineID == med.id) st -= (it.qty + it.freeQty);
        }
      }
      med.stock = st;
    }
    addLog("MAINTENANCE", "System-wide stock recalculation complete");
    await save();
  }

  void addLog(String action, String details) {
    logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now()));
  }

  Future<void> masterReset() async {
    final dir = await getFYDirectory();
    final directory = Directory(dir);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    await switchYear(currentFY);
  }

  // --- GETTERS ---
  DateTime get fyStartDate {
    int y = int.parse(currentFY.split('-')[0]);
    if (y < 2000) y += 2000;
    return DateTime(y, 4, 1);
  }
  DateTime get fyEndDate {
    int y = int.parse(currentFY.split('-')[0]);
    if (y < 2000) y += 2000;
    return DateTime(y + 1, 3, 31);
  }
}
