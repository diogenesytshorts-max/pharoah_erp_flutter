// FILE: lib_web/pharoah_web_manager.dart
// PURE FLUTTER WEB STATE MANAGER (100% Web-Safe, Zero dart:io dependency)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../lib/models.dart';
import '../lib/inventory_logic_center.dart';
import '../lib/gateway/company_registry_model.dart';
import '../lib/logic/app_settings_model.dart';
import '../lib/demo_data.dart';
import '../lib/master_data_library.dart';

class PharoahWebManager with ChangeNotifier {
  String activeModule = "HOME";
  bool get showBatchFilter => activeCompany != null && activeCompany!.fYears.length > 1;

  // Data Lists
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<RouteArea> routes = [];
  List<Company> companies = [];
  List<Salt> salts = [];
  List<DrugType> drugTypes = [];
  List<Bank> banks = [];
  List<NumberingSeries> numberingSeries = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<SaleChallan> saleChallans = [];
  List<PurchaseChallan> purchaseChallans = [];
  List<SaleReturn> saleReturns = [];
  List<PurchaseReturn> purchaseReturns = [];
  List<Voucher> vouchers = [];
  Map<String, List<BatchInfo>> batchHistory = {};
  
  AppConfig config = AppConfig(isArchitectMode: true);
  CompanyProfile? activeCompany;
  String currentFY = "2026-27";
  bool isAdminAuthenticated = true;

  PharoahWebManager() {
    initWebDatabase();
  }

  void updateModule(String newModule) {
    activeModule = newModule;
    notifyListeners();
  }

  // Initial Load from Web Storage / Google Drive
  Future<void> initWebDatabase() async {
    final prefs = await SharedPreferences.getInstance();
    
    activeCompany = CompanyProfile(
      id: "PH-C-101",
      name: prefs.getString('web_comp_name') ?? "DWARIKA MEDICALS",
      businessType: "WHOLESALE",
      createdAt: DateTime.now(),
      password: "admin",
      state: "Rajasthan",
      gstin: "08ABCDE1234F1Z5",
      fYears: ["2026-27"],
    );

    final rawDb = prefs.getString('pharoah_flutter_web_db');
    if (rawDb != null) {
      try {
        final Map<String, dynamic> db = jsonDecode(rawDb);
        _loadFromJson(db);
      } catch (e) {
        _loadDefaults();
      }
    } else {
      _loadDefaults();
    }

    InventoryLogicCenter.rebuildAllInventory(
      medicines: medicines,
      batchHistory: batchHistory,
      purchases: purchases,
      sales: sales,
      saleReturns: saleReturns,
      purchaseReturns: purchaseReturns,
    );
    notifyListeners();
  }

  void _loadDefaults() {
    medicines = DemoData.getMedicines();
    companies = MasterDataLibrary.getTopCompanies();
    salts = MasterDataLibrary.getTopSalts();
    drugTypes = MasterDataLibrary.getDrugTypes();
    parties = [
      DemoData.getDemoParty(),
      Party(id: 'p_cash', name: "CASH CUSTOMER", group: "Cash in Hand", state: "Rajasthan"),
      Party(id: 'p_sharma', name: "SHARMA MEDICALS", group: "Sundry Debtors", city: "JAIPUR", state: "Rajasthan", gst: "08ABCDE1234F1Z5", opBal: 4500.0),
    ];
    batchHistory = {
      "PH-00001": [BatchInfo(batch: "DL-101", exp: "12/28", packing: "15 TAB", mrp: 30.91, rate: 25.40, rateA: 28.50, rateB: 27.00, rateC: 26.50, qty: 150, openingQty: 150)],
      "PH-00002": [BatchInfo(batch: "PN-202", exp: "05/27", packing: "10 TAB", mrp: 120.00, rate: 95.00, rateA: 110.00, rateB: 105.00, rateC: 100.00, qty: 80, openingQty: 80)],
      "PH-00003": [BatchInfo(batch: "AZ-303", exp: "08/26", packing: "5 TAB", mrp: 115.00, rate: 88.00, rateA: 105.00, rateB: 100.00, rateC: 98.00, qty: 45, openingQty: 45)],
    };
    numberingSeries = [
      NumberingSeries(id: 's_sale', type: 'SALE', prefix: 'INV-', startNumber: 1001, isDefault: true),
      NumberingSeries(id: 's_pur', type: 'PURCHASE', prefix: 'PUR-', startNumber: 101, isDefault: true),
      NumberingSeries(id: 's_sch', type: 'CHALLAN', prefix: 'SCH-', startNumber: 101, isDefault: true),
      NumberingSeries(id: 's_ret', type: 'RETURN', prefix: 'CN-', startNumber: 101, isDefault: true),
    ];
  }

