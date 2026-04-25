// FILE: lib/returns/expiry_breakage_return_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../item_entry_card.dart';
import '../pharoah_date_controller.dart';

class ExpiryBreakageReturnView extends StatefulWidget {
  const ExpiryBreakageReturnView({super.key});

  @override
  State<ExpiryBreakageReturnView> createState() => _ExpiryBreakageReturnViewState();
}

class _ExpiryBreakageReturnViewState extends State<ExpiryBreakageReturnView> {
  final returnNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Party? selectedParty;
  List<BillItem> items = [];
  String searchQuery = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initBreakage();
  }

  void _initBreakage() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    if (ph.activeCompany != null) {
      String nextNo = await PharoahNumberingEngine.getNextNumber(
        type: "BREAKAGE_RETURN",
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
      backgroundColor: const Color(0xFFFFEBEE), // Very Light Red
      appBar: AppBar(
        title: const Text("Expiry / Breakage Return"),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _handleSave(ph),
              child: const Text("SAVE AS BREAKAGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          _buildWarningBanner(), // Special Banner for Breakage
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
              backgroundColor: Colors.red.shade900,
              icon: const Icon(Icons.delete_sweep, color: Colors.white),
              label: const Text("ADD EXPIRED ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
      color: Colors.red.shade100,
      child: Row(
        children: [
          Icon(Icons.report_problem, size: 16, color: Colors.red.shade900),
          const SizedBox(width: 10),
          const Text("Items added here will NOT be added to Sellable Stock.", 
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.red)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: TextField(controller: returnNoC, decoration: const InputDecoration(labelText: "BREAKAGE NO", border: OutlineInputBorder(), isDense: true))),
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
                    const Icon(Icons.calendar_today, color: Colors.red, size: 18),
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
        Padding(
          padding: const EdgeInsets.all(15),
          child: TextField(
            decoration: const InputDecoration(hintText: "Customer Name...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: ph.parties.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase())).map((p) => ListTile(
              leading: const Icon(Icons.person),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          tileColor: Colors.red.withOpacity(0.05),
          title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: IconButton(onPressed: () => setState(() => selectedParty = null), icon: const Icon(Icons.close)),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: items.length,
            itemBuilder: (c, i) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Batch: ${items[i].batch} | Reason: Expiry/Breakage"),
                trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
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
          const Text("NON-SELLABLE TOTAL:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.red.shade900)),
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
             const Padding(padding: EdgeInsets.all(15), child: Text("SELECT ITEM FOR BREAKAGE", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red))),
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
      type: "Breakage", // Sahi logic: Breakage stock mein jayega
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text("⚠️ Saved to Breakage/Expiry Stock!"), 
      backgroundColor: Colors.red.shade900
    ));
  }
}
