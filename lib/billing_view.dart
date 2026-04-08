import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf_service.dart';

class BillingView extends StatefulWidget {
  final Party party; final String billNo; final DateTime billDate; final String mode;
  final List<BillItem>? existingItems; final String? modifySaleId; final bool isReadOnly;
  const BillingView({super.key, required this.party, required this.billNo, required this.billDate, required this.mode, this.existingItems, this.modifySaleId, this.isReadOnly = false});

  @override State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = []; String search = ""; Medicine? selectedMed; int? editingIndex;
  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);
  double get totalGst => items.fold(0, (sum, item) => sum + (item.cgst + item.sgst));

  @override void initState() { super.initState(); if (widget.existingItems != null) items = List.from(widget.existingItems!); }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      appBar: AppBar(backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue, foregroundColor: Colors.white, title: Text(widget.party.name, style: const TextStyle(fontSize: 14)), actions: [IconButton(icon: const Icon(Icons.print), onPressed: items.isEmpty ? null : () => _saveAndPrint(ph)), if (!widget.isReadOnly) TextButton(onPressed: items.isEmpty ? null : () => _saveAndClose(ph), child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))]),
      body: Stack(children: [
        Column(children: [
          if (selectedMed == null && !widget.isReadOnly) Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: const InputDecoration(hintText: "Search Medicine...", border: OutlineInputBorder()), onChanged: (v) => setState(() => search = v))),
          if (selectedMed != null) ItemEntryForm(med: selectedMed!, srNo: editingIndex ?? items.length + 1, existingItem: editingIndex != null ? items[editingIndex!] : null, onAdd: (ni) { setState(() { if (editingIndex != null) items[editingIndex!] = ni; else { items.add(ni); ph.addToLocalInventory(selectedMed!); } selectedMed = null; editingIndex = null; search = ""; }); }, onCancel: () => setState(() { selectedMed = null; editingIndex = null; })),
          Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (c, i) => ListTile(title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Qty: ${items[i].qty.toInt()} | B: ${items[i].batch} | E: ${items[i].exp}"), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), if(!widget.isReadOnly) IconButton(icon: const Icon(Icons.copy, size: 18, color: Colors.orange), onPressed: () => setState(() { selectedMed = ph.medicines.firstWhere((m) => m.id == items[i].medicineID); editingIndex = null; }))]), onTap: widget.isReadOnly ? null : () => setState(() { selectedMed = ph.medicines.firstWhere((m) => m.id == items[i].medicineID); editingIndex = i; })))),
          Container(padding: const EdgeInsets.all(12), color: Colors.blue[50], child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Taxable: ₹${(grandTotal - totalGst).toStringAsFixed(2)}"), Text("GST: ₹${totalGst.toStringAsFixed(2)}")]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("Items: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)), Text("TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green))]),
          ]))
        ]),
        if (search.isNotEmpty && selectedMed == null) Positioned(top: 70, left: 10, right: 10, child: Material(elevation: 5, child: ListView(shrinkWrap: true, children: ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase())).map((m) => ListTile(title: Text(m.name), subtitle: Text("Stock: ${m.stock}"), onTap: () => setState(() { selectedMed = m; search = ""; }))).toList())))
      ]),
    );
  }
  void _saveAndClose(PharoahManager ph) async { if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!); ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode); if (widget.modifySaleId == null) await SaleBillNumber.increment(); if(mounted) Navigator.pop(context); }
  void _saveAndPrint(PharoahManager ph) async { final sale = Sale(id: DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, items: items, totalAmount: grandTotal, paymentMode: widget.mode); if (!widget.isReadOnly) { if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!); ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode); if (widget.modifySaleId == null) await SaleBillNumber.increment(); } await PdfService.generateInvoice(sale, widget.party); if (!widget.isReadOnly && mounted) Navigator.pop(context); }
}

class ItemEntryForm extends StatefulWidget {
  final Medicine med; final int srNo; final BillItem? existingItem; final Function(BillItem) onAdd; final VoidCallback onCancel;
  const ItemEntryForm({super.key, required this.med, required this.srNo, this.existingItem, required this.onAdd, required this.onCancel});
  @override State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController();
  final mC = TextEditingController(); final rC = TextEditingController(); final qC = TextEditingController();
  final rCD = TextEditingController(text: "0.0"); final nDP = TextEditingController(text: "0.0"); final nDR = TextEditingController(text: "0.0");
  String rT = "A";

