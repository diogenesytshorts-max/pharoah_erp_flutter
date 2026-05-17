// FILE: lib/returns/purchase_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../purchase/purchase_billing_view.dart'; // 🔥 Entry Card ke liye
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
  DateTime selectedDate = DateTime.now();
  Party? selectedSupplier;
  
  List<PurchaseItem> items = []; 
  bool isBreakageMode = false; // 🔥 Toggle: Sellable vs Breakage
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
        selectedSupplier = ph.parties.firstWhere((p) => p.name == ex.distributorName);
      } catch (e) {
        selectedSupplier = Party(id: "0", name: ex.distributorName);
      }
      setState(() => isLoading = false);
    } else {
      if (ph.activeCompany != null) {
        String nextNo = await PharoahNumberingEngine.getNextNumber(
          type: "RETURN", 
          companyID: ph.activeCompany!.id,
          prefix: "DN-", // Debit Note Prefix
          startFrom: 1,
          currentList: ph.purchaseReturns,
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
  // 🪄 THE MAGIC HISTORY BOX (PURCHASE REFERENCE)
  // ===========================================================================
  void _showPurchaseHistoryBox(Medicine med, PharoahManager ph) {
    if (selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Pehle Supplier select karein!")));
      return;
    }

    // Manager ka scanner function (isSale: false means Purchase history)
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
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(children: [
          Container(margin: const EdgeInsets.all(15), height: 5, width: 50, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
          const Text("PURCHASE HISTORY (Current FY)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.brown, letterSpacing: 1)),
          Padding(padding: const EdgeInsets.all(10), child: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          const Divider(),
          if (history.isEmpty)
             const Expanded(child: Center(child: Text("Is Supplier se is saal ye item nahi kharida gaya.")))
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
                        Text("Batch: ${h['batch']}", style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.bold)),
                      ]),
                      subtitle: Text("Date: ${DateFormat('dd-MMM').format(h['date'])} | Pur.Rate: ₹${h['rate']} | MRP: ₹${h['mrp']}"),
                      trailing: const Icon(Icons.download_done_rounded, color: Colors.brown),
                      onTap: () {
                        Navigator.pop(c);
                        _showPurchaseEntryCard(med, historyData: h); // 🔥 AUTOFILL
                      },
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextButton.icon(
              onPressed: () { Navigator.pop(c); _showPurchaseEntryCard(med); },
              icon: const Icon(Icons.edit_note), label: const Text("MANUAL ENTRY (NOT IN HISTORY)")
            ),
          )
        ]),
      ),
    );
  }

  // ===========================================================================
  // 📝 PURCHASE ENTRY CARD BRIDGE (AUTO-FILL SUPPORT)
  // ===========================================================================
  void _showPurchaseEntryCard(Medicine med, {Map<String, dynamic>? historyData}) {
    PurchaseItem? preFilled;
    if (historyData != null) {
      preFilled = PurchaseItem(
        id: "temp",
        srNo: items.length + 1,
        medicineID: med.id,
        name: med.name,
        packing: med.packing,
        batch: historyData['batch'],
        exp: "12/26", 
        hsn: med.hsnCode,
        mrp: historyData['mrp'],
        purchaseRate: historyData['rate'],
        gstRate: historyData['gst'],
        qty: 0, 
        total: 0,
      );
    }

    showDialog(
      context: context,
      builder: (c) => PurchaseItemEntryCard(
        med: med,
        srNo: items.length + 1,
        existingItem: preFilled, // 🔥 Autofill Logic
        onAdd: (newItem) {
          setState(() {
            // Debit Note always reduces stock
            items.add(newItem.copyWith(isBreakage: isBreakageMode)); 
          });
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  // ===========================================================================
  // 🖥️ UI BUILDER
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F3),
      appBar: AppBar(
        title: Text("Debit Note: ${returnNoC.text}"),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.print_rounded), onPressed: items.isEmpty ? null : () => _handlePrint(ph)),
          if (items.isNotEmpty) IconButton(icon: const Icon(Icons.check_circle, size: 28), onPressed: () => _handleSave(ph)),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(ph),
          _buildModeSwitcher(),
          _buildProductSearch(ph),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text("Debit Note is empty. Search products to add."))
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
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
    child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (selectedSupplier == null)
               const Text("Select Supplier...", style: TextStyle(color: Colors.brown, fontWeight: FontWeight.bold))
            else
               Text(selectedSupplier!.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.brown.shade900)),
            Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 10),
        if (selectedSupplier == null) 
          TextField(decoration: const InputDecoration(hintText: "Search Distributor...", prefixIcon: Icon(Icons.business_rounded), isDense: true, border: OutlineInputBorder()), onSubmitted: (v) {
            try { setState(() => selectedSupplier = ph.parties.firstWhere((p) => p.group == "Sundry Creditors" && p.name.toLowerCase().contains(v.toLowerCase()))); } catch(e) {}
          })
        else
          Row(children: [
            const Icon(Icons.location_on, size: 12, color: Colors.grey),
            Text(" ${selectedSupplier!.city}", style: const TextStyle(fontSize: 11, color: Colors.grey)),
            const Spacer(),
            TextButton(onPressed: () => setState(() => selectedSupplier = null), child: const Text("CHANGE SUPPLIER", style: TextStyle(fontSize: 10, color: Colors.brown))),
          ]),
    ]),
  );

  Widget _buildModeSwitcher() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 10),
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text("SELLABLE RETURN"), icon: Icon(Icons.inventory_2_rounded)),
        ButtonSegment(value: true, label: Text("DAMAGE / BREAKAGE"), icon: Icon(Icons.delete_sweep_rounded)),
      ],
      selected: {isBreakageMode},
      style: SegmentedButton.styleFrom(
        selectedBackgroundColor: isBreakageMode ? Colors.deepOrange.shade900 : Colors.blue.shade900,
        selectedForegroundColor: Colors.white,
      ),
      onSelectionChanged: (v) => setState(() => isBreakageMode = v.first),
    ),
  );

  Widget _buildProductSearch(PharoahManager ph) => Padding(
    padding: const EdgeInsets.all(10),
    child: InkWell(
      onTap: () {
        showModalBottomSheet(context: context, isScrollControlled: true, builder: (c) => Container(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(children: [
            Padding(padding: const EdgeInsets.all(15), child: TextField(autofocus: true, decoration: const InputDecoration(hintText: "Search Product for Debit Note...", border: OutlineInputBorder()), onChanged: (v) => setState(() => searchQuery = v))),
            Expanded(child: ListView(children: ph.medicines.where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase())).map((m) => ListTile(title: Text(m.name), subtitle: Text(m.packing), onTap: () { Navigator.pop(context); _showPurchaseHistoryBox(m, ph); })).toList())),
          ]),
        ));
      },
      child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.brown.shade200)), child: Row(children: [const Icon(Icons.search, color: Colors.brown), const SizedBox(width: 10), Text("Search Product for ${isBreakageMode ? 'Breakage' : 'Return'}...", style: const TextStyle(color: Colors.grey))])),
    ),
  );

  Widget _buildItemCard(PurchaseItem it, int index) {
    Color textColor = it.isBreakage ? Colors.deepOrange.shade900 : Colors.blue.shade900;
    Color bgColor = it.isBreakage ? Colors.deepOrange.shade50 : Colors.blue.shade50;

    return Card(
      elevation: 2, margin: const EdgeInsets.symmetric(vertical: 5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        tileColor: bgColor,
        title: Row(children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2), decoration: BoxDecoration(color: textColor, borderRadius: BorderRadius.circular(4)), child: Text(it.isBreakage ? "EXP" : "RET", style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          Text(it.name, style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        ]),
        subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Pur.Rate: ₹${it.purchaseRate} | MRP: ₹${it.mrp}"),
        trailing: Text("₹${it.total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        onLongPress: () => setState(() { items.removeAt(index); _recalculateSR(); }),
      ),
    );
  }

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.all(20), color: Colors.white,
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      const Text("NET DEBIT VALUE", style: TextStyle(fontWeight: FontWeight.bold)),
      Text("₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.brown.shade900)),
    ]),
  );

  void _handleSave(PharoahManager ph) {
    if (selectedSupplier == null) return;
    ph.finalizePurchaseReturn(billNo: returnNoC.text, date: selectedDate, party: selectedSupplier!, items: items, total: totalAmt);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Debit Note Generated! Supplier ledger adjusted."), backgroundColor: Colors.green));
  }

  void _handlePrint(PharoahManager ph) async {
    if (selectedSupplier == null) return;
    final returnObj = PurchaseReturn(id: "temp", billNo: returnNoC.text, date: selectedDate, distributorName: selectedSupplier!.name, items: items, totalAmount: totalAmt);
    await PdfRouterService.printDebitNote(returnObj: returnObj, supplier: selectedSupplier!, ph: ph);
  }
}
