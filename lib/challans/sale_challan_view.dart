// FILE: lib/challans/sale_challan_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../item_entry_card.dart';
import '../pharoah_date_controller.dart';
import '../product_master.dart'; // NAYA: For quick product addition

class SaleChallanView extends StatefulWidget {
  final SaleChallan? existingRecord; 

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

  void _initChallanFlow() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    if (widget.existingRecord != null) {
      final ex = widget.existingRecord!;
      challanNoC.text = ex.billNo;
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
        // NAYA: Get next number using Universal Engine
        String nextNo = await PharoahNumberingEngine.getNextNumber(
          type: "CHALLAN",
          companyID: ph.activeCompany!.id,
          prefix: ph.getDefaultSeries("CHALLAN").prefix,
          startFrom: ph.getDefaultSeries("CHALLAN").startNumber,
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

  // NAYA: Serial Number auto-fixer
  void _recalculateSR() {
    setState(() {
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(srNo: i + 1);
      }
    });
  }

  void _showItemSearch(PharoahManager ph, {BillItem? itemToEdit}) {
    String localSearch = "";
    Medicine? selectedMed;
    if (itemToEdit != null) {
      selectedMed = ph.medicines.firstWhere((m) => m.id == itemToEdit.medicineID);
    }

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
            decoration: BoxDecoration(
              color: Colors.blueGrey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            autofocus: true,
                            decoration: InputDecoration(
                              hintText: "Search Product...",
                              prefixIcon: const Icon(Icons.search),
                              filled: true, fillColor: Colors.white,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onChanged: (v) => setSheetState(() => localSearch = v),
                          ),
                        ),
                        const SizedBox(width: 10),
                        IconButton.filled(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (c) => const ProductMasterView(isSelectionMode: true)),
                            );
                            if (result != null && result is Medicine) {
                              setSheetState(() => selectedMed = result);
                            }
                          },
                          icon: const Icon(Icons.add_box_rounded),
                          style: IconButton.styleFrom(backgroundColor: Colors.blueGrey.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredMeds.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.inventory, color: Colors.blueGrey),
                        title: Text(filteredMeds[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Pack: ${filteredMeds[i].packing} | Stock: ${filteredMeds[i].stock}"),
                        onTap: () => setSheetState(() => selectedMed = filteredMeds[i]),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: ItemEntryCard(
                        med: selectedMed!,
                        srNo: itemToEdit != null ? itemToEdit.srNo : items.length + 1,
                        existingItem: itemToEdit,
                        onAdd: (newItem) {
                          setState(() {
                            if (itemToEdit != null) {
                              int idx = items.indexWhere((it) => it.id == itemToEdit.id);
                              items[idx] = newItem; 
                            } else {
                              items.add(newItem); 
                            }
                          });
                          Navigator.pop(context);
                        },
                        onCancel: () => itemToEdit != null ? Navigator.pop(context) : setSheetState(() => selectedMed = null),
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
              readOnly: widget.existingRecord != null, 
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
              if(widget.existingRecord == null) 
                IconButton(onPressed: () => setState(() => selectedParty = null), icon: const Icon(Icons.edit, size: 18, color: Colors.blue)),
            ],
          ),
        ),

        // --- NAYA: Search Bar Trigger (Replaced FAB) ---
        _buildSearchBarTrigger(ph),

        Expanded(
          child: items.isEmpty 
            ? const Center(child: Text("Cart is empty."))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                itemCount: items.length,
                itemBuilder: (c, i) => _itemRow(items[i], i, ph),
              ),
        ),
      ],
    );
  }

  // NAYA: Search Bar Widget
  Widget _buildSearchBarTrigger(PharoahManager ph) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: InkWell(
        onTap: () => _showItemSearch(ph),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blueGrey.shade300, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.blueGrey.shade700),
              const SizedBox(width: 10),
              Text("Tap here to search & add product...", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const Spacer(),
              Icon(Icons.add_circle, color: Colors.blueGrey.shade700),
            ],
          ),
        ),
      ),
    );
  }

  // NAYA: Swipe to Delete Card
  Widget _itemRow(BillItem it, int index, PharoahManager ph) {
    final card = Card(
      elevation: 2, margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.blueGrey.shade50, child: Text("${it.srNo}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey))),
        title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        subtitle: Text("Batch: ${it.batch} | Exp: ${it.exp} | Qty: ${it.qty.toInt()}"),
        trailing: Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
        onTap: () => _showItemSearch(ph, itemToEdit: it),
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

  void _handleSave(PharoahManager ph) {
    if (widget.existingRecord != null) {
      ph.deleteSaleChallan(widget.existingRecord!.id);
    }
    ph.finalizeSaleChallan(
      challanNo: challanNoC.text,
      date: selectedDate,
      party: selectedParty!,
      items: items,
      total: totalAmt,
    );
    
    // NAYA: Counter update logic if not editing
    if (widget.existingRecord == null && ph.activeCompany != null) {
      PharoahNumberingEngine.updateSeriesCounter(
        type: "CHALLAN", 
        companyID: ph.activeCompany!.id, 
        usedNumber: challanNoC.text, 
        prefix: ph.getDefaultSeries("CHALLAN").prefix
      );
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Challan Saved & Stock Synced!"), backgroundColor: Colors.green));
  }
}
