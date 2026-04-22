import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'pdf/sale_invoice_pdf.dart';
import 'item_entry_card.dart'; // NAYI FILE YAHAN IMPORT HO RAHI HAI

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;
  final List<BillItem>? existingItems;
  final String? modifySaleId;

  const BillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
    this.existingItems,
    this.modifySaleId,
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

  // --- NAYA BOTTOM SHEET LOGIC ---
  void _showItemSearchSheet(PharoahManager ph, {BillItem? itemToEdit}) {
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

          // Padding di gayi hai taaki keyboard ke upar screen khiske
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

                  // STEP 1: Search Product
                  if (selectedMed == null) ...[
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          hintText: "Search Product to Bill...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true, fillColor: Colors.white,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onChanged: (v) => setSheetState(() => localSearch = v),
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
                  ] 
                  
                  // STEP 2: Show Advanced Item Entry Card
                  else ...[
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
                          onCancel: () {
                            if (itemToEdit != null) {
                              Navigator.pop(context); 
                            } else {
                              setSheetState(() => selectedMed = null); 
                            }
                          },
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
        title: Text("Invoice: ${widget.billNo}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: items.isEmpty ? null : () => _printBill()),
          TextButton(
            onPressed: items.isEmpty ? null : () => _handleSave(ph),
            child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: items.length,
            itemBuilder: (c, i) => _buildItemCard(items[i], i, ph),
          ),
        ),
        _buildFooter(),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal.shade700,
        onPressed: () => _showItemSearchSheet(ph),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(15),
    margin: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(widget.party.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
      Text(DateFormat('dd/MM/yyyy').format(widget.billDate), style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _buildItemCard(BillItem it, int index, PharoahManager ph) => Card(
    elevation: 2,
    margin: const EdgeInsets.symmetric(vertical: 5),
    child: ListTile(
      title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
      subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()}${it.freeQty > 0 ? ' + ${it.freeQty.toInt()}' : ''} | Rate: ₹${it.rate.toStringAsFixed(2)}"),
      trailing: Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
      onTap: () => _showItemSearchSheet(ph, itemToEdit: it), // Edit logic attached here
      onLongPress: () => setState(() => items.removeAt(index)),
    ),
  );

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.all(20),
    color: Colors.white,
    child: Column(children: [
      _row("Gross Amount", "₹${totalAmt.toStringAsFixed(2)}"),
      const Divider(),
      _row("NET TOTAL", "₹${totalAmt.toStringAsFixed(2)}", bold: true, size: 20, color: Colors.teal.shade900),
    ]),
  );

  Widget _row(String l, String v, {bool bold = false, double size = 15, Color? color}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: size, color: color))]);

  void _handleSave(PharoahManager ph) {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: totalAmt, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _printBill() async {
    final sale = Sale(id: widget.modifySaleId ?? DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, partyGstin: widget.party.gst, partyState: widget.party.state, items: items, totalAmount: totalAmt, paymentMode: widget.mode);
    await SaleInvoicePdf.generate(sale, widget.party);
  }
}
