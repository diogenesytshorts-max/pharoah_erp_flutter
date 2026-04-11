import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_billing_view.dart';

class PurchaseEntryView extends StatefulWidget {
  const PurchaseEntryView({super.key});
  @override State<PurchaseEntryView> createState() => _PurchaseEntryViewState();
}

class _PurchaseEntryViewState extends State<PurchaseEntryView> {
  final supplierBillNoC = TextEditingController(); 
  final internalEntryNoC = TextEditingController();
  DateTime selectedBillDate = DateTime.now(); 
  String paymentMode = "CREDIT"; 
  Party? selectedDistributor; 
  String distSearch = "";

  @override
  void initState() {
    super.initState();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // Ensure default date is valid for this FY
    if (selectedBillDate.isBefore(ph.fyStartDate) || selectedBillDate.isAfter(ph.fyEndDate)) {
      selectedBillDate = ph.fyStartDate;
    }
    _loadInternalNo();
  }

  Future<void> _loadInternalNo() async {
    final prefs = await SharedPreferences.getInstance();
    int lastId = prefs.getInt('lastPurID') ?? 0;
    setState(() { internalEntryNoC.text = "PUR-${lastId + 1}"; });
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("Purchase Entry"), backgroundColor: Colors.orange.shade800, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20), color: Colors.white,
            child: Column(
              children: [
                Row(children: [
                  Expanded(child: TextField(controller: internalEntryNoC, enabled: false, decoration: const InputDecoration(labelText: "INTERNAL NO", border: OutlineInputBorder()))),
                  const SizedBox(width: 15),
                  Expanded(child: TextField(controller: supplierBillNoC, decoration: const InputDecoration(labelText: "SUPPLIER BILL NO", border: OutlineInputBorder()))),
                ]),
                const SizedBox(height: 15),
                Row(children: [
                  Expanded(child: InkWell(onTap: () async { 
                    DateTime? p = await showDatePicker(
                      context: context, 
                      initialDate: selectedBillDate, 
                      firstDate: ph.fyStartDate, // Strict Boundary
                      lastDate: ph.fyEndDate     // Strict Boundary
                    ); 
                    if (p != null) setState(() => selectedBillDate = p); 
                  }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)), child: Text(DateFormat('dd/MM/yyyy').format(selectedBillDate))))),
                  const SizedBox(width: 15),
                  Expanded(child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], selected: {paymentMode}, onSelectionChanged: (v) => setState(() => paymentMode = v.first))),
                ]),
              ],
            ),
          ),
          if (selectedDistributor != null)
            Padding(padding: const EdgeInsets.all(15), child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: Colors.orange.shade200, width: 1.5)), child: ListTile(leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.business, color: Colors.white)), title: Text(selectedDistributor!.name), trailing: IconButton(icon: const Icon(Icons.change_circle, color: Colors.red), onPressed: () => setState(() => selectedDistributor = null)))))
          else
            Expanded(child: Column(children: [Padding(padding: const EdgeInsets.all(20), child: TextField(decoration: const InputDecoration(hintText: "Search Supplier...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => distSearch = v))), Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(distSearch.toLowerCase())).map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () => setState(() => selectedDistributor = p))).toList()))])),
          if (selectedDistributor != null) Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.orange.shade800), onPressed: () {
            if (supplierBillNoC.text.trim().isEmpty) return;
            
            // Final check before proceeding
            if (selectedBillDate.isBefore(ph.fyStartDate) || selectedBillDate.isAfter(ph.fyEndDate)) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Date out of range!")));
               return;
            }

            Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: selectedDistributor!, internalNo: internalEntryNoC.text, distBillNo: supplierBillNoC.text.trim(), billDate: selectedBillDate, mode: paymentMode)));
          }, child: const Text("PROCEED TO ITEMS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)))),
        ],
      ),
    );
  }
}
