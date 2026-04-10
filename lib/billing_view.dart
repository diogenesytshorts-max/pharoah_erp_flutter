import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf_service.dart';

// --- CUSTOM FORMATTER FOR AUTO SLASH MM/YY ---
class ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    if (newValue.selection.baseOffset < oldValue.selection.baseOffset) return newValue;
    if (text.length == 2 && !text.contains('/')) {
      return TextEditingValue(
        text: '$text/',
        selection: TextSelection.collapsed(offset: 3),
      );
    }
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
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.blue.shade700, foregroundColor: Colors.white, title: Text(widget.party.name),
        actions: [
          IconButton(icon: const Icon(Icons.print_rounded), onPressed: items.isEmpty ? null : () => _saveAndPrint(ph)),
          if (!widget.isReadOnly) TextButton(onPressed: items.isEmpty ? null : () => _saveAndClose(ph), child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ],
      ),
      body: Stack(children: [
        Column(children: [
          if (selectedMed == null && !widget.isReadOnly)
            Padding(padding: const EdgeInsets.all(12), child: TextField(autofocus: true, decoration: const InputDecoration(hintText: "Search Product...", prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => search = v))),
          if (selectedMed != null)
            ItemEntryForm(
              med: selectedMed!, partyState: widget.party.state, shopState: ph.companyState, srNo: editingIndex ?? items.length + 1,
              existingItem: editingIndex != null ? items[editingIndex!] : null, batchHistory: ph.batchHistory[selectedMed!.id] ?? [],
              onAdd: (newItem) { setState(() { if (editingIndex != null) items[editingIndex!] = newItem; else items.add(newItem); selectedMed = null; editingIndex = null; search = ""; }); },
              onCancel: () => setState(() { selectedMed = null; editingIndex = null; }),
            ),
          Expanded(child: ListView.separated(itemCount: items.length, separatorBuilder: (c, i) => const Divider(), itemBuilder: (c, i) => ListTile(title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("Qty: ${items[i].qty.toInt()} | Batch: ${items[i].batch} | Exp: ${items[i].exp}"), trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), onTap: widget.isReadOnly ? null : () => setState(() { selectedMed = ph.medicines.firstWhere((m) => m.id == items[i].medicineID); editingIndex = i; })))),
          Container(padding: const EdgeInsets.all(15), color: Colors.blue.shade50, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold)), Text("₹${grandTotal.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.blue))])),
        ]),
        if (search.isNotEmpty && selectedMed == null)
          Positioned(top: 70, left: 15, right: 15, child: Material(elevation: 10, child: Container(constraints: const BoxConstraints(maxHeight: 250), child: ListView(shrinkWrap: true, children: ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase())).map((m) => ListTile(title: Text(m.name), subtitle: Text("Stock: ${m.stock}"), onTap: () => setState(() { selectedMed = m; search = ""; }))).toList()))))
      ]),
    );
  }

  void _saveAndClose(PharoahManager ph) async {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    if (widget.modifySaleId == null) await SaleBillNumber.incrementIfNecessary(widget.billNo);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Sale Invoice Saved!"), backgroundColor: Colors.green));
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _saveAndPrint(PharoahManager ph) async {
    final sale = Sale(id: DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, items: items, totalAmount: grandTotal, paymentMode: widget.mode);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: grandTotal, mode: widget.mode);
    await PdfService.generateInvoice(sale, widget.party);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

class ItemEntryForm extends StatefulWidget {
  final Medicine med; final String partyState, shopState; final int srNo; final BillItem? existingItem; final List<BatchInfo> batchHistory; final Function(BillItem) onAdd; final VoidCallback onCancel;
  const ItemEntryForm({super.key, required this.med, required this.partyState, required this.shopState, required this.srNo, this.existingItem, required this.batchHistory, required this.onAdd, required this.onCancel});
  @override State<ItemEntryForm> createState() => _ItemEntryFormState();
}

class _ItemEntryFormState extends State<ItemEntryForm> {
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController();
  final mC = TextEditingController(); final rC = TextEditingController(); final qC = TextEditingController();
  String? originalExp;

  @override void initState() {
    super.initState();
    mC.text = widget.med.mrp.toString(); gC.text = widget.med.gst.toString(); rC.text = widget.med.rateA.toString(); qC.text = "1";
    if (widget.existingItem != null) { bC.text = widget.existingItem!.batch; eC.text = widget.existingItem!.exp; originalExp = widget.existingItem!.exp; }
  }

  @override Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue.shade50, border: const Border(bottom: BorderSide(color: Colors.blue, width: 2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.blue))), IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: widget.onCancel)]),
      if (widget.batchHistory.isNotEmpty) ...[
        const Text("Purane Batches:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, children: widget.batchHistory.map((b) => Padding(padding: const EdgeInsets.only(right: 8), child: ActionChip(label: Text("${b.batch} (${b.exp})"), onPressed: () { setState(() { bC.text = b.batch; eC.text = b.exp; mC.text = b.mrp.toString(); rC.text = b.rate.toString(); originalExp = b.exp; }); }))).toList())),
      ],
      Row(children: [Expanded(child: _f(bC, "Batch")), const SizedBox(width: 5), Expanded(child: _f(eC, "Exp", fmt: [ExpiryDateFormatter()])), const SizedBox(width: 5), Expanded(child: _f(gC, "GST%"))]),
      const SizedBox(height: 10),
      Row(children: [Expanded(child: _f(mC, "MRP")), const SizedBox(width: 5), Expanded(child: _f(rC, "Rate")), const SizedBox(width: 5), Expanded(child: _f(qC, "Qty"))]),
      const SizedBox(height: 15),
      ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue.shade700), onPressed: () async {
        if (originalExp != null && originalExp != eC.text) {
          bool confirm = await showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Update Expiry?"), content: const Text("Aap purane batch ki expiry badal rahe hain. Sure?"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("NO")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("YES"))])) ?? false;
          if (!confirm) return;
        }
        double r = double.tryParse(rC.text) ?? 0, q = double.tryParse(qC.text) ?? 0, g = double.tryParse(gC.text) ?? 0, tax = r * q, gstAmt = tax * (g / 100);
        double cgst = 0, sgst = 0, igst = 0; if (widget.partyState == widget.shopState) { cgst = gstAmt/2; sgst = gstAmt/2; } else { igst = gstAmt; }
        widget.onAdd(BillItem(id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, name: widget.med.name, packing: widget.med.packing, batch: bC.text.toUpperCase(), exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, qty: q, rate: r, gstRate: g, cgst: cgst, sgst: sgst, igst: igst, total: tax + gstAmt));
      }, child: const Text("ADD TO BILL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
    ]));
  }
  Widget _f(TextEditingController c, String l, {List<TextInputFormatter>? fmt}) => TextField(controller: c, inputFormatters: fmt, decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(10)), keyboardType: TextInputType.text);
}
