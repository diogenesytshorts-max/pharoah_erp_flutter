import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';

class PharoahManager with ChangeNotifier {
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  Map<String, List<BatchInfo>> batchHistory = {};

  PharoahManager() { loadAllData(); }

  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<void> save() async {
    final path = await _localPath;
    try {
      File('$path/medicines.json').writeAsStringSync(jsonEncode(medicines.map((e) => e.toMap()).toList()));
      File('$path/parties.json').writeAsStringSync(jsonEncode(parties.map((e) => e.toMap()).toList()));
      File('$path/sales_final.json').writeAsStringSync(jsonEncode(sales.map((e) => e.toMap()).toList()));
      
      Map<String, dynamic> historyMap = {};
      batchHistory.forEach((k, v) => historyMap[k] = v.map((b) => b.toMap()).toList());
      File('$path/batches.json').writeAsStringSync(jsonEncode(historyMap));
      notifyListeners();
    } catch (e) { print("Save Error: $e"); }
  }

  Future<void> loadAllData() async {
    final path = await _localPath;
    try {
      final medsF = File('$path/medicines.json');
      if (medsF.existsSync()) medicines = (jsonDecode(medsF.readAsStringSync()) as List).map((e) => Medicine.fromMap(e)).toList();

      final partF = File('$path/parties.json');
      if (partF.existsSync()) parties = (jsonDecode(partF.readAsStringSync()) as List).map((e) => Party.fromMap(e)).toList();
      if (!parties.any((p) => p.name == "CASH")) parties.insert(0, Party(id: 'cash', name: "CASH"));

      final saleF = File('$path/sales_final.json');
      if (saleF.existsSync()) {
        final List decoded = jsonDecode(saleF.readAsStringSync());
        sales = decoded.map((e) => Sale(
          id: e['id'], billNo: e['billNo'], partyName: e['partyName'], paymentMode: e['paymentMode'],
          status: e['status'] ?? "Active", date: DateTime.parse(e['date']), totalAmount: (e['totalAmount']??0).toDouble(),
          items: (e['items'] as List).map((i) => BillItem.fromMap(i)).toList(),
        )).toList();
      }

      final batF = File('$path/batches.json');
      if (batF.existsSync()) {
        Map<String, dynamic> decoded = jsonDecode(batF.readAsStringSync());
        decoded.forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
      }
      notifyListeners();
    } catch (e) { print("Load Error: $e"); }
  }

  void reverseStock(String saleId) {
    int sIdx = sales.indexWhere((s) => s.id == saleId);
    if (sIdx != -1) {
      for (var item in sales[sIdx].items) {
        int mIdx = medicines.indexWhere((m) => m.id == item.medicineID);
        if (mIdx != -1) medicines[mIdx].stock += item.qty.toInt();
      }
    }
  }

  void deleteBill(String saleId) async {
    reverseStock(saleId);
    sales.removeWhere((s) => s.id == saleId);
    // Series adjust: lastID - 1 is risky if not latest, so we keep it as is.
    await save();
  }

  void cancelBill(String saleId) async {
    int idx = sales.indexWhere((s) => s.id == saleId);
    if (idx != -1 && sales[idx].status != "Cancelled") {
      reverseStock(saleId);
      sales[idx].status = "Cancelled";
      sales[idx].totalAmount = 0.0; // Outstanding removed
      await save();
    }
  }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(id: DateTime.now().millisecondsSinceEpoch.toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, paymentMode: mode));
    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= item.qty.toInt();
        if (!batchHistory.containsKey(item.medicineID)) batchHistory[item.medicineID] = [];
        batchHistory[item.medicineID]!.add(BatchInfo(batch: item.batch, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: item.rate));
      }
    }
    save();
  }

  void addToLocalInventory(Medicine med) { if (!medicines.any((m) => m.name == med.name)) { medicines.add(med); save(); } }
}
