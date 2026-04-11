import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pharoah_manager.dart';
import '../models.dart';

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

class PurchaseBillingView extends StatefulWidget {
  final Party distributor; 
  final String internalNo, distBillNo; 
  final DateTime billDate; 
  final String mode;

  const PurchaseBillingView({super.key, required this.distributor, required this.internalNo, required this.distBillNo, required this.billDate, required this.mode});

  @override State<PurchaseBillingView> createState() => _PurchaseBillingViewState();
}

class _PurchaseBillingViewState extends State<PurchaseBillingView> {
  List<PurchaseItem> items = []; 
  String searchQuery = ""; 
  Medicine? selectedMed;

  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white,
        title: Text(widget.distributor.name, style: const TextStyle(fontSize: 14)),
        actions: [
          TextButton(
            onPressed: items.isEmpty ? null : () => _handleSave(ph), 
            child: const Text("SAVE PURCHASE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      ),
      body: Column(
        children: [
          if (selectedMed == null)
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(hintText: "Search Product for Stock-In...", prefixIcon: Icon(Icons.search, color: Colors.orange), border: OutlineInputBorder()),
                onChanged: (v) => setState(() => searchQuery = v),
              ),
            ),
          if (selectedMed != null)
            PurchaseItemEntryForm(
              med: selectedMed!, 
              srNo: items.length + 1,
              batchHistory: ph.batchHistory[selectedMed!.id] ?? [],
              onAdd: (newItem) { 
                setState(() { 
                  items.add(newItem); 
                  selectedMed = null; 
                  searchQuery = ""; 
                }); 
              },
              onCancel: () => setState(() => selectedMed = null),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) => ListTile(
                title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Qty: ${items[i].qty} + ${items[i].freeQty} | Batch: ${items[i].batch}"),
                trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSave(PharoahManager ph) async {
    ph.finalizePurchase(internalNo: widget.internalNo, billNo: widget.distBillNo, date: widget.billDate, party: widget.distributor, items: items, total: totalAmt, mode: widget.mode);
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastPurID') ?? 0;
    await prefs.setInt('lastPurID', lastId + 1);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Purchase Entry Saved & Stock Updated!"), backgroundColor: Colors.orange));
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

class PurchaseItemEntryForm extends StatefulWidget {
  final Medicine med; final int srNo; final List<BatchInfo> batchHistory; final Function(PurchaseItem) onAdd; final VoidCallback onCancel;
  const PurchaseItemEntryForm({super.key, required this.med, required this.srNo, required this.batchHistory, required this.onAdd, required this.onCancel});
  @override State<PurchaseItemEntryForm> createState() => _PurchaseItemEntryFormState();
}

class _PurchaseItemEntryFormState extends State<PurchaseItemEntryForm> {
  final bC = TextEditingController(); final eC = TextEditingController(); final gC = TextEditingController();
  final mC = TextEditingController(); final pRC = TextEditingController(); final qC = TextEditingController(text: "1");
  final fC = TextEditingController(text: "0");
  final rAC = TextEditingController(); final rBC = TextEditingController(); final rCC = TextEditingController();
  final rCD = TextEditingController(text: "0"); // Rate C Discount %

  @override void initState() {
    super.initState();
    mC.text = widget.med.mrp.toString(); 
    gC.text = widget.med.gst.toString(); 
    pRC.text = widget.med.purRate.toString();
    rAC.text = widget.med.rateA.toString(); 
    rBC.text = widget.med.rateB.toString(); 
    _calcRateC();
  }

  void _calcRateC() {
    double mrp = double.tryParse(mC.text) ?? 0;
    double gst = double.tryParse(gC.text) ?? 0;
    double disc = double.tryParse(rCD.text) ?? 0;
    double taxable = mrp / (1 + (gst / 100));
    rCC.text = (taxable - (taxable * disc / 100)).toStringAsFixed(2);
  }

  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15), color: Colors.orange.shade50,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange))),
            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: widget.onCancel)
          ]),
          
          Row(children: [
            Expanded(child: _field(bC, "Batch")),
            const SizedBox(width: 5),
            Expanded(child: _field(eC, "Exp (MM/YY)", fmt: [ExpiryDateFormatter()])),
            const SizedBox(width: 5),
            Expanded(child: _field(gC, "GST%", onCh: (v) => _calcRateC())),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _field(mC, "MRP", onCh: (v) => _calcRateC())),
            const SizedBox(width: 5),
            Expanded(child: _field(pRC, "Pur Rate")),
            const SizedBox(width: 5),
            Expanded(child: _field(qC, "Qty")),
            const SizedBox(width: 5),
            Expanded(child: _field(fC, "Free")),
          ]),
          const SizedBox(height: 15),
          const Text("SET SELLING RATES FOR MASTER:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          const SizedBox(height: 5),
          Row(children: [
            Expanded(child: _field(rAC, "Rate A")),
            const SizedBox(width: 5),
            Expanded(child: _field(rBC, "Rate B")),
            const SizedBox(width: 5),
            Expanded(child: _field(rCD, "RC Disc%", onCh: (v) => _calcRateC())),
            const SizedBox(width: 5),
            Expanded(child: _field(rCC, "Rate C", en: false)),
          ]),
          const SizedBox(height: 15),
          ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.orange.shade800),
            onPressed: () {
              double pr = double.tryParse(pRC.text) ?? 0; 
              double qt = double.tryParse(qC.text) ?? 0;
              double gst = double.tryParse(gC.text) ?? 0;
              
              widget.onAdd(PurchaseItem(
                id: DateTime.now().toString(), srNo: widget.srNo, medicineID: widget.med.id, 
                name: widget.med.name, packing: widget.med.packing, batch: bC.text.toUpperCase(), 
                exp: eC.text, hsn: widget.med.hsnCode, mrp: double.tryParse(mC.text) ?? 0, 
                qty: qt, freeQty: double.tryParse(fC.text) ?? 0, purchaseRate: pr, 
                gstRate: gst, total: (pr * qt) * (1 + gst/100),
                rateA: double.tryParse(rAC.text) ?? 0, 
                rateB: double.tryParse(rBC.text) ?? 0, 
                rateC: double.tryParse(rCC.text) ?? 0
              ));
            }, 
            child: const Text("ADD TO LIST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String l, {List<TextInputFormatter>? fmt, bool en = true, Function(String)? onCh}) {
    return TextField(
      controller: c, enabled: en, inputFormatters: fmt, onChanged: onCh,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      decoration: InputDecoration(labelText: l, border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(8)),
      keyboardType: TextInputType.text,
    );
  }
}
