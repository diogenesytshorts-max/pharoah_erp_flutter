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
  String searchQuery = ""; 
  Medicine? selectedMed;

  // Real-time calculation for total bill amount
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.orange.shade800, 
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(widget.distributor.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), 
            Text("${widget.internalNo} | Supplier Bill: ${widget.distBillNo}", style: const TextStyle(fontSize: 10))
          ]
        ),
        actions: [
          // Option to Save and Print a Purchase copy
          IconButton(
            icon: const Icon(Icons.print_rounded), 
            onPressed: items.isEmpty ? null : () => _handleSave(ph, print: true)
          ), 
          // Main Save Button
          TextButton(
            onPressed: items.isEmpty ? null : () => _handleSave(ph), 
            child: const Text("SAVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ]
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // --- 1. SEARCH BAR ---
              if (selectedMed == null)
                Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.orange.shade50,
                  child: TextField(
                    autofocus: true, 
                    decoration: InputDecoration(
                      hintText: "Search Product to Stock-In...", 
                      prefixIcon: const Icon(Icons.search, color: Colors.orange), 
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    ), 
                    onChanged: (v) => setState(() => searchQuery = v)
                  ),
                ),

              // --- 2. DYNAMIC ITEM ENTRY FORM ---
              if (selectedMed != null)
                PurchaseItemEntryForm(
                  med: selectedMed!, 
                  srNo: items.length + 1,
                  onAdd: (newItem) { 
                    setState(() { 
                      items.add(newItem); 
                      selectedMed = null; 
                      searchQuery = ""; 
                    }); 
                  },
                  onCancel: () => setState(() => selectedMed = null),
                ),

              // --- 3. ADDED ITEMS LIST ---
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(10),
                  itemCount: items.length, 
                  separatorBuilder: (c, i) => const Divider(),
                  itemBuilder: (c, i) => ListTile(
                    title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Qty: ${items[i].qty.toInt()} + ${items[i].freeQty.toInt()} | Pur.Rate: ₹${items[i].purchaseRate} | Batch: ${items[i].batch}"),
                    trailing: Text("₹${items[i].total.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 16)),
                  )
                )
              ),

              // --- 4. SUMMARY FOOTER ---
              Container(
                padding: const EdgeInsets.all(20), 
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                  children: [
                    Text("Total Items: ${items.length}", style: const TextStyle(fontWeight: FontWeight.bold)), 
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(8)),
                      child: Text("TOTAL: ₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.deepOrange)),
                    )
                  ]
                )
              )
            ],
          ),
          
          // --- 5. SEARCH RESULTS OVERLAY ---
          if (searchQuery.isNotEmpty && selectedMed == null)
            Positioned(
              top: 70, left: 15, right: 15, 
              child: Material(
                elevation: 10, 
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300), 
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: ListView(
                    shrinkWrap: true, 
                    children: ph.medicines
                        .where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase()))
                        .map((m) => ListTile(
                              leading: const Icon(Icons.medication, color: Colors.orange), 
                              title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                              subtitle: Text("Pack: ${m.packing} | Stock: ${m.stock}"), 
                              onTap: () => setState(() { selectedMed = m; searchQuery = ""; })
                            ))
                        .toList()
                  )
                )
              )
            )
        ],
      ),
    );
  }

  // --- SAVE LOGIC ---
  void _handleSave(PharoahManager ph, {bool print = false}) async {
    // 1. Process via Manager (Updates Stock & Latest Master Rates)
    ph.finalizePurchase(
      internalNo: widget.internalNo, 
      billNo: widget.distBillNo, 
      date: widget.billDate, 
      party: widget.distributor, 
      items: items, 
      total: totalAmt, 
      mode: widget.mode
    );
    
    // 2. Increment Internal Purchase Sequence
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastPurID') ?? 0;
    await prefs.setInt('lastPurID', lastId + 1);
    
    // 3. Print if requested
    if (print) {
      final saleObjForPrint = Sale(
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
      await PdfService.generateInvoice(saleObjForPrint, widget.distributor, isPurchase: true);
    }
    
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Order Recorded & Stock Updated!")));
    }
  }
}

