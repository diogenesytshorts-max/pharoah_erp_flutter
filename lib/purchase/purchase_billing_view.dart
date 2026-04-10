import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf_service.dart';

// Reuse formatter
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) return newValue;
    if (text.length == 2 && !text.contains('/')) {
      return TextEditingValue(
        text: '$text/',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
    return newValue;
  }
}

class PurchaseBillingView extends StatefulWidget {
  final Party distributor; 
  final String internalNo, distBillNo; 
  final DateTime billDate; 
  final String mode;

  const PurchaseBillingView({super.key, required this.distributor, required this.internalNo, required this.distBillNo, required this.billDate, required this.mode});

  @override State<PurchaseBillingView> createState() => _PurchaseBillingViewState();
}

class _PurchaseBillingViewState extends State<PurchaseBillingView> {
  List<PurchaseItem> items = []; 
  String searchQuery = ""; 
  Medicine? selectedMed;

  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white,
        title: Text(widget.distributor.name, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: items.isEmpty ? null : () => _handleSave(ph), child: const Text("SAVE", style: TextStyle(color: Colors.white)))
        ],
      ),
      body: Column(
        children: [
          if (selectedMed == null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                decoration: const InputDecoration(hintText: "Search Product...", prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => searchQuery = v),
              ),
            ),
          if (selectedMed != null)
            PurchaseItemEntryForm(
              med: selectedMed!, 
              srNo: items.length + 1,
              onAdd: (newItem) { setState(() { items.add(newItem); selectedMed = null; searchQuery = ""; }); },
              onCancel: () => setState(() => selectedMed = null),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(items[i].name),
                subtitle: Text("Qty: ${items[i].qty} | Batch: ${items[i].batch} | Exp: ${items[i].exp}"),
                trailing: Text("₹${items[i].total.toStringAsFixed(2)}"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSave(PharoahManager ph) async {
    ph.finalizePurchase(internalNo: widget.internalNo, billNo: widget.distBillNo, date: widget.billDate, party: widget.distributor, items: items, total: totalAmt, mode: widget.mode);
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastPurID') ?? 0;
    await prefs.setInt('lastPurID', lastId + 1);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Saved!")));
    }
  }
}

class PurchaseItemEntryForm extends StatefulWidget {
  final Medicine med; final int srNo; final Function(PurchaseItem) onAdd; final VoidCallback onCancel;
  const PurchaseItemEntryForm({super.key, required this.med, required this.srNo, required this.onAdd, required this.onCancel});
  @override State<PurchaseItemEntryForm> createState() => _PurchaseItemEntryFormState();
}

class _PurchaseItemEntryFormState extends State<PurchaseItemEntryForm> {
  final bC = TextEditingController(); 
  final eC = TextEditingController(); 
  final gC = TextEditingController();
  final mC = TextEditingController(); 
  final pRC = TextEditingController(); 
  final qC = TextEditingController(text: "1");

  @override void initState() {
    super.initState();
    mC.text = widget.med.mrp.toString();
    gC.text = widget.med.gst.toString();
    pRC.text = widget.med.purRate.toString();
  }

  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.orange.shade50,
      child: Column(
        children: [
          Row(children: [
            Expanded(child: Text(widget.med.name, style: const TextStyle(fontWeight: FontWeight.bold))),
            IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)
          ]),
          Row(children: [
            Expanded(child: TextField(controller: bC, decoration: const InputDecoration(labelText: "Batch"))),
            const SizedBox(width: 5),
            Expanded(child: TextField(controller: eC, inputFormatters: [ExpiryDateFormatter()], decoration: const InputDecoration(labelText: "Exp (MM/YY)"))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextField(controller: pRC, decoration: const InputDecoration(labelText: "Pur. Rate"))),
            const SizedBox(width: 5),
            Expanded(child: TextField(controller: qC, decoration: const InputDecoration(labelText: "Qty"))),
          ]),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () {
              double pr = double.tryParse(pRC.text) ?? 0; double qt = double.tryParse(qC.text) ?? 0;
              double gst = double.tryParse(gC.text) ?? 0;
              widget.onAdd(PurchaseItem(
                id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, 
                name: widget.med.name, packing: widget.med.packing, batch: bC.text.toUpperCase(), 
                exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, 
                qty: qt, purchaseRate: pr, gstRate: gst, total: (pr * qt) * (1 + gst / 100),
                rateA: widget.med.rateA, rateB: widget.med.rateB, rateC: widget.med.rateC
              ));
            }, 
            child: const Text("ADD ITEM")
          )
        ],
      ),
    );
  }
}
