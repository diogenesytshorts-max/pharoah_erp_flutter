// FILE: lib/challans/purchase_challan_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../purchase/purchase_billing_view.dart'; 
import '../pharoah_date_controller.dart';
import '../product_master.dart'; // NAYA: For quick add product

class PurchaseChallanView extends StatefulWidget {
  final PurchaseChallan? existingRecord; 

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

  void _initPurchaseFlow() async {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    if (widget.existingRecord != null) {
      final ex = widget.existingRecord!;
      internalNoC.text = ex.internalNo;
      supplierChallanNoC.text = ex.billNo;
      selectedDate = ex.date;
      items = List.from(ex.items);
      
      try {
        selectedDistributor = ph.parties.firstWhere((p) => p.name == ex.distributorName);
      } catch (e) {
        selectedDistributor = Party(id: "0", name: ex.distributorName);
      }
      setState(() => isLoading = false);
    } else {
      if (ph.activeCompany != null) {
        String nextNo = await PharoahNumberingEngine.getNextNumber(
          type: "CHALLAN",
          companyID: ph.activeCompany!.id,
          prefix: ph.getDefaultSeries("CHALLAN").prefix,
          startFrom: ph.getDefaultSeries("CHALLAN").startNumber,
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

  // NAYA: Serial Number auto-fixer logic
  void _recalculateSR() {
    setState(() {
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(srNo: i + 1);
      }
    });
  }

  void _showItemSearch(PharoahManager ph, {PurchaseItem? itemToEdit}) {
    String localSearch = "";
    Medicine? selectedMed;

    if (itemToEdit != null) {
      try {
        selectedMed = ph.medicines.firstWhere((m) => m.id == itemToEdit.medicineID);
      } catch (e) { selectedMed = null; }
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
              color: Colors.amber.shade50,
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
                              prefixIcon: const Icon(Icons.search, color: Colors.brown),
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
                          icon: const Icon(Icons.library_add_rounded),
                          style: IconButton.styleFrom(backgroundColor: Colors.amber.shade900, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                        )
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filteredMeds.length,
                      itemBuilder: (c, i) => ListTile(
                        leading: const Icon(Icons.inventory_2, color: Colors.brown),
                        title: Text(filteredMeds[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Pack: ${filteredMeds[i].packing} | Stock: ${filteredMeds[i].stock}"),
                        onTap: () => setSheetState(() => selectedMed = filteredMeds[i]),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: SingleChildScrollView(
                      child: PurchaseItemEntryCard(
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
                  readOnly: true, 
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
          trailing: (widget.existingRecord == null) 
              ? IconButton(onPressed: () => setState(() => selectedDistributor = null), icon: const Icon(Icons.edit, color: Colors.blue))
              : null,
        ),

        // --- NAYA: Search Bar Trigger (Replaced FAB) ---
        _buildSearchBarTrigger(ph),

        Expanded(
          child: items.isEmpty 
            ? const Center(child: Text("No items in this inward note."))
            : ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                itemCount: items.length,
                itemBuilder: (c, i) => _buildItemCard(items[i], i, ph),
              ),
        ),
      ],
    );
  }

  // NAYA: Search Bar Trigger
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
            border: Border.all(color: Colors.amber.shade400, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.amber.shade900),
              const SizedBox(width: 10),
              Text("Tap here to search inward stock...", style: TextStyle(color: Colors.brown.shade600, fontSize: 14)),
              const Spacer(),
              Icon(Icons.add_circle, color: Colors.amber.shade900),
            ],
          ),
        ),
      ),
    );
  }

  // NAYA: Swipe to Delete Card
  Widget _buildItemCard(PurchaseItem it, int index, PharoahManager ph) {
    final card = Card(
      elevation: 2, margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: Colors.amber.shade50, child: Text("${it.srNo}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900))),
        title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.brown)),
        subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} + ${it.freeQty.toInt()}"),
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

  void _handleSave(PharoahManager ph) {
    if (widget.existingRecord != null) {
      ph.deletePurchaseChallan(widget.existingRecord!.id);
    }

    ph.finalizePurchaseChallan(
      challanNo: supplierChallanNoC.text.trim(),
      internalNo: internalNoC.text,
      date: selectedDate,
      party: selectedDistributor!,
      items: items,
      total: totalAmt,
    );
    
    // Counter Update
    if (widget.existingRecord == null && ph.activeCompany != null) {
      PharoahNumberingEngine.updateSeriesCounter(
        type: "CHALLAN", 
        companyID: ph.activeCompany!.id, 
        usedNumber: internalNoC.text, 
        prefix: ph.getDefaultSeries("CHALLAN").prefix
      );
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Inward Updated & Stock Synced!"), backgroundColor: Colors.green));
  }
}
