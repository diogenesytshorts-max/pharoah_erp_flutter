// FILE: lib/drug_type_master_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'logic/pharoah_numbering_engine.dart';

class DrugTypeMasterView extends StatefulWidget {
  const DrugTypeMasterView({super.key});
  @override State<DrugTypeMasterView> createState() => _DrugTypeMasterViewState();
}

class _DrugTypeMasterViewState extends State<DrugTypeMasterView> {
  String search = "";

  void _showForm({DrugType? dtype}) async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final nameC = TextEditingController(text: dtype?.name);

    // Smart ID Generation
    String nextId = dtype?.id ?? "Generating...";
    if (dtype == null) {
      nextId = await PharoahNumberingEngine.getNextNumber(
        type: "DRUGTYPE", 
        companyID: ph.activeCompany!.id, 
        prefix: "DT-", 
        startFrom: 101, 
        currentList: ph.drugTypes
      );
    }

    if(!mounted) return;

    showDialog(context: context, builder: (c) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Text(dtype == null ? "Add Category" : "Edit Category"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 15),
            decoration: BoxDecoration(color: Colors.cyan.shade50, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("SYSTEM ID:", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
              Text(nextId, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyan)),
            ]),
          ),
          TextField(controller: nameC, decoration: const InputDecoration(labelText: "Category Name", border: OutlineInputBorder()), textCapitalization: TextCapitalization.characters),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan.shade700, foregroundColor: Colors.white),
          onPressed: () {
            if (nameC.text.isEmpty) return;
            final newType = DrugType(id: nextId, name: nameC.text.toUpperCase());
            
            if (dtype == null) {
              ph.addDrugType(newType);
            } else {
              int i = ph.drugTypes.indexWhere((x) => x.id == dtype.id);
              if (i != -1) ph.drugTypes[i] = newType;
              ph.save();
            }
            Navigator.pop(c);
          }, 
          child: const Text("SAVE CATEGORY")
        )
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.drugTypes.where((d) => d.name.toLowerCase().contains(search.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Drug Category Master"), backgroundColor: Colors.cyan.shade700, foregroundColor: Colors.white),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          decoration: const InputDecoration(hintText: "Search Category...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          onChanged: (v) => setState(() => search = v),
        )),
        Expanded(child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (c, i) => ListTile(
            leading: CircleAvatar(backgroundColor: Colors.cyan.shade50, child: Text(list[i].id.replaceAll("DT-", ""), style: const TextStyle(fontSize: 10, color: Colors.cyan))),
            title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
            trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _showForm(dtype: list[i])),
          ),
        )),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add), backgroundColor: Colors.cyan.shade700, foregroundColor: Colors.white),
    );
  }
}
