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
  final discC = TextEditingController(text: "0");
  
  double get grossTotal => items.fold(0, (sum, i) => sum + (i.rate * i.qty));
  double get totalTax => items.fold(0, (sum, i) => sum + i.cgst + i.sgst + i.igst);
  double get netTotal => (grossTotal - (double.tryParse(discC.text) ?? 0)) + totalTax;

  @override
  void initState() {
    super.initState();
    if (widget.existingItems != null) items = List.from(widget.existingItems!);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text("Invoice: ${widget.billNo}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: items.isEmpty ? null : () => _printBill()),
          IconButton(icon: const Icon(Icons.check_circle, size: 28), onPressed: items.isEmpty ? null : () => _saveAndClose(ph)),
        ],
      ),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              itemCount: items.length,
              itemBuilder: (c, i) => _buildItemCard(items[i], i),
            ),
          ),
          _buildFooter(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal.shade900,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("ADD ITEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () => _openAddDialog(ph),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(16),
    margin: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.teal.shade100),
      boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.05), blurRadius: 10)],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.party.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.teal)),
          Text("Balance: ₹${widget.party.opBal.toStringAsFixed(0)}", style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 12)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
          child: Text(DateFormat('dd MMM yyyy').format(widget.billDate), style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
        )
      ],
    ),
  );

  Widget _buildItemCard(BillItem it, int index) => Card(
    elevation: 1,
    margin: const EdgeInsets.only(bottom: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.teal.shade50)),
    child: ListTile(
      title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
      subtitle: Text("Batch: ${it.batch} | Exp: ${it.exp} | Qty: ${it.qty.toInt()} @ ₹${it.rate}", style: const TextStyle(fontSize: 12)),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text("₹${it.total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
        InkWell(onTap: () => setState(() => items.removeAt(index)), child: const Icon(Icons.delete_forever, color: Colors.redAccent, size: 20)),
      ]),
    ),
  );

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
    ),
    child: Column(children: [
      _row("Gross Amount", "₹${grossTotal.toStringAsFixed(2)}"),
      const SizedBox(height: 5),
      Row(children: [
        const Text("Discount (₹): ", style: TextStyle(fontWeight: FontWeight.bold)), 
        SizedBox(width: 100, height: 35, child: TextField(controller: discC, keyboardType: TextInputType.number, decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10)))),
      ]),
      const SizedBox(height: 5),
      _row("GST Amount", "₹${totalTax.toStringAsFixed(2)}", color: Colors.teal),
      const Divider(height: 20),
      _row("NET TOTAL", "₹${netTotal.toStringAsFixed(2)}", bold: true, color: Colors.teal.shade900, size: 22),
    ]),
  );

  Widget _row(String l, String v, {bool bold = false, Color? color, double size = 15}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.w500)), Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, color: color, fontSize: size))]);

  void _openAddDialog(PharoahManager ph) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Search Product"),
      content: SizedBox(width: 400, height: 300, child: ListView(children: ph.medicines.map((m) => ListTile(
        title: Text(m.name), subtitle: Text("Stock: ${m.stock}"),
        onTap: () { Navigator.pop(c); _entryForm(ph, m); }
      )).toList())),
    ));
  }

  void _entryForm(PharoahManager ph, Medicine m) {
    final bC = TextEditingController(); final qC = TextEditingController(); final rC = TextEditingController(text: m.rateA.toString());
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Add ${m.name}"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        if(ph.batchHistory[m.identityKey] != null) Wrap(children: ph.batchHistory[m.identityKey]!.map((b) => ActionChip(label: Text(b.batch), onPressed: () { bC.text = b.batch; rC.text = b.rate.toString(); })).toList()),
        TextField(controller: bC, decoration: const InputDecoration(labelText: "Batch")),
        TextField(controller: qC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number),
        TextField(controller: rC, decoration: const InputDecoration(labelText: "Rate"), keyboardType: TextInputType.number),
      ]),
      actions: [ElevatedButton(onPressed: () {
        double q = double.tryParse(qC.text) ?? 0; double r = double.tryParse(rC.text) ?? 0;
        setState(() => items.add(BillItem(id: DateTime.now().toString(), srNo: items.length + 1, medicineID: m.id, name: m.name, packing: m.packing, batch: bC.text, exp: "12/26", hsn: m.hsnCode, mrp: m.mrp, qty: q, rate: r, gstRate: m.gst, total: (q * r))));
        ph.saveBatchCentrally(m, BatchInfo(batch: bC.text, exp: "12/26", packing: m.packing, mrp: m.mrp, rate: r));
        Navigator.pop(c);
      }, child: const Text("Confirm"))],
    ));
  }

  void _saveAndClose(PharoahManager ph) {
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: netTotal, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _printBill() async {
    final sale = Sale(id: widget.modifySaleId ?? DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, partyGstin: widget.party.gst, partyState: widget.party.state, items: items, totalAmount: netTotal, paymentMode: widget.mode);
    await SaleInvoicePdf.generate(sale, widget.party);
  }
}
