import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'pdf/sale_invoice_pdf.dart';

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;
  final List<BillItem>? existingItems;
  final String? modifySaleId;

  const BillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
    this.existingItems,
    this.modifySaleId,
  });

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = [];
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
      backgroundColor: const Color(0xFFF1F8E9), // Light Green Theme
      appBar: AppBar(
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.party.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text("Bill: ${widget.billNo}", style: const TextStyle(fontSize: 10))
        ]),
        actions: [
          TextButton(
            onPressed: items.isEmpty ? null : () => _handleSave(ph),
            child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      ),
      body: Column(children: [
        if (selectedMed == null)
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.teal.shade50,
            child: TextField(
              autofocus: true,
              decoration: const InputDecoration(hintText: "Search Product...", prefixIcon: Icon(Icons.search, color: Colors.teal), border: OutlineInputBorder()),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),

        if (selectedMed != null)
          SaleItemForm(
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
              title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
              subtitle: Text("Batch: ${items[i].batch} | Qty: ${items[i].qty.toInt()}"),
              trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              onLongPress: () => setState(() => items.removeAt(i)),
            ),
          ),
        ),

        if (searchQuery.isNotEmpty && selectedMed == null) _buildSearchList(ph),

        Container(
          padding: const EdgeInsets.all(15),
          color: Colors.teal.shade50,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("TOTAL ITEMS: ${items.length}"),
            Text("NET TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal.shade900))
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
          decoration: const BoxDecoration(border: Border(left: BorderSide(color: Colors.teal, width: 5))),
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
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: totalAmt, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// --- SALES ITEM ENTRY FORM ---
class SaleItemForm extends StatefulWidget {
  final Medicine med; final int srNo; final List<BatchInfo> batchHistory; final Function(BillItem) onAdd; final VoidCallback onCancel;
  const SaleItemForm({super.key, required this.med, required this.srNo, required this.batchHistory, required this.onAdd, required this.onCancel});
  @override State<SaleItemForm> createState() => _SaleItemFormState();
}

class _SaleItemFormState extends State<SaleItemForm> {
  final bC = TextEditingController(); final mC = TextEditingController(); 
  final rC = TextEditingController(); final qC = TextEditingController(text: "1");
  final discC = TextEditingController(text: "0");
  final rCC = TextEditingController();
  bool showDisc = false;

  @override void initState() {
    super.initState();
    mC.text = widget.med.mrp.toString();
    rC.text = widget.med.rateA.toString();
    _calcRateC();
  }

  void _calcRateC() {
    double mrp = double.tryParse(mC.text) ?? 0;
    double gst = widget.med.gst;
    double disc = double.tryParse(discC.text) ?? 0;
    double taxable = mrp / (1 + (gst / 100));
    double rateC = taxable * (1 - (disc / 100));
    rCC.text = rateC.toStringAsFixed(2);
  }

  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(15), color: Colors.teal.shade50, child: Column(children: [
      Row(children: [Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal))), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
      if (widget.batchHistory.isNotEmpty) SizedBox(height: 35, child: ListView(scrollDirection: Axis.horizontal, children: widget.batchHistory.map((b) => Padding(padding: const EdgeInsets.only(right: 5), child: ActionChip(label: Text(b.batch), onPressed: () => setState(() => bC.text = b.batch)))).toList())),
      Row(children: [Expanded(child: _field(bC, "Batch")), const SizedBox(width: 5), Expanded(child: _field(qC, "Qty", isNum: true)), const SizedBox(width: 5), Expanded(child: _field(rC, "Sale Rate"))]),
      const SizedBox(height: 10),
      GestureDetector(onTap: () => setState(() => showDisc = !showDisc), child: _field(rCC, "Rate C (Tap for Discount)", en: false)),
      if(showDisc) Padding(padding: const EdgeInsets.only(top: 10), child: _field(discC, "Discount %", onCh: (v) => _calcRateC())),
      const SizedBox(height: 15),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.teal.shade700), onPressed: () {
        double r = double.tryParse(rC.text) ?? 0; double q = double.tryParse(qC.text) ?? 0;
        double tax = (q * r) * (widget.med.gst / 100);
        widget.onAdd(BillItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text, exp: "12/26", hsn: widget.med.hsnCode, mrp: widget.med.mrp, qty: q, rate: r, gstRate: widget.med.gst, total: (q * r) + tax, cgst: tax/2, sgst: tax/2));
      }, child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
    ]));
  }
  Widget _field(ctrl, l, {bool en = true, Function(String)? onCh, bool isNum = false}) => TextField(controller: ctrl, enabled: en, onChanged: onCh, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8), filled: !en, fillColor: Colors.white));
}
