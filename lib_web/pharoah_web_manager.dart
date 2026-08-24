import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pharoah_erp/models.dart';
import 'package:pharoah_erp/inventory_logic_center.dart';
import 'package:pharoah_erp/gateway/company_registry_model.dart';
import 'package:pharoah_erp/demo_data.dart';
import 'package:pharoah_erp/master_data_library.dart';

class PharoahWebManager with ChangeNotifier {
  String activeModule = 'DASHBOARD';
  List<Medicine> medicines = [];
  List<Party> parties = [];
  List<Sale> sales = [];
  List<Purchase> purchases = [];
  List<SaleChallan> saleChallans = [];
  List<Voucher> vouchers = [];
  Map<String, List<BatchInfo>> batchHistory = {};
  CompanyProfile? activeCompany;
  String currentFY = '2026-27';
  String syncStatus = 'Ready';
  String driveWebhookUrl = '', driveUserEmail = '';

  PharoahWebManager() { init(); }

  void updateModule(String m) { activeModule = m; notifyListeners(); }

  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    driveWebhookUrl = p.getString('web_drive_url') ?? '';
    driveUserEmail = p.getString('web_drive_email') ?? '';
    activeCompany = CompanyProfile(id: 'PH-C-101', name: p.getString('web_cname') ?? 'DWARIKA MEDICALS', businessType: 'WHOLESALE', createdAt: DateTime.now(), password: 'admin', state: 'Rajasthan', gstin: '08ABCDE1234F1Z5', fYears: ['2026-27']);
    final raw = p.getString('pharoah_web_db_v10');
    if (raw != null) {
      try {
        final d = jsonDecode(raw);
        medicines = (d['meds'] as List?)?.map((e) => Medicine.fromMap(e)).toList() ?? [];
        parties = (d['parts'] as List?)?.map((e) => Party.fromMap(e)).toList() ?? [];
        sales = (d['sales'] as List?)?.map((e) => Sale.fromMap(e)).toList() ?? [];
        purchases = (d['purc'] as List?)?.map((e) => Purchase.fromMap(e)).toList() ?? [];
        vouchers = (d['vouc'] as List?)?.map((e) => Voucher.fromMap(e)).toList() ?? [];
        saleChallans = (d['s_challan'] as List?)?.map((e) => SaleChallan.fromMap(e)).toList() ?? [];
        final b = d['bats']; if (b != null) (b as Map).forEach((k, v) => batchHistory[k] = (v as List).map((x) => BatchInfo.fromMap(x)).toList());
      } catch (_) { _loadDefaults(); }
    } else { _loadDefaults(); }
    rebuild();
    notifyListeners();
    if (driveWebhookUrl.isNotEmpty) pullFromGoogleDrive();
  }

  void _loadDefaults() {
    medicines = DemoData.getMedicines();
    parties = [DemoData.getDemoParty(), Party(id: 'p_cash', name: 'CASH CUSTOMER', group: 'Cash in Hand', state: 'Rajasthan'), Party(id: 'p_sharma', name: 'SHARMA MEDICALS', group: 'Sundry Debtors', city: 'JAIPUR', state: 'Rajasthan', gst: '08ABCDE1234F1Z5', opBal: 4500.0)];
    batchHistory = {'PH-00001': [BatchInfo(batch: 'DL-101', exp: '12/28', packing: '15 TAB', mrp: 30.91, rate: 25.40, rateA: 28.50, rateB: 27.00, rateC: 26.50, qty: 150, openingQty: 150)]};
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('pharoah_web_db_v10', jsonEncode({'meds': medicines.map((e)=>e.toMap()).toList(), 'parts': parties.map((e)=>e.toMap()).toList(), 'sales': sales.map((e)=>e.toMap()).toList(), 'purc': purchases.map((e)=>e.toMap()).toList(), 'vouc': vouchers.map((e)=>e.toMap()).toList(), 's_challan': saleChallans.map((e)=>e.toMap()).toList(), 'bats': batchHistory.map((k, v) => MapEntry(k, v.map((b)=>b.toMap()).toList()))}));
    notifyListeners();
    if (driveWebhookUrl.isNotEmpty) pushToGoogleDrive();
  }

  void rebuild() {
    InventoryLogicCenter.rebuildAllInventory(medicines: medicines, batchHistory: batchHistory, purchases: purchases, sales: sales, saleReturns: [], purchaseReturns: []);
  }

  String getNextNumber(String type) {
    String pfx = type == 'SALE' ? 'INV-' : (type == 'PURCHASE' ? 'PUR-' : (type == 'CHALLAN' ? 'SCH-' : (type == 'RECEIPT' ? 'RCT-' : 'DOC-')));
    List<String> list = type == 'SALE' ? sales.map((s)=>s.billNo).toList() : (type == 'PURCHASE' ? purchases.map((p)=>p.internalNo).toList() : saleChallans.map((c)=>c.billNo).toList());
    final nums = list.where((n)=>n.startsWith(pfx)).map((n)=>int.tryParse(n.replaceFirst(pfx, ''))??0).toList();
    if (nums.isEmpty) return '${pfx}1001';
    nums.sort(); return '$pfx${nums.last + 1}';
  }

  Future<void> finalizeSale({required String billNo, required DateTime date, required Party party, required List<BillItem> items, required double total, required String mode, double extraDiscount = 0.0, double roundOff = 0.0, List<String>? linkedIds}) async {
    sales.add(Sale(id: 'SALE_${DateTime.now().millisecondsSinceEpoch}', billNo: billNo, partyId: party.id, date: date, partyName: party.name, partyGstin: party.gst, partyState: party.state, items: items, totalAmount: total, paymentMode: mode, extraDiscount: extraDiscount, roundOff: roundOff, linkedChallanIds: linkedIds ?? [], sourceTag: 'WEB_PORTAL'));
    if (linkedIds != null) for (var id in linkedIds) { int i = saleChallans.indexWhere((c)=>c.id==id); if (i!=-1) saleChallans[i].status = 'Billed'; }
    rebuild(); await save();
  }

  Future<void> finalizePurchase({required String internalNo, required String billNo, required DateTime date, required DateTime entryDate, required Party party, required List<PurchaseItem> items, required double total, required String mode}) async {
    purchases.add(Purchase(id: 'PUR_${DateTime.now().millisecondsSinceEpoch}', internalNo: internalNo, billNo: billNo, partyId: party.id, distributorName: party.name, date: date, entryDate: entryDate, items: items, totalAmount: total, paymentMode: mode, sourceTag: 'WEB_PORTAL'));
    rebuild(); await save();
  }

  Future<void> finalizeVoucher({required String type, required String voucherNo, required DateTime date, required Party party, required double amount, required String mode, required String internalLedger}) async {
    vouchers.add(Voucher(id: 'VOUC_${DateTime.now().millisecondsSinceEpoch}', type: type.toUpperCase(), voucherNo: voucherNo, date: date, partyId: party.id, partyName: party.name, amount: amount, paymentMode: mode, depositedIn: internalLedger, status: 'Active'));
    await save();
  }

  Future<bool> pushToGoogleDrive() async {
    if (driveWebhookUrl.isEmpty) return false;
    try {
      final res = await http.post(Uri.parse(driveWebhookUrl), body: jsonEncode({'action': 'SAVE_DATABASE', 'tenantEmail': driveUserEmail, 'timestamp': DateTime.now().toIso8601String(), 'payload': {'sales': sales.map((e)=>e.toMap()).toList(), 'purchases': purchases.map((e)=>e.toMap()).toList(), 'meds': medicines.map((e)=>e.toMap()).toList(), 'parts': parties.map((e)=>e.toMap()).toList(), 'vouc': vouchers.map((e)=>e.toMap()).toList()}}));
      syncStatus = res.statusCode == 200 || res.statusCode == 302 ? 'Synced (${DateFormat('hh:mm a').format(DateTime.now())})' : 'Sync Failed';
      notifyListeners(); return true;
    } catch (_) { return false; }
  }

  Future<bool> pullFromGoogleDrive() async {
    if (driveWebhookUrl.isEmpty) return false;
    try {
      final res = await http.get(Uri.parse('$driveWebhookUrl?action=GET_DATABASE&tenantEmail=${Uri.encodeComponent(driveUserEmail)}'));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['status'] == 'SUCCESS' && d['payload'] != null) {
          final p = d['payload'];
          if (p['sales'] != null) sales = (p['sales'] as List).map((e)=>Sale.fromMap(e)).toList();
          if (p['meds'] != null) medicines = (p['meds'] as List).map((e)=>Medicine.fromMap(e)).toList();
          if (p['parts'] != null) parties = (p['parts'] as List).map((e)=>Party.fromMap(e)).toList();
          rebuild(); await save();
          syncStatus = 'Synced (${DateFormat('hh:mm a').format(DateTime.now())})';
          notifyListeners(); return true;
        }
      }
    } catch (_) {}
    return false;
  }

  Future<void> saveDriveSettings(String u, String e) async {
    driveWebhookUrl = u.trim(); driveUserEmail = e.trim();
    final p = await SharedPreferences.getInstance();
    await p.setString('web_drive_url', driveWebhookUrl);
    await p.setString('web_drive_email', driveUserEmail);
    notifyListeners(); await pullFromGoogleDrive();
  }
}