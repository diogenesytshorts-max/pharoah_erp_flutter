import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pharoah_manager.dart';
import '../models.dart';

class ExpiryDateFormatter extends TextInputFormatter {
  @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) return newValue;
    if (text.length == 2 && !text.contains('/')) return TextEditingValue(text: '$text/', selection: TextSelection.collapsed(offset: 3));
    return newValue;
  }
}

class PurchaseBillingView extends StatefulWidget {
  final Party distributor; final String internalNo, distBillNo; final DateTime billDate; final String mode;
  final List<PurchaseItem>? existingItems; final String? modifyPurchaseId;

  const PurchaseBillingView({super.key, required this.distributor, required this.internalNo, required this.distBillNo, required this.billDate, required this.mode, this.existingItems, this.modifyPurchaseId});
  @override State<PurchaseBillingView> createState() => _PurchaseBillingViewState();
}

class _PurchaseBillingViewState extends State<PurchaseBillingView> {
  List<PurchaseItem> items = []; String searchQuery = ""; Medicine? selectedMed;
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override void initState() { super.initState(); if (widget.existingItems != null) items = List.from(widget.existingItems!); }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.distributor.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), Text("${widget.internalNo} | Bill: ${widget.distBillNo}", style: const TextStyle(fontSize: 10))]), actions: [TextButton(onPressed: items.isEmpty ? null : () => _handleSave(ph), child: const Text("SAVE & UPDATE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
      body: Stack(children: [
        Column(children: [
          if (selectedMed == null) Container(padding: const EdgeInsets.all(12), color: Colors.orange.shade50, child: TextField(autofocus: true, decoration: InputDecoration(hintText: "Search Product for Stock-In...", prefixIcon: const Icon(Icons.search, color: Colors.orange), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), onChanged: (v) => setState(() => searchQuery = v))),
          if (selectedMed != null) PurchaseItemEntryForm(med: selectedMed!, srNo: items.length + 1, batchHistory: ph.batchHistory[selectedMed!.id] ?? [], onAdd: (newItem) {
            ph.saveBatchCentrally(selectedMed!.id, BatchInfo(batch: newItem.batch, exp: newItem.exp, packing: newItem.packing, mrp: newItem.mrp, rate: newItem.purchaseRate));
            setState(() { items.add(newItem); selectedMed = null; searchQuery = ""; });
          }, onCancel: () => setState(() => selectedMed = null)),
          Expanded(child: ListView.separated(itemCount: items.length, separatorBuilder: (c, i) => const Divider(), itemBuilder: (c, i) => ListTile(title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Qty: ${items[i].qty.toInt()} + ${items[i].freeQty.toInt()} | Batch: ${items[i].batch}"), trailing: Text("₹${items[i].total.toStringAsFixed(2)}"), onTap: () => setState(() { selectedMed = ph.medicines.firstWhere((m) => m.id == items[i].medicineID); items.removeAt(i); })))),
          Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.orange.shade50, border: const Border(top: BorderSide(color: Colors.orange, width: 1))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Total Items: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)), Text("TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.deepOrange))]))
        ]),
        if (searchQuery.isNotEmpty && selectedMed == null) Positioned(top: 70, left: 15, right: 15, child: Material(elevation: 10, borderRadius: BorderRadius.circular(10), child: Container(constraints: const BoxConstraints(maxHeight: 250), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)), child: ListView(shrinkWrap: true, children: ph.medicines.where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase())).map((m) => ListTile(leading: const Icon(Icons.medication, color: Colors.orange), title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Pack: ${m.packing} | Stock: ${m.stock}"), onTap: () => setState(() { selectedMed = m; searchQuery = ""; }))).toList()))))
      ]),
    );
  }

  void _handleSave(PharoahManager ph) async { 
    if (widget.modifyPurchaseId != null) ph.deletePurchase(widget.modifyPurchaseId!);
    ph.finalizePurchase(internalNo: widget.internalNo, billNo: widget.distBillNo, date: widget.billDate, party: widget.distributor, items: items, total: totalAmt, mode: widget.mode); 
    if (widget.modifyPurchaseId == null) {
      final prefs = await SharedPreferences.getInstance();
      int lastId = prefs.getInt('lastPurID') ?? 0;
      await prefs.setInt('lastPurID', lastId + 1);
    }
    if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Purchase Saved/Updated!"), backgroundColor: Colors.orange)); Navigator.of(context).popUntil((route) => route.isFirst); } 
  }
}

class PurchaseItemEntryForm extends StatefulWidget {
  final Medicine med; final int srNo; final List<BatchInfo> batchHistory; final Function(PurchaseItem) onAdd; final VoidCallback onCancel;
  const PurchaseItemEntryForm({super.key, required this.med, required this.srNo, required this.batchHistory, required this.onAdd, required this.onCancel});
  @override State<PurchaseItemEntryForm> createState() => _PurchaseItemEntryFormState();
}

class _PurchaseItemEntryFormState extends State<PurchaseItemEntryForm> {
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController(); final mC = TextEditingController(); final pRC = TextEditingController(); final qC = TextEditingController(text: "1"); final fC = TextEditingController(text: "0"); final rAC = TextEditingController(); final rBC = TextEditingController(); final rCC = TextEditingController(); final rCD = TextEditingController(text: "0");
  @override void initState() { super.initState(); mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString(); pRC.text = widget.med.purRate.toString(); rAC.text = widget.med.rateA.toString(); rBC.text = widget.med.rateB.toString(); _calcRateC(); }
  void _calcRateC() { double mrp = double.tryParse(mC.text) ?? 0; double gst = double.tryParse(gC.text) ?? 0; double disc = double.tryParse(rCD.text) ?? 0; double taxable = mrp / (1 + (gst / 100)); rCC.text = (taxable - (taxable * disc / 100)).toStringAsFixed(2); }
  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(15), color: Colors.orange.shade50, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))), IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: widget.onCancel)]),
      if (widget.batchHistory.isNotEmpty) ...[
        SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: widget.batchHistory.map((b) => Padding(padding: const EdgeInsets.only(right: 5), child: ActionChip(label: Text(b.batch), onPressed: () { setState(() { bC.text = b.batch; eC.text = b.exp; mC.text = b.mrp.toString(); pRC.text = b.rate.toString(); }); }))).toList())),
      ],
      Row(children: [Expanded(child: _field(bC, "Batch")), const SizedBox(width: 5), Expanded(child: _field(eC, "Exp (MM/YY)", fmt: [ExpiryDateFormatter()])), const SizedBox(width: 5), Expanded(child: _field(gC, "GST%", onCh: (v) => _calcRateC()))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _field(mC, "MRP", onCh: (v) => _calcRateC())), const SizedBox(width: 5), Expanded(child: _field(pRC, "Pur Rate")), const SizedBox(width: 5), Expanded(child: _field(qC, "Qty")), const SizedBox(width: 5), Expanded(child: _field(fC, "Free"))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _field(rAC, "Rate A")), const SizedBox(width: 5), Expanded(child: _field(rBC, "Rate B")), const SizedBox(width: 5), Expanded(child: _field(rCD, "RC Disc%", onCh: (v) => _calcRateC())), const SizedBox(width: 5), Expanded(child: _field(rCC, "Rate C", en: false))]),
      const SizedBox(height: 15),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.orange.shade800), onPressed: () {
        double pr = double.tryParse(pRC.text) ?? 0, qt = double.tryParse(qC.text) ?? 0, gst = double.tryParse(gC.text) ?? 0;
        widget.onAdd(PurchaseItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text.toUpperCase(), exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, qty: qt, freeQty: double.tryParse(fC.text) ?? 0, purchaseRate: pr, gstRate: gst, total: (pr * qt) * (1 + gst/100), rateA: double.tryParse(rAC.text) ?? 0, rateB: double.tryParse(rBC.text) ?? 0, rateC: double.tryParse(rCC.text) ?? 0));
      }, child: const Text("ADD TO LIST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
    ]));
  }
  Widget _field(TextEditingController c, String l, {List<TextInputFormatter>? fmt, bool en = true, Function(String)? onCh}) { return TextField(controller: c, enabled: en, inputFormatters: fmt, onChanged: onCh, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)), keyboardType: TextInputType.text); }
}
