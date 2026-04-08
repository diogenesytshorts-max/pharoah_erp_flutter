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
  Map<String, List<BatchInfo>> batchHistory = {};
  String currentFY = "2025-26";

  PharoahManager() { 
    initManager(); 
  }

  Future<void> initManager() async {
    final p = await SharedPreferences.getInstance();
    currentFY = p.getString('fy') ?? "2025-26";
    await loadAllData();
  }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  // --- ROBUST SYNC SAVING ---
  Future<void> save() async {
    final path = await _localPath;
    try {
      // Saving all modules with Year-Specific FileNames
      File('$path/meds_$currentFY.json').writeAsStringSync(jsonEncode(medicines.map((e)=>e.toMap()).toList()));
      File('$path/parts_$currentFY.json').writeAsStringSync(jsonEncode(parties.map((e)=>e.toMap()).toList()));
      File('$path/sales_$currentFY.json').writeAsStringSync(jsonEncode(sales.map((e)=>e.toMap()).toList()));
      File('$path/purchases_$currentFY.json').writeAsStringSync(jsonEncode(purchases.map((e)=>e.toMap()).toList()));
      
      Map<String, dynamic> historyMap = {};
      batchHistory.forEach((k, v) => historyMap[k] = v.map((b) => b.toMap()).toList());
      File('$path/bats_$currentFY.json').writeAsStringSync(jsonEncode(historyMap));
      
      notifyListeners();
      debugPrint("All Data Saved Successfully for FY $currentFY");
    } catch (e) { 
      debugPrint("CRITICAL SAVE ERROR: $e"); 
    }
  }

  Future<void> loadAllData() async {
    final path = await _localPath;
    try {
      // 1. Load Medicines
      final mf = File('$path/meds_$currentFY.json');
      if (mf.existsSync()) {
        medicines = (jsonDecode(mf.readAsStringSync()) as List).map((e)=>Medicine.fromMap(e)).toList();
      } else {
        medicines = DemoData.getMedicines(); // Load 50 Demo Meds if new file
      }

      // 2. Load Parties
      final pf = File('$path/parts_$currentFY.json');
      if (pf.existsSync()) {
        parties = (jsonDecode(pf.readAsStringSync()) as List).map((e)=>Party.fromMap(e)).toList();
      } else {
        parties = [DemoData.getDemoParty()];
      }
      if (!parties.any((p) => p.name == "CASH")) parties.insert(0, Party(id: 'cash', name: "CASH"));

      // 3. Load Sales
      final sf = File('$path/sales_$currentFY.json');
      if (sf.existsSync()) {
        final List decoded = jsonDecode(sf.readAsStringSync());
        sales = decoded.map((e) => Sale(
          id: e['id'], billNo: e['billNo'], partyName: e['partyName'], paymentMode: e['paymentMode'],
          status: e['status'] ?? "Active", date: DateTime.parse(e['date']), 
          totalAmount: (e['totalAmount']??0).toDouble(),
          items: (e['items'] as List).map((i) => BillItem.fromMap(i)).toList(),
        )).toList();
      } else { sales = []; }

      // 4. Load Purchases
      final purF = File('$path/purchases_$currentFY.json');
      if (purF.existsSync()) {
        final List decoded = jsonDecode(purF.readAsStringSync());
        purchases = decoded.map((e) => Purchase.fromMap(e)).toList();
      } else { purchases = []; }

      // 5. Load Batch History
      final bf = File('$path/bats_$currentFY.json');
      if (bf.existsSync()) {
        Map<String, dynamic> decoded = jsonDecode(bf.readAsStringSync());
        decoded.forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
      } else { batchHistory = {}; }

      notifyListeners();
    } catch (e) { 
      debugPrint("LOAD ERROR: $e"); 
    }
  }

  // --- LOGIC: DELETE & REVERSE STOCK ---
  void deleteBill(String saleId) {
    int idx = sales.indexWhere((s) => s.id == saleId);
    if (idx != -1) {
      if (sales[idx].status == "Active") {
        for (var item in sales[idx].items) {
          int mIdx = medicines.indexWhere((m) => m.id == item.medicineID);
          if (mIdx != -1) medicines[mIdx].stock += item.qty.toInt();
        }
      }
      sales.removeAt(idx);
      save();
    }
  }

  // --- LOGIC: CANCEL BILL ---
  void cancelBill(String saleId) {
    int idx = sales.indexWhere((s) => s.id == saleId);
    if (idx != -1 && sales[idx].status != "Cancelled") {
      for (var item in sales[idx].items) {
        int mIdx = medicines.indexWhere((m) => m.id == item.medicineID);
        if (mIdx != -1) medicines[mIdx].stock += item.qty.toInt();
      }
      sales[idx].status = "Cancelled";
      sales[idx].totalAmount = 0.0;
      save();
    }
  }

  // --- FINALIZE SALE ---
  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(id: DateTime.now().millisecondsSinceEpoch.toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, paymentMode: mode));
    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= item.qty.toInt();
        _updateBatch(item.medicineID, BatchInfo(batch: item.batch, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: item.rate));
      }
    }
    save();
  }

  // --- FINALIZE PURCHASE ---
  void finalizePurchase({required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    purchases.add(Purchase(id: DateTime.now().millisecondsSinceEpoch.toString(), billNo: billNo, date: date, distributorName: party.name, items: items, totalAmount: total, paymentMode: mode));
    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) {
        medicines[idx].stock += (item.qty + item.freeQty).toInt();
        medicines[idx].mrp = item.mrp;
        _updateBatch(item.medicineID, BatchInfo(batch: item.batch, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: item.purchaseRate));
      }
    }
    save();
  }

  void _updateBatch(String mId, BatchInfo b) {
    if (!batchHistory.containsKey(mId)) batchHistory[mId] = [];
    int idx = batchHistory[mId]!.indexWhere((x) => x.batch == b.batch);
    if (idx != -1) batchHistory[mId]![idx] = b; else batchHistory[mId]!.add(b);
  }

  void addToLocalInventory(Medicine med) { 
    if (!medicines.any((m) => m.name == med.name)) { medicines.add(med); save(); } 
  }
}
