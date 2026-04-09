import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'demo_data.dart';

class PharoahManager with ChangeNotifier {
  // --- STATE DATA ---
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<LogEntry> logs = [];
  Map<String, List<BatchInfo>> batchHistory = {};
  
  String currentFY = "2025-26";
  String companyState = "Rajasthan"; // Standard for GST calculation

  PharoahManager() {
    initManager();
  }

  // --- INITIALIZATION ---
  Future<void> initManager() async {
    final p = await SharedPreferences.getInstance();
    currentFY = p.getString('fy') ?? "2025-26";
    companyState = p.getString('compState') ?? "Rajasthan";
    await loadAllData();
  }

  // --- STORAGE HELPERS ---
  Future<String> get _localPath async {
    final d = await getApplicationDocumentsDirectory();
    return d.path;
  }

  void addLog(String action, String details) {
    logs.add(LogEntry(
      id: DateTime.now().toString(), 
      action: action, 
      details: details, 
      time: DateTime.now()
    ));
    save();
  }

  // --- PERSISTENCE: SAVE ALL TO JSON ---
  Future<void> save() async {
    final path = await _localPath;
    try {
      File('$path/meds_$currentFY.json').writeAsStringSync(jsonEncode(medicines.map((e) => e.toMap()).toList()));
      File('$path/parts_$currentFY.json').writeAsStringSync(jsonEncode(parties.map((e) => e.toMap()).toList()));
      File('$path/sales_$currentFY.json').writeAsStringSync(jsonEncode(sales.map((e) => e.toMap()).toList()));
      File('$path/purc_$currentFY.json').writeAsStringSync(jsonEncode(purchases.map((e) => e.toMap()).toList()));
      File('$path/logs_$currentFY.json').writeAsStringSync(jsonEncode(logs.map((e) => e.toMap()).toList()));
      
      // Save batch history map
      Map<String, dynamic> hMap = {};
      batchHistory.forEach((k, v) => hMap[k] = v.map((b) => b.toMap()).toList());
      File('$path/bats_$currentFY.json').writeAsStringSync(jsonEncode(hMap));
      
      notifyListeners(); // Refresh UI components
    } catch (e) {
      debugPrint("System Save Error: $e");
    }
  }

