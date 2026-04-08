import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class PharoahManager with ChangeNotifier {
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  Map<String, List<BatchInfo>> batchHistory = {}; // MedicineID -> List of Batches

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
      
      final batchesFile = await _getFile('batch_history.json');
      Map<String, dynamic> historyMap = {};
      batchHistory.forEach((key, value) {
        historyMap[key] = value.map((b) => b.toMap()).toList();
      });
      await batchesFile.writeAsString(jsonEncode(historyMap));
      
      notifyListeners();
    } catch (e) { print(e); }
  }

  Future<void> loadAllData() async {
    try {
      final medsFile = await _getFile('medicines.json');
      if (await medsFile.exists()) {
        medicines = (jsonDecode(await medsFile.readAsString()) as List).map((e) => Medicine.fromMap(e)).toList();
      }
      
      final partiesFile = await _getFile('parties.json');
      if (await partiesFile.exists()) {
        parties = (jsonDecode(await partiesFile.readAsString()) as List).map((e) => Party.fromMap(e)).toList();
      }
      if (!parties.any((p) => p.name == "CASH")) parties.insert(0, Party(id: 'cash', name: "CASH"));

      final batchesFile = await _getFile('batch_history.json');
      if (await batchesFile.exists()) {
        Map<String, dynamic> decoded = jsonDecode(await batchesFile.readAsString());
        decoded.forEach((key, value) {
          batchHistory[key] = (value as List).map((b) => BatchInfo.fromMap(b)).toList();
        });
      }
      
      notifyListeners();
    } catch (e) { print(e); }
  }

  void updateBatchHistory(String medId, BatchInfo info) {
    if (!batchHistory.containsKey(medId)) batchHistory[medId] = [];
    int idx = batchHistory[medId]!.indexWhere((b) => b.batch == info.batch);
    if (idx != -1) {
      batchHistory[medId]![idx] = info;
    } else {
      batchHistory[medId]!.add(info);
    }
  }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, paymentMode: mode));
    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= item.qty.toInt();
        updateBatchHistory(item.medicineID, BatchInfo(batch: item.batch, exp: item.exp, packing: item.packing, mrp: item.mrp, rate: item.rate));
      }
    }
    save();
  }

  void addToLocalInventory(Medicine med) {
    if (!medicines.any((m) => m.name == med.name)) {
      medicines.add(med);
      save();
    }
  }
}
