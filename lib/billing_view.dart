import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;

  const BillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
  });

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.party.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text("${widget.billNo} | ${widget.mode}", style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: items.isEmpty ? null : () => _saveBill(ph),
            child: const Text("SAVE BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- SEARCH BAR ---
              if (editingIndex == null)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search Medicine...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (val) => setState(() => search = val),
                  ),
                ),

              // --- ITEM ENTRY FORM (Jab select ho jaye) ---
              if (selectedMed != null)
                ItemEntryForm(
                  med: selectedMed!,
                  srNo: editingIndex ?? items.length + 1,
                  existingItem: editingIndex != null ? items[editingIndex!] : null,
                  onAdd: (newItem) {
                    setState(() {
                      if (editingIndex != null) {
                        items[editingIndex!] = newItem;
                      } else {
                        items.add(newItem);
                        ph.addToLocalInventory(selectedMed!);
                      }
                      selectedMed = null;
                      editingIndex = null;
                      search = "";
                    });
                  },
                  onCancel: () => setState(() {
                    selectedMed = null;
                    editingIndex = null;
                  }),
                ),

              // --- BILLING LIST ---
              Expanded(
                child: ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      dense: true,
                      title: Text("${index + 1}. ${item.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Qty: ${item.qty.toInt()} | Batch: ${item.batch} | MRP: ${item.mrp}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("₹${item.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          IconButton(
                            icon: const Icon(Icons.edit, size: 18, color: Colors.blue),
                            onPressed: () => _startEditing(index, ph),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // --- FOOTER ---
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2))],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Items: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("GRAND TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),

          // --- SEARCH SUGGESTIONS OVERLAY ---
          if (search.isNotEmpty && selectedMed == null)
            Positioned(
              top: 60, left: 10, right: 10,
              child: Material(
                elevation: 10,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    shrinkWrap: true,
                    children: ph.medicines
                        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
                        .map((m) => ListTile(
                              title: Text(m.name),
                              subtitle: Text(m.manufacturer),
                              onTap: () => setState(() {
                                selectedMed = m;
                                search = "";
                              }),
                            ))
                        .toList(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _startEditing(int index, PharoahManager ph) {
    final item = items[index];
    final med = ph.medicines.firstWhere((m) => m.id == item.medicineID);
    setState(() {
      selectedMed = med;
      editingIndex = index;
    });
  }

  void _saveBill(PharoahManager ph) async {
    ph.finalizeSale(
      billNo: widget.billNo,
      date: widget.billDate,
      party: widget.party,
      items: items,
      total: grandTotal,
      mode: widget.mode,
    );
    await SaleBillNumber.increment();
    if (mounted) Navigator.pop(context);
  }
}

// =====================================================================
// --- SUB-WIDGET: ITEM ENTRY FORM ---
// =====================================================================
class ItemEntryForm extends StatefulWidget {
  final Medicine med;
  final int srNo;
  final BillItem? existingItem;
  final Function(BillItem) onAdd;
  final VoidCallback onCancel;

  const ItemEntryForm({
    super.key,
    required this.med,
    required this.srNo,
    this.existingItem,
    required this.onAdd,
    required this.onCancel,
  });

  @override
  State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final batchC = TextEditingController();
  final expC = TextEditingController();
  final mrpC = TextEditingController();
  final rateC = TextEditingController();
  final qtyC = TextEditingController();
  final discC = TextEditingController();
  String rateType = "A";

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      batchC.text = widget.existingItem!.batch;
      expC.text = widget.existingItem!.exp;
      mrpC.text = widget.existingItem!.mrp.toString();
      rateC.text = widget.existingItem!.rate.toString();
      qtyC.text = widget.existingItem!.qty.toString();
      discC.text = widget.existingItem!.discount.toString();
    } else {
      mrpC.text = widget.med.mrp.toString();
      rateC.text = widget.med.rateA.toString();
      qtyC.text = "1";
      discC.text = "0";
    }
  }

  void _updateRate() {
    if (rateType == "A") rateC.text = widget.med.rateA.toString();
    if (rateType == "B") rateC.text = widget.med.rateB.toString();
    // Rate C Formula (Custom Logic)
    if (rateType == "C") {
      double mrp = double.tryParse(mrpC.text) ?? 0;
      double gst = widget.med.gst;
      double base = (mrp / (1 + gst / 100));
      rateC.text = base.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel),
            ],
          ),
          Row(
            children: [
              Expanded(child: TextField(controller: batchC, decoration: const InputDecoration(labelText: "Batch"))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: expC, decoration: const InputDecoration(labelText: "Exp (MM/YY)"))),
            ],
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'A', label: Text('Rate A')),
              ButtonSegment(value: 'B', label: Text('Rate B')),
              ButtonSegment(value: 'C', label: Text('Rate C')),
            ],
            selected: {rateType},
            onSelectionChanged: (val) {
              setState(() => rateType = val.first);
              _updateRate();
            },
          ),
          Row(
            children: [
              Expanded(child: TextField(controller: mrpC, decoration: const InputDecoration(labelText: "MRP"), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: rateC, decoration: const InputDecoration(labelText: "Rate"), keyboardType: TextInputType.number)),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: qtyC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number)),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 45), backgroundColor: Colors.green),
            onPressed: () {
              double r = double.tryParse(rateC.text) ?? 0;
              double q = double.tryParse(qtyC.text) ?? 0;
              double d = double.tryParse(discC.text) ?? 0;
              double total = (r * q) - d;

              widget.onAdd(BillItem(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                srNo: widget.srNo,
                medicineID: widget.med.id,
                name: widget.med.name,
                packing: widget.med.packing,
                batch: batchC.text.toUpperCase(),
                exp: expC.text,
                hsn: widget.med.hsnCode,
                mrp: double.tryParse(mrpC.text) ?? 0,
                qty: q,
                rate: r,
                discount: d,
                gstRate: widget.med.gst,
                cgst: 0, sgst: 0, total: total,
              ));
            },
            child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
// --- Rate C Formula Logic Update ---
void _updateRate() {
  double mrp = double.tryParse(mrpC.text) ?? 0;
  double gst = widget.med.gst;
  if (rateType == "A") rateC.text = widget.med.rateA.toString();
  if (rateType == "B") rateC.text = widget.med.rateB.toString();
  if (rateType == "C") {
    // Formula: Rate = MRP / (1 + GST/100)
    double base = (mrp / (1 + (gst / 100)));
    rateC.text = base.toStringAsFixed(2);
  }
}

// --- Total Calculation including GST ---
onPressed: () {
  double r = double.tryParse(rateC.text) ?? 0;
  double q = double.tryParse(qtyC.text) ?? 0;
  double d = double.tryParse(discC.text) ?? 0;
  double gstRate = widget.med.gst;

  double taxable = (r * q) - d;
  double gstAmt = taxable * (gstRate / 100);
  double total = taxable + gstAmt;

  widget.onAdd(BillItem(
    // ... other fields ...
    gstRate: gstRate,
    cgst: gstAmt / 2,
    sgst: gstAmt / 2,
    total: total,
  ));
}
