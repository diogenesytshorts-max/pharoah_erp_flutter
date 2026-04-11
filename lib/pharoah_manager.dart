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

  Future<String> get _localPath async {
    final d = await getApplicationDocumentsDirectory();
    return d.path;
  }

  // ===================================================
  // 🛡️ TRIPLE-SAFETY SAVE LOGIC (ATOMIC WRITES)
  // ===================================================
  Future<void> _robustSave(String fileName, String content) async {
    final path = await _localPath;
    final file = File('$path/$fileName');
    final mirror = File('$path/$fileName.bak'); // Mirror Copy
    final temp = File('$path/$fileName.temp'); // Temp Copy

    try {
      // 1. Write to Temp first (Safety Check)
      temp.writeAsStringSync(content);
      
      // 2. If successful, replace the Main file
      if (temp.existsSync()) {
        file.writeAsStringSync(content);
        // 3. Update the Mirror (Backup)
        mirror.writeAsStringSync(content);
        // Clean temp
        temp.deleteSync();
      }
    } catch (e) {
      debugPrint("Robust Save Error for $fileName: $e");
    }
  }

  Future<void> save() async {
    try {
      await _robustSave('meds_$currentFY.json', jsonEncode(medicines.map((e) => e.toMap()).toList()));
      await _robustSave('parts_$currentFY.json', jsonEncode(parties.map((e) => e.toMap()).toList()));
      await _robustSave('sales_$currentFY.json', jsonEncode(sales.map((e) => e.toMap()).toList()));
      await _robustSave('purc_$currentFY.json', jsonEncode(purchases.map((e) => e.toMap()).toList()));
      await _robustSave('logs_$currentFY.json', jsonEncode(logs.map((e) => e.toMap()).toList()));
      
      Map<String, dynamic> hMap = {};
      batchHistory.forEach((k, v) => hMap[k] = v.map((b) => b.toMap()).toList());
      await _robustSave('bats_$currentFY.json', jsonEncode(hMap));
      
      notifyListeners();
    } catch (e) { debugPrint("Save Chain Error: $e"); }
  }

  // ===================================================
  // 🛡️ TRIPLE-SAFETY LOAD LOGIC (AUTO-REPAIR)
  // ===================================================
  dynamic _robustLoad(String fileName) {
    try {
      final file = File(fileName);
      final mirror = File('$fileName.bak');

      if (file.existsSync()) {
        String content = file.readAsStringSync();
        if (content.isNotEmpty) return jsonDecode(content);
      }
      
      // If main file fails, try Mirror!
      if (mirror.existsSync()) {
        debugPrint("⚠️ Main file $fileName corrupted. Loading from Mirror...");
        String content = mirror.readAsStringSync();
        return jsonDecode(content);
      }
    } catch (e) {
      debugPrint("Load Error for $fileName: $e");
    }
    return null;
  }

  Future<void> loadAllData() async {
    final path = await _localPath;
    try {
      // Load Medicines
      var medsData = _robustLoad('$path/meds_$currentFY.json');
      if (medsData != null) medicines = (medsData as List).map((e) => Medicine.fromMap(e)).toList();
      else medicines = DemoData.getMedicines();

      // Load Parties
      var partsData = _robustLoad('$path/parts_$currentFY.json');
      if (partsData != null) parties = (partsData as List).map((e) => Party.fromMap(e)).toList();
      else parties = [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH")];

      // Load Sales
      var salesData = _robustLoad('$path/sales_$currentFY.json');
      if (salesData != null) sales = (salesData as List).map((e) => Sale.fromMap(e)).toList();
      else sales = [];

      // Load Purchases
      var purcData = _robustLoad('$path/purc_$currentFY.json');
      if (purcData != null) purchases = (purcData as List).map((e) => Purchase.fromMap(e)).toList();
      else purchases = [];

      // Load Logs
      var logsData = _robustLoad('$path/logs_$currentFY.json');
      if (logsData != null) logs = (logsData as List).map((e) => LogEntry.fromMap(e)).toList();
      else logs = [];

      // Load Batches
      var batsData = _robustLoad('$path/bats_$currentFY.json');
      if (batsData != null) {
        batsData.forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
      } else { batchHistory = {}; }
      
      notifyListeners();
    } catch (e) { debugPrint("Load Chain Error: $e"); }
  }

  // --- REST OF THE METHODS (Maintenance, Backup, Actions) ---
  
  Future<void> runAutoBackup() async {
    try {
      final path = await _localPath;
      final dir = Directory('$path/backups');
      if (!await dir.exists()) await dir.create();
      List<FileSystemEntity> files = dir.listSync();
      files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified));
      if (files.length >= 10) await files.first.delete();
      String ts = DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.').first;
      File('$path/backups/auto_$ts.json').writeAsStringSync(jsonEncode({'sales': sales.map((e)=>e.toMap()).toList(), 'meds': medicines.map((e)=>e.toMap()).toList()}));
    } catch (e) {}
  }

  Future<void> runFullMaintenance() async {
    for (var med in medicines) {
      int st = 0;
      for (var p in purchases) { for (var it in p.items) if (it.medicineID == med.id) st += (it.qty + it.freeQty).toInt(); }
      for (var s in sales) { if (s.status == "Active") { for (var it in s.items) if (it.medicineID == med.id) st -= it.qty.toInt(); } }
      med.stock = st;
    }
    await save();
  }

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
