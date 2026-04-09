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
  final distBillNoC = TextEditingController(); 
  final internalNoC = TextEditingController();
  DateTime bD = DateTime.now(); 
  String mode = "CREDIT"; 
  Party? sD; 
  String sK = "";
  DateTime fD = DateTime(2024, 4, 1); 
  DateTime lD = DateTime(2030, 3, 31);

  @override
  void initState() {
    super.initState();
    _setup();
  }

  _setup() async {
    final p = await SharedPreferences.getInstance();
    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    // FY Logic
    String fy = p.getString('fy') ?? "2025-26";
    int sY = int.parse(fy.split('-')[0]); if (sY < 2000) sY += 2000;
    
    // Internal Purchase No Logic
    int lastPurId = p.getInt('lastPurID') ?? 0;
    
    setState(() {
      fD = DateTime(sY, 4, 1);
      lD = DateTime(sY + 1, 3, 31);
      if (bD.isBefore(fD) || bD.isAfter(lD)) bD = fD;
      internalNoC.text = "PUR-${lastPurId + 1}";
    });
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Purchase Entry (Stock In)"), backgroundColor: Colors.orange, foregroundColor: Colors.white),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(15), color: Colors.orange[50], child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: internalNoC, enabled: false, decoration: const InputDecoration(labelText: "ENTRY NO", border: OutlineInputBorder(), filled: true, fillColor: Colors.white70))),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: distBillNoC, decoration: const InputDecoration(labelText: "PARTY BILL NO", border: OutlineInputBorder(), filled: true, fillColor: Colors.white))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: InkWell(onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: bD, firstDate: fD, lastDate: lD); if (p != null) setState(() => bD = p); },
              child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(4), color: Colors.white), 
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("DATE", style: TextStyle(fontSize: 10)), Text(DateFormat('dd/MM/yyyy').format(bD), style: const TextStyle(fontWeight: FontWeight.bold))])))),
            const SizedBox(width: 10),
            Expanded(child: SegmentedButton<String>(segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], selected: {mode}, onSelectionChanged: (v) => setState(() => mode = v.first))),
          ]),
        ])),
        if (sD != null) Card(margin: const EdgeInsets.all(15), child: ListTile(leading: const Icon(Icons.business, color: Colors.orange), title: Text(sD!.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(sD!.city), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => sD = null))))
        else Expanded(child: Column(children: [
          Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: const InputDecoration(hintText: "Search Distributor/Supplier...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => sK = v))),
          Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(sK.toLowerCase())).map((p) => ListTile(title: Text(p.name), subtitle: Text(p.city), onTap: () => setState(() => sD = p))).toList()))
        ])),
        if (sD != null) Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.orange), onPressed: () {
          if (distBillNoC.text.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Enter Party Bill Number"))); return; }
          Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: sD!, internalNo: internalNoC.text, distBillNo: distBillNoC.text, billDate: bD, mode: mode)));
        }, child: const Text("PROCEED TO ITEMS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
      ]),
    );
  }
}
