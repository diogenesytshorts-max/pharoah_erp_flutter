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
  final List<BillItem>? existingItems;
  final String? modifySaleId;
  final bool isReadOnly;

  const BillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
    this.existingItems,
    this.modifySaleId,
    this.isReadOnly = false,
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
  double get totalGst => items.fold(0, (sum, item) => sum + (item.cgst + item.sgst));
  double get totalTaxable => items.fold(0, (sum, item) => sum + (item.total - (item.cgst + item.sgst)));

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) {
      items = List.from(widget.existingItems!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 2,
        backgroundColor: widget.isReadOnly ? Colors.purple : Colors.blue,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.party.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("${widget.billNo} | ${widget.mode}", style: const TextStyle(fontSize: 10)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: items.isEmpty ? null : () => _saveAndPrint(ph),
          ),
          if (!widget.isReadOnly)
            TextButton(
              onPressed: items.isEmpty ? null : () => _saveAndClose(ph),
              child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (selectedMed == null && !widget.isReadOnly)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.grey[100],
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search Medicine Name...",
                      prefixIcon: const Icon(Icons.search, color: Colors.blue),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ),
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
                      if (editingIndex != null) {
                        items[editingIndex!] = newItem;
                      } else {
                        items.add(newItem);
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

              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (c, i) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Qty: ${item.qty.toInt()} | B: ${item.batch} | MRP: ${item.mrp}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("₹${item.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          if (!widget.isReadOnly)
                            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => items.removeAt(index))),
                        ],
                      ),
                      onTap: widget.isReadOnly ? null : () => setState(() {
                        selectedMed = ph.medicines.firstWhere((m) => m.id == item.medicineID);
                        editingIndex = index;
                      }),
                    );
                  },
                ),
              ),

              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("ITEMS: ${items.length}"),
                    Text("TOTAL: ₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
                  ],
                ),
              ),
            ],
          ),

          if (search.isNotEmpty && selectedMed == null)
            Positioned(
              top: 70, left: 15, right: 15,
              child: Material(
                elevation: 10,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView(
                    shrinkWrap: true,
                    children: ph.medicines
                        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
                        .map((m) => ListTile(
                              title: Text(m.name),
                              subtitle: Text("Pack: ${m.packing} | Stock: ${m.stock}"),
                              onTap: () => setState(() { selectedMed = m; search = ""; }),
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

  void _saveAndClose(PharoahManager ph) async {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    
    // Agar gap wala bill tha toh counter nahi badhega, naya bill tha toh badhega
    if (widget.modifySaleId == null) await SaleBillNumber.incrementIfNecessary(widget.billNo);
    
    if (mounted) Navigator.pop(context);
  }

  void _saveAndPrint(PharoahManager ph) async {
    final sale = Sale(id: DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, items: items, totalAmount: grandTotal, paymentMode: widget.mode);
    if (!widget.isReadOnly) {
      if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
      ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
      if (widget.modifySaleId == null) await SaleBillNumber.incrementIfNecessary(widget.billNo);
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
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController();
  final mC = TextEditingController(); final rC = TextEditingController(); final qC = TextEditingController();
  final dpC = TextEditingController(text: "0"); final drC = TextEditingController(text: "0");

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      bC.text = widget.existingItem!.batch; eC.text = widget.existingItem!.exp;
      gC.text = widget.existingItem!.gstRate.toString(); mC.text = widget.existingItem!.mrp.toString();
      rC.text = widget.existingItem!.rate.toString(); qC.text = widget.existingItem!.qty.toString();
      dpC.text = widget.existingItem!.discountPercent.toString(); drC.text = widget.existingItem!.discountRupees.toString();
    } else {
      mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString();
      rC.text = widget.med.rateA.toString(); qC.text = "1";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.blue[50],
      child: Column(
        children: [
          Row(children: [Text(widget.med.name, style: const TextStyle(fontWeight: FontWeight.bold)), const Spacer(), IconButton(icon: const Icon(Icons.close), onPressed: widget.onCancel)]),
          Row(children: [
            Expanded(child: TextField(controller: bC, decoration: const InputDecoration(labelText: "Batch"))),
            Expanded(child: TextField(controller: eC, decoration: const InputDecoration(labelText: "Exp"))),
            Expanded(child: TextField(controller: qC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number)),
          ]),
          Row(children: [
            Expanded(child: TextField(controller: rC, decoration: const InputDecoration(labelText: "Rate"), keyboardType: TextInputType.number)),
            Expanded(child: TextField(controller: dpC, decoration: const InputDecoration(labelText: "Disc %"), keyboardType: TextInputType.number)),
            Expanded(child: TextField(controller: drC, decoration: const InputDecoration(labelText: "Disc ₹"), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () {
            double r = double.tryParse(rC.text) ?? 0; double q = double.tryParse(qC.text) ?? 0;
            double dp = double.tryParse(dpC.text) ?? 0; double dr = double.tryParse(drC.text) ?? 0;
            double g = double.tryParse(gC.text) ?? 0;
            double taxable = (r * q) - ((r * q) * dp / 100) - dr;
            double gst = taxable * g / 100;
            widget.onAdd(BillItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text.toUpperCase(), exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, qty: q, rate: r, discountPercent: dp, discountRupees: dr, gstRate: g, cgst: gst/2, sgst: gst/2, total: taxable + gst));
          }, child: const Text("ADD TO BILL"))
        ],
      ),
    );
  }
}
