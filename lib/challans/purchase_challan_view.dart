// FILE: lib/challans/purchase_challan_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../purchase/purchase_billing_view.dart'; 
import '../pharoah_date_controller.dart';

class PurchaseChallanView extends StatefulWidget {
  final PurchaseChallan? existingRecord; // NAYA: Edit support

  const PurchaseChallanView({super.key, this.existingRecord});

  @override
  State<PurchaseChallanView> createState() => _PurchaseChallanViewState();
}

class _PurchaseChallanViewState extends State<PurchaseChallanView> {
  final supplierChallanNoC = TextEditingController();
  final internalNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Party? selectedDistributor;
  List<PurchaseItem> items = [];
  String searchQuery = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initPurchaseFlow();
  }

  // --- LOGIC: NEW ENTRY vs MODIFY ---
  void _initPurchaseFlow() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    if (widget.existingRecord != null) {
      // CASE: EDIT MODE (Purana record load karo)
      final ex = widget.existingRecord!;
      internalNoC.text = ex.internalNo;
      supplierChallanNoC.text = ex.billNo;
      selectedDate = ex.date;
      items = List.from(ex.items);
      
      // Distributor dhoondhna
      try {
        selectedDistributor = ph.parties.firstWhere((p) => p.name == ex.distributorName);
      } catch (e) {
        selectedDistributor = Party(id: "0", name: ex.distributorName);
      }
      setState(() => isLoading = false);
    } else {
      // CASE: NEW ENTRY
      if (ph.activeCompany != null) {
        String nextNo = await PharoahNumberingEngine.getNextNumber(
          type: "PUR_CHALLAN",
          companyID: ph.activeCompany!.id,
          currentList: ph.purchaseChallans,
        );
        setState(() {
          internalNoC.text = nextNo;
          selectedDate = PharoahDateController.getInitialBillDate(ph.currentFY);
          isLoading = false;
        });
      }
    }
  }

  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1),
      appBar: AppBar(
        title: Text(widget.existingRecord != null ? "Modify Inward Challan" : "Purchase Inward Note"),
        backgroundColor: Colors.amber.shade900,
        foregroundColor: Colors.white,
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _handleSave(ph),
              child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildAlertBanner(),
          Expanded(
            child: selectedDistributor == null 
              ? _buildSupplierPicker(ph) 
              : _buildChallanItemsList(ph),
          ),
          if (selectedDistributor != null) _buildSummaryFooter(),
        ],
      ),
      floatingActionButton: (selectedDistributor != null)
          ? FloatingActionButton.extended(
              onPressed: () => _showItemSearch(ph),
              backgroundColor: Colors.amber.shade900,
              icon: const Icon(Icons.add_box_rounded, color: Colors.white),
              label: const Text("ADD ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: internalNoC, 
                  readOnly: true, // Internal ID is locked
                  decoration: const InputDecoration(labelText: "INTERNAL ID", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF5F5F5))
                )
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: supplierChallanNoC, 
                  textCapitalization: TextCapitalization.characters, 
                  decoration: const InputDecoration(labelText: "SUPPLIER CH. NO", border: OutlineInputBorder())
                )
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () async {
              DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: Provider.of<PharoahManager>(context, listen: false).currentFY, initialDate: selectedDate);
              if (p != null) setState(() => selectedDate = p);
            },
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("DATE: ${DateFormat('dd/MM/yyyy').format(selectedDate)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const Icon(Icons.calendar_month, color: Colors.amber, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertBanner() {
    return Container(
      width: double.infinity,
      color: Colors.amber.shade100,
      padding: const EdgeInsets.all(8),
      child: const Text("This entry will update your current stock levels.", textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
    );
  }

  Widget _buildSupplierPicker(PharoahManager ph) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: TextField(
            decoration: const InputDecoration(hintText: "Search Supplier Name...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: ph.parties.where((p) => p.group == "Sundry Creditors" && p.name.toLowerCase().contains(searchQuery.toLowerCase())).map((p) => ListTile(
              leading: const Icon(Icons.business),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => setState(() => selectedDistributor = p),
            )).toList(),
          ),
        )
      ],
    );
  }

  Widget _buildChallanItemsList(PharoahManager ph) {
    return Column(
      children: [
        ListTile(
          tileColor: Colors.amber.shade100,
          leading: const Icon(Icons.business, color: Colors.brown),
          title: Text(selectedDistributor!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: (widget.existingRecord == null) // Supplier change allowed only in new entries
              ? IconButton(onPressed: () => setState(() => selectedDistributor = null), icon: const Icon(Icons.edit, color: Colors.blue))
              : null,
        ),
        Expanded(
          child: items.isEmpty 
            ? const Center(child: Text("No items in this inward note."))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (c, i) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Batch: ${items[i].batch} | Qty: ${items[i].qty.toInt()} + ${items[i].freeQty.toInt()}"),
                    trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    onLongPress: () => setState(() => items.removeAt(i)),
                  ),
                ),
              ),
        ),
      ],
    );
  }

  Widget _buildSummaryFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("TOTAL INWARD:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.amber.shade900)),
        ],
      ),
    );
  }

  void _showItemSearch(PharoahManager ph) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
             const Padding(padding: EdgeInsets.all(15), child: Text("SELECT ITEM", style: TextStyle(fontWeight: FontWeight.bold))),
             Expanded(
               child: ListView.builder(
                 itemCount: ph.medicines.length,
                 itemBuilder: (c, i) => ListTile(
                   title: Text(ph.medicines[i].name),
                   onTap: () {
                     Navigator.pop(context);
                     _showPurchaseEntry(ph.medicines[i]);
                   },
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }

  void _showPurchaseEntry(Medicine med) {
    showDialog(
      context: context,
      builder: (c) => PurchaseItemEntryCard(
        med: med,
        srNo: items.length + 1,
        onAdd: (newItem) {
          setState(() { items.add(newItem); });
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  void _handleSave(PharoahManager ph) {
    // 1. Agar edit mode hai, toh purana record hatao taaki stock double na ho
    if (widget.existingRecord != null) {
      ph.deletePurchaseChallan(widget.existingRecord!.id);
    }

    // 2. Finalize New/Modified Challan
    ph.finalizePurchaseChallan(
      challanNo: supplierChallanNoC.text.trim(),
      internalNo: internalNoC.text,
      date: selectedDate,
      party: selectedDistributor!,
      items: items,
      total: totalAmt,
    );
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Inward Updated & Stock Synced!"), backgroundColor: Colors.green));
  }
}
