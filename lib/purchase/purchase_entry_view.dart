import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_billing_view.dart';
import '../app_date_logic.dart';

class PurchaseEntryView extends StatefulWidget {
  final Purchase? existingPurchase;
  const PurchaseEntryView({super.key, this.existingPurchase});

  @override State<PurchaseEntryView> createState() => _PurchaseEntryViewState();
}

class _PurchaseEntryViewState extends State<PurchaseEntryView> {
  final supplierBillNoC = TextEditingController(); 
  final internalEntryNoC = TextEditingController();
  DateTime selectedBillDate = DateTime.now(); 
  String paymentMode = "CREDIT"; 
  Party? selectedDistributor; 
  String distSearchQuery = "";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      setState(() {
        if (widget.existingPurchase != null) {
          supplierBillNoC.text = widget.existingPurchase!.billNo;
          internalEntryNoC.text = widget.existingPurchase!.internalNo;
          selectedBillDate = widget.existingPurchase!.date;
          paymentMode = widget.existingPurchase!.paymentMode;
          selectedDistributor = ph.parties.firstWhere((p) => p.name == widget.existingPurchase!.distributorName, orElse: () => ph.parties[0]);
        } else {
          // AUTOMATIC SMART DATE FOR PURCHASE
          selectedBillDate = AppDateLogic.getSmartDate(ph.currentFY);
          _loadInternalNo();
        }
      });
    });
  }

  Future<void> _loadInternalNo() async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastPurID') ?? 0;
    setState(() { internalEntryNoC.text = "PUR-${lastId + 1}"; });
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: Text(widget.existingPurchase != null ? "Modify Purchase" : "Purchase Entry"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(20), color: Colors.white, child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: internalEntryNoC, enabled: false, decoration: const InputDecoration(labelText: "INTERNAL NO", border: OutlineInputBorder(), filled: true, fillColor: Color(0xFFF0F0F0)))),
            const SizedBox(width: 15),
            Expanded(child: TextField(controller: supplierBillNoC, textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "SUPPLIER BILL NO", border: OutlineInputBorder()))),
          ]),
          const SizedBox(height: 15),
          Row(children: [
            Expanded(child: InkWell(onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: selectedBillDate, firstDate: ph.fyStartDate, lastDate: ph.fyEndDate); if (p != null) setState(() => selectedBillDate = p); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(AppDateLogic.format(selectedBillDate), style: const TextStyle(fontWeight: FontWeight.bold)), const Icon(Icons.calendar_month, color: Colors.orange, size: 18)])))),
            const SizedBox(width: 15),
            Expanded(child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], selected: {paymentMode}, onSelectionChanged: (v) => setState(() => paymentMode = v.first))),
          ]),
        ])),
        const Padding(padding: EdgeInsets.all(20), child: Align(alignment: Alignment.centerLeft, child: Text("SELECT SUPPLIER", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)))),
        if (selectedDistributor != null)
          ListTile(tileColor: Colors.white, leading: const Icon(Icons.business, color: Colors.orange), title: Text(selectedDistributor!.name), subtitle: Text(selectedDistributor!.city), trailing: IconButton(icon: const Icon(Icons.change_circle, color: Colors.red), onPressed: () => setState(() => selectedDistributor = null)))
        else
          Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(distSearchQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () => setState(() => selectedDistributor = p))).toList())),
        if (selectedDistributor != null) 
          Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.orange.shade800), onPressed: () {
            if (supplierBillNoC.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bill Number is mandatory!"))); return; }
            Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: selectedDistributor!, internalNo: internalEntryNoC.text, distBillNo: supplierBillNoC.text.trim(), billDate: selectedBillDate, mode: paymentMode, existingItems: widget.existingPurchase?.items, modifyPurchaseId: widget.existingPurchase?.id)));
          }, child: const Text("PROCEED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
      ]),
    );
  }
}
