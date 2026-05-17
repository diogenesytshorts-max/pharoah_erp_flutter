// FILE: lib/returns/sale_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';

class SaleReturnView extends StatefulWidget {
  final SaleReturn? existingRecord; 
  const SaleReturnView({super.key, this.existingRecord});

  @override
  State<SaleReturnView> createState() => _SaleReturnViewState();
}

class _SaleReturnViewState extends State<SaleReturnView> {
  final returnNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Party? selectedParty;
  
  List<BillItem> items = []; // Combined List (Logic isBreakage par chalega)
  bool isBreakageMode = false; // Toggle for adding items
  String searchQuery = "";
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
          type: "RETURN",
          companyID: ph.activeCompany!.id,
          prefix: series.prefix,
          startFrom: series.startNumber,
          currentList: ph.saleReturns,
        );
        setState(() {
          returnNoC.text = nextNo;
          selectedDate = AppDateLogic.getSmartDate(ph.currentFY);
          isLoading = false;
        });
      }
    }
  }

  // --- LOGIC: DUAL LIST BIFURCATION ---
  List<BillItem> get sellableList => items.where((i) => !i.isBreakage).toList();
  List<BillItem> get breakageList => items.where((i) => i.isBreakage).toList();
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  void _recalculateSR() {
    setState(() {
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(srNo: i + 1);
      }
    });
  }

  // ===========================================================================
  // 🪄 THE MAGIC HISTORY BOX (CURRENT FY ONLY)
  // ===========================================================================
  void _showMagicHistory(Medicine med, PharoahManager ph) {
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
          color: Colors.white, 
          borderRadius: BorderRadius.vertical(top: Radius.circular(30))
        ),
        child: Column(children: [
          Container(margin: const EdgeInsets.all(15), height: 5, width: 50, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          Text("CHOOSE FROM PREVIOUS BILLS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.indigo.shade900, letterSpacing: 1)),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          const Divider(),
          if (history.isEmpty)
             const Expanded(child: Center(child: Text("No purchase history found for this party in this year.")))
          else
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (c, i) {
                  final h = history[i];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    decoration: BoxDecoration(border: Border.all(color: Colors.indigo.withOpacity(0.1)), borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("Bill: ${h['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Batch: ${h['batch']}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ]),
                      subtitle: Text("Date: ${DateFormat('dd-MMM').format(h['date'])} | Qty: ${h['qty']} | Rate: ₹${h['rate']} | MRP: ₹${h['mrp']}"),
                      trailing: const Icon(Icons.check_circle, color: Colors.green),
                      onTap: () {
                        Navigator.pop(c);
                        _showQuantityDialog(med, preFill: h);
                      },
                    ),
                  );
                },
              ),
            ),
          // --- MANUAL ENTRY IF NOT IN HISTORY ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: ElevatedButton.icon(
              onPressed: () { Navigator.pop(c); _showQuantityDialog(med); },
              icon: const Icon(Icons.edit), label: const Text("NOT IN LIST? ENTER MANUALLY")
            ),
          )
        ]),
      ),
    );
  }

  // ===========================================================================
  // 📝 QUANTITY & RATE ENTRY (AUTO-FILL SUPPORT)
  // ===========================================================================
  void _showQuantityDialog(Medicine med, {Map<String, dynamic>? preFill}) {
    final qtyC = TextEditingController();
    final rateC = TextEditingController(text: preFill != null ? preFill['rate'].toString() : med.rateA.toString());
    final mrpC = TextEditingController(text: preFill != null ? preFill['mrp'].toString() : med.mrp.toString());
    final batchC = TextEditingController(text: preFill != null ? preFill['batch'].toString() : "");
    final gstC = TextEditingController(text: preFill != null ? preFill['gst'].toString() : med.gst.toString());

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Return Item Details (${isBreakageMode ? 'Breakage' : 'Sellable'})", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            const SizedBox(height: 15),
            TextField(controller: batchC, decoration: const InputDecoration(labelText: "Batch Number", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: rateC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Sale Rate", border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: mrpC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "MRP", border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: qtyC, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Return Qty", border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: gstC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "GST %", border: OutlineInputBorder()))),
            ]),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: isBreakageMode ? Colors.orange.shade900 : Colors.green.shade800),
            onPressed: () {
              double q = double.tryParse(qtyC.text) ?? 0;
              if (q <= 0) return;
              double r = double.tryParse(rateC.text) ?? 0;
              double g = double.tryParse(gstC.text) ?? 0;

              setState(() {
                items.add(BillItem(
                  id: DateTime.now().toString(),
                  srNo: items.length + 1,
                  medicineID: med.id,
                  name: med.name,
                  packing: med.packing,
                  batch: batchC.text.toUpperCase(),
                  exp: preFill?['exp'] ?? "12/26",
                  hsn: med.hsnCode,
                  mrp: double.tryParse(mrpC.text) ?? 0,
                  qty: q,
                  rate: r,
                  gstRate: g,
                  total: (q * r) * (1 + g/100),
                  isBreakage: isBreakageMode, // 🔥 FLAG SAVED
                ));
              });
              Navigator.pop(c);
            }, 
            child: const Text("ADD TO LIST", style: TextStyle(color: Colors.white))
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        title: const Text("Advanced Credit Note", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          if (items.isNotEmpty)
             IconButton(icon: const Icon(Icons.save_rounded, size: 28), onPressed: () => _handleSave(ph)),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(ph),
          _buildModeToggle(),
          _buildProductSearch(ph),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("No items added. Search medicine to begin."))
                : ListView(
                    children: [
                      if (sellableList.isNotEmpty) ...[
                        _listHeader("SECTION 1: SELLABLE RETURNS", Icons.check_circle, Colors.green.shade800),
                        ...sellableList.map((it) => _itemCard(it)),
                      ],
                      if (breakageList.isNotEmpty) ...[
                        _listHeader("SECTION 2: EXPIRY & BREAKAGE", Icons.warning_amber_rounded, Colors.orange.shade900),
                        ...breakageList.map((it) => _itemCard(it)),
                      ],
                    ],
                  ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: Colors.white,
    child: Column(children: [
        Row(children: [
          Expanded(child: TextField(controller: returnNoC, readOnly: true, decoration: const InputDecoration(labelText: "VOUCHER NO", border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Color(0xFFF5F5F5)))),
          const SizedBox(width: 10),
          Expanded(child: InkWell(onTap: () async {
            DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: ph.currentFY, initialDate: selectedDate);
            if(p!=null) setState(()=>selectedDate = p);
          }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(DateFormat('dd/MM/yyyy').format(selectedDate)), const Icon(Icons.calendar_month, size: 16)])))),
        ]),
        const SizedBox(height: 10),
        if (selectedParty == null)
           _buildPartySearch(ph)
        else
           ListTile(tileColor: Colors.blue.shade50, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), leading: const Icon(Icons.person), title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedParty = null))),
    ]),
  );

  Widget _buildPartySearch(PharoahManager ph) => TextField(
    decoration: const InputDecoration(hintText: "Search Customer for Credit Note...", prefixIcon: Icon(Icons.person_search), border: OutlineInputBorder()),
    onChanged: (v) => setState(() => searchQuery = v),
    onSubmitted: (v) {
      try {
        final p = ph.parties.firstWhere((p) => p.name.toLowerCase().contains(v.toLowerCase()));
        setState(() => selectedParty = p);
      } catch (e) {}
    },
  );

  Widget _buildModeToggle() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text("SELLABLE RETURN"), icon: Icon(Icons.inventory)),
        ButtonSegment(value: true, label: Text("EXPIRY / BREAKAGE"), icon: Icon(Icons.delete_sweep)),
      ],
      selected: {isBreakageMode},
      onSelectionChanged: (v) => setState(() => isBreakageMode = v.first),
    ),
  );

  Widget _buildProductSearch(PharoahManager ph) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 15),
    child: TextField(
      decoration: InputDecoration(
        hintText: "Search Product for ${isBreakageMode ? 'Breakage' : 'Return'}...", 
        prefixIcon: const Icon(Icons.search), 
        filled: true, fillColor: isBreakageMode ? Colors.orange.shade50 : Colors.green.shade50,
        border: const OutlineInputBorder()
      ),
      onSubmitted: (v) {
        if(selectedParty == null) return;
        try {
          final med = ph.medicines.firstWhere((m) => m.name.toLowerCase().contains(v.toLowerCase()));
          _showMagicHistory(med, ph);
        } catch(e) {}
      },
    ),
  );

  Widget _listHeader(String title, IconData icon, Color color) => Padding(
    padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
    child: Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: color, letterSpacing: 1))]),
  );

  Widget _itemCard(BillItem it) => Card(
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    child: ListTile(
      dense: true,
      title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Rate: ₹${it.rate} | MRP: ₹${it.mrp}"),
      trailing: Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
      onLongPress: () => setState(() => items.removeWhere((i) => i.id == it.id)),
    ),
  );

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.all(20), color: Colors.white,
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text("NET CREDIT NOTE TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
      Text("₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red.shade900)),
    ]),
  );

  void _handleSave(PharoahManager ph) {
    if (selectedParty == null) return;
    ph.finalizeSaleReturn(billNo: returnNoC.text, date: selectedDate, party: selectedParty!, items: items, total: totalAmt);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Credit Note Generated & Stock Adjusted!"), backgroundColor: Colors.green));
  }
}
