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
          if (!widget.isReadOnly) TextButton(onPressed: items.isEmpty ? null : () => _saveAndClose(ph), child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ],
      ),
      body: Stack(children: [
        Column(children: [
          if (selectedMed == null && !widget.isReadOnly) 
            Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: const InputDecoration(hintText: "Search Medicine...", border: OutlineInputBorder()), onChanged: (v) => setState(() => search = v))),
          
          if (selectedMed != null) 
            ItemEntryForm(
              med: selectedMed!, 
              srNo: editingIndex ?? items.length + 1, 
              existingItem: editingIndex != null ? items[editingIndex!] : null, 
              onAdd: (ni) { setState(() { if (editingIndex != null) items[editingIndex!] = ni; else { items.add(ni); ph.addToLocalInventory(selectedMed!); } selectedMed = null; editingIndex = null; search = ""; }); }, 
              onCancel: () => setState(() { selectedMed = null; editingIndex = null; })
            ),
          
          Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (c, i) => ListTile(
            title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Qty: ${items[i].qty.toInt()} | Batch: ${items[i].batch} | Exp: ${items[i].exp}"),
            trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
            onTap: widget.isReadOnly ? null : () {
              setState(() {
                selectedMed = ph.medicines.firstWhere((m) => m.id == items[i].medicineID);
                editingIndex = i;
              });
            },
          ))),

          // SUMMARY FOOTER
          Container(padding: const EdgeInsets.all(12), color: Colors.blue[50], child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Taxable: ₹${(grandTotal - totalGst).toStringAsFixed(2)}"),
              Text("GST: ₹${totalGst.toStringAsFixed(2)}"),
            ]),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text("Items: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
              Text("TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
            ]),
          ]))
        ]),

        if (search.isNotEmpty && selectedMed == null) 
          Positioned(top: 70, left: 10, right: 10, child: Material(elevation: 5, child: ListView(shrinkWrap: true, children: ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase())).map((m) => ListTile(title: Text(m.name), subtitle: Text("Stock: ${m.stock}"), onTap: () => setState(() { selectedMed = m; search = ""; }))).toList())))
      ]),
    );
  }

  void _saveAndClose(PharoahManager ph) async { 
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!); 
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode); 
    if (widget.modifySaleId == null) await SaleBillNumber.increment(); 
    if(mounted) Navigator.pop(context); 
  }

  void _saveAndPrint(PharoahManager ph) async { 
    final sale = Sale(id: DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, items: items, totalAmount: grandTotal, paymentMode: widget.mode); 
    if (!widget.isReadOnly) {
      if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
      ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
      if (widget.modifySaleId == null) await SaleBillNumber.increment();
    }
    await PdfService.generateInvoice(sale, widget.party);
    if (!widget.isReadOnly && mounted) Navigator.pop(context);
  }
}

class ItemEntryForm extends StatefulWidget {
  final Medicine med; final int srNo; final BillItem? existingItem; final Function(BillItem) onAdd; final VoidCallback onCancel;
  const ItemEntryForm({super.key, required this.med, required this.srNo, this.existingItem, required this.onAdd, required this.onCancel});
  @override State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final batchC = TextEditingController(); final expC = TextEditingController(); final gstC = TextEditingController();
  final mrpC = TextEditingController(); final rateC = TextEditingController(); final qtyC = TextEditingController();
  final rateCDiscC = TextEditingController(text: "0.0"); 
  final normalDiscPC = TextEditingController(text: "0.0"); // Percent %
  final normalDiscRC = TextEditingController(text: "0.0"); // Rupees Less ₹
  String rateType = "A";

  @override void initState() {
    super.initState();
    if (widget.existingItem != null) {
      batchC.text = widget.existingItem!.batch; expC.text = widget.existingItem!.exp; gstC.text = widget.existingItem!.gstRate.toString();
      mrpC.text = widget.existingItem!.mrp.toString(); rateC.text = widget.existingItem!.rate.toString();
      qtyC.text = widget.existingItem!.qty.toString(); 
      normalDiscPC.text = widget.existingItem!.discountPercent.toString();
      normalDiscRC.text = widget.existingItem!.discountRupees.toString();
    } else {
      mrpC.text = widget.med.mrp.toString(); gstC.text = widget.med.gst.toString(); rateC.text = widget.med.rateA.toString(); qtyC.text = "1";
    }
    // AUTO SLASH LOGIC FOR MM/YY
    expC.addListener(() {
      String text = expC.text;
      if (text.length == 2 && !text.contains("/")) {
        expC.text = "$text/";
        expC.selection = TextSelection.fromPosition(TextPosition(offset: expC.text.length));
      }
    });
  }

