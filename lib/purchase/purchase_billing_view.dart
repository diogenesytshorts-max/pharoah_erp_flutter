import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';

class PurchaseBillingView extends StatefulWidget {
  final Party distributor; final String billNo; final DateTime billDate; final String mode;
  const PurchaseBillingView({super.key, required this.distributor, required this.billNo, required this.billDate, required this.mode});

  @override State<PurchaseBillingView> createState() => _PurchaseBillingViewState();
}

class _PurchaseBillingViewState extends State<PurchaseBillingView> {
  List<PurchaseItem> items = [];
  String search = "";
  Medicine? selectedMed;

  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange, foregroundColor: Colors.white,
        title: Text(widget.distributor.name, style: const TextStyle(fontSize: 14)),
        actions: [TextButton(onPressed: items.isEmpty ? null : () => _save(ph), child: const Text("SAVE PURCHASE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]
      ),
      body: Column(children: [
        if (selectedMed == null)
          Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: const InputDecoration(hintText: "Search Medicine for Purchase...", border: OutlineInputBorder()), onChanged: (v) => setState(() => search = v))),
        
        if (selectedMed != null)
          PurchaseItemEntryForm(
            med: selectedMed!, srNo: items.length + 1,
            onAdd: (newItem) { setState(() { items.add(newItem); selectedMed = null; search = ""; }); },
            onCancel: () => setState(() => selectedMed = null),
          ),

        Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (c, i) => ListTile(
          title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Qty: ${items[i].qty} + ${items[i].freeQty} Free | Rate: ${items[i].purchaseRate}"),
          trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
        ))),

        Container(
          padding: const EdgeInsets.all(15), color: Colors.orange[50],
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("Items: ${items.length}"),
            Text("TOTAL PURCHASE: ₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          ]),
        )
      ]),
    );
  }

  void _save(PharoahManager ph) {
    ph.finalizePurchase(billNo: widget.billNo, date: widget.billDate, party: widget.distributor, items: items, total: totalAmt, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Bill Saved & Stock Updated!")));
  }
}

// --- SUB-WIDGET: PURCHASE ITEM FORM ---
class PurchaseItemEntryForm extends StatefulWidget {
  final Medicine med; final int srNo; final Function(PurchaseItem) onAdd; final VoidCallback onCancel;
  const PurchaseItemEntryForm({super.key, required this.med, required this.srNo, required this.onAdd, required this.onCancel});

  @override State<PurchaseItemEntryForm> createState() => _PurchaseItemEntryFormState();
}

class _PurchaseItemEntryFormState extends State<PurchaseItemEntryForm> {
  final bC = TextEditingController(); final eC = TextEditingController();
  final mC = TextEditingController(); final rC = TextEditingController();
  final qC = TextEditingController(text: "1"); final fC = TextEditingController(text: "0");
  final gC = TextEditingController();

  @override void initState() { super.initState(); mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString(); }

  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.white,
      child: Column(children: [
        Row(children: [Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
        Row(children: [
          Expanded(child: TextField(controller: bC, decoration: const InputDecoration(labelText: "Batch"))), const SizedBox(width: 5),
          Expanded(child: TextField(controller: eC, decoration: const InputDecoration(labelText: "Exp"))), const SizedBox(width: 5),
          Expanded(child: TextField(controller: gC, decoration: const InputDecoration(labelText: "GST %"))),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: mC, decoration: const InputDecoration(labelText: "MRP"), keyboardType: TextInputType.number)), const SizedBox(width: 5),
          Expanded(child: TextField(controller: rC, decoration: const InputDecoration(labelText: "Purchase Rate"), keyboardType: TextInputType.number)),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: qC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number)), const SizedBox(width: 5),
          Expanded(child: TextField(controller: fC, decoration: const InputDecoration(labelText: "Free Qty"), keyboardType: TextInputType.number)),
        ]),
        const SizedBox(height: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.orange),
          onPressed: () {
            double rate = double.tryParse(rC.text) ?? 0;
            double qty = double.tryParse(qC.text) ?? 0;
            double gst = double.tryParse(gC.text) ?? 0;
            double taxable = rate * qty;
            double total = taxable + (taxable * gst / 100);

            widget.onAdd(PurchaseItem(
              id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name,
              packing: widget.med.packing, batch: bC.text.toUpperCase(), exp: eC.text,
              mrp: double.tryParse(mC.text) ?? 0, qty: qty, freeQty: double.tryParse(fC.text) ?? 0,
              purchaseRate: rate, gstRate: gst, total: total
            ));
          },
          child: const Text("ADD TO PURCHASE", style: TextStyle(color: Colors.white)),
        )
      ]),
    );
  }
}
