import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_billing_view.dart';

class PurchaseEntryView extends StatefulWidget {
  final Purchase? existingPurchase;
  final bool isReadOnly; 

  const PurchaseEntryView({super.key, this.existingPurchase, this.isReadOnly = false});

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

  @override void initState() {
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
        internalEntryNoC.text = "PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";
      }
    });
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.isReadOnly ? "View Purchase (Read Only)" : (widget.existingPurchase != null ? "Modify Purchase" : "Purchase Entry")), 
        backgroundColor: widget.isReadOnly ? Colors.purple.shade700 : Colors.orange.shade800, 
        foregroundColor: Colors.white
      ),
      body: IgnorePointer(
        ignoring: widget.isReadOnly,
        child: Column(children: [
          Container(padding: const EdgeInsets.all(20), color: Colors.white, child: Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: internalEntryNoC, enabled: false, decoration: const InputDecoration(labelText: "INTERNAL ID", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF5F5F5)))),
              const SizedBox(width: 15),
              Expanded(child: TextField(controller: supplierBillNoC, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "SUPPLIER BILL NO", border: OutlineInputBorder()))),
            ]),
            const SizedBox(height: 15),
            Row(children: [
              Expanded(child: InkWell(onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: selectedBillDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (p != null) setState(() => selectedBillDate = p); }, child: _dateDisplay("BILL DATE", selectedBillDate, Colors.orange))),
              const SizedBox(width: 10),
              Expanded(child: InkWell(onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: selectedEntryDate, firstDate: DateTime(2020), lastDate: DateTime(2100)); if (p != null) setState(() => selectedEntryDate = p); }, child: _dateDisplay("ENTRY DATE", selectedEntryDate, Colors.blue))),
            ]),
            const SizedBox(height: 15),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], 
              selected: {paymentMode}, 
              onSelectionChanged: (v) => setState(() => paymentMode = v.first)
            ),
          ])),

          Expanded(child: selectedDistributor != null ? _buildSupplierCard() : _buildSearchList(ph)),

          if (selectedDistributor != null) Padding(
            padding: const EdgeInsets.all(20), 
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 60), 
                backgroundColor: widget.isReadOnly ? Colors.purple : Colors.orange.shade800,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
              ), 
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(
                distributor: selectedDistributor!, 
                internalNo: internalEntryNoC.text, 
                distBillNo: supplierBillNoC.text.trim(), 
                billDate: selectedBillDate, 
                entryDate: selectedEntryDate, 
                mode: paymentMode, 
                existingItems: widget.existingPurchase?.items, 
                modifyPurchaseId: widget.existingPurchase?.id,
                isReadOnly: widget.isReadOnly,
              ))), 
              child: Text(
                widget.isReadOnly ? "VIEW PURCHASED ITEMS" : "PROCEED TO ITEM ENTRY", 
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)
              )
            )
          )
        ]),
      ),
    );
  }

  Widget _dateDisplay(String l, DateTime d, Color c) => Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(5)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.bold)), Text(DateFormat('dd/MM/yyyy').format(d), style: const TextStyle(fontWeight: FontWeight.bold))]));
  
  Widget _buildSupplierCard() => Card(
    margin: const EdgeInsets.all(15), 
    elevation: 3,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(15), 
      side: BorderSide(color: Colors.orange.shade100, width: 1), // FIXED PARAMETER
    ),
    child: ListTile(
      leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.business, color: Colors.white)),
      title: Text(selectedDistributor!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)), 
      subtitle: Text("${selectedDistributor!.city} | GST: ${selectedDistributor!.gst}"), 
      trailing: widget.isReadOnly ? null : IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedDistributor = null))
    )
  );

  Widget _buildSearchList(PharoahManager ph) => Column(children: [
    Padding(padding: const EdgeInsets.all(15), child: TextField(decoration: const InputDecoration(hintText: "Search Supplier...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => distSearchQuery = v))), 
    Expanded(child: ListView(children: ph.parties.where((p) => p.group == "Sundry Creditors" && p.name.toLowerCase().contains(distSearchQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () => setState(() => selectedDistributor = p))).toList()))
  ]);
}
