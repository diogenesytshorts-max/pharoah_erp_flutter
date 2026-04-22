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
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text("Invoice: ${widget.billNo}", style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: items.isEmpty ? null : () => _printBill()),
          TextButton(
            onPressed: items.isEmpty ? null : () => _handleSave(ph),
            child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: items.length,
            itemBuilder: (c, i) => _buildItemCard(items[i], i),
          ),
        ),
        _buildFooter(),
      ]),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal.shade700,
        onPressed: () => _openAddDialog(ph),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(15),
    margin: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(widget.party.name, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal.shade800)),
      Text(DateFormat('dd/MM/yyyy').format(widget.billDate), style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  Widget _buildItemCard(BillItem it, int index) => Card(
    child: ListTile(
      title: Text(it.name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
      subtitle: Text("Batch: ${it.batch} | Qty: ${it.qty.toInt()} | Rate: ₹${it.rate}"),
      trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => items.removeAt(index))),
    ),
  );

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.all(20),
    color: Colors.white,
    child: Column(children: [
      _row("Gross Amount", "₹${totalAmt.toStringAsFixed(2)}"),
      const Divider(),
      _row("NET TOTAL", "₹${totalAmt.toStringAsFixed(2)}", bold: true, size: 20, color: Colors.teal.shade900),
    ]),
  );

  Widget _row(String l, String v, {bool bold = false, double size = 15, Color? color}) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)), Text(v, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: size, color: color))]);

  void _openAddDialog(PharoahManager ph) {
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Select Product"),
      content: SizedBox(width: 400, height: 300, child: ListView(children: ph.medicines.map((m) => ListTile(
        title: Text(m.name),
        onTap: () { Navigator.pop(c); _entryForm(ph, m); }
      )).toList())),
    ));
  }

  void _entryForm(PharoahManager ph, Medicine m) {
    final bC = TextEditingController(); final qC = TextEditingController(); final rC = TextEditingController(text: m.rateA.toString());
    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text("Add ${m.name}"),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: bC, decoration: const InputDecoration(labelText: "Batch")),
        TextField(controller: qC, decoration: const InputDecoration(labelText: "Qty"), keyboardType: TextInputType.number),
        TextField(controller: rC, decoration: const InputDecoration(labelText: "Rate"), keyboardType: TextInputType.number),
      ]),
      actions: [ElevatedButton(onPressed: () {
        double q = double.tryParse(qC.text) ?? 0; double r = double.tryParse(rC.text) ?? 0;
        double tax = (q * r) * (m.gst / 100);
        setState(() => items.add(BillItem(id: DateTime.now().toString(), srNo: items.length + 1, medicineID: m.id, name: m.name, packing: m.packing, batch: bC.text, exp: "12/26", hsn: m.hsnCode, mrp: m.mrp, qty: q, rate: r, gstRate: m.gst, total: (q * r) + tax, cgst: tax/2, sgst: tax/2)));
        Navigator.pop(c);
      }, child: const Text("Confirm"))],
    ));
  }

  void _handleSave(PharoahManager ph) {
    if (widget.modifySaleId != null) ph.deleteBill(widget.modifySaleId!);
    ph.finalizeSale(billNo: widget.billNo, date: widget.billDate, party: widget.party, items: items, total: totalAmt, mode: widget.mode);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _printBill() async {
    final sale = Sale(id: widget.modifySaleId ?? DateTime.now().toString(), billNo: widget.billNo, date: widget.billDate, partyName: widget.party.name, partyGstin: widget.party.gst, partyState: widget.party.state, items: items, totalAmount: totalAmt, paymentMode: widget.mode);
    await SaleInvoicePdf.generate(sale, widget.party);
  }
}
