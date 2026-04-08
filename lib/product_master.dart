import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class ProductMasterView extends StatefulWidget {
  const ProductMasterView({super.key});
  @override
  State<ProductMasterView> createState() => _ProductMasterViewState();
}

class _ProductMasterViewState extends State<ProductMasterView> {
  String search = "";
  void _showForm({Medicine? med}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final nameC = TextEditingController(text: med?.name ?? "");
    final packC = TextEditingController(text: med?.packing ?? "");
    final hsnC = TextEditingController(text: med?.hsnCode ?? "");
    final gstC = TextEditingController(text: med?.gst.toString() ?? "12.0");
    final mrpC = TextEditingController(text: med?.mrp.toString() ?? "");
    final rAC = TextEditingController(text: med?.rateA.toString() ?? "");
    final rBC = TextEditingController(text: med?.rateB.toString() ?? "");
    final rCC = TextEditingController(text: med?.rateC.toString() ?? "");
    final stC = TextEditingController(text: med?.stock.toString() ?? "0");

    showDialog(context: context, builder: (c) => AlertDialog(
      title: Text(med == null ? "New Product" : "Edit Product"),
      content: SingleChildScrollView(child: Column(children: [
        TextField(controller: nameC, decoration: const InputDecoration(labelText: "Product Name")),
        TextField(controller: packC, decoration: const InputDecoration(labelText: "Packing")),
        TextField(controller: hsnC, decoration: const InputDecoration(labelText: "HSN Code")),
        TextField(controller: gstC, decoration: const InputDecoration(labelText: "GST %"), keyboardType: TextInputType.number),
        TextField(controller: mrpC, decoration: const InputDecoration(labelText: "MRP"), keyboardType: TextInputType.number),
        TextField(controller: rAC, decoration: const InputDecoration(labelText: "Rate A"), keyboardType: TextInputType.number),
        TextField(controller: rBC, decoration: const InputDecoration(labelText: "Rate B"), keyboardType: TextInputType.number),
        TextField(controller: rCC, decoration: const InputDecoration(labelText: "Rate C"), keyboardType: TextInputType.number),
        TextField(controller: stC, decoration: const InputDecoration(labelText: "Opening Stock"), keyboardType: TextInputType.number),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")),
        ElevatedButton(onPressed: () {
          final m = Medicine(id: med?.id ?? DateTime.now().toString(), name: nameC.text.toUpperCase(), packing: packC.text.toUpperCase(), hsnCode: hsnC.text, gst: double.tryParse(gstC.text) ?? 12.0, mrp: double.tryParse(mrpC.text) ?? 0.0, rateA: double.tryParse(rAC.text) ?? 0.0, rateB: double.tryParse(rBC.text) ?? 0.0, rateC: double.tryParse(rCC.text) ?? 0.0, stock: int.tryParse(stC.text) ?? 0);
          if (med == null) ph.medicines.add(m); else ph.medicines[ph.medicines.indexWhere((x)=>x.id==med.id)] = m;
          ph.save(); Navigator.pop(c);
        }, child: const Text("SAVE"))
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.medicines.where((m) => m.name.toLowerCase().contains(search.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Inventory"), actions: [IconButton(icon: const Icon(Icons.add), onPressed: () => _showForm())]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(10), child: TextField(decoration: const InputDecoration(hintText: "Search Item...", prefixIcon: Icon(Icons.search)), onChanged: (v)=>setState(()=>search=v))),
        Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(title: Text(list[i].name), subtitle: Text("Pack: ${list[i].packing} | Stock: ${list[i].stock}"), trailing: Text("₹${list[i].mrp}"), onTap: () => _showForm(med: list[i]))))
      ]),
    );
  }
}
