import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'demo_data.dart';

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

  Future<void> initManager() async {
    final p = await SharedPreferences.getInstance();
    currentFY = p.getString('fy') ?? "2025-26";
    companyState = p.getString('compState') ?? "Rajasthan";
    await loadAllData();
  }

  // --- 1. FINANCIAL YEAR LOGIC ---
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

  Future<String> get _localPath async {
    final d = await getApplicationDocumentsDirectory();
    return d.path;
  }

  // --- 2. ROLLING AUTO-BACKUP (LAST 10 LOGINS) ---
  Future<void> runAutoBackup() async {
    try {
      final path = await _localPath;
      final dir = Directory('$path/backups');
      if (!await dir.exists()) await dir.create();

      List<FileSystemEntity> files = dir.listSync();
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      if (files.length >= 10) await files.first.delete();

      String ts = DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.').first;
      File('$path/backups/auto_$ts.json').writeAsStringSync(jsonEncode({
        'meds': medicines.map((e) => e.toMap()).toList(),
        'parts': parties.map((e) => e.toMap()).toList(),
        'sales': sales.map((e) => e.toMap()).toList(),
        'purc': purchases.map((e) => e.toMap()).toList(),
      }));
    } catch (e) { debugPrint("Backup Error: $e"); }
  }

  // --- 3. SYSTEM MAINTENANCE (REPAIR) ---
  Future<void> runFullMaintenance() async {
    for (var med in medicines) {
      int stock = 0;
      for (var p in purchases) {
        for (var it in p.items) { if (it.medicineID == med.id) stock += (it.qty + it.freeQty).toInt(); }
      }
      for (var s in sales) {
        if (s.status == "Active") {
          for (var it in s.items) { if (it.medicineID == med.id) stock -= it.qty.toInt(); }
        }
      }
      med.stock = stock;
    }
    await save();
  }

  // --- 4. FINANCIAL YEAR TRANSFER ---
  Future<void> transferToNewYear(String targetFY) async {
    final path = await _localPath;
    File('$path/meds_$targetFY.json').writeAsStringSync(jsonEncode(medicines.map((e) => e.toMap()).toList()));
    File('$path/parts_$targetFY.json').writeAsStringSync(jsonEncode(parties.map((e) => e.toMap()).toList()));
  }

  // --- 5. CORE PERSISTENCE ---
  Future<void> save() async {
    final path = await _localPath;
    try {
      File('$path/meds_$currentFY.json').writeAsStringSync(jsonEncode(medicines.map((e) => e.toMap()).toList()));
      File('$path/parts_$currentFY.json').writeAsStringSync(jsonEncode(parties.map((e) => e.toMap()).toList()));
      File('$path/sales_$currentFY.json').writeAsStringSync(jsonEncode(sales.map((e) => e.toMap()).toList()));
      File('$path/purc_$currentFY.json').writeAsStringSync(jsonEncode(purchases.map((e) => e.toMap()).toList()));
      File('$path/logs_$currentFY.json').writeAsStringSync(jsonEncode(logs.map((e) => e.toMap()).toList()));
      Map<String, dynamic> hMap = {};
      batchHistory.forEach((k, v) => hMap[k] = v.map((b) => b.toMap()).toList());
      File('$path/bats_$currentFY.json').writeAsStringSync(jsonEncode(hMap));
      notifyListeners();
    } catch (e) { debugPrint("Save Error: $e"); }
  }

  Future<void> loadAllData() async {
    final path = await _localPath;
    try {
      final mf = File('$path/meds_$currentFY.json');
      if (mf.existsSync()) medicines = (jsonDecode(mf.readAsStringSync()) as List).map((e) => Medicine.fromMap(e)).toList();
      else medicines = DemoData.getMedicines();

      final pf = File('$path/parts_$currentFY.json');
      if (pf.existsSync()) parties = (jsonDecode(pf.readAsStringSync()) as List).map((e) => Party.fromMap(e)).toList();
      else parties = [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH")];

      final sf = File('$path/sales_$currentFY.json');
      if (sf.existsSync()) sales = (jsonDecode(sf.readAsStringSync()) as List).map((e) => Sale.fromMap(e)).toList();
      else sales = [];

      final purF = File('$path/purc_$currentFY.json');
      if (purF.existsSync()) purchases = (jsonDecode(purF.readAsStringSync()) as List).map((e) => Purchase.fromMap(e)).toList();
      else purchases = [];

      final lf = File('$path/logs_$currentFY.json');
      if (lf.existsSync()) logs = (jsonDecode(lf.readAsStringSync()) as List).map((e) => LogEntry.fromMap(e)).toList();
      else logs = [];

      final bf = File('$path/bats_$currentFY.json');
      if (bf.existsSync()) {
        Map d = jsonDecode(bf.readAsStringSync());
        d.forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
      } else { batchHistory = {}; }
      notifyListeners();
    } catch (e) { debugPrint("Load Error: $e"); }
  }

  // --- 6. BUSINESS ACTIONS ---
  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode, invoiceType: party.isB2B ? "B2B" : "B2C"));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= it.qty.toInt();
        _updateBatch(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.rate));
      }
    }
    save();
  }

  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().toString(), internalNo: internalNo, billNo: billNo, date: date, distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock += (it.qty + it.freeQty).toInt();
        medicines[idx].purRate = it.purchaseRate;
        medicines[idx].mrp = it.mrp; medicines[idx].gst = it.gstRate;
        medicines[idx].rateA = it.rateA; medicines[idx].rateB = it.rateB; medicines[idx].rateC = it.rateC;
        _updateBatch(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.purchaseRate));
      }
    }
    save();
  }

  void deletePurchase(String id) {
    int i = purchases.indexWhere((p) => p.id == id);
    if (i != -1) {
      for (var it in purchases[i].items) {
        int mi = medicines.indexWhere((m) => m.id == it.medicineID);
        if (mi != -1) medicines[mi].stock -= (it.qty + it.freeQty).toInt();
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
          if (mi != -1) medicines[mi].stock += it.qty.toInt();
        }
      }
      sales.removeAt(i);
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

  void _updateBatch(String mId, BatchInfo b) {
    if (!batchHistory.containsKey(mId)) batchHistory[mId] = [];
    int idx = batchHistory[mId]!.indexWhere((x) => x.batch == b.batch);
    if (idx != -1) batchHistory[mId]![idx] = b; else batchHistory[mId]!.add(b);
  }

  void addLog(String action, String details) {
    logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now()));
    save();
  }

  Future<void> masterReset() async {
    final path = await _localPath;
    final files = ['$path/meds_$currentFY.json', '$path/parts_$currentFY.json', '$path/sales_$currentFY.json', '$path/purc_$currentFY.json', '$path/logs_$currentFY.json', '$path/bats_$currentFY.json'];
    for (var f in files) { if (File(f).existsSync()) File(f).deleteSync(); }
    final p = await SharedPreferences.getInstance();
    await p.setInt('lastBillID', 0); await p.setInt('lastPurID', 0);
    batchHistory.clear(); await loadAllData();
  }
}
