import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'demo_data.dart'; // IMPORTED

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
      File('$path/meds.json').writeAsStringSync(jsonEncode(medicines.map((e) => e.toMap()).toList()));
      File('$path/parts.json').writeAsStringSync(jsonEncode(parties.map((e) => e.toMap()).toList()));
      File('$path/sales_final.json').writeAsStringSync(jsonEncode(sales.map((e) => e.toMap()).toList()));
      Map<String, dynamic> hMap = {};
      batchHistory.forEach((k, v) => hMap[k] = v.map((b) => b.toMap()).toList());
      File('$path/bats.json').writeAsStringSync(jsonEncode(hMap));
      notifyListeners();
    } catch (e) { debugPrint("Save Error: $e"); }
  }

  Future<void> loadAllData() async {
    final path = await _localPath;
    try {
      final medsF = File('$path/meds.json');
      if (medsF.existsSync()) {
        medicines = (jsonDecode(medsF.readAsStringSync()) as List).map((e) => Medicine.fromMap(e)).toList();
      }
      // LOAD DEMO MEDICINES IF EMPTY
      if (medicines.isEmpty) medicines = DemoData.getMedicines();

      final partF = File('$path/parties.json');
      if (partF.existsSync()) {
        parties = (jsonDecode(partF.readAsStringSync()) as List).map((e) => Party.fromMap(e)).toList();
      }
      // LOAD DEMO PARTY AND CASH IF EMPTY
      if (parties.isEmpty || parties.length <= 1) {
        if (!parties.any((p) => p.name == "CASH")) parties.insert(0, Party(id: 'cash', name: "CASH"));
        parties.add(DemoData.getDemoParty());
      }

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
    } catch (e) { debugPrint("Load Error: $e"); }
  }

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
