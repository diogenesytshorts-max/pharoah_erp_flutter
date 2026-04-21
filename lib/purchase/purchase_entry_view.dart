import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_billing_view.dart';
import 'package:intl/intl.dart';

class PurchaseEntryView extends StatefulWidget {
  final Purchase? existingPurchase;
  const PurchaseEntryView({super.key, this.existingPurchase});

  @override State<PurchaseEntryView> createState() => _PurchaseEntryViewState();
}

class _PurchaseEntryViewState extends State<PurchaseEntryView> {
  final supplierBillNoC = TextEditingController(); 
  final internalEntryNoC = TextEditingController();
  
  DateTime selectedBillDate = DateTime.now(); 
  DateTime selectedEntryDate = DateTime.now(); 
  String paymentMode = "CREDIT"; 
  Party? selectedDistributor; 
  String distSearchQuery = "";

  @override
  void initState() {
    super.initState();
    _initializePurchaseSession();
  }

  void _initializePurchaseSession() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      if (widget.existingPurchase != null) {
        setState(() {
          supplierBillNoC.text = widget.existingPurchase!.billNo;
          internalEntryNoC.text = widget.existingPurchase!.internalNo;
          selectedBillDate = widget.existingPurchase!.date;
          selectedEntryDate = widget.existingPurchase!.entryDate;
          paymentMode = widget.existingPurchase!.paymentMode;
          selectedDistributor = ph.parties.firstWhere(
            (p) => p.name == widget.existingPurchase!.distributorName, 
            orElse: () => ph.parties[0]
          );
        });
      } else {
        // Naya Bill ID generate karna
        internalEntryNoC.text = "PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}";
      }
    });
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.existingPurchase != null ? "Modify Purchase" : "New Purchase Entry"), 
        backgroundColor: Colors.orange.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- SECTION 1: BILL HEADER ---
          Container(
            padding: const EdgeInsets.all(20), 
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: internalEntryNoC, enabled: false, decoration: const InputDecoration(labelText: "INTERNAL ID", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF0F0F0)))),
                    const SizedBox(width: 15),
                    Expanded(child: TextField(controller: supplierBillNoC, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "SUPPLIER BILL NO", border: OutlineInputBorder(), prefixIcon: Icon(Icons.receipt)))),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    // Bill Date (Supplier Date)
                    Expanded(
                      child: InkWell(
                        onTap: () async { 
                          DateTime? p = await showDatePicker(context: context, initialDate: selectedBillDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); 
                          if (p != null) setState(() => selectedBillDate = p); 
                        }, 
                        child: _dateDisplay("BILL DATE", selectedBillDate, Colors.orange)
                      )
                    ),
                    const SizedBox(width: 10),
                    // Entry Date (System Date)
                    Expanded(
                      child: InkWell(
                        onTap: () async { 
                          DateTime? p = await showDatePicker(context: context, initialDate: selectedEntryDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); 
                          if (p != null) setState(() => selectedEntryDate = p); 
                        }, 
                        child: _dateDisplay("ENTRY DATE", selectedEntryDate, Colors.blue)
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'CASH', label: Text('CASH'), icon: Icon(Icons.money)), 
                    ButtonSegment(value: 'CREDIT', label: Text('CREDIT'), icon: Icon(Icons.credit_card))
                  ], 
                  selected: {paymentMode}, 
                  onSelectionChanged: (v) => setState(() => paymentMode = v.first),
                ),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10), 
            child: Align(alignment: Alignment.centerLeft, child: Text("SELECT SUPPLIER / DISTRIBUTOR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)))
          ),

          // --- SECTION 2: SUPPLIER SELECTION ---
          if (selectedDistributor != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.business, color: Colors.white)),
                  title: Text(selectedDistributor!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${selectedDistributor!.city} | GST: ${selectedDistributor!.gst}"),
                  trailing: IconButton(icon: const Icon(Icons.change_circle, color: Colors.red), onPressed: () => setState(() => selectedDistributor = null)),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: "Search Supplier...", 
                        prefixIcon: const Icon(Icons.search, color: Colors.orange),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        filled: true, fillColor: Colors.white
                      ),
                      onChanged: (v) => setState(() => distSearchQuery = v),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView(
                      children: ph.parties
                          .where((p) => p.group == "Sundry Creditors" && p.name.toLowerCase().contains(distSearchQuery.toLowerCase()))
                          .map((p) => ListTile(
                                leading: const Icon(Icons.store_outlined),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                                subtitle: Text(p.city), 
                                onTap: () => setState(() => selectedDistributor = p)
                              ))
                          .toList()
                    ),
                  ),
                ],
              )
            ),

          if (selectedDistributor != null) 
            Padding(
              padding: const EdgeInsets.all(20), 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60), 
                  backgroundColor: Colors.orange.shade800,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5
                ), 
                onPressed: () {
                  if (supplierBillNoC.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter Supplier Bill Number!")));
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(
                    distributor: selectedDistributor!, 
                    internalNo: internalEntryNoC.text, 
                    distBillNo: supplierBillNoC.text.trim(), 
                    billDate: selectedBillDate, 
                    entryDate: selectedEntryDate,
                    mode: paymentMode, 
                    existingItems: widget.existingPurchase?.items, 
                    modifyPurchaseId: widget.existingPurchase?.id
                  )));
                }, 
                child: const Text("PROCEED TO ITEM ENTRY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))
              )
            ),
        ],
      ),
    );
  }

  Widget _dateDisplay(String label, DateTime date, Color color) {
    return Container(
      padding: const EdgeInsets.all(12), 
      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)), 
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(DateFormat('dd/MM/yyyy').format(date), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      )
    );
  }
}
