// FILE: lib/returns/sale_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../item_entry_card.dart';
import '../pharoah_date_controller.dart';

class SaleReturnView extends StatefulWidget {
  const SaleReturnView({super.key});

  @override
  State<SaleReturnView> createState() => _SaleReturnViewState();
}

class _SaleReturnViewState extends State<SaleReturnView> {
  final returnNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Party? selectedParty;
  List<BillItem> items = [];
  String searchQuery = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initReturn();
  }

  void _initReturn() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    if (ph.activeCompany != null) {
      // SRN- (Sale Return Note) series generator
      String nextNo = await PharoahNumberingEngine.getNextNumber(
        type: "SALE_RETURN",
        companyID: ph.activeCompany!.id,
        currentList: ph.saleReturns,
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
      backgroundColor: const Color(0xFFFFF3E0), // Light Orange Background
      appBar: AppBar(
        title: const Text("Sale Return (Credit Note)"),
        backgroundColor: Colors.deepOrange.shade900,
        foregroundColor: Colors.white,
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _handleSave(ph),
              child: const Text("SAVE RETURN", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          // --- HEADER: Return No & Date ---
          _buildHeader(),

          // --- UI FLOW: Party Picker -> Items ---
          Expanded(
            child: selectedParty == null 
              ? _buildPartyPicker(ph) 
              : _buildReturnItemsList(ph),
          ),

          if (selectedParty != null) _buildSummaryFooter(),
        ],
      ),
      floatingActionButton: (selectedParty != null)
          ? FloatingActionButton.extended(
              onPressed: () => _showItemSearch(ph),
              backgroundColor: Colors.deepOrange.shade900,
              icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              label: const Text("ADD RETURN ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          Expanded(child: TextField(controller: returnNoC, decoration: const InputDecoration(labelText: "RETURN NO", border: OutlineInputBorder(), isDense: true))),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.calendar_today, color: Colors.deepOrange, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartyPicker(PharoahManager ph) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 20, bottom: 10),
          child: Text("SELECT CUSTOMER FOR RETURN", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 12)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: TextField(
            decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder()),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: ph.parties.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase())).map((p) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(p.city),
              onTap: () => setState(() => selectedParty = p),
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
          tileColor: Colors.deepOrange.withOpacity(0.1),
          leading: const Icon(Icons.account_circle, color: Colors.deepOrange),
          title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: TextButton(onPressed: () => setState(() => selectedParty = null), child: const Text("CHANGE")),
        ),
        Expanded(
          child: items.isEmpty 
            ? const Center(child: Text("No items selected for return."))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (c, i) => Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Batch: ${items[i].batch} | Qty: ${items[i].qty.toInt()}"),
                    trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
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
          const Text("CREDIT TOTAL:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.deepOrange.shade900)),
        ],
      ),
    );
  }

  void _showItemSearch(PharoahManager ph) {
    // Standard Search Modal (Already used in Billing)
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
             const Padding(padding: EdgeInsets.all(15), child: Text("SELECT ITEM TO RETURN", style: TextStyle(fontWeight: FontWeight.bold))),
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
      builder: (c) => ItemEntryCard(
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
    ph.finalizeSaleReturn(
      billNo: returnNoC.text,
      date: selectedDate,
      party: selectedParty!,
      items: items,
      total: totalAmt,
      type: "Sellable", // Confirmed: Currently only working on sellable
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Sale Return Saved & Stock Updated!"), backgroundColor: Colors.green));
  }
}
