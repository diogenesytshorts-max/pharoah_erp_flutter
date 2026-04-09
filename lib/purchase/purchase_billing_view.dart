import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pdf_service.dart';

class PurchaseBillingView extends StatefulWidget {
  final Party distributor; 
  final String internalNo; 
  final String distBillNo; 
  final DateTime billDate; 
  final String mode;

  const PurchaseBillingView({
    super.key, 
    required this.distributor, 
    required this.internalNo, 
    required this.distBillNo, 
    required this.billDate, 
    required this.mode
  });

  @override State<PurchaseBillingView> createState() => _PurchaseBillingViewState();
}

class _PurchaseBillingViewState extends State<PurchaseBillingView> {
  List<PurchaseItem> items = []; 
  String search = ""; 
  Medicine? selectedMed;
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange, 
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(widget.distributor.name, style: const TextStyle(fontSize: 14)), 
            Text("${widget.internalNo} | Bill: ${widget.distBillNo}", style: const TextStyle(fontSize: 10))
          ]
        ),
        actions: [
          IconButton(icon: const Icon(Icons.print), onPressed: items.isEmpty ? null : () => _save(ph, print: true)), 
          TextButton(onPressed: items.isEmpty ? null : () => _save(ph), child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))
        ]
      ),
      body: Stack(children: [
        Column(children: [
          if (selectedMed == null)
            Padding(
              padding: const EdgeInsets.all(10), 
              child: TextField(
                autofocus: true, 
                decoration: const InputDecoration(hintText: "Search Product to Stock-In...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), 
                onChanged: (v) => setState(() => search = v)
              )
            ),
          if (selectedMed != null)
            PurchaseItemEntryForm(
              med: selectedMed!, 
              srNo: items.length + 1,
              onAdd: (newItem) { 
                setState(() { 
                  items.add(newItem); 
                  selectedMed = null; 
                  search = ""; 
                }); 
              },
              onCancel: () => setState(() => selectedMed = null),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length, 
              itemBuilder: (c, i) => ListTile(
                title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Qty: ${items[i].qty.toInt()} + ${items[i].freeQty.toInt()} | Pur.Rate: ${items[i].purchaseRate} | MRP: ${items[i].mrp}"),
                trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              )
            )
          ),
          Container(
            padding: const EdgeInsets.all(15), 
            color: Colors.orange[50], 
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text("Items: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)), 
                Text("TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange))
              ]
            )
          )
        ]),
        
        // Search Suggestion Overlay
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
                            leading: const Icon(Icons.medication), 
                            title: Text(m.name), 
                            subtitle: Text("Pack: ${m.packing} | Stock: ${m.stock}"), 
                            onTap: () => setState(() { selectedMed = m; search = ""; })
                          ))
                      .toList()
                )
              )
            )
          )
      ]),
    );
  }

  void _save(PharoahManager ph, {bool print = false}) async {
    ph.finalizePurchase(
      internalNo: widget.internalNo, 
      billNo: widget.distBillNo, 
      date: widget.billDate, 
      party: widget.distributor, 
      items: items, 
      total: totalAmt, 
      mode: widget.mode
    );
    
    final p = await SharedPreferences.getInstance();
    int lastId = p.getInt('lastPurID') ?? 0;
    await p.setInt('lastPurID', lastId + 1);
    
    if (print) {
      final saleObj = Sale(
        id: DateTime.now().toString(), 
        billNo: widget.distBillNo, 
        date: widget.billDate, 
        partyName: widget.distributor.name, 
        items: items.map((e) => BillItem(
          id: e.id, srNo: e.srNo, medicineID: e.medicineID, name: e.name, packing: e.packing, 
          batch: e.batch, exp: e.exp, hsn: e.hsn, mrp: e.mrp, qty: e.qty, rate: e.purchaseRate, 
          gstRate: e.gstRate, cgst: 0, sgst: 0, total: e.total
        )).toList(), 
        totalAmount: totalAmt, 
        paymentMode: widget.mode
      );
      await PdfService.generateInvoice(saleObj, widget.distributor, isPurchase: true);
    }
    
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Bill Saved Successfully!")));
    }
  }
}

class PurchaseItemEntryForm extends StatefulWidget {
  final Medicine med; 
  final int srNo; 
  final Function(PurchaseItem) onAdd; 
  final VoidCallback onCancel;
  
  const PurchaseItemEntryForm({super.key, required this.med, required this.srNo, required this.onAdd, required this.onCancel});
  @override State<PurchaseItemEntryForm> createState() => _PurchaseItemEntryFormState();
}

class _PurchaseItemEntryFormState extends State<PurchaseItemEntryForm> {
  final bC = TextEditingController(); // Batch
  final eC = TextEditingController(); // Exp
  final gC = TextEditingController(); // GST
  final mC = TextEditingController(); // MRP
  final pRC = TextEditingController(); // Purchase Rate
  final qC = TextEditingController(text: "1"); // Qty
  final fC = TextEditingController(text: "0"); // Free
  
