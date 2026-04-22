import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf/sale_invoice_pdf.dart'; 
import 'package:intl/intl.dart';

class ExpiryDateFormatter extends TextInputFormatter {
  @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) return newValue;
    if (text.length == 2 && !text.contains('/')) return TextEditingValue(text: '$text/', selection: TextSelection.collapsed(offset: 3));
    return newValue;
  }
}

class BillingView extends StatefulWidget {
  final Party party; final String billNo; final DateTime billDate; final String mode;
  final List<BillItem>? existingItems; final String? modifySaleId; final bool isReadOnly;

  const BillingView({super.key, required this.party, required this.billNo, required this.billDate, required this.mode, this.existingItems, this.modifySaleId, this.isReadOnly = false});

  @override State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = []; String search = ""; Medicine? selectedMed; int? editingIndex;
  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);

  @override void initState() { super.initState(); if (widget.existingItems != null) items = List.from(widget.existingItems!); }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.party.name), backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, actions: [if(!widget.isReadOnly) TextButton(onPressed: items.isEmpty ? null : () => _saveAndClose(ph), child: const Text("SAVE", style: TextStyle(color: Colors.white)))]),
      body: Column(children: [
        if (selectedMed == null && !widget.isReadOnly) Container(padding: const EdgeInsets.all(12), color: Colors.blue.shade50, child: TextField(autofocus: true, decoration: const InputDecoration(hintText: "Search Medicine...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => search = v))),
        if (selectedMed != null) ItemEntryForm(med: selectedMed!, party: widget.party, srNo: editingIndex != null ? (editingIndex! + 1) : items.length + 1, existingItem: editingIndex != null ? items[editingIndex!] : null, batchHistory: ph.batchHistory[selectedMed!.id] ?? [], onAdd: (newItem) {
          ph.saveBatchCentrally(newItem.medicineID, BatchInfo(batch: newItem.batch, exp: newItem.exp, packing: newItem.packing, mrp: newItem.mrp, rate: newItem.rate));
          setState(() { if(editingIndex != null) items[editingIndex!] = newItem; else items.add(newItem); selectedMed = null; editingIndex = null; search = ""; });
        }, onCancel: () => setState(() => selectedMed = null)),
        Expanded(child: ListView.separated(itemCount: items.length, separatorBuilder: (c, i) => const Divider(), itemBuilder: (c, i) => ListTile(
          title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Qty: ${items[i].qty} + ${items[i].freeQty} Free | Batch: ${items[i].batch}"), // Free Qty added
          trailing: Text("₹${items[i].total.toStringAsFixed(2)}"),
          onTap: widget.isReadOnly ? null : () => setState(() { selectedMed = ph.medicines.firstWhere((m) => m.id == items[i].medicineID); editingIndex = i; }),
        ))),
        if (search.isNotEmpty && selectedMed == null) Container(height: 200, child: ListView(children: ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase())).map((m) => ListTile(title: Text(m.name), onTap: () => setState(() { selectedMed = m; search = ""; }))).toList())),
        Container(padding: const EdgeInsets.all(15), color: Colors.blue.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]))
      ]),
    );
  }

  void _saveAndClose(PharoahManager ph) async {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class ItemEntryForm extends StatefulWidget {
  final Medicine med; final Party party; final BillItem? existingItem; final List<BatchInfo> batchHistory; final int srNo; final Function(BillItem) onAdd; final VoidCallback onCancel;
  const ItemEntryForm({super.key, required this.med, required this.party, required this.srNo, this.existingItem, required this.batchHistory, required this.onAdd, required this.onCancel});
  @override State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController(); 
  final mC = TextEditingController(); final rC = TextEditingController(); final qC = TextEditingController(text: "1");
  final fC = TextEditingController(text: "0"); final rCD = TextEditingController(text: "0");
  String rT = "A";

  @override void initState() { super.initState(); mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString(); rT = widget.party.priceLevel; _updateRate(); if (widget.existingItem != null) { bC.text = widget.existingItem!.batch; eC.text = widget.existingItem!.exp; qC.text = widget.existingItem!.qty.toString(); fC.text = widget.existingItem!.freeQty.toString(); rC.text = widget.existingItem!.rate.toString(); } }
  
  void _updateRate() { if (rT == 'A') rC.text = widget.med.rateA.toString(); else if (rT == 'B') rC.text = widget.med.rateB.toString(); else _calcRateC(); }
  void _calcRateC() { double mrp = double.tryParse(mC.text) ?? 0; double gst = double.tryParse(gC.text) ?? 0; double disc = double.tryParse(rCD.text) ?? 0; double taxable = mrp / (1 + (gst / 100)); rC.text = (taxable - (taxable * disc / 100)).toStringAsFixed(2); }

  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(15), color: Colors.blue.shade50, child: Column(children: [
      Row(children: [Expanded(child: Text("${widget.srNo}. ${widget.med.name}")), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'A', label: Text('A')), ButtonSegment(value: 'B', label: Text('B')), ButtonSegment(value: 'C', label: Text('C'))], selected: {rT}, onSelectionChanged: (v) => setState(() { rT = v.first; _updateRate(); })),
      Row(children: [
        Expanded(child: TextField(controller: bC, keyboardType: TextInputType.text, textCapitalization: TextCapitalization.none, decoration: const InputDecoration(labelText: "Batch", border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)))),
        const SizedBox(width: 5), Expanded(child: _f(eC, "Exp", fmt: [ExpiryDateFormatter()])), 
        const SizedBox(width: 5), Expanded(child: _f(gC, "GST%")),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _f(mC, "MRP", onCh: (v) => rT == 'C' ? _calcRateC() : null)),
        const SizedBox(width: 5), Expanded(child: _f(qC, "Qty", isNum: true)),
        const SizedBox(width: 5), Expanded(child: _f(fC, "Free", isNum: true)), // Free Qty field
      ]),
      const SizedBox(height: 10),
      if (rT == 'C') TextField(controller: rCD, decoration: const InputDecoration(labelText: "Disc%", border: OutlineInputBorder()), onChanged: (v) => _calcRateC()),
      const SizedBox(height: 10),
      TextField(controller: rC, enabled: rT != 'C', decoration: const InputDecoration(labelText: "Rate", border: OutlineInputBorder())),
      const SizedBox(height: 15),
      ElevatedButton(onPressed: () {
        double r = double.tryParse(rC.text) ?? 0; double q = double.tryParse(qC.text) ?? 0; double f = double.tryParse(fC.text) ?? 0; double g = double.tryParse(gC.text) ?? 0;
        widget.onAdd(BillItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text, exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, qty: q, freeQty: f, rate: r, gstRate: g, total: (r * q) * (1 + g/100)));
      }, child: const Text("ADD TO LIST"))
    ]));
  }
  Widget _f(ctrl, l, {List<TextInputFormatter>? fmt, bool en = true, Function(String)? onCh, bool isNum = false}) => TextField(controller: ctrl, enabled: en, inputFormatters: fmt, onChanged: onCh, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)));
}
