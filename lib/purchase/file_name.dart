import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_billing_view.dart';

class PurchaseEntryView extends StatefulWidget {
  const PurchaseEntryView({super.key});

  @override
  State<PurchaseEntryView> createState() => _PurchaseEntryViewState();
}

class _PurchaseEntryViewState extends State<PurchaseEntryView> {
  final billNoC = TextEditingController();
  DateTime billDate = DateTime.now();
  String mode = "CREDIT";
  Party? selectedDistributor;
  String searchKey = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Purchase Entry (Stock In)")),
      body: Column(children: [
        // --- Header Section ---
        Container(
          padding: const EdgeInsets.all(15),
          color: Colors.orange[50],
          child: Column(children: [
            Row(children: [
              Expanded(child: TextField(controller: billNoC, decoration: const InputDecoration(labelText: "DISTRIBUTOR BILL NO", hintText: "Enter Bill No"))),
              const SizedBox(width: 10),
              Expanded(child: InkWell(
                onTap: () async {
                  DateTime? p = await showDatePicker(context: context, initialDate: billDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (p != null) setState(() => billDate = p);
                },
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text("BILL DATE", style: TextStyle(fontSize: 10)),
                  Text(DateFormat('dd/MM/yyyy').format(billDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ]),
              )),
            ]),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))],
              selected: {mode},
              onSelectionChanged: (v) => setState(() => mode = v.first),
            )
          ]),
        ),
        
        // --- Distributor Selection ---
        const Padding(padding: EdgeInsets.all(15), child: Align(alignment: Alignment.centerLeft, child: Text("SELECT DISTRIBUTOR", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)))),
        
        if (selectedDistributor != null)
          ListTile(
            leading: const Icon(Icons.business, color: Colors.orange),
            title: Text(selectedDistributor!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(selectedDistributor!.city),
            trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => selectedDistributor = null)),
          )
        else
          Expanded(child: Column(children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 15), child: TextField(decoration: const InputDecoration(hintText: "Search Distributor..."), onChanged: (v) => setState(() => searchKey = v))),
            Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(searchKey.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () => setState(() => selectedDistributor = p))).toList()))
          ])),

        if (selectedDistributor != null)
          Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.orange),
            onPressed: () {
              if (billNoC.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter Bill Number")));
                return;
              }
              Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(
                distributor: selectedDistributor!,
                billNo: billNoC.text,
                billDate: billDate,
                mode: mode,
              )));
            },
            child: const Text("PROCEED TO PURCHASE BILLING", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )),
      ]),
    );
  }
}
