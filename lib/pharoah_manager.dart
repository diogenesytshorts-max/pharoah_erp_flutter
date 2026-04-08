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
  List<Medicine> masterMedicines = [];

  PharoahManager() {
    loadAllData();
  }

  // --- PERSISTENT SETTINGS ---
  bool get isSetupDone {
    final prefs = SharedPreferences.getInstance();
    // Logic will be handled in UI, but we provide data here
    return false; 
  }

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
      final salesFile = await _getFile('sales.json');
      await salesFile.writeAsString(jsonEncode(sales.map((e) => e.toMap()).toList()));
      notifyListeners();
    } catch (e) { print("Save Error: $e"); }
  }

  Future<void> loadAllData() async {
    try {
      final medsFile = await _getFile('medicines.json');
      if (await medsFile.exists()) {
        medicines = (jsonDecode(await medsFile.readAsString()) as List).map((e) => Medicine.fromMap(e)).toList();
      } else { medicines = []; }

      final partiesFile = await _getFile('parties.json');
      if (await partiesFile.exists()) {
        parties = (jsonDecode(await partiesFile.readAsString()) as List).map((e) => Party.fromMap(e)).toList();
      } else { parties = []; }

      if (!parties.any((p) => p.name == "CASH")) {
        parties.insert(0, Party(id: 'cash', name: "CASH", phone: "000"));
      }

      final salesFile = await _getFile('sales.json');
      if (await salesFile.exists()) {
        sales = (jsonDecode(await salesFile.readAsString()) as List).map((e) => Sale(
          id: e['id'], billNo: e['billNo'], partyName: e['partyName'],
          totalAmount: e['totalAmount'], paymentMode: e['paymentMode'],
          date: DateTime.parse(e['date']),
          items: (e['items'] as List).map((i) => BillItem(
            id: i['id'], srNo: i['srNo'], medicineID: i['medicineID'], name: i['name'],
            packing: i['packing'], batch: i['batch'], exp: i['exp'], hsn: i['hsn'],
            mrp: i['mrp'], qty: i['qty'], rate: i['rate'], discount: i['discount'],
            gstRate: i['gstRate'], cgst: i['cgst'], sgst: i['sgst'], total: i['total']
          )).toList()
        )).toList();
      }
      notifyListeners();
    } catch (e) { print("Load Error: $e"); }
  }

  void finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode}) {
    sales.add(Sale(id: DateTime.now().toString(), billNo: billNo, date: date, partyName: party.name, items: items, totalAmount: total, paymentMode: mode));
    for (var item in items) {
      int idx = medicines.indexWhere((m) => m.id == item.medicineID);
      if (idx != -1) { medicines[idx].stock -= item.qty.toInt(); }
    }
    save();
  }

  void addToLocalInventory(Medicine med) {
    if (!medicines.any((m) => m.name == med.name)) { medicines.add(med); save(); }
  }
}
