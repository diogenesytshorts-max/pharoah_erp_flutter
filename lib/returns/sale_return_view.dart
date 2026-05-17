// FILE: lib/returns/sale_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../item_entry_card.dart';
import '../product_master.dart';
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
  DateTime selectedDate = DateTime.now();
  Party? selectedParty;
  
  List<BillItem> items = []; 
  bool isBreakageMode = false; // 🔥 Quick Switch Mode
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

  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  void _recalculateSR() {
    setState(() {
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(srNo: i + 1);
      }
    });
  }

  // ===========================================================================
  // 🪄 THE MAGIC HISTORY BOX (INTERCEPTOR)
  // ===========================================================================
  void _showHistoryMagicBox(Medicine med, PharoahManager ph) {
    if (selectedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pehle Customer Select karein!")));
      return;
    }

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
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(children: [
          Container(margin: const EdgeInsets.all(15), height: 5, width: 50, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const Text("SALES HISTORY (Current FY)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.indigo, letterSpacing: 1)),
          Padding(padding: const EdgeInsets.all(10), child: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const Divider(),
          if (history.isEmpty)
             const Expanded(child: Center(child: Text("Is party ko is saal ye item nahi becha gaya.")))
          else
            Expanded(
              child: ListView.builder(
                itemCount: history.length,
                itemBuilder: (c, i) {
                  final h = history[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                    child: ListTile(
                      title: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text("Bill: ${h['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text("Batch: ${h['batch']}", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                      ]),
                      subtitle: Text("Date: ${DateFormat('dd-MMM').format(h['date'])} | Rate: ₹${h['rate']} | MRP: ₹${h['mrp']}"),
                      trailing: const Icon(Icons.input_rounded, color: Colors.green),
                      onTap: () {
                        Navigator.pop(c);
                        _showEntryCard(med, historyData: h); // 🔥 AUTOFILL CALL
                      },
                    ),
                  );
                },
              ),
            ),
          // --- MANUAL ENTRY OPTION (Will show batch history actions chips) ---
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextButton.icon(
              onPressed: () { Navigator.pop(c); _showEntryCard(med); },
              icon: const Icon(Icons.edit_note), label: const Text("Enter Manually / New Batch")
            ),
          )
        ]),
      ),
    );
  }

  // ===========================================================================
  // 📝 ENTRY CARD BRIDGE (SALE BILL MIRROR)
  // ===========================================================================
  void _showEntryCard(Medicine med, {Map<String, dynamic>? historyData}) {
    BillItem? preFilled;
    if (historyData != null) {
      // Mocking an existing item to trigger Autofill in ItemEntryCard
      preFilled = BillItem(
        id: "temp",
        srNo: items.length + 1,
        medicineID: med.id,
        name: med.name,
        packing: med.packing,
        batch: historyData['batch'],
        exp: "12/26", // Placeholder, will be corrected in card
        hsn: med.hsnCode,
        mrp: historyData['mrp'],
        rate: historyData['rate'],
        gstRate: historyData['gst'],
        qty: 0, 
        total: 0,
      );
    }

    showDialog(
      context: context,
      builder: (c) => ItemEntryCard(
        med: med,
        srNo: items.length + 1,
        partyState: selectedParty?.state ?? "Rajasthan",
        existingItem: preFilled, // 🔥 This triggers the Autofill
        onAdd: (newItem) {
          setState(() {
            // Adding the item with the correct breakage tag
            items.add(newItem.copyWith(isBreakage: isBreakageMode)); 
          });
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  // ===========================================================================
  // 🖥️ UI BUILDER (EXACT BILLING VIEW MIRROR)
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        title: Text("Credit Note: ${returnNoC.text}"),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print_rounded), onPressed: items.isEmpty ? null : () => _handlePrint(ph)),
          if (items.isNotEmpty) TextButton(onPressed: () => _handleSave(ph), child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(ph),
          _buildModeSwitcher(), // 🔥 NAYA Mode Switcher
          _buildSearchBarTrigger(ph),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("Return list is empty."))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: items.length,
                    itemBuilder: (c, i) => _buildItemCard(items[i], i),
                  ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), margin: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (selectedParty == null)
               const Text("Select Customer...", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
            else
               Text(selectedParty!.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade900)),
            Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        if (selectedParty == null) 
          TextField(decoration: const InputDecoration(hintText: "Type name to select party...", prefixIcon: Icon(Icons.person_search), isDense: true, border: OutlineInputBorder()), onSubmitted: (v) {
            try { setState(() => selectedParty = ph.parties.firstWhere((p) => p.name.toLowerCase().contains(v.toLowerCase()))); } catch(e) {}
          })
        else
          Row(children: [
            const Icon(Icons.location_on, size: 12, color: Colors.grey),
            Text(" ${selectedParty!.city}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const Spacer(),
            TextButton(onPressed: () => setState(() => selectedParty = null), child: const Text("CHANGE PARTY", style: TextStyle(fontSize: 10))),
          ]),
    ]),
  );

  Widget _buildModeSwitcher() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text("SALE RETURN (Stock In)"), icon: Icon(Icons.assignment_return_rounded)),
        ButtonSegment(value: true, label: Text("BREAKAGE / EXPIRY"), icon: Icon(Icons.delete_sweep_rounded)),
      ],
      selected: {isBreakageMode},
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: isBreakageMode ? Colors.orange.shade900 : Colors.green.shade800,
        selectedForegroundColor: Colors.white,
      ),
      onSelectionChanged: (v) => setState(() => isBreakageMode = v.first),
    ),
  );

  Widget _buildSearchBarTrigger(PharoahManager ph) => Padding(
    padding: const EdgeInsets.all(10),
    child: InkWell(
      onTap: () {
        showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(15), child: TextField(autofocus: true, decoration: const InputDecoration(hintText: "Search Medicine...", border: OutlineInputBorder()), onChanged: (v) => setState(() => searchQuery = v))),
            Expanded(child: ListView(children: ph.medicines.where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase())).map((m) => ListTile(title: Text(m.name), subtitle: Text(m.packing), onTap: () { Navigator.pop(context); _showHistoryMagicBox(m, ph); })).toList())),
          ]),
        ));
      },
      child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)), child: Row(children: [const Icon(Icons.search, color: Colors.red), const SizedBox(width: 10), Text("Tap to search product for ${isBreakageMode ? 'Breakage' : 'Return'}...", style: const TextStyle(color: Colors.grey))])),
    ),
  );

  Widget _buildItemCard(BillItem it, int index) {
    Color cardColor = it.isBreakage ? Colors.orange.shade50 : Colors.green.shade50;
    Color textColor = it.isBreakage ? Colors.orange.shade900 : Colors.green.shade900;

    return Card(
      elevation: 2, margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: textColor.withOpacity(0.3))),
      child: ListTile(
        tileColor: cardColor,
        title: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(4)), child: Text(it.isBreakage ? "EXP" : "RET", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Text(it.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        ]),
        subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Rate: ₹${it.rate} | MRP: ₹${it.mrp}"),
        trailing: Text("₹${it.total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        onLongPress: () => setState(() { items.removeAt(index); _recalculateSR(); }),
      ),
    );
  }

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.all(20), color: Colors.white,
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text("NET CREDIT TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
      Text("₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red.shade900)),
    ]),
  );

  void _handleSave(PharoahManager ph) {
    if (selectedParty == null) return;
    ph.finalizeSaleReturn(billNo: returnNoC.text, date: selectedDate, party: selectedParty!, items: items, total: totalAmt);
    Navigator.pop(context);
  }

  void _handlePrint(PharoahManager ph) async {
    if (selectedParty == null) return;
    final returnObj = SaleReturn(id: "temp", billNo: returnNoC.text, date: selectedDate, partyName: selectedParty!.name, items: items, totalAmount: totalAmt);
    await PdfRouterService.printCreditNote(returnObj: returnObj, party: selectedParty!, ph: ph);
  }
}