  // --- RATE C FORMULA LOGIC ---
  void _calculateRateC() {
    double mrpVal = double.tryParse(mrpC.text) ?? 0;
    double gstVal = double.tryParse(gstC.text) ?? 0;
    double rCDiscVal = double.tryParse(rateCDiscC.text) ?? 0;
    
    // Step 1: MRP se Tax hatao
    double taxableBase = (mrpVal / (1 + (gstVal / 100)));
    // Step 2: Taxable value par discount lagao
    double finalRate = taxableBase - (taxableBase * (rCDiscVal / 100));
    
    rateC.text = finalRate.toStringAsFixed(2);
  }

  void _updateRateType() {
    if (rateType == "A") rateC.text = widget.med.rateA.toString();
    else if (rateType == "B") rateC.text = widget.med.rateB.toString();
    else _calculateRateC();
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final history = ph.batchHistory[widget.med.id] ?? [];

    return Container(padding: const EdgeInsets.all(10), color: Colors.white, child: Column(children: [
      Row(children: [Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
      
      if (history.isNotEmpty) 
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: history.map((b)=>ActionChip(label: Text(b.batch), onPressed: (){ setState(() { batchC.text = b.batch; expC.text = b.exp; mrpC.text = b.mrp.toString(); rateC.text = b.rate.toString(); }); })).toList())),
      
      Row(children: [
        Expanded(child: TextField(controller: batchC, decoration: const InputDecoration(labelText: "Batch"))), const SizedBox(width: 5),
        Expanded(child: TextField(controller: expC, decoration: const InputDecoration(hintText: "MM/YY", labelText: "Exp"), keyboardType: TextInputType.number)), const SizedBox(width: 5),
        Expanded(child: TextField(controller: gstC, decoration: const InputDecoration(labelText: "GST%"), keyboardType: TextInputType.number, onChanged: (v) { if(rateType == 'C') _calculateRateC(); })),
      ]),
      const SizedBox(height: 10),
      SegmentedButton<String>(
        segments: const [ButtonSegment(value: 'A', label: Text('Rate A')), ButtonSegment(value: 'B', label: Text('Rate B')), ButtonSegment(value: 'C', label: Text('Rate C'))],
        selected: {rateType}, onSelectionChanged: (val) { setState(() => rateType = val.first); _updateRateType(); },
      ),
      const SizedBox(height: 5),
      Row(children: [
        if (rateType == 'C') Expanded(child: TextField(controller: rateCDiscC, decoration: const InputDecoration(labelText: "RC Disc%", labelStyle: TextStyle(color: Colors.purple, fontSize: 12)), keyboardType: TextInputType.number, onChanged: (v)=>_calculateRateC())),
        Expanded(child: TextField(controller: mrpC, decoration: const InputDecoration(labelText: "MRP"), keyboardType: TextInputType.number, onChanged: (v) { if(rateType == 'C') _calculateRateC(); })),
        Expanded(child: TextField(controller: rateC, decoration: const InputDecoration(labelText: "Rate"), keyboardType: TextInputType.number, enabled: rateType != 'C')),
        Expanded(child: TextField(controller: qtyC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number)),
      ]),
      Row(children: [
        Expanded(child: TextField(controller: normalDiscPC, decoration: const InputDecoration(labelText: "Normal Disc %"), keyboardType: TextInputType.number)),
        const SizedBox(width: 5),
        Expanded(child: TextField(controller: normalDiscRC, decoration: const InputDecoration(labelText: "Disc Rupees ₹"), keyboardType: TextInputType.number)),
      ]),
      const SizedBox(height: 10),
      ElevatedButton(
        style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.green), 
        onPressed: () {
          double r = double.tryParse(rateC.text) ?? 0, q = double.tryParse(qtyC.text) ?? 0;
          double dP = double.tryParse(normalDiscPC.text) ?? 0;
          double dR = double.tryParse(normalDiscRC.text) ?? 0;
          double g = double.tryParse(gstC.text) ?? 0;

          // FINAL CALCULATION: (Rate * Qty) - % Disc - ₹ Less
          double gross = r * q;
          double taxable = gross - (gross * (dP / 100)) - dR;
          double gstAmt = taxable * (g / 100);

          widget.onAdd(BillItem(
            id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: batchC.text.toUpperCase(), exp: expC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mrpC.text) ?? 0, qty: q, rate: r, discountPercent: dP, discountRupees: dR, gstRate: g, cgst: gstAmt/2, sgst: gstAmt/2, total: taxable + gstAmt
          ));
        }, 
        child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
      )
    ]));
  }
}