// =====================================================================
// --- PURCHASE ITEM ENTRY FORM (CALCULATION ENGINE) ---
// =====================================================================
class PurchaseItemEntryForm extends StatefulWidget {
  final Medicine med; 
  final int srNo; 
  final Function(PurchaseItem) onAdd; 
  final VoidCallback onCancel;
  
  const PurchaseItemEntryForm({super.key, required this.med, required this.srNo, required this.onAdd, required this.onCancel});
  @override State<PurchaseItemEntryForm> createState() => _PurchaseItemEntryFormState();
}

class _PurchaseItemEntryFormState extends State<PurchaseItemEntryForm> {
  // Main Controllers
  final bC = TextEditingController(); // Batch
  final eC = TextEditingController(); // Exp
  final gC = TextEditingController(); // GST
  final mC = TextEditingController(); // MRP
  final pRC = TextEditingController(); // Purchase Rate
  final qC = TextEditingController(text: "1"); // Qty
  final fC = TextEditingController(text: "0"); // Free
  
  // Master Rate Controllers (A, B, C)
  final rAC = TextEditingController(); 
  final rBC = TextEditingController(); 
  final rCC = TextEditingController(); 
  final rCD = TextEditingController(text: "0"); // Rate C Disc %

  @override void initState() { 
    super.initState(); 
    // Loading default master data into form
    mC.text = widget.med.mrp.toString(); 
    gC.text = widget.med.gst.toString(); 
    rAC.text = widget.med.rateA.toString(); 
    rBC.text = widget.med.rateB.toString(); 
    rCC.text = widget.med.rateC.toString();
    _calculateRateC(); 
  }

  // --- RATE C AUTOMATIC FORMULA ---
  // (MRP / (1 + GST/100)) - (Rate C Discount %)
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
      decoration: BoxDecoration(
        color: Colors.white, 
        border: Border(bottom: BorderSide(color: Colors.orange.shade300, width: 2))
      ),
      child: Column(
        children: [
          Row(children: [
            Text("${widget.srNo}. ${widget.med.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.orange)), 
            const Spacer(), 
            IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: widget.onCancel)
          ]),
          
          // Row 1: Batch Details
          Row(children: [
            Expanded(child: _field(bC, "Batch")),
            const SizedBox(width: 5),
            Expanded(child: _field(eC, "Exp (MM/YY)")),
            const SizedBox(width: 5),
            Expanded(child: _field(gC, "GST %", onChange: (v) => _calculateRateC())),
          ]),
          
          // Row 2: Basic Pricing
          Row(children: [
            Expanded(child: _field(mC, "MRP (₹)", onChange: (v) => _calculateRateC(), labelColor: Colors.blue)),
            const SizedBox(width: 5),
            Expanded(child: _field(pRC, "Pur. Rate", labelColor: Colors.red)),
            const SizedBox(width: 5),
            Expanded(child: _field(qC, "Qty")),
            const SizedBox(width: 5),
            Expanded(child: _field(fC, "Free")),
          ]),

          const SizedBox(height: 15),
          const Row(children: [
            Icon(Icons.update_rounded, size: 14, color: Colors.blueGrey),
            SizedBox(width: 5),
            Text("SET NEW SELLING RATES (MASTER)", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          ]),
          const SizedBox(height: 10),

          // Row 3: Advanced Rate Logic (A, B and Auto-C)
          Row(children: [
            Expanded(child: _field(rAC, "Rate A")),
            const SizedBox(width: 5),
            Expanded(child: _field(rBC, "Rate B")),
            const SizedBox(width: 10),
            Container(width: 1.5, height: 35, color: Colors.grey.shade300),
            const SizedBox(width: 10),
            Expanded(child: _field(rCD, "RC Disc%", onChange: (v) => _calculateRateC(), labelColor: Colors.purple)),
            const SizedBox(width: 5),
            Expanded(child: _field(rCC, "Rate C", isEnabled: false, labelColor: Colors.deepPurple)),
          ]),

          const SizedBox(height: 20),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50), 
              backgroundColor: Colors.orange.shade800,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
            ), 
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
            child: const Text("ADD ITEM TO LIST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
          )
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {Function(String)? onChange, bool isEnabled = true, Color? labelColor}) {
    return TextField(
      controller: ctrl,
      onChanged: onChange,
      enabled: isEnabled,
      keyboardType: TextInputType.text,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.normal, color: labelColor),
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      ),
    );
  }
}
