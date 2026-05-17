// FILE: lib/returns/sale_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../item_entry_card.dart'; // 🔥 REUSING YOUR ORIGINAL CARD (No more yellow lines)
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import '../pdf/pdf_router_service.dart';

class SaleReturnView extends StatefulWidget {
  final SaleReturn? existingRecord; 
  const SaleReturnView({super.key, this.existingRecord});

  @override
  State<SaleReturnView> createState() => _SaleReturnViewState();
}

class _SaleReturnViewState extends State<SaleReturnView> {
  final returnNoC = TextEditingController();
  final discountC = TextEditingController(text: "0"); // 🔥 For Footer
  DateTime selectedDate = DateTime.now();
  Party? selectedParty;
  
  List<BillItem> items = []; 
  bool isBreakageMode = false; // 🔥 Current Mode Toggle
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
        selectedParty = ph.parties.firstWhere((p) => p.name == ex.partyName);
      } catch (e) {
        selectedParty = Party(id: "0", name: ex.partyName);
      }
      setState(() => isLoading = false);
    } else {
      if (ph.activeCompany != null) {
        var series = ph.getDefaultSeries("RETURN");
        String nextNo = await PharoahNumberingEngine.getNextNumber(
          type: "RETURN", companyID: ph.activeCompany!.id,
          prefix: series.prefix, startFrom: series.startNumber, currentList: ph.saleReturns,
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
  // ✨ THE BEAUTIFUL MAGIC HISTORY BOX
  // ===========================================================================
  void _showMagicHistoryBox(Medicine med, PharoahManager ph) {
    if (selectedParty == null) return;

    final history = ph.getMedicineHistory(
      partyId: selectedParty!.id, 
      medicineId: med.id, 
      isSale: true
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: const BoxDecoration(
          color: Color(0xFFF8F9FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(children: [
          // Handle Bar
          Container(margin: const EdgeInsets.all(15), height: 5, width: 60, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10))),
          
          // Header with Product Info
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(children: [
               Text("TRANSACTION HISTORY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.blue.shade900, letterSpacing: 2)),
               const SizedBox(height: 5),
               Text(med.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
               Text("Search limited to current Financial Year", style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
            ]),
          ),
          
          const Divider(),

          if (history.isEmpty)
             Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
               Icon(Icons.history_toggle_off, size: 50, color: Colors.grey.shade300),
               const Text("No previous sales found for this party.", style: TextStyle(color: Colors.grey)),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.indigo.withOpacity(0.1))),
                    child: InkWell(
                      onTap: () { Navigator.pop(c); _showEntryCard(med, historyData: h); },
                      borderRadius: BorderRadius.circular(15),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(children: [
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Row(children: [
                              const Icon(Icons.receipt_long, size: 16, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text("Bill: ${h['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ]),
                            Text(DateFormat('dd MMM yyyy').format(h['date'] as DateTime), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ]),
                          const Divider(height: 20),
                          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            _miniInfo("BATCH", h['batch']),
                            _miniInfo("RATE", "₹${h['rate']}"),
                            _miniInfo("MRP", "₹${h['mrp']}", isBold: true),
                            const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.blue),
                          ])
                        ]),
                      ),
                    ),
                  );
                },
              ),
            ),
          
          // Manual Entry Button
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity, height: 50,
              child: OutlinedButton.icon(
                onPressed: () { Navigator.pop(c); _showEntryCard(med); },
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.edit_document), label: const Text("NOT IN HISTORY? ENTER MANUALLY"),
              ),
            ),
          )
        ]),
      ),
    );
  }

  Widget _miniInfo(String l, String v, {bool isBold = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
    Text(v, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.w900 : FontWeight.bold, color: isBold ? Colors.indigo : Colors.black87)),
  ]);

  // ===========================================================================
  // 📝 ENTRY CARD (SALE BILL MIRROR)
  // ===========================================================================
  void _showEntryCard(Medicine med, {Map<String, dynamic>? historyData}) {
    BillItem? preFilled;
    if (historyData != null) {
      preFilled = BillItem(
        id: "temp", srNo: items.length + 1, medicineID: med.id, name: med.name, packing: med.packing,
        batch: historyData['batch'], exp: "12/26", hsn: med.hsnCode, mrp: (historyData['mrp'] as num).toDouble(),
        rate: (historyData['rate'] as num).toDouble(), gstRate: (historyData['gst'] as num).toDouble(), qty: 0, total: 0,
      );
    }

    showDialog(
      context: context,
      builder: (c) => ItemEntryCard(
        med: med,
        srNo: items.length + 1,
        partyState: selectedParty?.state ?? "Rajasthan",
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
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Credit Note: ${returnNoC.text}", style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          Text(selectedParty?.name ?? "Select Party First", style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ]),
        backgroundColor: const Color(0xFFB71C1C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print_rounded), onPressed: items.isEmpty ? null : () => _handlePrint(ph)),
          if (items.isNotEmpty) TextButton(onPressed: () => _handleSave(ph), child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(children: [
        _buildHeader(ph),
        if (selectedParty != null) ...[
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

  // --- UI: HEADER (PARTY SELECTION) ---
  Widget _buildHeader(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: Colors.white,
    child: Column(children: [
        if (selectedParty == null) ...[
          TextField(
            decoration: const InputDecoration(hintText: "Search Customer for Credit Note...", prefixIcon: Icon(Icons.person_search), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => partySearch = v),
          ),
          Container(
            height: 150, margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
            child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(partySearch.toLowerCase())).map((p) => ListTile(
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(p.city),
              onTap: () => setState(() => selectedParty = p),
            )).toList()),
          )
        ] else
          ListTile(
            tileColor: Colors.red.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: const CircleAvatar(backgroundColor: Color(0xFFB71C1C), child: Icon(Icons.person, color: Colors.white)),
            title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${selectedParty!.city} | Bal: ₹${selectedParty!.opBal}"),
            trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedParty = null)),
          ),
    ]),
  );

  // --- UI: QUICK MODE ---
  Widget _buildQuickModeToggle() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    child: Row(children: [
        _modeBtn("SELLABLE RETURN", !isBreakageMode, Colors.green.shade700, () => setState(() => isBreakageMode = false)),
        const SizedBox(width: 10),
        _modeBtn("EXPIRY / BREAKAGE", isBreakageMode, Colors.orange.shade900, () => setState(() => isBreakageMode = true)),
    ]),
  );

  Widget _modeBtn(String l, bool act, Color c, VoidCallback tap) => Expanded(child: InkWell(onTap: tap, child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: act ? c : Colors.grey.shade200, borderRadius: BorderRadius.circular(10)), child: Text(l, textAlign: TextAlign.center, style: TextStyle(color: act ? Colors.white : Colors.black54, fontWeight: FontWeight.bold, fontSize: 10)))));

  // --- UI: PRODUCT SEARCH ---
  Widget _buildLiveSearch(PharoahManager ph) => Padding(
    padding: const EdgeInsets.all(10),
    child: Column(children: [
        TextField(
          decoration: InputDecoration(
            hintText: "Search product to add in ${isBreakageMode ? 'Breakage' : 'Return'}...",
            prefixIcon: Icon(Icons.search, color: isBreakageMode ? Colors.orange : Colors.green),
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
  Widget _buildItemCard(BillItem it, int index) {
    Color theme = it.isBreakage ? Colors.orange.shade900 : Colors.green.shade800;
    return Card(
      elevation: 2, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.withOpacity(0.2))),
      child: ListTile(
        onTap: () {
          final ph = Provider.of<PharoahManager>(context, listen: false);
          final med = ph.medicines.firstWhere((m) => m.id == it.medicineID);
          showDialog(context: context, builder: (c) => ItemEntryCard(med: med, srNo: it.srNo, partyState: selectedParty!.state, existingItem: it, onAdd: (updated) { setState(() => items[index] = updated); Navigator.pop(context); }, onCancel: () => Navigator.pop(context)));
        },
        tileColor: it.isBreakage ? Colors.orange.shade50.withOpacity(0.5) : Colors.white,
        title: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: theme, borderRadius: BorderRadius.circular(5)), child: Text(it.isBreakage ? "EXP" : "RET", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Rate: ₹${it.rate} | MRP: ₹${it.mrp}"),
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
          SizedBox(width: 100, child: TextField(controller: discountC, keyboardType: TextInputType.number, textAlign: TextAlign.right, decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()), onSelectionChanged: (v,e)=>setState((){}), onChanged: (v)=>setState((){}))),
        ]),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("GRAND TOTAL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text("₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFFB71C1C))),
          ]),
          Text("Round Off: ${roundOff.toStringAsFixed(2)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
    ]),
  );

  Widget _buildEmptyState() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.assignment_return_outlined, size: 60, color: Colors.grey.shade300), const Text("No items added yet", style: TextStyle(color: Colors.grey))]));

  void _handleSave(PharoahManager ph) {
    if (selectedParty == null) return;
    ph.finalizeSaleReturn(billNo: returnNoC.text, date: selectedDate, party: selectedParty!, items: items, total: grandTotal);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Credit Note Saved!"), backgroundColor: Colors.green));
  }

  void _handlePrint(PharoahManager ph) async {
    if (selectedParty == null) return;
    final returnObj = SaleReturn(id: "temp", billNo: returnNoC.text, date: selectedDate, partyName: selectedParty!.name, items: items, totalAmount: grandTotal);
    await PdfRouterService.printCreditNote(returnObj: returnObj, party: selectedParty!, ph: ph);
  }
}