  // --- PERSISTENCE: LOAD ALL FROM JSON ---
  Future<void> loadAllData() async {
    final path = await _localPath;
    try {
      // 1. Load Medicines
      final mf = File('$path/meds_$currentFY.json');
      if (mf.existsSync()) {
        medicines = (jsonDecode(mf.readAsStringSync()) as List).map((e) => Medicine.fromMap(e)).toList();
      } else {
        medicines = DemoData.getMedicines();
      }

      // 2. Load Parties
      final pf = File('$path/parts_$currentFY.json');
      if (pf.existsSync()) {
        parties = (jsonDecode(pf.readAsStringSync()) as List).map((e) => Party.fromMap(e)).toList();
      } else {
        parties = [DemoData.getDemoParty()];
        if (!parties.any((p) => p.name == "CASH")) parties.insert(0, Party(id: 'cash', name: "CASH"));
      }

      // 3. Load Sales
      final sf = File('$path/sales_$currentFY.json');
      if (sf.existsSync()) {
        final List d = jsonDecode(sf.readAsStringSync());
        sales = d.map((e) => Sale.fromMap(e)).toList();
      }

      // 4. Load Purchases
      final purF = File('$path/purc_$currentFY.json');
      if (purF.existsSync()) {
        final List d = jsonDecode(purF.readAsStringSync());
        purchases = d.map((e) => Purchase.fromMap(e)).toList();
      }

      // 5. Load Audit Logs
      final lf = File('$path/logs_$currentFY.json');
      if (lf.existsSync()) {
        logs = (jsonDecode(lf.readAsStringSync()) as List).map((e) => LogEntry.fromMap(e)).toList();
      }

      // 6. Load Batch History
      final bf = File('$path/bats_$currentFY.json');
      if (bf.existsSync()) {
        Map<String, dynamic> d = jsonDecode(bf.readAsStringSync());
        d.forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint("System Load Error: $e");
    }
  }

  // --- MASTER RESET: DATA WIPE ---
  Future<void> masterReset() async {
    final path = await _localPath;
    final files = [
      '$path/meds_$currentFY.json', '$path/parts_$currentFY.json',
      '$path/sales_$currentFY.json', '$path/purc_$currentFY.json',
      '$path/logs_$currentFY.json', '$path/bats_$currentFY.json'
    ];
    for (var f in files) {
      File file = File(f);
      if (file.existsSync()) file.deleteSync();
    }
    final p = await SharedPreferences.getInstance();
    await p.setInt('lastBillID', 0);
    await p.setInt('lastPurID', 0);
    await loadAllData();
    addLog("SYSTEM RESET", "Database was completely wiped clean.");
  }

  // --- BUSINESS LOGIC: FINALIZE SALE ---
  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    String invType = party.isB2B ? "B2B" : "B2C";
    addLog("SALE", "Invoice $billNo ($invType) issued to ${party.name}");
    
    sales.add(Sale(
      id: DateTime.now().toString(), 
      billNo: billNo, 
      date: date, 
      partyName: party.name, 
      items: items, 
      totalAmount: total, 
      paymentMode: mode,
      invoiceType: invType
    ));

    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= item.qty.toInt(); // Reduce Stock
        // Record this batch info for future sale suggestions
        _updateBatch(item.medicineID, BatchInfo(batch: item.batch, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: item.rate));
      }
    }
    save();
  }

  // --- BUSINESS LOGIC: FINALIZE PURCHASE ---
  void finalizePurchase({required String internalNo, required String billNo, required DateTime date, required Party party, required List<PurchaseItem> items, required double total, required String mode}) {
    addLog("PURCHASE", "Entry $internalNo (Bill: $billNo) from ${party.name}");
    
    purchases.add(Purchase(
      id: DateTime.now().toString(), 
      internalNo: internalNo, 
      billNo: billNo, 
      date: date, 
      distributorName: party.name, 
      items: items, 
      totalAmount: total, 
      paymentMode: mode
    ));

    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) {
        // Update Stock and Master Pricing
        medicines[idx].stock += (item.qty + item.freeQty).toInt();
        medicines[idx].purRate = item.purchaseRate; // For Stock Valuation
        medicines[idx].mrp = item.mrp;
        medicines[idx].gst = item.gstRate;
        medicines[idx].rateA = item.rateA;
        medicines[idx].rateB = item.rateB;
        medicines[idx].rateC = item.rateC;
        
        // Save batch info
        _updateBatch(item.medicineID, BatchInfo(batch: item.batch, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: item.purchaseRate));
      }
    }
    save();
  }

  // Batch Suggestion Helper
  void _updateBatch(String mId, BatchInfo b) {
    if (!batchHistory.containsKey(mId)) batchHistory[mId] = [];
    int idx = batchHistory[mId]!.indexWhere((x) => x.batch == b.batch);
    if (idx != -1) batchHistory[mId]![idx] = b; else batchHistory[mId]!.add(b);
  }

  // --- STOCK REVERSAL: DELETE BILL ---
  void deleteBill(String id) {
    int i = sales.indexWhere((s) => s.id == id);
    if (i != -1) {
      addLog("DELETE", "Invoice ${sales[i].billNo} deleted. Stock reversed.");
      if (sales[i].status == "Active") {
        for (var it in sales[i].items) {
          int mi = medicines.indexWhere((m) => m.id == it.medicineID);
          if (mi != -1) medicines[mi].stock += it.qty.toInt(); // Reverse Stock
        }
      }
      sales.removeAt(i);
      save();
    }
  }

  // --- STOCK REVERSAL: CANCEL BILL ---
  void cancelBill(String id) {
    int i = sales.indexWhere((s) => s.id == id);
    if (i != -1 && sales[i].status != "Cancelled") {
      addLog("CANCEL", "Invoice ${sales[i].billNo} cancelled. Stock reversed.");
      for (var it in sales[i].items) {
        int mi = medicines.indexWhere((m) => m.id == it.medicineID);
        if (mi != -1) medicines[mi].stock += it.qty.toInt(); // Reverse Stock
      }
      sales[i].status = "Cancelled";
      sales[i].totalAmount = 0.0;
      save();
    }
  }

  // Safety helper
  void addToLocalInventory(Medicine med) { 
    if (!medicines.any((m) => m.name == med.name)) { 
      medicines.add(med); 
      save(); 
    } 
  }
}
