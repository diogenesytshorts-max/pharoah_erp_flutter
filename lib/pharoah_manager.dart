import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class PharoahManager with ChangeNotifier {
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Medicine> masterMedicines = [];

  PharoahManager() {
    loadAllData();
  }

  // --- FILE PATHS (Storage) ---
  Future<File> _getFile(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }

  // --- SAVE DATA ---
  Future<void> save() async {
    try {
      final medsFile = await _getFile('medicines.json');
      await medsFile.writeAsString(jsonEncode(medicines.map((e) => e.toMap()).toList()));

      final partiesFile = await _getFile('parties.json');
      await partiesFile.writeAsString(jsonEncode(parties.map((e) => e.toMap()).toList()));

      final salesFile = await _getFile('sales.json');
      await salesFile.writeAsString(jsonEncode(sales.map((e) => e.toMap()).toList()));
      
      notifyListeners(); // UI ko update karne ke liye
    } catch (e) {
      print("Save Error: $e");
    }
  }

  // --- LOAD DATA ---
  Future<void> loadAllData() async {
    try {
      // Load Medicines
      final medsFile = await _getFile('medicines.json');
      if (await medsFile.exists()) {
        String content = await medsFile.readAsString();
        List<dynamic> jsonList = jsonDecode(content);
        medicines = jsonList.map((e) => Medicine.fromMap(e)).toList();
      } else {
        medicines = getDemoItems(); // Initial Demo Data
      }

      // Load Parties
      final partiesFile = await _getFile('parties.json');
      if (await partiesFile.exists()) {
        String content = await partiesFile.readAsString();
        List<dynamic> jsonList = jsonDecode(content);
        parties = jsonList.map((e) => Party.fromMap(e)).toList();
      } else {
        parties = [getDemoParty()];
      }

      // CASH Party Check
      if (!parties.any((p) => p.name == "CASH")) {
        parties.insert(0, Party(id: 'cash_id', name: "CASH", phone: "000"));
      }

      // Load Sales
      final salesFile = await _getFile('sales.json');
      if (await salesFile.exists()) {
        String content = await salesFile.readAsString();
        List<dynamic> jsonList = jsonDecode(content);
        // Sales loading logic depends on date format, keeping simple for now
      }

      masterMedicines = getDemoItems();
      notifyListeners();
    } catch (e) {
      print("Load Error: $e");
    }
  }

  // --- BUSINESS LOGIC ---
  void finalizeSale({
    required String billNo,
    required DateTime date,
    required Party party,
    required List<BillItem> items,
    required double total,
    required String mode,
  }) {
    final newSale = Sale(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      billNo: billNo,
      date: date,
      partyName: party.name,
      items: items,
      totalAmount: total,
      paymentMode: mode,
    );
    sales.add(newSale);

    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) {
        medicines[idx].stock -= item.qty.toInt();
        // Update batch history logic would go here
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

  double getOutstanding(String partyName) {
    return sales
        .where((s) => s.partyName == partyName && s.paymentMode == "CREDIT")
        .fold(0, (sum, item) => sum + item.totalAmount);
  }

  // --- DEMO DATA HELPERS ---
  List<Medicine> getDemoItems() {
    return [
      Medicine(id: '1', name: "DOLO 650 MG", packing: "15 TAB", mrp: 30.90, rateA: 24.50, rateB: 23, rateC: 22, stock: 100),
      Medicine(id: '2', name: "PAN 40 MG", packing: "10 TAB", mrp: 145.0, rateA: 110.0, rateB: 105, rateC: 100, stock: 50),
    ];
  }

  Party getDemoParty() {
    return Party(id: 'd1', name: "DEMO PHARMA DISTRIBUTORS", phone: "9876543210", address: "Udaipur, Rajasthan");
  }
}
