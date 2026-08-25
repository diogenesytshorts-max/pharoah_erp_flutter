import "package:flutter/material.dart";
import "package:pharoah_erp/models.dart";
import "package:pharoah_erp/demo_data.dart";
import "package:pharoah_erp/inventory_logic_center.dart";
import "web_drive_bridge.dart";

class WebManager with ChangeNotifier {
  bool isLoading = false;
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

  WebManager() {
    try {
      medicines = DemoData.getMedicines();
      parties = [DemoData.getDemoParty(), Party(id: "cash", name: "CASH", group: "Cash in Hand")];
      companies = [Company(id: "1", name: "CIPLA LTD"), Company(id: "2", name: "SUN PHARMA"), Company(id: "3", name: "MANKIND PHARMA")];
      salts = [Salt(id: "1", name: "PARACETAMOL 650MG", type: "Mono"), Salt(id: "2", name: "PANTOPRAZOLE 40MG", type: "Mono")];
      drugTypes = [DrugType(id: "1", name: "GENERAL / OTC"), DrugType(id: "2", name: "SCHEDULE H")];
      routes = [RouteArea(id: "1", name: "CITY MAIN ROUTE")];
      _recalculateAll();
    } catch (e) {
      debugPrint("WebManager Init Exception Safe Handled: $e");
    }
  }

  Future<void> initWebDatabase() async {
    try {
      final cloudData = await WebDriveBridge.fetchDatabaseFromDrive();
      if (cloudData != null && cloudData.isNotEmpty) {
        if (cloudData["medicines"] != null) medicines = (cloudData["medicines"] as List).map((e) => Medicine.fromMap(e)).toList();
        if (cloudData["parties"] != null) parties = (cloudData["parties"] as List).map((e) => Party.fromMap(e)).toList();
        if (cloudData["sales"] != null) sales = (cloudData["sales"] as List).map((e) => Sale.fromMap(e)).toList();
        if (cloudData["purchases"] != null) purchases = (cloudData["purchases"] as List).map((e) => Purchase.fromMap(e)).toList();
        if (cloudData["vouchers"] != null) vouchers = (cloudData["vouchers"] as List).map((e) => Voucher.fromMap(e)).toList();
        isOnline = true;
        syncStatus = "Connected to Google Drive";
      }
      _recalculateAll();
      notifyListeners();
    } catch (e) {
      debugPrint("Cloud Fetch Error: $e");
    }
  }

  void _recalculateAll() {
    try {
      InventoryLogicCenter.rebuildAllInventory(
        medicines: medicines,
        batchHistory: batchHistory,
        purchases: purchases,
        sales: sales,
        saleReturns: saleReturns,
        purchaseReturns: purchaseReturns,
      );
    } catch (e) {
      debugPrint("Inventory Rebuild Error: $e");
    }
  }

  Future<void> addSale(Sale s) async { sales.add(s); _recalculateAll(); notifyListeners(); await syncWithDrive(); }
  Future<void> addPurchase(Purchase p) async { purchases.add(p); _recalculateAll(); notifyListeners(); await syncWithDrive(); }
  Future<void> addVoucher(Voucher v) async { vouchers.add(v); notifyListeners(); await syncWithDrive(); }
  Future<void> addParty(Party p) async { parties.add(p); notifyListeners(); await syncWithDrive(); }
  Future<void> addMedicine(Medicine m) async { medicines.add(m); notifyListeners(); await syncWithDrive(); }

  Future<bool> syncWithDrive() async {
    try {
      final payload = {
        "activeCompany": {"name": shopName, "fy": currentFY},
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
    } catch (e) {
      return false;
    }
  }
}
