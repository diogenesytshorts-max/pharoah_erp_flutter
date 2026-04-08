import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf_service.dart';

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;

  const BillingView({super.key, required this.party, required this.billNo, required this.billDate, required this.mode});

  @override
  State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = [];
  String search = "";
  Medicine? selectedMed;
  int? editingIndex;

  double get grandTotal => items.fold(0, (sum, item) => sum + item.total);

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: Text(widget.party.name, style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: items.isEmpty ? null : () => _saveAndPrint(ph),
          ),
          TextButton(
            onPressed: items.isEmpty ? null : () => _saveAndClose(ph),
            child: const Text("SAVE", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (selectedMed == null)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    decoration: InputDecoration(hintText: "Search Medicine...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                    onChanged: (val) => setState(() => search = val),
                  ),
                ),
              if (selectedMed != null)
                ItemEntryForm(
                  med: selectedMed!,
                  srNo: editingIndex ?? items.length + 1,
                  existingItem: editingIndex != null ? items[editingIndex!] : null,
                  onAdd: (newItem) {
                    setState(() {
                      if (editingIndex != null) { items[editingIndex!] = newItem; } 
                      else { items.add(newItem); ph.addToLocalInventory(selectedMed!); }
                      selectedMed = null; editingIndex = null; search = "";
                    });
                  },
                  onCancel: () => setState(() { selectedMed = null; editingIndex = null; }),
                ),
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Qty: ${item.qty.toInt()} | Rate: ${item.rate} | GST: ${item.gstRate}%"),
                      trailing: Text("₹${item.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      onTap: () => setState(() { selectedMed = ph.medicines.firstWhere((m) => m.id == item.medicineID); editingIndex = index; }),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Items: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              )
            ],
          ),
          if (search.isNotEmpty && selectedMed == null)
            Positioned(
              top: 70, left: 10, right: 10,
              child: Material(
                elevation: 5,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ListView(
                    shrinkWrap: true,
                    children: ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
                        .map((m) => ListTile(title: Text(m.name), subtitle: Text("Stock: ${m.stock}"), onTap: () => setState(() { selectedMed = m; search = ""; }))).toList(),
                  ),
                ),
              ),
            )
        ],
      ),
    );
  }

  void _saveAndClose(PharoahManager ph) async {
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    await SaleBillNumber.increment();
    Navigator.pop(context);
  }

  void _saveAndPrint(PharoahManager ph) async {
    final sale = Sale(id: DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, items: items, totalAmount: grandTotal, paymentMode: widget.mode);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    await SaleBillNumber.increment();
    await PdfService.generateInvoice(sale, widget.party);
    Navigator.pop(context);
  }
}

class ItemEntryForm extends StatefulWidget {
  final Medicine med; final int srNo; final BillItem? existingItem; final Function(BillItem) onAdd; final VoidCallback onCancel;
  const ItemEntryForm({super.key, required this.med, required this.srNo, this.existingItem, required this.onAdd, required this.onCancel});
  @override
  State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final batchC = TextEditingController(); final expC = TextEditingController(); final mrpC = TextEditingController();
  final rateC = TextEditingController(); final qtyC = TextEditingController(); final discC = TextEditingController();
  String rateType = "A";

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      batchC.text = widget.existingItem!.batch; expC.text = widget.existingItem!.exp;
      mrpC.text = widget.existingItem!.mrp.toString(); rateC.text = widget.existingItem!.rate.toString();
      qtyC.text = widget.existingItem!.qty.toString(); discC.text = widget.existingItem!.discount.toString();
    } else {
      mrpC.text = widget.med.mrp.toString(); rateC.text = widget.med.rateA.toString(); qtyC.text = "1"; discC.text = "0";
    }
  }

  void _updateRate() {
    double mrp = double.tryParse(mrpC.text) ?? 0;
    double gst = widget.med.gst;
    if (rateType == "A") rateC.text = widget.med.rateA.toString();
    if (rateType == "B") rateC.text = widget.med.rateB.toString();
    if (rateType == "C") {
      double base = (mrp / (1 + (gst / 100)));
      rateC.text = base.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.blue[50],
      child: Column(
        children: [
          Row(children: [Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
          Row(children: [Expanded(child: TextField(controller: batchC, decoration: const InputDecoration(labelText: "Batch"))), const SizedBox(width: 10), Expanded(child: TextField(controller: expC, decoration: const InputDecoration(labelText: "Exp")))]),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [ButtonSegment(value: 'A', label: Text('Rate A')), ButtonSegment(value: 'B', label: Text('Rate B')), ButtonSegment(value: 'C', label: Text('Rate C'))],
            selected: {rateType},
            onSelectionChanged: (val) { setState(() => rateType = val.first); _updateRate(); },
          ),
          Row(children: [
            Expanded(child: TextField(controller: mrpC, decoration: const InputDecoration(labelText: "MRP"), keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: rateC, decoration: const InputDecoration(labelText: "Rate"), keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: qtyC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.blue),
            onPressed: () {
              double r = double.tryParse(rateC.text) ?? 0; double q = double.tryParse(qtyC.text) ?? 0; double d = double.tryParse(discC.text) ?? 0;
              double taxable = (r * q) - d; double gstAmt = taxable * (widget.med.gst / 100);
              widget.onAdd(BillItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: batchC.text.toUpperCase(), exp: expC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mrpC.text) ?? 0, qty: q, rate: r, discount: d, gstRate: widget.med.gst, cgst: gstAmt/2, sgst: gstAmt/2, total: taxable + gstAmt));
            },
            child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
// ... inside ItemEntryForm State ...
var matchingBatches = ph.batchHistory[widget.med.id] ?? [];

// UI code to show matching batches
if (matchingBatches.isNotEmpty)
  SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: matchingBatches.map((b) => 
    ActionChip(label: Text(b.batch), onTap: () {
      setState(() { batchC.text = b.batch; expC.text = b.exp; mrpC.text = b.mrp.toString(); rateC.text = b.rate.toString(); });
    })).toList()
  )),
