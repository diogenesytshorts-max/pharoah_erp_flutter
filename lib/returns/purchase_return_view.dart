// FILE: lib/returns/purchase_return_view.dart (Replacement Code - FIXED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../pharoah_date_controller.dart';
import '../product_master.dart';
import '../purchase/purchase_billing_view.dart';

class PurchaseReturnView extends StatefulWidget {
  const PurchaseReturnView({super.key});

  @override
  State<PurchaseReturnView> createState() => _PurchaseReturnViewState();
}

class _PurchaseReturnViewState extends State<PurchaseReturnView> {
  final returnNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Party? selectedSupplier;
  List<PurchaseItem> items = [];
  String returnNature = "Sellable"; 
  String searchQuery = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initReturnFlow();
  }

  // ===========================================================================
  // INITIALIZATION (Smart Numbering & Context)
  // ===========================================================================
  void _initReturnFlow() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    if (ph.activeCompany != null) {
      // Fetching next sequential number for Returns (Debit Note)
      var series = ph.getDefaultSeries("RETURN");
      String nextNo = await PharoahNumberingEngine.getNextNumber(
        type: "RETURN",
        companyID: ph.activeCompany!.id,
        prefix: series.prefix,
        startFrom: series.startNumber,
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

  void _recalculateSR() {
    setState(() {
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(srNo: i + 1);
      }
    });
  }

  // ===========================================================================
  // ITEM SEARCH & ENTRY
  // ===========================================================================
  void _showItemSearch(PharoahManager ph) {
    String localSearch = "";
    Medicine? selectedMed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredMeds = ph.medicines
              .where((m) => m.name.toLowerCase().contains(localSearch.toLowerCase()))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: const BoxDecoration(
              color: Color(0xFFEFEBE9),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  height: 5, width: 50,
                  decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(10)),
                ),
                if (selectedMed == null) ...[
                  Padding(
                    padding: const EdgeInsets.all(15),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "Search Product for Debit Note...",
                        prefixIcon: Icon(Icons.search),
                        filled: true, fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                      onChanged: (v) => setSheetState(() => localSearch = v),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredMeds.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.assignment_return, color: Colors.brown),
                        title: Text(filteredMeds[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Pack: ${filteredMeds[i].packing}"),
                        onTap: () => setSheetState(() => selectedMed = filteredMeds[i]),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: PurchaseItemEntryCard(
                        med: selectedMed!,
                        srNo: items.length + 1,
                        onAdd: (newItem) {
                          setState(() { items.add(newItem); });
                          Navigator.pop(context);
                        },
                        onCancel: () => setSheetState(() => selectedMed = null),
                      ),
                    ),
                  ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    Color themeColor = returnNature == "Sellable" ? Colors.blue.shade900 : Colors.brown.shade800;

    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text("Purchase Return (Debit Note)"),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        actions: [
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _handleSave(ph),
              child: const Text("FINALIZE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          _buildHeader(ph, themeColor),
          Expanded(
            child: selectedSupplier == null 
              ? _buildSupplierPicker(ph) 
              : _buildReturnList(ph, themeColor),
          ),
          if (selectedSupplier != null) _buildSummaryFooter(themeColor),
        ],
      ),
    );
  }

  Widget _buildHeader(PharoahManager ph, Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: TextField(controller: returnNoC, readOnly: true, decoration: const InputDecoration(labelText: "DEBIT NOTE NO", border: OutlineInputBorder(), isDense: true, filled: true, fillColor: Color(0xFFF5F5F5)))),
              const SizedBox(width: 15),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: ph.currentFY, initialDate: selectedDate);
                    if (p != null) setState(() => selectedDate = p);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)),
                    child: Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Sellable', label: Text('Sellable'), icon: Icon(Icons.check_circle_outline)),
              ButtonSegment(value: 'Breakage', label: Text('Breakage'), icon: Icon(Icons.delete_outline)),
            ],
            selected: {returnNature},
            onSelectionChanged: (v) => setState(() => returnNature = v.first),
          ),
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
            decoration: const InputDecoration(hintText: "Search Distributor for Return...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
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

  Widget _buildReturnList(PharoahManager ph, Color themeColor) {
    return Column(
      children: [
        ListTile(
          tileColor: themeColor.withOpacity(0.05),
          title: Text(selectedSupplier!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          trailing: TextButton(onPressed: () => setState(() => selectedSupplier = null), child: const Text("CHANGE")),
        ),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: InkWell(
            onTap: () => _showItemSearch(ph),
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: themeColor.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: themeColor),
                  const SizedBox(width: 10),
                  Text("Tap here to search return stock...", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                  const Spacer(),
                  Icon(Icons.add_circle, color: themeColor),
                ],
              ),
            ),
          ),
        ),

        Expanded(
          child: items.isEmpty 
            ? const Center(child: Text("No items selected."))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                itemCount: items.length,
                itemBuilder: (c, i) => _buildItemTile(i, themeColor),
              ),
        ),
      ],
    );
  }

  Widget _buildItemTile(int index, Color themeColor) {
    final it = items[index];
    final card = Card(
      elevation: 2, margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: themeColor.withOpacity(0.1), child: Text("${it.srNo}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: themeColor))),
        title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()}"),
        trailing: Text("₹${it.total.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
        onTap: () => _showItemSearch(Provider.of<PharoahManager>(context, listen: false)),
      ),
    );

    return Dismissible(
      key: Key(it.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      onDismissed: (direction) {
        setState(() { items.removeAt(index); });
        _recalculateSR(); 
      },
      child: card,
    );
  }

  Widget _buildSummaryFooter(Color themeColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("TOTAL RETURN VALUE:", style: TextStyle(fontWeight: FontWeight.bold)),
          Text("₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: themeColor)),
        ],
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
      type: returnNature,
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Debit Note Saved Successfully!"), backgroundColor: Colors.green));
  }
}
