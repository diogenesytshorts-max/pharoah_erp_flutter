import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf_service.dart';

class BillingView extends StatefulWidget {
  final Party party; final String billNo; final DateTime billDate; final String mode;
  final List<BillItem>? existingItems;
  final String? modifySaleId;
  final bool isReadOnly;

  const BillingView({super.key, required this.party, required this.billNo, required this.billDate, required this.mode, this.existingItems, this.modifySaleId, this.isReadOnly = false});

  @override State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = []; String search = ""; Medicine? selectedMed; int? editingIndex;
  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);

  @override void initState() {
    super.initState();
    if (widget.existingItems != null) items = List.from(widget.existingItems!);
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue,
        foregroundColor: Colors.white,
        title: Text(widget.party.name, style: const TextStyle(fontSize: 14)),
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: items.isEmpty ? null : () => _saveAndPrint(ph)),
          if (!widget.isReadOnly) TextButton(onPressed: items.isEmpty ? null : () => _saveAndClose(ph), child: const Text("SAVE", style: TextStyle(color: Colors.white))),
        ],
      ),
      body: Stack(children: [
        Column(children: [
          if (selectedMed == null && !widget.isReadOnly) Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: InputDecoration(hintText: "Search Medicine...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))), onChanged: (v) => setState(() => search = v))),
          if (selectedMed != null) ItemEntryForm(med: selectedMed!, srNo: editingIndex ?? items.length + 1, existingItem: editingIndex != null ? items[editingIndex!] : null, onAdd: (ni) { setState(() { if (editingIndex != null) items[editingIndex!] = ni; else { items.add(ni); ph.addToLocalInventory(selectedMed!); } selectedMed = null; editingIndex = null; search = ""; }); }, onCancel: () => setState(() { selectedMed = null; editingIndex = null; })),
          Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (c, i) => ListTile(
            title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Qty: ${items[i].qty.toInt()} | Rate: ${items[i].rate} | Batch: ${items[i].batch}"),
            trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
            onTap: widget.isReadOnly ? null : () => setState(() { selectedMed = ph.medicines.firstWhere((m) => m.id == items[i].medicineID); editingIndex = i; }),
          ))),
          Container(padding: const EdgeInsets.all(15), color: Colors.blue[50], child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Items: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)), Text("TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green))]))
        ]),
        if (search.isNotEmpty && selectedMed == null) Positioned(top: 70, left: 10, right: 10, child: Material(elevation: 5, child: ListView(shrinkWrap: true, children: ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase())).map((m) => ListTile(title: Text(m.name), onTap: () => setState(() { selectedMed = m; search = ""; }))).toList())))
      ]),
    );
  }

  void _saveAndClose(PharoahManager ph) async {
    if (widget.modifySaleId != null) ph.deleteSaleAndReverseStock(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    if (widget.modifySaleId == null) await SaleBillNumber.increment();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _saveAndPrint(PharoahManager ph) async {
    final sale = Sale(id: DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, items: items, totalAmount: grandTotal, paymentMode: widget.mode);
    if (!widget.isReadOnly) {
      if (widget.modifySaleId != null) ph.deleteSaleAndReverseStock(widget.modifySaleId!);
      ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
      if (widget.modifySaleId == null) await SaleBillNumber.increment();
    }
    await PdfService.generateInvoice(sale, widget.party);
    if (!widget.isReadOnly) Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// ... (Baki ItemEntryForm ka code same rahega pichle message wala)
