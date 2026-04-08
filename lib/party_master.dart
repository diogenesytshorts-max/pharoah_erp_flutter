import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class PartyMasterView extends StatefulWidget {
  const PartyMasterView({super.key});
  @override
  State<PartyMasterView> createState() => _PartyMasterViewState();
}

class _PartyMasterViewState extends State<PartyMasterView> {
  String search = "";
  void _showForm({Party? party}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final nameC = TextEditingController(text: party?.name ?? "");
    final phoneC = TextEditingController(text: party?.phone ?? "");
    final addrC = TextEditingController(text: party?.address ?? "");
    final cityC = TextEditingController(text: party?.city ?? "");
    final routeC = TextEditingController(text: party?.route ?? "");
    final dlC = TextEditingController(text: party?.dl ?? "");
    final gstC = TextEditingController(text: party?.gst ?? "");
    final balC = TextEditingController(text: party?.openingBalance.toString() ?? "0.0");

    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(party == null ? "New Party" : "Edit Party"),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: "Firm Name")),
        TextField(controller: phoneC, decoration: const InputDecoration(labelText: "Phone"), keyboardType: TextInputType.phone),
        TextField(controller: addrC, decoration: const InputDecoration(labelText: "Address")),
        TextField(controller: cityC, decoration: const InputDecoration(labelText: "City")),
        TextField(controller: routeC, decoration: const InputDecoration(labelText: "Area / Route")),
        TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN")),
        TextField(controller: dlC, decoration: const InputDecoration(labelText: "DL Number")),
        TextField(controller: balC, decoration: const InputDecoration(labelText: "Opening Balance"), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(onPressed: () {
          final p = Party(id: party?.id ?? DateTime.now().toString(), name: nameC.text.toUpperCase(), phone: phoneC.text, address: addrC.text, city: cityC.text, route: routeC.text.toUpperCase(), gst: gstC.text.toUpperCase(), dl: dlC.text.toUpperCase(), openingBalance: double.tryParse(balC.text) ?? 0.0);
          if (party == null) ph.parties.add(p); else ph.parties[ph.parties.indexWhere((x)=>x.id==party.id)] = p;
          ph.save(); Navigator.pop(c);
        }, child: const Text("SAVE"))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.parties.where((p) => p.name.toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Party Master"), actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showForm())]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: const InputDecoration(hintText: "Search Party...", prefixIcon: Icon(Icons.search)), onChanged: (v)=>setState(()=>search=v))),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(title: Text(list[i].name), subtitle: Text("${list[i].route} | ${list[i].city}"), trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(party: list[i])))))
      ]),
    );
  }
}
