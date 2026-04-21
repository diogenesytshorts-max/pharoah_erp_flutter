import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'demo_data.dart';
import 'batch_master_logic.dart';

class PharoahManager with ChangeNotifier {
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<LogEntry> logs = [];
  Map<String, List<BatchInfo>> batchHistory = {};
  
  String currentFY = "2025-26";
  String companyState = "Rajasthan";

  PharoahManager() { initManager(); }

  // --- FOLDER ISOLATION ---
  Future<String> getFYDirectory() async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/DATA_FY_$currentFY');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory.path;
  }

  Future<void> initManager() async {
    final p = await SharedPreferences.getInstance();
    currentFY = p.getString('fy') ?? "2025-26";
    companyState = p.getString('compState') ?? "Rajasthan";
    await loadAllData();
  }

  Future<void> switchYear(String newYear) async {
    medicines.clear();
    parties.clear();
    sales.clear();
    purchases.clear();
    logs.clear();
    batchHistory.clear();
    currentFY = newYear;
    notifyListeners();
    await loadAllData();
  }

  // --- CORE DATA OPERATIONS ---
  Future<void> save() async {
    final dir = await getFYDirectory();
    await File('$dir/meds.json').writeAsString(jsonEncode(medicines.map((e)=>e.toMap()).toList()));
    await File('$dir/parts.json').writeAsString(jsonEncode(parties.map((e)=>e.toMap()).toList()));
    await File('$dir/sales.json').writeAsString(jsonEncode(sales.map((e)=>e.toMap()).toList()));
    await File('$dir/purc.json').writeAsString(jsonEncode(purchases.map((e)=>e.toMap()).toList()));
    await File('$dir/logs.json').writeAsString(jsonEncode(logs.map((e)=>e.toMap()).toList()));
    await File('$dir/bats.json').writeAsString(jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    notifyListeners();
  }

  Future<void> loadAllData() async {
    final dir = await getFYDirectory();
    dynamic loadJson(String name) {
      final f = File('$dir/$name');
      if (f.existsSync()) return jsonDecode(f.readAsStringSync());
      return null;
    }

    var mD = loadJson('meds.json');
    medicines = mD != null ? (mD as List).map((e)=>Medicine.fromMap(e)).toList() : DemoData.getMedicines();
    var pD = loadJson('parts.json');
    parties = pD != null ? (pD as List).map((e)=>Party.fromMap(e)).toList() : [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH")];
    var sD = loadJson('sales.json');
    sales = sD != null ? (sD as List).map((e)=>Sale.fromMap(e)).toList() : [];
    var purD = loadJson('purc.json');
    purchases = purD != null ? (purD as List).map((e)=>Purchase.fromMap(e)).toList() : [];
    var lD = loadJson('logs.json');
    logs = lD != null ? (lD as List).map((e)=>LogEntry.fromMap(e)).toList() : [];
    var bD = loadJson('bats.json');
    if (bD != null) { 
      batchHistory.clear();
      (bD as Map).forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList()); 
    }
    notifyListeners();
  }

  Future<void> runAutoBackup() async {
    try {
      final dirPath = await getFYDirectory();
      final backupDir = Directory('$dirPath/backups');
      if (!await backupDir.exists()) await backupDir.create(recursive: true);

      String ts = DateTime.now().millisecondsSinceEpoch.toString();
      final backupFile = File('${backupDir.path}/auto_backup_$ts.json');
      
      await backupFile.writeAsString(jsonEncode({
        'meds': medicines.map((e)=>e.toMap()).toList(),
        'sales': sales.map((e)=>e.toMap()).toList(),
        'purchases': purchases.map((e)=>e.toMap()).toList(),
      }));
    } catch (e) {
      debugPrint("Backup Failed: $e");
    }
  }

  // Stock repair logic updated for Decimal and Free Qty
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
    await save();
  }

  // --- BUSINESS LOGIC ---
  void saveBatchCentrally(String medId, BatchInfo b) {
    if (!batchHistory.containsKey(medId)) batchHistory[medId] = [];
    batchHistory[medId] = BatchMasterLogic.updateBatchList(batchHistory[medId]!, b);
    save(); 
  }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(
      id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, 
      partyGstin: party.gst, partyState: party.state, partyAddress: party.address, 
      partyDl: party.dl, partyEmail: party.email, items: items, totalAmount: total, 
      paymentMode: mode, invoiceType: party.isB2B ? "B2B" : "B2C"
    ));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        // Stock deduction includes FREE quantity
        medicines[idx].stock -= (it.qty + it.freeQty);
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.rate));
      }
    }
    save();
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock += (it.qty + it.freeQty);
        medicines[idx].purRate = it.purchaseRate;
        medicines[idx].mrp = it.mrp; medicines[idx].gst = it.gstRate;
        medicines[idx].rateA = it.rateA; medicines[idx].rateB = it.rateB; medicines[idx].rateC = it.rateC;
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.purchaseRate));
      }
    }
    save();
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

  void cancelBill(String id) {
    int i = sales.indexWhere((s) => s.id == id);
    if (i != -1 && sales[i].status != "Cancelled") {
      for (var it in sales[i].items) {
        int mi = medicines.indexWhere((m) => m.id == it.medicineID);
        if (mi != -1) medicines[mi].stock += (it.qty + it.freeQty);
      }
      sales[i].status = "Cancelled";
      sales[i].totalAmount = 0.0;
      save();
    }
  }

  void deleteParty(String id) {
    int i = parties.indexWhere((p) => p.id == id);
    if (i != -1 && parties[i].name != "CASH") {
      parties.removeAt(i);
      save();
    }
  }

  void addLog(String action, String details) {
    logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now()));
    save();
  }

  Future<void> masterReset() async {
    final dir = await getFYDirectory();
    final directory = Directory(dir);
    if (directory.existsSync()) directory.deleteSync(recursive: true);
    final p = await SharedPreferences.getInstance();
    await p.setInt('lastBillID', 0); 
    await p.setInt('lastPurID', 0);
    await switchYear(currentFY);
  }

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
