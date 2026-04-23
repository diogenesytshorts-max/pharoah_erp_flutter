import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'models.dart';

class FYTransferEngine {
  
  /// MAIN FUNCTION: Purane saal se naye saal mein data le jana
  static Future<bool> transferData({
    required String sourceFY,
    required String targetFY,
  }) async {
    try {
      final root = await getApplicationDocumentsDirectory();
      final sourcePath = '${root.path}/DATA_FY_$sourceFY';
      final targetPath = '${root.path}/DATA_FY_$targetFY';

      final sourceDir = Directory(sourcePath);
      final targetDir = Directory(targetPath);

      // 1. Agar target folder pehle se hai, toh hum overwrite nahi karenge (Safety)
      if (!await targetDir.exists()) {
        await targetDir.create(recursive: true);
      }

      // 2. Load Source Data
      dynamic loadJson(String name) {
        final f = File('$sourcePath/$name');
        return f.existsSync() ? jsonDecode(f.readAsStringSync()) : null;
      }

      List<Medicine> oldMeds = (loadJson('meds.json') as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? [];
      List<Party> oldParties = (loadJson('parts.json') as List?)?.map((e) => Party.fromMap(e)).toList() ?? [];
      List<Sale> oldSales = (loadJson('sales.json') as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
      List<Purchase> oldPurc = (loadJson('purc.json') as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
      List<Voucher> oldVouc = (loadJson('vouc.json') as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];

      // 3. CALCULATE NEW PARTY BALANCES (Opening Balances for New Year)
      List<Party> newParties = oldParties.map((p) {
        if (p.name == "CASH") return p; // Cash handles separately

        double runningBal = p.opBal;
        // Sales add to Dr
        for (var s in oldSales.where((s) => s.partyName == p.name && s.status == "Active")) {
          runningBal += s.totalAmount;
        }
        // Purchases subtract (Credit)
        for (var pr in oldPurc.where((pr) => pr.distributorName == p.name)) {
          runningBal -= pr.totalAmount;
        }
        // Vouchers
        for (var v in oldVouc.where((v) => v.partyName == p.name)) {
          if (v.type == "Receipt") runningBal -= v.amount;
          if (v.type == "Payment") runningBal += v.amount;
        }

        // Update Opening Balance for New Year
        p.opBal = runningBal;
        return p;
      }).toList();

      // 4. PREPARE ITEM MASTER (Closing Stock becomes Opening Stock)
      // Stock updates automatically because 'Medicine.stock' already has the current value.
      // We just reset transactional history.

      // 5. SAVE TO NEW FY DIRECTORY
      Future saveToNew(String name, dynamic data) async {
        await File('$targetPath/$name').writeAsString(jsonEncode(data));
      }

      await saveToNew('meds.json', oldMeds.map((e) => e.toMap()).toList());
      await saveToNew('parts.json', newParties.map((e) => e.toMap()).toList());
      await saveToNew('bats.json', loadJson('bats.json') ?? {}); // Copy batch history as is
      
      // Copy Static Masters
      await saveToNew('routs.json', loadJson('routs.json') ?? []);
      await saveToNew('comps.json', loadJson('comps.json') ?? []);
      await saveToNew('salts.json', loadJson('salts.json') ?? []);
      await saveToNew('dtypes.json', loadJson('dtypes.json') ?? []);

      // RESET TRANSACTIONS FOR NEW YEAR
      await saveToNew('sales.json', []);
      await saveToNew('purc.json', []);
      await saveToNew('vouc.json', []);
      await saveToNew('logs.json', [
        LogEntry(id: '1', action: 'SYSTEM', details: 'Financial Year Transferred from $sourceFY', time: DateTime.now()).toMap()
      ]);

      return true;
    } catch (e) {
      print("Transfer Error: $e");
      return false;
    }
  }
}
