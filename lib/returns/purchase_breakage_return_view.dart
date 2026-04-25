// FILE: lib/returns/purchase_breakage_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../purchase/purchase_billing_view.dart';
import '../pharoah_date_controller.dart';

class PurchaseBreakageReturnView extends StatefulWidget {
  const PurchaseBreakageReturnView({super.key});

  @override
  State<PurchaseBreakageReturnView> createState() => _PurchaseBreakageReturnViewState();
}

class _PurchaseBreakageReturnViewState extends State<PurchaseBreakageReturnView> {
  final returnNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Party? selectedSupplier;
  List<PurchaseItem> items = [];
  String searchQuery = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initReturn();
  }

  // PRN- series use karenge lekin type "Breakage" bhejenge
  void _initReturn() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    if (ph.activeCompany != null) {
      String nextNo = await PharoahNumberingEngine.getNextNumber(
        type: "PUR_RETURN",
        companyID: ph.activeCompany!.id,
        currentList: ph.purchaseReturns,
      );
      setState(() {
        returnNoC.text = nextNo;
        selectedDate = PharoahDateController.getInitialBillDate(ph.currentFY);
        isLoading = false;
      });
    }
  }

  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFEFEBE9), // Brownish tint
      appBar: AppBar(
        title: const Text("Pur. Return (Breakage/Exp)"),
        backgroundColor: Colors.brown.shade800,
        foregroundColor: Colors.white,
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _handleSave(ph),
              child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildAlertBanner(),
          Expanded(
            child: selectedSupplier == null 
              ? _buildSupplierPicker(ph) 
              : _buildReturnItemsList(ph),
          ),
          if (selectedSupplier != null) _buildSummaryFooter(),
        ],
      ),
      floatingActionButton: (selectedSupplier != null)
          ? FloatingActionButton.extended(
              onPressed: () => _showItemSearch(ph),
              backgroundColor: Colors.brown.shade800,
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              label: const Text("ADD EXPIRED MAAL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: TextField(controller: returnNoC, decoration: const InputDecoration(labelText: "DEBIT NOTE NO", border: OutlineInputBorder(), isDense: true))),
          const SizedBox(width: 15),
          Expanded(
            child: InkWell(
              onTap: () async {
                DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: Provider.of<PharoahManager>(context, listen: false).currentFY, initialDate: selectedDate);
                if (p != null) setState(() => selectedDate = p);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)),
                child: Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
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
      color: Colors.brown.shade100,
      padding: const EdgeInsets.all(8),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 14, color: Colors.brown),
          SizedBox(width: 8),
          Text("This entry will decrease your non-sellable (Breakage) stock.", 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.brown)),
        ],
      ),
    );
  }

  Widget _buildSupplierPicker(PharoahManager ph) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(15),
          child: TextField(
            decoration: const InputDecoration(hintText: "Search Supplier for Return...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: ph.parties.where((p) => p.group == "Sundry Creditors" && p.name.toLowerCase().contains(searchQuery.toLowerCase())).map((p) => ListTile(
              leading: const Icon(Icons.business),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              onTap: () => setState(() => selectedSupplier = p),
            )).toList(),
          ),
        )
      ],
    );
  }

  Widget _buildReturnItemsList(PharoahManager ph) {
    return Column(
      children: [
        ListTile(
          tileColor: Colors.white,
          title: Text(selectedSupplier!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: TextButton(onPressed: () => setState(() => selectedSupplier = null), child: const Text("CHANGE")),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (c, i) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Batch: ${items[i].batch} | Qty: ${items[i].qty.toInt()}"),
                trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
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
          const Text("TOTAL BREAKAGE VALUE:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.brown.shade900)),
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
             const Padding(padding: EdgeInsets.all(15), child: Text("SELECT BREAKAGE ITEM TO RETURN", style: TextStyle(fontWeight: FontWeight.bold))),
             Expanded(
               child: ListView.builder(
                 itemCount: ph.medicines.length,
                 itemBuilder: (c, i) => ListTile(
                   title: Text(ph.medicines[i].name),
                   onTap: () {
                     Navigator.pop(context);
                     _showQuantityEntry(ph.medicines[i]);
                   },
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }

  void _showQuantityEntry(Medicine med) {
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
    ph.finalizePurchaseReturn(
      billNo: returnNoC.text,
      date: selectedDate,
      party: selectedSupplier!,
      items: items,
      total: totalAmt,
      type: "Breakage", // Ye maal breakage box se kam hoga
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Purchase Breakage Return Saved!"), backgroundColor: Colors.green));
  }
}
