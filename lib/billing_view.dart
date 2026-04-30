// FILE: lib/billing_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'pdf/sale_invoice_pdf.dart';
import 'pdf/thermal_invoice_pdf.dart'; 
import 'item_entry_card.dart';
import 'product_master.dart'; 

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;
  final List<BillItem>? existingItems;
  final String? modifySaleId;
  final bool isReadOnly; 

  const BillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
    this.existingItems,
    this.modifySaleId,
    this.isReadOnly = false,
  });

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = [];
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) items = List.from(widget.existingItems!);
  }

  void _recalculateSR() {
    setState(() {
      for (int i = 0; i < items.length; i++) {
        items[i] = items[i].copyWith(srNo: i + 1);
      }
    });
  }

  void _showItemSearchSheet(PharoahManager ph, {BillItem? itemToEdit}) {
    if (widget.isReadOnly) return; 

    String localSearch = "";
    Medicine? selectedMed;
    if (itemToEdit != null) {
      selectedMed = ph.medicines.firstWhere((m) => m.id == itemToEdit.medicineID);
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, 
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredMeds = ph.medicines
              .where((m) => m.name.toLowerCase().contains(localSearch.toLowerCase()))
              .toList();

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F8E9),
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
                                setSheetState(() {
                                  selectedMed = result;
                                });
                              }
                            },
                            icon: const Icon(Icons.add_box_rounded),
                            style: IconButton.styleFrom(backgroundColor: Colors.teal.shade800, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          )
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredMeds.length,
                        itemBuilder: (c, i) => ListTile(
                          leading: const Icon(Icons.medication, color: Colors.teal),
                          title: Text(filteredMeds[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Stock: ${filteredMeds[i].stock} | MRP: ₹${filteredMeds[i].mrp}"),
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
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text(widget.isReadOnly ? "View Bill Items" : "Invoice: ${widget.billNo}"),
        backgroundColor: widget.isReadOnly ? Colors.purple.shade700 : Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded), 
            onPressed: items.isEmpty ? null : () => _printBill(ph)
          ),
          if (!widget.isReadOnly) 
            TextButton(
              onPressed: items.isEmpty ? null : () => _handleSave(ph),
              child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Column(children: [
        _buildHeader(),
        
        // --- NAYA: Search Bar Trigger (Replaced FAB) ---
        _buildSearchBarTrigger(ph),

        Expanded(
          child: items.isEmpty 
          ? const Center(child: Text("Bill is empty"))
          : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            itemCount: items.length,
            itemBuilder: (c, i) => _buildItemCard(items[i], i, ph),
          ),
        ),
        _buildFooter(),
      ]),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(15), margin: const EdgeInsets.fromLTRB(10, 10, 10, 5),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(widget.party.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
      Text(DateFormat('dd/MM/yyyy').format(widget.billDate), style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  // NAYA: Search Bar Widget
  Widget _buildSearchBarTrigger(PharoahManager ph) {
    if (widget.isReadOnly) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: InkWell(
        onTap: () => _showItemSearchSheet(ph),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.teal.shade300, width: 1.5),
          ),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.teal.shade700),
              const SizedBox(width: 10),
              Text("Tap here to search & add product...", style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
              const Spacer(),
              Icon(Icons.add_circle, color: Colors.teal.shade700),
            ],
          ),
        ),
      ),
    );
  }

  // NAYA: Swipe to Delete Card
  Widget _buildItemCard(BillItem it, int index, PharoahManager ph) => Card(
    elevation: 2, margin: const EdgeInsets.symmetric(vertical: 5),
    child: ListTile(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
          // NAYA: Agar source challan info hai toh dikhao
          if (it.sourceChallanNo.isNotEmpty)
            Text("Source: ${it.sourceChallanNo}", style: const TextStyle(fontSize: 9, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
        ],
      ),
      subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Rate: ₹${it.rate.toStringAsFixed(2)}"),
      trailing: Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: widget.isReadOnly ? null : () => _showItemSearchSheet(ph, itemToEdit: it),
      onLongPress: widget.isReadOnly ? null : () => setState(() => items.removeAt(index)),
    ),
  );

    // Agar View Only mode hai toh Swipe band rahega
    if (widget.isReadOnly) return card;

    // NAYA: Swipe Widget
    return Dismissible(
      key: Key(it.id),
      direction: DismissDirection.endToStart, // Sirf right se left swipe allowed
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

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.all(20), color: Colors.white,
    child: Column(children: [
      _row("Gross Amount", "₹${totalAmt.toStringAsFixed(2)}"),
      const Divider(),
      _row("NET TOTAL", "₹${totalAmt.toStringAsFixed(2)}", bold: true, size: 20, color: widget.isReadOnly ? Colors.purple.shade900 : Colors.teal.shade900),
    ]),
  );

  Widget _row(String l, String v, {bool bold = false, double size = 15, Color? color}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: size, color: color))]);

  void _handleSave(PharoahManager ph) {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(
      billNo: widget.billNo, 
      date: widget.billDate, 
      party: widget.party, 
      items: items, 
      total: totalAmt, 
      mode: widget.mode,
      isEdit: widget.modifySaleId != null
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _printBill(PharoahManager ph) async {
    if (ph.activeCompany == null) return;
    
    final sale = Sale(
      id: widget.modifySaleId ?? DateTime.now().toString(), 
      billNo: widget.billNo, 
      date: widget.billDate, 
      partyName: widget.party.name, 
      partyGstin: widget.party.gst, 
      partyState: widget.party.state, 
      items: items, 
      totalAmount: totalAmt, 
      paymentMode: widget.mode
    );

    if (ph.config.printFormat == "Thermal") {
      await ThermalInvoicePdf.generate(sale, widget.party, ph.activeCompany!, ph.config);
    } else {
      await SaleInvoicePdf.generate(sale, widget.party, ph.activeCompany!);
    }
  }
}
