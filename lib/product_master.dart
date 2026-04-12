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

  Future<void> initManager() async {
    final p = await SharedPreferences.getInstance();
    currentFY = p.getString('fy') ?? "2025-26";
    companyState = p.getString('compState') ?? "Rajasthan";
    await loadAllData();
  }

  // --- SMART DATE LOGIC ---
  DateTime get smartDate {
    DateTime now = DateTime.now();
    if (now.isAfter(fyStartDate.subtract(const Duration(days: 1))) && now.isBefore(fyEndDate.add(const Duration(days: 1)))) return now;
    return fyStartDate;
  }

  DateTime get fyStartDate {
    try { int y = int.parse(currentFY.split('-')[0]); if (y < 2000) y += 2000; return DateTime(y, 4, 1); } catch (e) { return DateTime(DateTime.now().year, 4, 1); }
  }

  DateTime get fyEndDate {
    try { int y = int.parse(currentFY.split('-')[0]); if (y < 2000) y += 2000; return DateTime(y + 1, 3, 31); } catch (e) { return DateTime(DateTime.now().year + 1, 3, 31); }
  }

  Future<String> get _localPath async { final d = await getApplicationDocumentsDirectory(); return d.path; }

  Future<void> _robustSave(String fileName, String content) async {
    final path = await _localPath;
    final file = File('$path/$fileName');
    try { file.writeAsStringSync(content); } catch (e) { debugPrint("Save Error: $e"); }
  }

  dynamic _robustLoad(String fileName) {
    try {
      final f = File(fileName);
      if (f.existsSync()) { String c = f.readAsStringSync(); if (c.isNotEmpty) return jsonDecode(c); }
    } catch (e) { debugPrint("Load Error: $e"); }
    return null;
  }

  Future<void> save() async {
    await _robustSave('meds_$currentFY.json', jsonEncode(medicines.map((e)=>e.toMap()).toList()));
    await _robustSave('parts_$currentFY.json', jsonEncode(parties.map((e)=>e.toMap()).toList()));
    await _robustSave('sales_$currentFY.json', jsonEncode(sales.map((e)=>e.toMap()).toList()));
    await _robustSave('purc_$currentFY.json', jsonEncode(purchases.map((e)=>e.toMap()).toList()));
    await _robustSave('logs_$currentFY.json', jsonEncode(logs.map((e)=>e.toMap()).toList()));
    await _robustSave('bats_$currentFY.json', jsonEncode(batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList()))));
    notifyListeners();
  }

  Future<void> loadAllData() async {
    final path = await _localPath;
    var mD = _robustLoad('$path/meds_$currentFY.json');
    medicines = mD != null ? (mD as List).map((e)=>Medicine.fromMap(e)).toList() : DemoData.getMedicines();
    var pD = _robustLoad('$path/parts_$currentFY.json');
    parties = pD != null ? (pD as List).map((e)=>Party.fromMap(e)).toList() : [DemoData.getDemoParty(), Party(id: 'cash', name: "CASH")];
    var sD = _robustLoad('$path/sales_$currentFY.json');
    sales = sD != null ? (sD as List).map((e)=>Sale.fromMap(e)).toList() : [];
    var purD = _robustLoad('$path/purc_$currentFY.json');
    purchases = purD != null ? (purD as List).map((e)=>Purchase.fromMap(e)).toList() : [];
    var lD = _robustLoad('$path/logs_$currentFY.json');
    logs = lD != null ? (lD as List).map((e)=>LogEntry.fromMap(e)).toList() : [];
    var bD = _robustLoad('$path/bats_$currentFY.json');
    if (bD != null) { bD.forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList()); }
    notifyListeners();
  }

  // --- BATCH YAAD RAKHNE KI MASTER LOGIC ---
  void saveBatchCentrally(String medId, BatchInfo b) {
    if (!batchHistory.containsKey(medId)) batchHistory[medId] = [];
    batchHistory[medId] = BatchMasterLogic.updateBatchList(batchHistory[medId]!, b);
    save(); // Database mein hamesha ke liye save ho gaya
  }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, partyAddress: party.address, partyDl: party.dl, partyEmail: party.email, items: items, totalAmount: total, paymentMode: mode, invoiceType: party.isB2B ? "B2B" : "B2C"));
    for (var it in items) {
      int idx = medicines.indexWhere((m) => m.id == it.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= it.qty.toInt();
        // Sale ke waqt bhi batch details yaad rakho
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
        medicines[idx].stock += (it.qty + it.freeQty).toInt();
        medicines[idx].purRate = it.purchaseRate;
        medicines[idx].mrp = it.mrp; medicines[idx].gst = it.gstRate;
        medicines[idx].rateA = it.rateA; medicines[idx].rateB = it.rateB; medicines[idx].rateC = it.rateC;
        // Purchase ke waqt naya batch database mein save karo
        saveBatchCentrally(it.medicineID, BatchInfo(batch: it.batch, exp: it.exp, packing: it.packing, mrp: it.mrp, rate: it.purchaseRate));
      }
    }
    save();
  }

  // ... Baki functions (deletePurchase, deleteBill etc.) same rahenge
  void deletePurchase(String id) { int i = purchases.indexWhere((p) => p.id == id); if (i != -1) { for (var it in purchases[i].items) { int mi = medicines.indexWhere((m) => m.id == it.medicineID); if (mi != -1) medicines[mi].stock -= (it.qty + it.freeQty).toInt(); } purchases.removeAt(i); save(); } }
  void deleteBill(String id) { int i = sales.indexWhere((s) => s.id == id); if (i != -1) { if (sales[i].status == "Active") { for (var it in sales[i].items) { int mi = medicines.indexWhere((m) => m.id == it.medicineID); if (mi != -1) medicines[mi].stock += it.qty.toInt(); } } sales.removeAt(i); save(); } }
  void cancelBill(String id) { int i = sales.indexWhere((s) => s.id == id); if (i != -1 && sales[i].status != "Cancelled") { for (var it in sales[i].items) { int mi = medicines.indexWhere((m) => m.id == it.medicineID); if (mi != -1) medicines[mi].stock += it.qty.toInt(); } sales[i].status = "Cancelled"; sales[i].totalAmount = 0.0; save(); } }
  void deleteParty(String id) { int i = parties.indexWhere((p) => p.id == id); if (i != -1 && parties[i].name != "CASH") { parties.removeAt(i); save(); } }
  void addLog(String action, String details) { logs.add(LogEntry(id: DateTime.now().toString(), action: action, details: details, time: DateTime.now())); save(); }
  Future<void> runAutoBackup() async { try { final path = await _localPath; final dir = Directory('$path/backups'); if (!await dir.exists()) await dir.create(); List<FileSystemEntity> files = dir.listSync(); files.sort((a, b) => a.statSync().modified.compareTo(b.statSync().modified)); if (files.length >= 10) await files.first.delete(); String ts = DateTime.now().toString().replaceAll(' ', '_').replaceAll(':', '-').split('.').first; File('$path/backups/auto_$ts.json').writeAsStringSync(jsonEncode({'meds': medicines.map((e)=>e.toMap()).toList(), 'sales': sales.map((e)=>e.toMap()).toList()})); } catch (e) {} }
  Future<void> runFullMaintenance() async { for (var med in medicines) { int st = 0; for (var p in purchases) { for (var it in p.items) if (it.medicineID == med.id) st += (it.qty + it.freeQty).toInt(); } for (var s in sales) { if (s.status == "Active") { for (var it in s.items) if (it.medicineID == med.id) st -= it.qty.toInt(); } } med.stock = st; } await save(); }
  Future<void> masterReset() async { final path = await _localPath; final files = ['$path/meds_$currentFY.json', '$path/parts_$currentFY.json', '$path/sales_$currentFY.json', '$path/purc_$currentFY.json', '$path/logs_$currentFY.json', '$path/bats_$currentFY.json']; for (var f in files) { if (File(f).existsSync()) File(f).deleteSync(); } final p = await SharedPreferences.getInstance(); await p.setInt('lastBillID', 0); await p.setInt('lastPurID', 0); batchHistory.clear(); await loadAllData(); }
}
