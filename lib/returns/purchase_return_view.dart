// FILE: lib/returns/purchase_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../purchase/purchase_billing_view.dart'; // Reusing Enterprise Entry Card
import '../product_master.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../pdf/pdf_router_service.dart';

class PurchaseReturnView extends StatefulWidget {
  final PurchaseReturn? existingRecord; 
  final bool isReadOnly; // NAYA: Action Hub support

  const PurchaseReturnView({super.key, this.existingRecord, this.isReadOnly = false});

  @override
  State<PurchaseReturnView> createState() => _PurchaseReturnViewState();
}

class _PurchaseReturnViewState extends State<PurchaseReturnView> {
  final returnNoC = TextEditingController();
  final discountC = TextEditingController(text: "0"); 
  DateTime selectedDate = DateTime.now();
  Party? selectedSupplier;
  
  List<PurchaseItem> items = []; 
  bool isBreakageMode = false; 
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
      discountC.text = ex.extraDiscount.toString();
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
          prefix: "DN-", 
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
  double get roundOff => double.parse((grandTotal - (subTotal - extraDiscount)).toStringAsFixed(2));

  // ===========================================================================
  // 🪄 THE PURCHASE MAGIC BOX (QTY + FREE UPGRADED)
  // ===========================================================================
  void _showMagicHistoryBox(Medicine med, PharoahManager ph) {
    if (selectedSupplier == null) return;
    
    // isSale: false means Purchase/Distributor History
    final history = ph.getMedicineHistory(partyId: selectedSupplier!.id, medicineId: med.id, isSale: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(color: Color(0xFFFDF8F5), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(children: [
          Container(margin: const EdgeInsets.all(15), height: 5, width: 60, decoration: BoxDecoration(color: Colors.brown.withOpacity(0.2), borderRadius: BorderRadius.circular(10))),
          
          Text("PURCHASE INWARD HISTORY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.brown.shade900, letterSpacing: 2)),
          Text(med.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.brown)),
          const Divider(),

          if (history.isEmpty)
             const Expanded(child: Center(child: Text("No previous purchases found from this supplier.")))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: history.length,
                itemBuilder: (c, i) {
                  final h = history[i];
                  return Card(
                    child: ListTile(
                      onTap: widget.isReadOnly ? null : () { Navigator.pop(c); _showEntryCard(med, historyData: h); },
                      title: Text("Bill: ${h['billNo']} | ${DateFormat('dd MMM').format(h['date'])}"),
                      subtitle: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        _miniInfo("BATCH", h['batch']),
                        // 🔥 LOGIC: Distributor scheme (Qty + Free)
                        _miniInfo("LAST INWARD", "${h['qty'].toInt()} + ${h['free'].toInt()}", isBold: true),
                        _miniInfo("PUR. RATE", "₹${h['rate']}"),
                        _miniInfo("MRP", "₹${h['mrp']}"),
                      ]),
                    ),
                  );
                },
              ),
            ),
        ]),
      ),
    );
  }

  Widget _miniInfo(String l, String v, {bool isBold = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
    Text(v, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: isBold ? Colors.brown.shade900 : Colors.black87)),
  ]);

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
        allowExpired: true,
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
        title: Text(widget.isReadOnly ? "Audit Debit Note" : "Debit Note Entry"),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print_rounded), onPressed: items.isEmpty ? null : () => _handlePrint(ph)),
          if (!widget.isReadOnly && items.isNotEmpty) 
            IconButton(icon: const Icon(Icons.check_circle_rounded, size: 28), onPressed: () => _handleSave(ph)),
        ],
      ),
      body: IgnorePointer(
        ignoring: widget.isReadOnly,
        child: Column(children: [
          _buildHeader(ph),
          if (selectedSupplier != null) ...[
            _buildQuickModeToggle(),
            _buildLiveSearch(ph),
          ],
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("No items for return"))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    itemBuilder: (c, i) => _buildItemCard(items[i], i),
                  ),
          ),
          _buildAdvancedFooter(),
        ]),
      ),
    );
  }

  // --- UI BUILDING BLOCKS (Preserving Enterprise Design) ---
  Widget _buildHeader(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: Colors.white,
    child: Column(children: [
        if (selectedSupplier == null) ...[
          TextField(
            decoration: const InputDecoration(hintText: "Search Distributor for Return...", prefixIcon: Icon(Icons.business), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => partySearch = v),
          ),
          Container(
            height: 150, margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
            child: ListView(children: ph.parties.where((p) => p.group == "Sundry Creditors" && p.name.toLowerCase().contains(partySearch.toLowerCase())).map((p) => ListTile(
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => setState(() => selectedSupplier = p),
            )).toList()),
          )
        ] else
          ListTile(
            tileColor: Colors.brown.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            title: Text(selectedSupplier!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Debit Note ID: ${returnNoC.text}"),
            trailing: widget.isReadOnly ? null : IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedSupplier = null)),
          ),
    ]),
  );

  Widget _buildQuickModeToggle() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Row(children: [
        _modeBtn("SELLABLE RETURN", !isBreakageMode, Colors.blue.shade800, () => setState(() => isBreakageMode = false)),
        const SizedBox(width: 10),
        _modeBtn("EXPIRY / BREAKAGE", isBreakageMode, Colors.deepOrange.shade900, () => setState(() => isBreakageMode = true)),
    ]),
  );

  Widget _modeBtn(String l, bool act, Color c, VoidCallback tap) => Expanded(child: InkWell(onTap: tap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: act ? c : Colors.grey.shade200, borderRadius: BorderRadius.circular(10)), child: Text(l, textAlign: TextAlign.center, style: TextStyle(color: act ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 10)))));

  Widget _buildLiveSearch(PharoahManager ph) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(children: [
        TextField(
          decoration: InputDecoration(
            hintText: "Search product to return...",
            prefixIcon: Icon(Icons.search, color: isBreakageMode ? Colors.deepOrange : Colors.blue),
            border: const OutlineInputBorder(), filled: true, fillColor: Colors.white
          ),
          onChanged: (v) => setState(() => medSearch = v),
        ),
        if (medSearch.isNotEmpty)
          Container(
            height: 200, decoration: BoxDecoration(color: Colors.white, boxShadow: [const BoxShadow(color: Colors.black12, blurRadius: 10)]),
            child: ListView(children: ph.medicines.where((m) => m.name.toLowerCase().contains(medSearch.toLowerCase())).map((m) => ListTile(
              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () { setState(() => medSearch = ""); _showMagicHistoryBox(m, ph); },
            )).toList()),
          )
    ]),
  );

  Widget _buildItemCard(PurchaseItem it, int index) => Card(
    child: ListTile(
      title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Rate: ₹${it.purchaseRate}"),
      trailing: Text("₹${it.total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.brown.shade900)),
      onLongPress: widget.isReadOnly ? null : () => setState(() => items.removeAt(index)),
    ),
  );

  Widget _buildAdvancedFooter() => Container(
    padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
    child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text("Extra Discount (-)", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          SizedBox(width: 100, child: TextField(controller: discountC, keyboardType: TextInputType.number, textAlign: TextAlign.right, onChanged: (v) => setState(() {}), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()))),
        ]),
        const Divider(),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("NET DEBIT TOTAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text("₹${grandTotal.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.brown.shade900)),
          ]),
          Text("R/O: ${roundOff.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
    ]),
  );

  void _handleSave(PharoahManager ph) {
    if (selectedSupplier == null) return;
    
    if (widget.existingRecord != null) {
      ph.updatePurchaseReturn(id: widget.existingRecord!.id, billNo: returnNoC.text, date: selectedDate, party: selectedSupplier!, items: items, total: grandTotal, extraDiscount: extraDiscount, roundOff: roundOff);
    } else {
      ph.finalizePurchaseReturn(billNo: returnNoC.text, date: selectedDate, party: selectedSupplier!, items: items, total: grandTotal, extraDiscount: extraDiscount, roundOff: roundOff);
    }
    Navigator.pop(context);
  }

  void _handlePrint(PharoahManager ph) async {
    if (selectedSupplier == null) return;
    final returnObj = PurchaseReturn(id: "temp", billNo: returnNoC.text, date: selectedDate, distributorName: selectedSupplier!.name, items: items, totalAmount: grandTotal, extraDiscount: extraDiscount, roundOff: roundOff);
    await PdfRouterService.printDebitNote(returnObj: returnObj, supplier: selectedSupplier!, ph: ph);
  }
}
