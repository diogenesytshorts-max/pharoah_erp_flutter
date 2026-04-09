import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class PartyMasterView extends StatefulWidget {
  const PartyMasterView({super.key});
  @override State<PartyMasterView> createState() => _PartyMasterViewState();
}

class _PartyMasterViewState extends State<PartyMasterView> {
  String search = "";
  final List<String> states = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal"
  ];

  void _showForm({Party? party}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final nameC = TextEditingController(text: party?.name ?? "");
    final phoneC = TextEditingController(text: party?.phone ?? "");
    final addrC = TextEditingController(text: party?.address ?? "");
    final cityC = TextEditingController(text: party?.city ?? "");
    final routeC = TextEditingController(text: party?.route ?? "");
    final emailC = TextEditingController(text: party?.email ?? "");
    final dlC = TextEditingController(text: party?.dl ?? "");
    final gstC = TextEditingController(text: party?.gst ?? "");
    final balC = TextEditingController(text: party?.openingBalance.toString() ?? "0.0");
    String selectedState = party?.state ?? "Rajasthan";

    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(party == null ? "New Party (Customer/Supplier)" : "Edit Party Details"),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: "Firm Name")),
        TextField(controller: phoneC, decoration: const InputDecoration(labelText: "Phone"), keyboardType: TextInputType.phone),
        TextField(controller: addrC, decoration: const InputDecoration(labelText: "Full Address")),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: selectedState,
          items: states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
          onChanged: (v) => selectedState = v!,
          decoration: const InputDecoration(labelText: "State"),
        ),
        Row(children: [
          Expanded(child: TextField(controller: cityC, decoration: const InputDecoration(labelText: "City"))),
          const SizedBox(width: 5),
          Expanded(child: TextField(controller: routeC, decoration: const InputDecoration(labelText: "Route"))),
        ]),
        Row(children: [
          Expanded(child: TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN (If B2B)"))),
          const SizedBox(width: 5),
          Expanded(child: TextField(controller: dlC, decoration: const InputDecoration(labelText: "Drug License"))),
        ]),
        TextField(controller: balC, decoration: const InputDecoration(labelText: "Opening Balance"), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(onPressed: () {
          if (nameC.text.isEmpty) return;
          final p = Party(
            id: party?.id ?? DateTime.now().toString(),
            name: nameC.text.toUpperCase(), phone: phoneC.text, email: emailC.text,
            address: addrC.text, city: cityC.text, state: selectedState, route: routeC.text.toUpperCase(),
            gst: gstC.text.isNotEmpty ? gstC.text.toUpperCase() : "N/A", 
            dl: dlC.text.isNotEmpty ? dlC.text.toUpperCase() : "N/A",
            openingBalance: double.tryParse(balC.text) ?? 0.0, rateType: "A"
          );
          if (party == null) ph.parties.add(p); else ph.parties[ph.parties.indexWhere((x)=>x.id==party.id)] = p;
          ph.save(); Navigator.pop(c);
        }, child: const Text("SAVE"))
      ],
    ));
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.parties.where((p) => p.name.toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Party Master"), backgroundColor: Colors.teal, foregroundColor: Colors.white, actions: [IconButton(icon: const Icon(Icons.person_add), onPressed: () => _showForm())]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: const InputDecoration(hintText: "Search Customer or Supplier...", prefixIcon: Icon(Icons.search)), onChanged: (v)=>setState(()=>search=v))),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(
          title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), 
          subtitle: Text("${list[i].city} (${list[i].state})"), 
          trailing: Text(list[i].isB2B ? "B2B" : "B2C", style: TextStyle(color: list[i].isB2B ? Colors.blue : Colors.grey, fontWeight: FontWeight.bold)),
          onTap: () => _showForm(party: list[i]))))
      ]),
    );
  }
}
