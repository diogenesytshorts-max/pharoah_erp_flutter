// FILE: lib/challans/sale_challan_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../item_entry_card.dart';
import '../pharoah_date_controller.dart';

class SaleChallanView extends StatefulWidget {
  final SaleChallan? existingRecord; // NAYA: Edit support ke liye

  const SaleChallanView({super.key, this.existingRecord});

  @override
  State<SaleChallanView> createState() => _SaleChallanViewState();
}

class _SaleChallanViewState extends State<SaleChallanView> {
  final challanNoC = TextEditingController();
  DateTime selectedDate = DateTime.now();
  Party? selectedParty;
  List<BillItem> items = [];
  String searchQuery = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _initChallanFlow();
  }

  // --- LOGIC: NEW vs EDIT FLOW ---
  void _initChallanFlow() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    if (widget.existingRecord != null) {
      // CASE: EDIT MODE (Purana data load karo)
      final ex = widget.existingRecord!;
      challanNoC.text = ex.billNo;
      selectedDate = ex.date;
      items = List.from(ex.items);
      // Party object dhoondhna name se
      try {
        selectedParty = ph.parties.firstWhere((p) => p.name == ex.partyName);
      } catch (e) {
        selectedParty = Party(id: "0", name: ex.partyName);
      }
      setState(() => isLoading = false);
    } else {
      // CASE: NEW ENTRY MODE
      if (ph.activeCompany != null) {
        String nextNo = await PharoahNumberingEngine.getNextNumber(
          type: "SALE_CHALLAN",
          companyID: ph.activeCompany!.id,
          currentList: ph.saleChallans,
        );
        setState(() {
          challanNoC.text = nextNo;
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
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        title: Text(widget.existingRecord != null ? "Modify Sale Challan" : "New Sale Challan"),
        backgroundColor: Colors.blueGrey.shade800,
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
          _buildHeader(ph),
          Expanded(
            child: selectedParty == null 
              ? _buildPartyPicker(ph) 
              : _buildItemSection(ph),
          ),
          if (selectedParty != null) _buildBottomBar(),
        ],
      ),
      floatingActionButton: (selectedParty != null)
          ? FloatingActionButton.extended(
              onPressed: () => _showItemSearch(ph),
              backgroundColor: Colors.blueGrey.shade800,
              icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
              label: const Text("ADD ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildHeader(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: challanNoC,
              readOnly: widget.existingRecord != null, // Lock number during edit
              decoration: InputDecoration(
                labelText: "CHALLAN NO", 
                border: const OutlineInputBorder(), 
                isDense: true,
                filled: widget.existingRecord != null,
                fillColor: Colors.grey.shade100
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: InkWell(
              onTap: () async {
                DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: ph.currentFY, initialDate: selectedDate);
                if (p != null) setState(() => selectedDate = p);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(DateFormat('dd/MM/yyyy').format(selectedDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                    const Icon(Icons.calendar_month, color: Colors.blueGrey, size: 18),
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
            decoration: const InputDecoration(hintText: "Search Customer Name...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onChanged: (v) => setState(() => searchQuery = v),
          ),
        ),
        Expanded(
          child: ListView(
            children: ph.parties.where((p) => p.name.toLowerCase().contains(searchQuery.toLowerCase())).map((p) => ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(p.city),
              onTap: () => setState(() => selectedParty = p),
            )).toList(),
          ),
        )
      ],
    );
  }

  Widget _buildItemSection(PharoahManager ph) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          color: Colors.blueGrey.shade50,
          child: Row(
            children: [
              const Icon(Icons.person, color: Colors.blueGrey, size: 18),
              const SizedBox(width: 10),
              Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              if(widget.existingRecord == null) // Party change allowed only in new entries
                IconButton(onPressed: () => setState(() => selectedParty = null), icon: const Icon(Icons.edit, size: 18, color: Colors.blue)),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty 
            ? const Center(child: Text("Cart is empty."))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (c, i) => _itemRow(items[i], i),
              ),
        ),
      ],
    );
  }

  Widget _itemRow(BillItem it, int idx) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: ListTile(
        title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("Batch: ${it.batch} | Exp: ${it.exp} | Qty: ${it.qty.toInt()}"),
        trailing: Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        onLongPress: () => setState(() => items.removeAt(idx)),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("ITEMS: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text("TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade900)),
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
                     _showQuantityDialog(ph.medicines[i]);
                   },
                 ),
               ),
             )
          ],
        ),
      ),
    );
  }

  void _showQuantityDialog(Medicine med) {
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
    // 1. Agar edit mode hai, toh purana record hatao taaki stock sync rahe
    if (widget.existingRecord != null) {
      ph.deleteSaleChallan(widget.existingRecord!.id);
    }

    // 2. Save current data
    ph.finalizeSaleChallan(
      challanNo: challanNoC.text,
      date: selectedDate,
      party: selectedParty!,
      items: items,
      total: totalAmt,
    );
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Challan Saved & Stock Synced!"), backgroundColor: Colors.green));
  }
}