  void _loadFromJson(Map<String, dynamic> db) {
    medicines = (db['meds'] as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? [];
    parties = (db['parts'] as List?)?.map((e) => Party.fromMap(e)).toList() ?? [];
    sales = (db['sales'] as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
    purchases = (db['purc'] as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
    vouchers = (db['vouc'] as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
    saleChallans = (db['s_challan'] as List?)?.map((e) => SaleChallan.fromMap(e)).toList() ?? [];
    purchaseChallans = (db['p_challan'] as List?)?.map((e) => PurchaseChallan.fromMap(e)).toList() ?? [];
    saleReturns = (db['s_return'] as List?)?.map((e) => SaleReturn.fromMap(e)).toList() ?? [];
    purchaseReturns = (db['p_return'] as List?)?.map((e) => PurchaseReturn.fromMap(e)).toList() ?? [];
    
    final bData = db['bats'];
    if (bData != null) {
      batchHistory.clear();
      (bData as Map).forEach((k, v) {
        batchHistory[k] = (v as List).map((b) => BatchInfo.fromMap(b)).toList();
      });
    }
  }

  // Save State & Push to Google Drive
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    final dataMap = {
      'meds': medicines.map((e) => e.toMap()).toList(),
      'parts': parties.map((e) => e.toMap()).toList(),
      'sales': sales.map((e) => e.toMap()).toList(),
      'purc': purchases.map((e) => e.toMap()).toList(),
      'vouc': vouchers.map((e) => e.toMap()).toList(),
      's_challan': saleChallans.map((e) => e.toMap()).toList(),
      'p_challan': purchaseChallans.map((e) => e.toMap()).toList(),
      's_return': saleReturns.map((e) => e.toMap()).toList(),
      'p_return': purchaseReturns.map((e) => e.toMap()).toList(),
      'bats': batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList())),
    };

    await prefs.setString('pharoah_flutter_web_db', jsonEncode(dataMap));
    notifyListeners();
  }

  // Next Bill Number Calculator
  String getNextNumber(String type, {String prefix = "INV-"}) {
    List<String> list = [];
    if (type == 'SALE') list = sales.map((s) => s.billNo).toList();
    if (type == 'PURCHASE') list = purchases.map((p) => p.internalNo).toList();
    if (type == 'CHALLAN') list = saleChallans.map((c) => c.billNo).toList();
    if (type == 'RETURN') list = saleReturns.map((r) => r.billNo).toList();

    final existingNums = list
        .filter((no) => no.startsWith(prefix))
        .map((no) => int.tryParse(no.replaceFirst(prefix, '')) ?? 0)
        .toList();

    if (existingNums.isEmpty) return "${prefix}1001";
    existingNums.sort();
    return "$prefix${existingNums.last + 1}";
  }

  // Finalize Sale Bill on Web
  Future<void> finalizeSale({
    required String billNo,
    required DateTime date,
    required Party party,
    required List<BillItem> items,
    required double total,
    required String mode,
    double extraDiscount = 0.0,
    double roundOff = 0.0,
    List<String>? linkedIds,
  }) async {
    sales.add(Sale(
      id: "SALE_${DateTime.now().millisecondsSinceEpoch}",
      billNo: billNo,
      partyId: party.id,
      date: date,
      partyName: party.name,
      partyGstin: party.gst,
      partyState: party.state,
      items: items,
      totalAmount: total,
      paymentMode: mode,
      extraDiscount: extraDiscount,
      roundOff: roundOff,
      linkedChallanIds: linkedIds ?? [],
    ));

    InventoryLogicCenter.rebuildAllInventory(
      medicines: medicines,
      batchHistory: batchHistory,
      purchases: purchases,
      sales: sales,
      saleReturns: saleReturns,
      purchaseReturns: purchaseReturns,
    );

    await save();
  }
}

extension ListFilter<T> on List<T> {
  List<T> filter(bool Function(T) test) => where(test).toList();
}
