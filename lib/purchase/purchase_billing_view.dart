import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';

class PurchaseBillingView extends StatefulWidget {
  final Party distributor;
  final String internalNo, distBillNo, mode;
  final DateTime billDate, entryDate;
  final List<PurchaseItem>? existingItems;
  final String? modifyPurchaseId;

  const PurchaseBillingView({
    super.key,
    required this.distributor,
    required this.internalNo,
    required this.distBillNo,
    required this.billDate,
    required this.entryDate,
    required this.mode,
    this.existingItems,
    this.modifyPurchaseId,
  });

  @override
  State<PurchaseBillingView> createState() => _PurchaseBillingViewState();
}

class _PurchaseBillingViewState extends State<PurchaseBillingView> {
  List<PurchaseItem> items = [];
  String searchQuery = "";
  Medicine? selectedMed;
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) items = List.from(widget.existingItems!);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        backgroundColor: Colors.orange.shade800,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.distributor.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text("Bill: ${widget.distBillNo} | ID: ${widget.internalNo}", style: const TextStyle(fontSize: 10))
        ]),
        actions: [
          TextButton(
            onPressed: items.isEmpty ? null : () => _handleSave(ph),
            child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ],
      ),
      body: Column(children: [
        if (selectedMed == null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.orange.shade50,
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: "Search Product...", prefixIcon: Icon(Icons.search, color: Colors.orange), border: OutlineInputBorder()),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),
        
        if (selectedMed != null)
          PurchaseItemForm(
            med: selectedMed!,
            srNo: items.length + 1,
            batchHistory: ph.batchHistory[selectedMed!.id] ?? [],
            onAdd: (newItem) => setState(() { items.add(newItem); selectedMed = null; searchQuery = ""; }),
            onCancel: () => setState(() => selectedMed = null),
          ),
        
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (c, i) => const Divider(height: 1),
            itemBuilder: (c, i) => ListTile(
              title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Batch: ${items[i].batch} | Qty: ${items[i].qty.toInt()}"),
              trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              onLongPress: () => setState(() => items.removeAt(i)),
            ),
          ),
        ),

        if (searchQuery.isNotEmpty && selectedMed == null)
          _buildSearchList(ph),

        Container(
          padding: const EdgeInsets.all(15),
          color: Colors.orange.shade50,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("TOTAL ITEMS: ${items.length}"),
            Text("NET TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange))
          ]),
        )
      ]),
    );
  }

  Widget _buildSearchList(PharoahManager ph) => Container(
    constraints: const BoxConstraints(maxHeight: 250),
    color: Colors.white,
    child: ListView.builder(
      itemCount: ph.medicines.where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase())).length,
      itemBuilder: (c, i) {
        final m = ph.medicines.where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase())).toList()[i];
        return Container(
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.orange, width: 5))),
          child: ListTile(
            title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Stock: ${m.stock} | Pack: ${m.packing}"),
            onTap: () => setState(() { selectedMed = m; searchQuery = ""; }),
          ),
        );
      },
    ),
  );

  void _handleSave(PharoahManager ph) {
    if (widget.modifyPurchaseId != null) ph.deletePurchase(widget.modifyPurchaseId!);
    ph.finalizePurchase(internalNo: widget.internalNo, billNo: widget.distBillNo, date: widget.billDate, entryDate: widget.entryDate, party: widget.distributor, items: items, total: totalAmt, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// --- PURCHASE ITEM FORM WITH RATE C LOGIC ---
class PurchaseItemForm extends StatefulWidget {
  final Medicine med; final int srNo; final List<BatchInfo> batchHistory; final Function(PurchaseItem) onAdd; final VoidCallback onCancel;
  const PurchaseItemForm({super.key, required this.med, required this.srNo, required this.batchHistory, required this.onAdd, required this.onCancel});
  @override State<PurchaseItemForm> createState() => _PurchaseItemFormState();
}

class _PurchaseItemFormState extends State<PurchaseItemForm> {
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController();
  final mC = TextEditingController(); final pRC = TextEditingController(); final qC = TextEditingController(text: "1");
  final rAC = TextEditingController(); final rBC = TextEditingController(); final rCC = TextEditingController();
  final discC = TextEditingController(text: "0");
  bool showDisc = false;

  @override void initState() {
    super.initState();
    mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString(); pRC.text = widget.med.purRate.toString();
    rAC.text = widget.med.rateA.toString(); rBC.text = widget.med.rateB.toString();
    _calcRateC();
  }

  void _calcRateC() {
    double mrp = double.tryParse(mC.text) ?? 0;
    double gst = double.tryParse(gC.text) ?? 0;
    double disc = double.tryParse(discC.text) ?? 0;
    double taxable = mrp / (1 + (gst / 100));
    double rateC = taxable * (1 - (disc / 100));
    rCC.text = rateC.toStringAsFixed(2);
  }

  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(15), color: Colors.orange.shade50, child: Column(children: [
      Row(children: [Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold))), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
      if (widget.batchHistory.isNotEmpty) SizedBox(height: 35, child: ListView(scrollDirection: Axis.horizontal, children: widget.batchHistory.map((b) => Padding(padding: const EdgeInsets.only(right: 5), child: ActionChip(label: Text(b.batch), onPressed: () => setState(() => bC.text = b.batch)))).toList())),
      Row(children: [Expanded(child: _field(bC, "Batch")), const SizedBox(width: 5), Expanded(child: _field(eC, "Exp")), const SizedBox(width: 5), Expanded(child: _field(gC, "GST%", onCh: (v) => _calcRateC()))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _field(mC, "MRP", onCh: (v) => _calcRateC())), const SizedBox(width: 5), Expanded(child: _field(pRC, "Pur. Rate")), const SizedBox(width: 5), Expanded(child: _field(qC, "Qty", isNum: true))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _field(rAC, "Rate A")), const SizedBox(width: 5), Expanded(child: _field(rBC, "Rate B")), const SizedBox(width: 5), 
        Expanded(child: GestureDetector(onTap: () => setState(() => showDisc = !showDisc), child: _field(rCC, "Rate C (Tap for Disc)", en: false)))
      ]),
      if(showDisc) Padding(padding: const EdgeInsets.only(top: 10), child: _field(discC, "Discount %", onCh: (v) => _calcRateC())),
      const SizedBox(height: 15),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.orange.shade800), onPressed: () {
        double pr = double.tryParse(pRC.text) ?? 0, qt = double.tryParse(qC.text) ?? 0, gst = double.tryParse(gC.text) ?? 0;
        widget.onAdd(PurchaseItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text.toUpperCase(), exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, qty: qt, purchaseRate: pr, gstRate: gst, total: (pr * qt) * (1 + gst/100), rateA: double.tryParse(rAC.text) ?? 0, rateB: double.tryParse(rBC.text) ?? 0, rateC: double.tryParse(rCC.text) ?? 0));
      }, child: const Text("ADD TO STOCK", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
    ]));
  }
  Widget _field(ctrl, l, {bool en = true, Function(String)? onCh, bool isNum = false}) => TextField(controller: ctrl, enabled: en, onChanged: onCh, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8), filled: !en, fillColor: Colors.white));
}