  // Selling Rates
  final rAC = TextEditingController(); 
  final rBC = TextEditingController(); 
  final rCC = TextEditingController(); 
  final rCD = TextEditingController(text: "0"); // Rate C Discount %

  @override void initState() { 
    super.initState(); 
    mC.text = widget.med.mrp.toString(); 
    gC.text = widget.med.gst.toString(); 
    rAC.text = widget.med.rateA.toString(); 
    rBC.text = widget.med.rateB.toString(); 
    rCC.text = widget.med.rateC.toString();
    _calculateRateC(); // Initial calculation
  }

  // --- RATE C FORMULA: (MRP / (1 + GST/100)) - (Disc %) ---
  void _calculateRateC() {
    double mrp = double.tryParse(mC.text) ?? 0;
    double gst = double.tryParse(gC.text) ?? 0;
    double disc = double.tryParse(rCD.text) ?? 0;

    double baseTaxable = mrp / (1 + (gst / 100));
    double finalRateC = baseTaxable - (baseTaxable * (disc / 100));
    
    setState(() {
      rCC.text = finalRateC.toStringAsFixed(2);
    });
  }

  @override Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15), 
      decoration: BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Colors.orange.shade200, width: 2))),
      child: Column(children: [
        Row(children: [
          Text(widget.med.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)), 
          const Spacer(), 
          IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: widget.onCancel)
        ]),
        
        // Row 1: Item Details
        Row(children: [
          Expanded(child: _field(bC, "Batch")),
          const SizedBox(width: 5),
          Expanded(child: _field(eC, "Exp (MM/YY)")),
          const SizedBox(width: 5),
          Expanded(child: _field(gC, "GST %", onChange: (v) => _calculateRateC())),
        ]),
        
        // Row 2: Pricing & Qty
        Row(children: [
          Expanded(child: _field(mC, "MRP", onChange: (v) => _calculateRateC())),
          const SizedBox(width: 5),
          Expanded(child: _field(pRC, "Pur. Rate")),
          const SizedBox(width: 5),
          Expanded(child: _field(qC, "Qty")),
          const SizedBox(width: 5),
          Expanded(child: _field(fC, "Free")),
        ]),

        const Divider(height: 25),
        const Row(children: [
          Icon(Icons.sell, size: 14, color: Colors.blueGrey),
          SizedBox(width: 5),
          Text("SET SELLING RATES", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ]),
        const SizedBox(height: 10),

        // Row 3: Selling Rates A, B and Rate C Calculation
        Row(children: [
          Expanded(child: _field(rAC, "Rate A (Main)")),
          const SizedBox(width: 5),
          Expanded(child: _field(rBC, "Rate B")),
          const SizedBox(width: 10),
          Container(width: 1, height: 40, color: Colors.grey.shade300),
          const SizedBox(width: 10),
          Expanded(child: _field(rCD, "RC Disc %", onChange: (v) => _calculateRateC(), color: Colors.purple.shade700)),
          const SizedBox(width: 5),
          Expanded(child: _field(rCC, "Rate C", isEnabled: false, color: Colors.blue.shade700)),
        ]),

        const SizedBox(height: 20),
        ElevatedButton(
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48), backgroundColor: Colors.orange), 
          onPressed: () {
            double pr = double.tryParse(pRC.text) ?? 0; 
            double qt = double.tryParse(qC.text) ?? 0; 
            double gst = double.tryParse(gC.text) ?? 0;
            
            widget.onAdd(PurchaseItem(
              id: DateTime.now().toString(), 
              srNo: widget.srNo, 
              medicineID: widget.med.id, 
              name: widget.med.name, 
              packing: widget.med.packing, 
              batch: bC.text.toUpperCase(), 
              exp: eC.text, 
              hsn: widget.med.hsnCode, 
              mrp: double.tryParse(mC.text) ?? 0, 
              qty: qt, 
              freeQty: double.tryParse(fC.text) ?? 0, 
              purchaseRate: pr, 
              gstRate: gst, 
              total: (pr * qt) * (1 + gst / 100), 
              rateA: double.tryParse(rAC.text) ?? 0, 
              rateB: double.tryParse(rBC.text) ?? 0, 
              rateC: double.tryParse(rCC.text) ?? 0
            ));
          }, 
          child: const Text("ADD TO PURCHASE LIST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
        )
      ]),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {Function(String)? onChange, bool isEnabled = true, Color? color}) {
    return TextField(
      controller: ctrl,
      onChanged: onChange,
      enabled: isEnabled,
      keyboardType: TextInputType.text,
      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.normal),
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
      ),
    );
  }
}
