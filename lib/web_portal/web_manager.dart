import "package:flutter/material.dart";
import "package:pharoah_erp/models.dart";
import "package:pharoah_erp/demo_data.dart";
import "package:pharoah_erp/master_data_library.dart";
import "package:pharoah_erp/inventory_logic_center.dart";
import "web_drive_bridge.dart";

class WebManager with ChangeNotifier {
  bool isLoading = true;
  bool isOnline = false;
  String syncStatus = "Ready";

  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<SaleReturn> saleReturns = [];
  List<PurchaseReturn> purchaseReturns = [];
  List<Voucher> vouchers = [];
  List<Company> companies = [];
  List<Salt> salts = [];
  List<DrugType> drugTypes = [];
  List<RouteArea> routes = [];
  List<ShortageItem> shortages = [];
  Map<String, List<BatchInfo>> batchHistory = {};

  String currentFY = "2026-27";
  String shopName = "PHAROAH PHARMA (WEB SUITE)";
  String gstin = "08FSBPM0623R1ZC";

  WebManager() { initWebDatabase(); }

  Future<void> initWebDatabase() async {
    isLoading = true;
    notifyListeners();
    final cloudData = await WebDriveBridge.fetchDatabaseFromDrive();
    if (cloudData != null && cloudData.isNotEmpty) {
      if (cloudData["medicines"] != null) medicines = (cloudData["medicines"] as List).map((e) => Medicine.fromMap(e)).toList();
      if (cloudData["parties"] != null) parties = (cloudData["parties"] as List).map((e) => Party.fromMap(e)).toList();
      if (cloudData["sales"] != null) sales = (cloudData["sales"] as List).map((e) => Sale.fromMap(e)).toList();
      if (cloudData["purchases"] != null) purchases = (cloudData["purchases"] as List).map((e) => Purchase.fromMap(e)).toList();
      if (cloudData["vouchers"] != null) vouchers = (cloudData["vouchers"] as List).map((e) => Voucher.fromMap(e)).toList();
      if (cloudData["activeCompany"] != null && cloudData["activeCompany"]["name"] != null) shopName = cloudData["activeCompany"]["name"];
      isOnline = true;
      syncStatus = "Connected to Google Drive";
    } else {
      medicines = DemoData.getMedicines();
      parties = [DemoData.getDemoParty(), Party(id: "cash", name: "CASH", group: "Cash in Hand")];
      companies = MasterDataLibrary.getTopCompanies();
      salts = MasterDataLibrary.getTopSalts();
      drugTypes = MasterDataLibrary.getDrugTypes();
      routes = [RouteArea(id: "1", name: "CITY MAIN ROUTE"), RouteArea(id: "2", name: "HIGHWAY SECTOR")];
      isOnline = false;
      syncStatus = "Offline Mode (Local)";
    }
    _recalculateAll();
    isLoading = false;
    notifyListeners();
  }

  void _recalculateAll() {
    InventoryLogicCenter.rebuildAllInventory(
      medicines: medicines,
      batchHistory: batchHistory,
      purchases: purchases,
      sales: sales,
      saleReturns: saleReturns,
      purchaseReturns: purchaseReturns,
    );
    shortages.clear();
    for (var med in medicines) {
      if (med.stock <= med.reorderLevel && med.reorderLevel > 0) {
        shortages.add(ShortageItem(id: "short_${med.id}", medicineId: med.id, medicineName: med.name, companyName: med.companyId, qtyRequired: (med.reorderLevel * 1.5) - med.stock, currentStock: med.stock, date: DateTime.now(), source: "Auto"));
      }
    }
  }

  Future<void> addSale(Sale s) async { sales.add(s); _recalculateAll(); notifyListeners(); if (isOnline) await syncWithDrive(); }
  Future<void> addPurchase(Purchase p) async { purchases.add(p); _recalculateAll(); notifyListeners(); if (isOnline) await syncWithDrive(); }
  Future<void> addVoucher(Voucher v) async { vouchers.add(v); notifyListeners(); if (isOnline) await syncWithDrive(); }
  Future<void> addParty(Party p) async { parties.add(p); notifyListeners(); if (isOnline) await syncWithDrive(); }
  Future<void> addMedicine(Medicine m) async { medicines.add(m); notifyListeners(); if (isOnline) await syncWithDrive(); }

  Future<bool> syncWithDrive() async {
    syncStatus = "Syncing with Google Drive...";
    notifyListeners();
    final payload = {
      "activeCompany": {"name": shopName, "fy": currentFY, "gstin": gstin},
      "medicines": medicines.map((e) => e.toMap()).toList(),
      "parties": parties.map((e) => e.toMap()).toList(),
      "sales": sales.map((e) => e.toMap()).toList(),
      "purchases": purchases.map((e) => e.toMap()).toList(),
      "vouchers": vouchers.map((e) => e.toMap()).toList(),
      "batchHistory": batchHistory.map((k, v) => MapEntry(k, v.map((b) => b.toMap()).toList())),
      "lastSync": DateTime.now().toIso8601String(),
    };
    bool ok = await WebDriveBridge.saveDatabaseToDrive(payload);
    syncStatus = ok ? "Synced with Google Drive" : "Sync Failed";
    isOnline = ok;
    notifyListeners();
    return ok;
  }
}
