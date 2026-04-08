import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'purchase_billing_view.dart';

class PurchaseEntryView extends StatefulWidget {
  const PurchaseEntryView({super.key});
  @override State<PurchaseEntryView> createState() => _PurchaseEntryViewState();
}

class _PurchaseEntryViewState extends State<PurchaseEntryView> {
  final bNoC = TextEditingController(); DateTime bD = DateTime.now(); String mode = "CREDIT"; Party? sD; String sK = "";

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    return Scaffold(
      appBar: AppBar(title: const Text("Purchase Entry")),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(15), color: Colors.orange[50], child: Column(children: [
          Row(children: [
            Expanded(child: TextField(controller: bNoC, decoration: const InputDecoration(labelText: "Distributor Bill No"))),
            Expanded(child: InkWell(onTap: () async { DateTime? p = await showDatePicker(context: context, initialDate: bD, firstDate: DateTime(2000), lastDate: DateTime(2100)); if (p != null) setState(() => bD = p); },
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [const Text("BILL DATE", style: TextStyle(fontSize: 10)), Text(DateFormat('dd/MM/yyyy').format(bD), style: const TextStyle(fontWeight: FontWeight.bold))]))),
          ]),
          const SizedBox(height: 10),
          SegmentedButton<String>(segments: const [ButtonSegment(value: 'CASH', label: Text('CASH')), ButtonSegment(value: 'CREDIT', label: Text('CREDIT'))], selected: {mode}, onSelectionChanged: (v) => setState(() => mode = v.first))
        ])),
        if (sD != null) ListTile(leading: const Icon(Icons.business, color: Colors.orange), title: Text(sD!.name, style: const TextStyle(fontWeight: FontWeight.bold)), trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => sD = null)))
        else Expanded(child: Column(children: [
          Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: const InputDecoration(hintText: "Search Distributor..."), onChanged: (v) => setState(() => sK = v))),
          Expanded(child: ListView(children: ph.parties.where((p) => p.name.toLowerCase().contains(sK.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () => setState(() => sD = p))).toList()))
        ])),
        if (sD != null) Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.orange), onPressed: () {
          if (bNoC.text.isEmpty) return;
          Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: sD!, billNo: bNoC.text, billDate: bD, mode: mode)));
        }, child: const Text("PROCEED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))))
      ]),
    );
  }
}
