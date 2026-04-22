import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';

// --- BATCH & EXPIRY FORMATTERS ---
class ExpiryDateFormatter extends TextInputFormatter {
  @override TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) return newValue;
    if (text.length == 2 && !text.contains('/')) {
      return TextEditingValue(text: '$text/', selection: TextSelection.collapsed(offset: 3));
    }
    return newValue;
  }
}

class PurchaseBillingView extends StatefulWidget {
  final Party distributor; 
  final String internalNo, distBillNo, mode; 
  final DateTime billDate, entryDate;
  final List<PurchaseItem>? existingItems; 
  final String? modifyPurchaseId;

  const PurchaseBillingView({super.key, required this.distributor, required this.internalNo, required this.distBillNo, required this.billDate, required this.entryDate, required this.mode, this.existingItems, this.modifyPurchaseId});
  
  @override State<PurchaseBillingView> createState() => _PurchaseBillingViewState();
}

class _PurchaseBillingViewState extends State<PurchaseBillingView> {
  List<PurchaseItem> items = []; 
  String searchQuery = ""; 
  Medicine? selectedMed;
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override void initState() { 
    super.initState(); 
    if (widget.existingItems != null) items = List.from(widget.existingItems!); 
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white, 
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.distributor.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), 
            Text("Bill: ${widget.distBillNo} | ID: ${widget.internalNo}", style: const TextStyle(fontSize: 10))
          ]
        ), 
        actions: [
          TextButton(onPressed: items.isEmpty ? null : () => _handleSave(ph), child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ]
      ),
      body: Stack(children: [
        Column(children: [
          if (selectedMed == null) 
            Container(padding: const EdgeInsets.all(12), color: Colors.orange.shade50, child: TextField(autofocus: true, decoration: const InputDecoration(hintText: "Search Product...", prefixIcon: Icon(Icons.search, color: Colors.orange), filled: true, fillColor: Colors.white, border: OutlineInputBorder()), onChanged: (v) => setState(() => searchQuery = v))),
          
          if (selectedMed != null) 
            PurchaseItemForm(
              med: selectedMed!, 
              srNo: items.length + 1, 
              batchHistory: ph.batchHistory[selectedMed!.id] ?? [],
              onAdd: (newItem) {
                setState(() { items.add(newItem); selectedMed = null; searchQuery = ""; });
              }, 
              onCancel: () => setState(() => selectedMed = null)
            ),
          
          Expanded(child: ListView.separated(
            itemCount: items.length, separatorBuilder: (c, i) => const Divider(), itemBuilder: (c, i) => ListTile(
              title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), 
              subtitle: Text("Qty: ${items[i].qty} + ${items[i].freeQty} | Batch: ${items[i].batch}"), 
              trailing: Text("₹${items[i].total.toStringAsFixed(2)}"),
              onLongPress: () => setState(() => items.removeAt(i)),
            )
          )),

          if (searchQuery.isNotEmpty && selectedMed == null)
            Container(constraints: const BoxConstraints(maxHeight: 250), color: Colors.white, child: ListView(children: ph.medicines.where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase())).map((m) => ListTile(
              leading: const Icon(Icons.medication), title: Text(m.name), onTap: () => setState(() { selectedMed = m; searchQuery = ""; }),
            )).toList())),

          Container(padding: const EdgeInsets.all(15), color: Colors.orange.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text("TOTAL ITEMS: ${items.length}"), Text("NET TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange))]))
        ]),
      ]),
    );
  }

  void _handleSave(PharoahManager ph) { 
    if (widget.modifyPurchaseId != null) ph.deletePurchase(widget.modifyPurchaseId!);
    ph.finalizePurchase(internalNo: widget.internalNo, billNo: widget.distBillNo, date: widget.billDate, entryDate: widget.entryDate, party: widget.distributor, items: items, total: totalAmt, mode: widget.mode); 
    Navigator.of(context).popUntil((route) => route.isFirst); 
  }
}

