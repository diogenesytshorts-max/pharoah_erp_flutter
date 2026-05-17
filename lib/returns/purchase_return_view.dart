// FILE: lib/returns/purchase_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../purchase/purchase_billing_view.dart'; // 🔥 REUSING YOUR PURCHASE ENTRY CARD
import '../product_master.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../pdf/pdf_router_service.dart';

class PurchaseReturnView extends StatefulWidget {
  final PurchaseReturn? existingRecord; 
  const PurchaseReturnView({super.key, this.existingRecord});

  @override
  State<PurchaseReturnView> createState() => _PurchaseReturnViewState();
}

class _PurchaseReturnViewState extends State<PurchaseReturnView> {
  final returnNoC = TextEditingController();
  final discountC = TextEditingController(text: "0"); // 🔥 Extra Discount
  DateTime selectedDate = DateTime.now();
  Party? selectedSupplier;
  
  List<PurchaseItem> items = []; 
  bool isBreakageMode = false; // Toggle: Sellable vs Breakage
  String partySearch = "";
  String medSearch = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initReturnFlow();
  }

  void _initReturnFlow() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    if (widget.existingRecord != null) {
      final ex = widget.existingRecord!;
      returnNoC.text = ex.billNo;
      selectedDate = ex.date;
      items = List.from(ex.items);
      try {
        selectedSupplier = ph.parties.firstWhere((p) => p.name == ex.distributorName);
      } catch (e) {
        selectedSupplier = Party(id: "0", name: ex.distributorName);
      }
      setState(() => isLoading = false);
    } else {
      if (ph.activeCompany != null) {
        String nextNo = await PharoahNumberingEngine.getNextNumber(
          type: "RETURN", companyID: ph.activeCompany!.id,
          prefix: "DN-", // Debit Note
          startFrom: 1, currentList: ph.purchaseReturns,
        );
        setState(() {
          returnNoC.text = nextNo;
          selectedDate = AppDateLogic.getSmartDate(ph.currentFY);
          isLoading = false;
        });
      }
    }
  }

  // --- CALCULATIONS ---
  double get subTotal => items.fold(0, (sum, it) => sum + it.total);
  double get extraDiscount => double.tryParse(discountC.text) ?? 0.0;
  double get grandTotal => (subTotal - extraDiscount).roundToDouble();
  double get roundOff => grandTotal - (subTotal - extraDiscount);

  // ===========================================================================
  // 🪄 THE BEAUTIFUL MAGIC HISTORY BOX (PURCHASE HISTORY)
  // ===========================================================================
  void _showMagicHistoryBox(Medicine med, PharoahManager ph) {
    if (selectedSupplier == null) return;

    // Fetch history from PharoahManager (isSale: false means Purchase history)
    final history = ph.getMedicineHistory(
      partyId: selectedSupplier!.id, 
      medicineId: med.id, 
      isSale: false 
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFFDF8F5), // Light Brownish tint
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.all(15), height: 5, width: 60, decoration: BoxDecoration(color: Colors.brown.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),
          
          Text("PURCHASE INWARD HISTORY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.brown.shade900, letterSpacing: 2)),
          const SizedBox(height: 5),
          Text(med.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
          const Divider(),

          if (history.isEmpty)
             Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
               Icon(Icons.manage_search_rounded, size: 50, color: Colors.brown.shade200),
               const Text("No purchase records found from this supplier.", style: TextStyle(color: Colors.grey)),
             ])))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: history.length,
                itemBuilder: (c, i) {
                  final h = history[i];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.brown.withOpacity(0.1))),
                    child: InkWell(
                      onTap: () { Navigator.pop(c); _showEntryCard(med, historyData: h); },
                      borderRadius: BorderRadius.circular(15),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Row(children: [
                              const Icon(Icons.shopping_bag_outlined, size: 16, color: Colors.brown),
                              const SizedBox(width: 8),
                              Text("Bill: ${h['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                            Text(DateFormat('dd MMM yy').format(h['date'] as DateTime), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ]),
                          const Divider(height: 20),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            _miniInfo("BATCH", h['batch']),
                            _miniInfo("PUR. RATE", "₹${h['rate']}"),
                            _miniInfo("MRP", "₹${h['mrp']}", isBold: true),
                            const Icon(Icons.keyboard_arrow_right, color: Colors.brown),
                          ])
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(c); _showEntryCard(med); },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.brown, side: const BorderSide(color: Colors.brown), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.edit_note), label: const Text("MANUAL ENTRY (NEW BATCH)"),
              ),
            ),
          )
        ]),
      ),
    );
  }

  Widget _miniInfo(String l, String v, {bool isBold = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
    Text(v, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: isBold ? Colors.brown.shade900 : Colors.black87)),
  ]);

  // ===========================================================================
  // 📝 ENTRY CARD BRIDGE (PURCHASE BILL MIRROR)
  // ===========================================================================
  void _showEntryCard(Medicine med, {Map<String, dynamic>? historyData}) {
    PurchaseItem? preFilled;
    if (historyData != null) {
      preFilled = PurchaseItem(
        id: "temp", srNo: items.length + 1, medicineID: med.id, name: med.name, packing: med.packing,
        batch: historyData['batch'], exp: "12/26", hsn: med.hsnCode, mrp: (historyData['mrp'] as num).toDouble(),
        purchaseRate: (historyData['rate'] as num).toDouble(), gstRate: (historyData['gst'] as num).toDouble(), qty: 0, total: 0,
      );
    }

    showDialog(
      context: context,
      builder: (c) => PurchaseItemEntryCard(
        med: med,
        srNo: items.length + 1,
        existingItem: preFilled,
        onAdd: (newItem) {
          setState(() { items.add(newItem.copyWith(isBreakage: isBreakageMode)); });
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F3),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Debit Note: ${returnNoC.text}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(selectedSupplier?.name ?? "Select Supplier", style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ]),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print_rounded), onPressed: items.isEmpty ? null : () => _handlePrint(ph)),
          if (items.isNotEmpty) IconButton(icon: const Icon(Icons.check_circle_rounded, size: 28), onPressed: () => _handleSave(ph)),
        ],
      ),
      body: Column(children: [
        _buildHeader(ph),
        if (selectedSupplier != null) ...[
          _buildQuickModeToggle(),
          _buildLiveSearch(ph),
        ],
        Expanded(
          child: items.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: items.length,
                  itemBuilder: (c, i) => _buildItemCard(items[i], i),
                ),
        ),
        _buildAdvancedFooter(),
      ]),
    );
  }

  // --- UI: HEADER ---
  Widget _buildHeader(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: Colors.white,
    child: Column(children: [
        if (selectedSupplier == null) ...[
          TextField(
            decoration: const InputDecoration(hintText: "Search Distributor for Debit Note...", prefixIcon: Icon(Icons.business_rounded), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => partySearch = v),
          ),
          Container(
            height: 150, margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
            child: ListView(children: ph.parties.where((p) => p.group == "Sundry Creditors" && p.name.toLowerCase().contains(partySearch.toLowerCase())).map((p) => ListTile(
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(p.city),
              onTap: () => setState(() => selectedSupplier = p),
            )).toList()),
          )
        ] else
          ListTile(
            tileColor: Colors.brown.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const CircleAvatar(backgroundColor: Colors.brown, child: Icon(Icons.business, color: Colors.white)),
            title: Text(selectedSupplier!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${selectedSupplier!.city} | Bal: ₹${selectedSupplier!.opBal}"),
            trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedSupplier = null)),
          ),
    ]),
  );

  // --- UI: QUICK MODE ---
  Widget _buildQuickModeToggle() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Row(children: [
        _modeBtn("SELLABLE RETURN", !isBreakageMode, Colors.blue.shade800, () => setState(() => isBreakageMode = false)),
        const SizedBox(width: 10),
        _modeBtn("BREAKAGE / EXPIRY", isBreakageMode, Colors.deepOrange.shade900, () => setState(() => isBreakageMode = true)),
    ]),
  );

  Widget _modeBtn(String l, bool act, Color c, VoidCallback tap) => Expanded(child: InkWell(onTap: tap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: act ? c : Colors.grey.shade200, borderRadius: BorderRadius.circular(10)), child: Text(l, textAlign: TextAlign.center, style: TextStyle(color: act ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 10)))));

  // --- UI: PRODUCT SEARCH ---
  Widget _buildLiveSearch(PharoahManager ph) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(children: [
        TextField(
          decoration: InputDecoration(
            hintText: "Search product to return to ${selectedSupplier?.name}...",
            prefixIcon: Icon(Icons.search, color: isBreakageMode ? Colors.deepOrange : Colors.blue),
            border: const OutlineInputBorder(), filled: true, fillColor: Colors.white
          ),
          onChanged: (v) => setState(() => medSearch = v),
        ),
        if (medSearch.isNotEmpty)
          Container(
            height: 200, decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
            child: ListView(children: ph.medicines.where((m) => m.name.toLowerCase().contains(medSearch.toLowerCase())).map((m) => ListTile(
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(m.packing),
              onTap: () { setState(() => medSearch = ""); _showMagicHistoryBox(m, ph); },
            )).toList()),
          )
    ]),
  );

  // --- UI: ITEM CARDS ---
  Widget _buildItemCard(PurchaseItem it, int index) {
    Color theme = it.isBreakage ? Colors.deepOrange.shade900 : Colors.blue.shade900;
    return Card(
      elevation: 2, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.withOpacity(0.2))),
      child: ListTile(
        onTap: () {
          final ph = Provider.of<PharoahManager>(context, listen: false);
          final med = ph.medicines.firstWhere((m) => m.id == it.medicineID);
          showDialog(context: context, builder: (c) => PurchaseItemEntryCard(med: med, srNo: it.srNo, existingItem: it, onAdd: (updated) { setState(() => items[index] = updated); Navigator.pop(context); }, onCancel: () => Navigator.pop(context)));
        },
        tileColor: it.isBreakage ? Colors.deepOrange.shade50.withOpacity(0.5) : Colors.white,
        title: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: theme, borderRadius: BorderRadius.circular(5)), child: Text(it.isBreakage ? "EXP" : "RET", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Pur.Rate: ₹${it.purchaseRate} | MRP: ₹${it.mrp}"),
        trailing: Text("₹${it.total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, color: theme)),
        onLongPress: () => setState(() => items.removeAt(index)),
      ),
    );
  }

  // --- UI: FOOTER ---
  Widget _buildAdvancedFooter() => Container(
    padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))]),
    child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Extra Discount (-)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          SizedBox(
  width: 100, 
  child: TextField(
    controller: discountC, 
    keyboardType: TextInputType.number, 
    textAlign: TextAlign.right, 
    decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), 
    onChanged: (v) => setState(() {}), // 🔥 Sirf onChanged rahega
  ),
), ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("NET DEBIT TOTAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text("₹${grandTotal.toStringAsFixed(2)}", style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.brown.shade900)),
          ]),
          Text("Round Off: ${roundOff.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
    ]),
  );

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.remove_shopping_cart_rounded, size: 60, color: Colors.grey.shade300), const Text("No items for return", style: TextStyle(color: Colors.grey))]));

  void _handleSave(PharoahManager ph) {
    if (selectedSupplier == null) return;
    ph.finalizePurchaseReturn(billNo: returnNoC.text, date: selectedDate, party: selectedSupplier!, items: items, total: grandTotal);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Debit Note Processed!"), backgroundColor: Colors.green));
  }

  void _handlePrint(PharoahManager ph) async {
    if (selectedSupplier == null) return;
    final returnObj = PurchaseReturn(id: "temp", billNo: returnNoC.text, date: selectedDate, distributorName: selectedSupplier!.name, items: items, totalAmount: grandTotal);
    await PdfRouterService.printDebitNote(returnObj: returnObj, supplier: selectedSupplier!, ph: ph);
  }
}