  @override void initState() {
    super.initState();
    if (widget.existingItem != null) {
      bC.text = widget.existingItem!.batch; eC.text = widget.existingItem!.exp; gC.text = widget.existingItem!.gstRate.toString();
      mC.text = widget.existingItem!.mrp.toString(); rC.text = widget.existingItem!.rate.toString();
      qC.text = widget.existingItem!.qty.toString(); nDP.text = widget.existingItem!.discountPercent.toString(); nDR.text = widget.existingItem!.discountRupees.toString();
    } else { mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString(); rC.text = widget.med.rateA.toString(); qC.text = "1"; }
    eC.addListener(() {
      String t = eC.text.replaceAll("/", "");
      if (t.length >= 2) {
        int month = int.tryParse(t.substring(0, 2)) ?? 1;
        if (month > 12) t = "12${t.substring(2)}"; if (month == 0) t = "01${t.substring(2)}";
        String formatted = "${t.substring(0, 2)}/${t.substring(2)}";
        if (eC.text != formatted) { eC.text = formatted; eC.selection = TextSelection.fromPosition(TextPosition(offset: eC.text.length)); }
      }
    });
  }

  void _upd() {
    double m = double.tryParse(mC.text) ?? 0, g = double.tryParse(gC.text) ?? 0;
    if (rT == "A") rC.text = widget.med.rateA.toString();
    else if (rT == "B") rC.text = widget.med.rateB.toString();
    else { double d = double.tryParse(rCD.text) ?? 0, b = (m / (1 + (g / 100))); rC.text = (b - (b * (d / 100))).toStringAsFixed(2); }
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final history = ph.batchHistory[widget.med.id] ?? [];
    return Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Column(children: [
      Row(children: [Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
      if (history.isNotEmpty) SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: history.map((b)=>ActionChip(label: Text(b.batch), onPressed: (){ setState(() { bC.text = b.batch; eC.text = b.exp; mC.text = b.mrp.toString(); rC.text = b.rate.toString(); }); })).toList())),
      Row(children: [Expanded(child: TextField(controller: bC, decoration: const InputDecoration(labelText: "Batch"))), const SizedBox(width: 5), Expanded(child: TextField(controller: eC, decoration: const InputDecoration(hintText: "MM/YY", labelText: "Exp"), keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: gC, decoration: const InputDecoration(labelText: "GST%"), keyboardType: TextInputType.number, onChanged: (v)=>_upd()))]),
      const SizedBox(height: 10),
      SegmentedButton<String>(segments: const [ButtonSegment(value: 'A', label: Text('Rate A')), ButtonSegment(value: 'B', label: Text('Rate B')), ButtonSegment(value: 'C', label: Text('Rate C'))], selected: {rT}, onSelectionChanged: (val) { setState(() => rT = val.first); _upd(); }),
      Row(children: [if (rT == 'C') Expanded(child: TextField(controller: rCD, decoration: const InputDecoration(labelText: "RC Disc%"), keyboardType: TextInputType.number, onChanged: (v)=>_upd())), Expanded(child: TextField(controller: mC, decoration: const InputDecoration(labelText: "MRP"), keyboardType: TextInputType.number, onChanged: (v) => _upd())), Expanded(child: TextField(controller: rC, decoration: const InputDecoration(labelText: "Rate"), keyboardType: TextInputType.number, enabled: rT != 'C')), Expanded(child: TextField(controller: qC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number))]),
      Row(children: [Expanded(child: TextField(controller: nDP, decoration: const InputDecoration(labelText: "Disc %"), keyboardType: TextInputType.number)), const SizedBox(width: 5), Expanded(child: TextField(controller: nDR, decoration: const InputDecoration(labelText: "Disc ₹"), keyboardType: TextInputType.number))]),
      const SizedBox(height: 10),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.green), onPressed: () {
        double r = double.tryParse(rC.text) ?? 0, q = double.tryParse(qC.text) ?? 0, dp = double.tryParse(nDP.text) ?? 0, dr = double.tryParse(nDR.text) ?? 0, g = double.tryParse(gC.text) ?? 0;
        double tx = (r * q); tx = tx - (tx * (dp / 100)) - dr; double ga = tx * (g / 100);
        widget.onAdd(BillItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text.toUpperCase(), exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, qty: q, rate: r, discountPercent: dp, discountRupees: dr, gstRate: g, cgst: ga/2, sgst: ga/2, total: tx + ga));
      }, child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
    ]));
  }
}