class PurchaseItemForm extends StatefulWidget {
  final Medicine med; final int srNo; final List<BatchInfo> batchHistory; final Function(PurchaseItem) onAdd; final VoidCallback onCancel;
  const PurchaseItemForm({super.key, required this.med, required this.srNo, required this.batchHistory, required this.onAdd, required this.onCancel});
  @override State<PurchaseItemForm> createState() => _PurchaseItemFormState();
}

class _PurchaseItemFormState extends State<PurchaseItemForm> {
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController(); 
  final mC = TextEditingController(); final pRC = TextEditingController(); final qC = TextEditingController(text: "1"); 
  final fC = TextEditingController(text: "0"); final rAC = TextEditingController(); 
  final rBC = TextEditingController(); final rCC = TextEditingController(); final rCD = TextEditingController(text: "0");

  @override void initState() { 
    super.initState(); 
    mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString(); pRC.text = widget.med.purRate.toString();
    rAC.text = widget.med.rateA.toString(); rBC.text = widget.med.rateB.toString(); _calcRateC(); 
  }

  void _calcRateC() {
    double mrp = double.tryParse(mC.text) ?? 0;
    double gst = double.tryParse(gC.text) ?? 0;
    double disc = double.tryParse(rCD.text) ?? 0;
    double taxableValue = mrp / (1 + (gst / 100));
    rCC.text = (taxableValue - (taxableValue * disc / 100)).toStringAsFixed(2);
  }

  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(15), color: Colors.orange.shade50, child: Column(children: [
      Row(children: [Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
      if (widget.batchHistory.isNotEmpty) SizedBox(height: 35, child: ListView(scrollDirection: Axis.horizontal, children: widget.batchHistory.map((b) => Padding(padding: const EdgeInsets.only(right: 5), child: ActionChip(label: Text("${b.batch} (${b.exp})"), onPressed: () => setState(() { bC.text = b.batch; eC.text = b.exp; mC.text = b.mrp.toString(); pRC.text = b.rate.toString(); _calcRateC(); })) )).toList())),
      Row(children: [
        Expanded(child: TextField(controller: bC, keyboardType: TextInputType.text, textCapitalization: TextCapitalization.none, decoration: const InputDecoration(labelText: "Batch", border: OutlineInputBorder(), contentPadding: EdgeInsets.all(8)))),
        const SizedBox(width: 5), Expanded(child: _f(eC, "Exp", fmt: [ExpiryDateFormatter()])), const SizedBox(width: 5), Expanded(child: _f(gC, "GST%", onCh: (v) => _calcRateC())),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _f(mC, "MRP", onCh: (v) => _calcRateC())), const SizedBox(width: 5),
        Expanded(child: _f(pRC, "Pur. Rate")), const SizedBox(width: 5),
        Expanded(child: _f(qC, "Qty", isNum: true)), const SizedBox(width: 5),
        Expanded(child: _f(fC, "Free", isNum: true)),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _f(rAC, "Rate A")), const SizedBox(width: 5),
        Expanded(child: _f(rBC, "Rate B")), const SizedBox(width: 5),
        Expanded(child: _f(rCD, "RC Disc%", onCh: (v) => _calcRateC())), const SizedBox(width: 5),
        Expanded(child: _f(rCC, "Rate C", en: false)),
      ]),
      const SizedBox(height: 15),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.orange.shade800), onPressed: () {
        double pr = double.tryParse(pRC.text) ?? 0, qt = double.tryParse(qC.text) ?? 0, gst = double.tryParse(gC.text) ?? 0;
        widget.onAdd(PurchaseItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text, exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, qty: qt, freeQty: double.tryParse(fC.text) ?? 0, purchaseRate: pr, gstRate: gst, total: (pr * qt) * (1 + gst/100), rateA: double.tryParse(rAC.text) ?? 0, rateB: double.tryParse(rBC.text) ?? 0, rateC: double.tryParse(rCC.text) ?? 0));
      }, child: const Text("ADD TO STOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
    ]));
  }
  Widget _f(ctrl, l, {List<TextInputFormatter>? fmt, bool en = true, Function(String)? onCh, bool isNum = false}) => TextField(controller: ctrl, enabled: en, inputFormatters: fmt, onChanged: onCh, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)));
}
