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

  @override void initState() { super.initState(); if(widget.existingItems != null) items = List.from(widget.existingItems!); }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      appBar: AppBar(title: Text(widget.party.name), backgroundColor: Colors.blue.shade800, foregroundColor: Colors.white, actions: [
        if(!widget.isReadOnly) TextButton(onPressed: items.isEmpty ? null : () => _saveAndClose(ph), child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
      ]),
      body: Column(children: [
        if (selectedMed == null && !widget.isReadOnly) Container(padding: const EdgeInsets.all(12), color: Colors.blue.shade50, child: TextField(autofocus: true, decoration: const InputDecoration(hintText: "Search Product...", prefixIcon: Icon(Icons.search, color: Colors.blue), border: OutlineInputBorder()), onChanged: (v) => setState(() => search = v))),
        if (selectedMed != null) ItemEntryForm(med: selectedMed!, party: widget.party, srNo: items.length + 1, batchHistory: ph.batchHistory[selectedMed!.uniqueCode] ?? [], onAdd: (newItem) {
            ph.saveBatchCentrally(selectedMed!.uniqueCode, BatchInfo(batch: newItem.batch, exp: newItem.exp, packing: newItem.packing, mrp: newItem.mrp, rate: newItem.rate));
            setState(() { items.add(newItem); selectedMed = null; search = ""; });
          }, onCancel: () => setState(() => selectedMed = null)),
        Expanded(child: ListView.separated(itemCount: items.length, separatorBuilder: (c, i) => const Divider(), itemBuilder: (c, i) => ListTile(
          title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text("Qty: ${items[i].qty} | Batch: ${items[i].batch}"),
          trailing: Text("₹${items[i].total.toStringAsFixed(2)}"),
          onLongPress: () => setState(() => items.removeAt(i)),
        ))),
        Container(padding: const EdgeInsets.all(15), color: Colors.blue.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]))
      ]),
    );
  }

  void _saveAndClose(PharoahManager ph) async {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    if (widget.modifySaleId == null) await SaleBillNumber.incrementIfNecessary(widget.billNo);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class ItemEntryForm extends StatefulWidget {
  final Medicine med; final Party party; final int srNo; final List<BatchInfo> batchHistory; final Function(BillItem) onAdd; final VoidCallback onCancel;
  const ItemEntryForm({super.key, required this.med, required this.party, required this.srNo, required this.batchHistory, required this.onAdd, required this.onCancel});
  @override State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController(); 
  final mC = TextEditingController(); final rC = TextEditingController(); final qC = TextEditingController(text: "1");
  final fC = TextEditingController(text: "0");

  @override void initState() { super.initState(); mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString(); rC.text = widget.med.rateA.toString(); }

  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(15), color: Colors.blue.shade50, child: Column(children: [
      Row(children: [Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
      if (widget.batchHistory.isNotEmpty) SizedBox(height: 35, child: ListView(scrollDirection: Axis.horizontal, children: widget.batchHistory.map((b) => Padding(padding: const EdgeInsets.only(right: 5), child: ActionChip(label: Text(b.batch), onPressed: () => setState(() { bC.text = b.batch; eC.text = b.exp; mC.text = b.mrp.toString(); rC.text = b.rate.toString(); })))).toList())),
      Row(children: [
        Expanded(child: _field(bC, "Batch")), const SizedBox(width: 5), Expanded(child: _field(eC, "Exp", fmt: [ExpiryDateFormatter()])),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _field(mC, "MRP")), const SizedBox(width: 5), Expanded(child: _field(rC, "Rate")), 
        const SizedBox(width: 5), Expanded(child: _field(qC, "Qty", isNum: true)),
      ]),
      const SizedBox(height: 15),
      ElevatedButton(onPressed: () {
        double r = double.tryParse(rC.text) ?? 0; double q = double.tryParse(qC.text) ?? 0; double g = double.tryParse(gC.text) ?? 0;
        widget.onAdd(BillItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text, exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, qty: q, freeQty: 0, rate: r, gstRate: g, total: (r * q) * (1 + g/100)));
      }, child: const Text("ADD TO LIST"))
    ]));
  }
  Widget _field(ctrl, l, {List<TextInputFormatter>? fmt, bool isNum = false}) => TextField(controller: ctrl, inputFormatters: fmt, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)));
}
