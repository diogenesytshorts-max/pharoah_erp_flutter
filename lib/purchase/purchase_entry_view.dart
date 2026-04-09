import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_billing_view.dart';

class PurchaseEntryView extends StatefulWidget {
  const PurchaseEntryView({super.key});

  @override
  State<PurchaseEntryView> createState() => _PurchaseEntryViewState();
}

class _PurchaseEntryViewState extends State<PurchaseEntryView> {
  final supplierBillNoController = TextEditingController(); 
  final internalEntryNoController = TextEditingController();
  
  DateTime selectedBillDate = DateTime.now(); 
  String paymentMode = "CREDIT"; 
  Party? selectedDistributor; 
  String distributorSearchQuery = "";

  DateTime startOfFY = DateTime(2024, 4, 1); 
  DateTime endOfFY = DateTime(2030, 3, 31);

  @override
  void initState() {
    super.initState();
    _setupInitialData();
  }

  Future<void> _setupInitialData() async {
    final prefs = await SharedPreferences.getInstance();
    String fy = prefs.getString('fy') ?? "2025-26";
    try {
      int startYear = int.parse(fy.split('-')[0]); 
      if (startYear < 2000) startYear += 2000;
      setState(() {
        startOfFY = DateTime(startYear, 4, 1);
        endOfFY = DateTime(startYear + 1, 3, 31);
        DateTime today = DateTime.now();
        if (today.isBefore(startOfFY) || today.isAfter(endOfFY)) {
          selectedBillDate = startOfFY;
        } else {
          selectedBillDate = today;
        }
      });
    } catch (e) {}

    int lastPurId = prefs.getInt('lastPurID') ?? 0;
    setState(() {
      internalEntryNoController.text = "PUR-${lastPurId + 1}";
    });
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Purchase Entry"), 
        backgroundColor: Colors.orange.shade800, 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20), 
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: TextField(controller: internalEntryNoController, enabled: false, decoration: const InputDecoration(labelText: "INTERNAL NO", border: OutlineInputBorder()))),
                    const SizedBox(width: 15),
                    Expanded(child: TextField(controller: supplierBillNoController, decoration: const InputDecoration(labelText: "SUPPLIER BILL NO", border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(child: InkWell(onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: selectedBillDate, firstDate: startOfFY, lastDate: endOfFY); if (p != null) setState(() => selectedBillDate = p); }, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(5)), child: Text(DateFormat('dd/MM/yyyy').format(selectedBillDate))))),
                    const SizedBox(width: 15),
                    Expanded(child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], selected: {paymentMode}, onSelectionChanged: (v) => setState(() => paymentMode = v.first))),
                  ],
                ),
              ],
            ),
          ),
          if (selectedDistributor != null)
            Padding(
              padding: const EdgeInsets.all(15),
              child: Card(
                elevation: 4,
                // FIX: border parameter removed, side used instead
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), 
                  side: BorderSide(color: Colors.orange.shade200, width: 1.5)
                ),
                child: ListTile(
                  leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.business, color: Colors.white)),
                  title: Text(selectedDistributor!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: IconButton(icon: const Icon(Icons.change_circle, color: Colors.red), onPressed: () => setState(() => selectedDistributor = null)),
                ),
              ),
            )
          else
            Expanded(
              child: Column(
                children: [
                  Padding(padding: const EdgeInsets.all(20), child: TextField(decoration: const InputDecoration(hintText: "Search Distributor...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => distributorSearchQuery = v))),
                  Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(distributorSearchQuery.toLowerCase())).map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () => setState(() => selectedDistributor = p))).toList())),
                ],
              )
            ),
          if (selectedDistributor != null)
            Padding(
              padding: const EdgeInsets.all(20), 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 60), backgroundColor: Colors.orange.shade800),
                onPressed: () {
                  if (supplierBillNoController.text.trim().isEmpty) return;
                  Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: selectedDistributor!, internalNo: internalEntryNoController.text, distBillNo: supplierBillNoController.text.trim(), billDate: selectedBillDate, mode: paymentMode)));
                },
                child: const Text("PROCEED TO ITEMS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
        ],
      ),
    );
  }
}
