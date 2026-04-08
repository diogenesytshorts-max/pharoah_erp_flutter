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
  String searchText = "";
  
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final filteredMeds = ph.medicines.where((m) => 
      searchText.isEmpty ? true : m.name.toLowerCase().contains(searchText.toLowerCase())
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Product Master"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: Colors.blue, size: 30),
            onPressed: () => _showProductForm(context),
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Inventory...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (val) => setState(() => searchText = val),
            ),
          ),
          // List
          Expanded(
            child: ListView.builder(
              itemCount: filteredMeds.length,
              itemBuilder: (context, index) {
                final med = filteredMeds[index];
                return ListTile(
                  title: Text(med.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Pack: ${med.packing} | Stock: ${med.stock}"),
                  trailing: TextButton(
                    child: const Text("EDIT"),
                    onPressed: () => _showProductForm(context, med: med),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- ADD/EDIT FORM ---
  void _showProductForm(BuildContext context, {Medicine? med}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final nameController = TextEditingController(text: med?.name ?? "");
    final packingController = TextEditingController(text: med?.packing ?? "");
    final mrpController = TextEditingController(text: med?.mrp.toString() ?? "");
    final rateAController = TextEditingController(text: med?.rateA.toString() ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(med == null ? "New Product" : "Edit Product", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Product Name")),
              TextField(controller: packingController, decoration: const InputDecoration(labelText: "Packing")),
              TextField(controller: mrpController, decoration: const InputDecoration(labelText: "MRP"), keyboardType: TextInputType.number),
              TextField(controller: rateAController, decoration: const InputDecoration(labelText: "Rate A"), keyboardType: TextInputType.number),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.blue),
                onPressed: () {
                  final newMed = Medicine(
                    id: med?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.toUpperCase(),
                    packing: packingController.text,
                    mrp: double.tryParse(mrpController.text) ?? 0,
                    rateA: double.tryParse(rateAController.text) ?? 0,
                    rateB: 0, rateC: 0, stock: med?.stock ?? 0,
                  );
                  
                  if (med == null) {
                    ph.medicines.add(newMed);
                  } else {
                    int idx = ph.medicines.indexWhere((m) => m.id == med.id);
                    ph.medicines[idx] = newMed;
                  }
                  ph.save();
                  Navigator.pop(context);
                },
                child: const Text("SAVE PRODUCT", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
