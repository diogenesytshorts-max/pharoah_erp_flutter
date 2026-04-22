import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_bill_number.dart';
import 'pdf/sale_invoice_pdf.dart';

class BillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;
  final List<BillItem>? existingItems;
  final String? modifySaleId;

  const BillingView({super.key, required this.party, required this.billNo, required this.billDate, required this.mode, this.existingItems, this.modifySaleId});

  @override State<BillingView> createState() => _BillingViewState();
}

class _BillingViewState extends State<BillingView> {
  List<BillItem> items = [];
  double discountInput = 0.0;
  final discC = TextEditingController(text: "0");

  double get grossTotal => items.fold(0, (sum, item) => sum + (item.rate * item.qty));
  double get totalTax => items.fold(0, (sum, item) => sum + (item.cgst + item.sgst + item.igst));
  double get netTotal => (grossTotal - discountInput) + totalTax;

  @override void initState() {
    super.initState();
    if (widget.existingItems != null) items = List.from(widget.existingItems!);
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text("Bill: ${widget.billNo}"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: items.isEmpty ? null : () => _printBill()),
          IconButton(icon: const Icon(Icons.save), onPressed: items.isEmpty ? null : () => _saveAndClose(ph)),
        ],
      ),
      body: Column(children: [
        // PARTY HEADER
        Container(padding: const EdgeInsets.all(15), color: Colors.blue.shade900, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(widget.party.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          Text("Bal: ${widget.party.opBal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold))
        ])),
        
        // ITEM LIST
        Expanded(child: ListView.builder(itemCount: items.length, itemBuilder: (c, i) {
          final it = items[i];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(
            title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Batch: ${it.batch} | Exp: ${it.exp} | Qty: ${it.qty} | Rate: ${it.rate}"),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.delete, color: Colors.red, size: 20), onPressed: () => setState(() => items.removeAt(i)))
            ])
          ));
        })),

        // FOOTER PANEL
        Container(padding: const EdgeInsets.all(15), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Gross Total:"), Text("₹${grossTotal.toStringAsFixed(2)}")],),
          Row(children: [const Expanded(child: Text("Discount (₹):")), SizedBox(width: 100, child: TextField(controller: discC, keyboardType: TextInputType.number, onChanged: (v) => setState(() => discountInput = double.tryParse(v) ?? 0), decoration: const InputDecoration(isDense: true, border: OutlineInputBorder())))]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("NET AMOUNT:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)), Text("₹${netTotal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blue))]),
        ]))
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => _addItemDialog(ph), child: const Icon(Icons.add)),
    );
  }

  void _addItemDialog(PharoahManager ph) {
    Medicine? selected;
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Select Product"),
      content: SizedBox(width: 400, height: 300, child: ListView(children: ph.medicines.map((m) => ListTile(title: Text(m.name), onTap: () { selected = m; Navigator.pop(c); _itemEntryForm(ph, m); })).toList())),
    ));
  }

  void _itemEntryForm(PharoahManager ph, Medicine m) {
    final bC = TextEditingController(); final qC = TextEditingController(); final rC = TextEditingController(text: m.rateA.toString());
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Entry: ${m.name}"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: bC, decoration: const InputDecoration(labelText: "Batch")),
        TextField(controller: qC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number),
        TextField(controller: rC, decoration: const InputDecoration(labelText: "Rate"), keyboardType: TextInputType.number),
      ]),
      actions: [ElevatedButton(onPressed: () {
        double q = double.tryParse(qC.text) ?? 0; double r = double.tryParse(rC.text) ?? 0;
        setState(() => items.add(BillItem(id: DateTime.now().toString(), srNo: items.length + 1, medicineID: m.id, name: m.name, packing: m.packing, batch: bC.text, exp: "12/26", hsn: m.hsnCode, mrp: m.mrp, qty: q, rate: r, gstRate: m.gst, total: (q * r))));
        Navigator.pop(c);
      }, child: const Text("ADD"))],
    ));
  }

  void _saveAndClose(PharoahManager ph) async {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: netTotal, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _printBill() async {
    final sale = Sale(id: widget.modifySaleId ?? DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, partyGstin: widget.party.gst, partyState: widget.party.state, items: items, totalAmount: netTotal, paymentMode: widget.mode);
    await SaleInvoicePdf.generate(sale, widget.party);
  }
}
