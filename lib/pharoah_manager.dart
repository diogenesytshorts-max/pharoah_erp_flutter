import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class PharoahManager with ChangeNotifier {
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  Map<String, List<BatchInfo>> batchHistory = {};

  PharoahManager() { loadAllData(); }

  Future<File> _getFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  Future<void> save() async {
    try {
      final medsFile = await _getFile('medicines.json');
      await medsFile.writeAsString(jsonEncode(medicines.map((e) => e.toMap()).toList()));
      final partiesFile = await _getFile('parties.json');
      await partiesFile.writeAsString(jsonEncode(parties.map((e) => e.toMap()).toList()));
      final salesFile = await _getFile('sales_v2.json');
      await salesFile.writeAsString(jsonEncode(sales.map((e) => e.toMap()).toList()));
      
      final batchesFile = await _getFile('batch_history.json');
      Map<String, dynamic> historyMap = {};
      batchHistory.forEach((key, value) => historyMap[key] = value.map((b) => b.toMap()).toList());
      await batchesFile.writeAsString(jsonEncode(historyMap));
      
      notifyListeners();
    } catch (e) { print(e); }
  }

  Future<void> loadAllData() async {
    try {
      final medsFile = await _getFile('medicines.json');
      if (await medsFile.exists()) medicines = (jsonDecode(await medsFile.readAsString()) as List).map((e) => Medicine.fromMap(e)).toList();
      
      final partiesFile = await _getFile('parties.json');
      if (await partiesFile.exists()) parties = (jsonDecode(await partiesFile.readAsString()) as List).map((e) => Party.fromMap(e)).toList();
      if (!parties.any((p) => p.name == "CASH")) parties.insert(0, Party(id: 'cash', name: "CASH"));

      final salesFile = await _getFile('sales_v2.json');
      if (await salesFile.exists()) {
        final List decoded = jsonDecode(await salesFile.readAsString());
        sales = decoded.map((e) => Sale(
          id: e['id'], billNo: e['billNo'], partyName: e['partyName'], paymentMode: e['paymentMode'],
          date: DateTime.parse(e['date']), totalAmount: e['totalAmount'].toDouble(),
          items: (e['items'] as List).map((i) => BillItem.fromMap(i)).toList(),
        )).toList();
      }

      final batchesFile = await _getFile('batch_history.json');
      if (await batchesFile.exists()) {
        Map<String, dynamic> decoded = jsonDecode(await batchesFile.readAsString());
        decoded.forEach((k, v) => batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList());
      }
      notifyListeners();
    } catch (e) { print(e); }
  }

  // --- MODIFY KE LIYE STOCK REVERSE KARNA ---
  void deleteSaleAndReverseStock(String saleId) {
    int saleIdx = sales.indexWhere((s) => s.id == saleId);
    if (saleIdx != -1) {
      for (var item in sales[saleIdx].items) {
        int medIdx = medicines.indexWhere((m) => m.id == item.medicineID);
        if (medIdx != -1) {
          medicines[medIdx].stock += item.qty.toInt(); // Stock Wapas Badhao
        }
      }
      sales.removeAt(saleIdx);
      save();
    }
  }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, paymentMode: mode));
    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= item.qty.toInt();
        if (!batchHistory.containsKey(item.medicineID)) batchHistory[item.medicineID] = [];
        int bIdx = batchHistory[item.medicineID]!.indexWhere((b) => b.batch == item.batch);
        var bInfo = BatchInfo(batch: item.batch, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: item.rate);
        if (bIdx != -1) batchHistory[item.medicineID]![bIdx] = bInfo; else batchHistory[item.medicineID]!.add(bInfo);
      }
    }
    save();
  }

  void addToLocalInventory(Medicine med) { if (!medicines.any((m) => m.name == med.name)) { medicines.add(med); save(); } }
}
