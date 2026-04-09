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

    // Controllers for every single field
    final nameC = TextEditingController(text: med?.name ?? "");
    final packC = TextEditingController(text: med?.packing ?? "");
    final hsnC = TextEditingController(text: med?.hsnCode ?? "");
    final gstC = TextEditingController(text: med?.gst.toString() ?? "12.0");
    final mrpC = TextEditingController(text: med?.mrp.toString() ?? "");
    final pRC = TextEditingController(text: med?.purRate.toString() ?? "");
    final rAC = TextEditingController(text: med?.rateA.toString() ?? "");
    final rBC = TextEditingController(text: med?.rateB.toString() ?? "");
    final rCC = TextEditingController(text: med?.rateC.toString() ?? "");
    final stC = TextEditingController(text: med?.stock.toString() ?? "0");

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents accidental closing
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(med == null ? Icons.add_box : Icons.edit, color: Colors.purple),
            const SizedBox(width: 10),
            Text(med == null ? "New Product" : "Edit Product Details"),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Section 1: Basic Info
                _inputHeader("BASIC INFORMATION"),
                _textField(nameC, "Product Name (e.g. DOLO 650)"),
                Row(
                  children: [
                    Expanded(child: _textField(packC, "Packing (10 TAB)")),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(hsnC, "HSN Code")),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _textField(gstC, "GST %", isNum: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(mrpC, "MRP", isNum: true)),
                  ],
                ),

                const Divider(height: 30),

                // Section 2: Purchase & Valuation
                _inputHeader("PURCHASE & VALUATION"),
                _textField(pRC, "Purchase Rate (Cost Price)", isNum: true, labelColor: Colors.red),
                
                const SizedBox(height: 10),

                // Section 3: Selling Rates
                _inputHeader("SELLING PRICE LEVELS"),
                Row(
                  children: [
                    Expanded(child: _textField(rAC, "Rate A", isNum: true)),
                    const SizedBox(width: 5),
                    Expanded(child: _textField(rBC, "Rate B", isNum: true)),
                    const SizedBox(width: 5),
                    Expanded(child: _textField(rCC, "Rate C", isNum: true)),
                  ],
                ),

                const Divider(height: 30),

                // Section 4: Inventory
                _inputHeader("INVENTORY"),
                _textField(stC, "Current Stock Quantity", isNum: true, labelColor: Colors.blue),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
            onPressed: () {
              if (nameC.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name is required!")));
                return;
              }

              final m = Medicine(
                id: med?.id ?? DateTime.now().toString(),
                name: nameC.text.toUpperCase(),
                packing: packC.text.toUpperCase(),
                hsnCode: hsnC.text,
                gst: double.tryParse(gstC.text) ?? 12.0,
                mrp: double.tryParse(mrpC.text) ?? 0.0,
                purRate: double.tryParse(pRC.text) ?? 0.0,
                rateA: double.tryParse(rAC.text) ?? 0.0,
                rateB: double.tryParse(rBC.text) ?? 0.0,
                rateC: double.tryParse(rCC.text) ?? 0.0,
                stock: int.tryParse(stC.text) ?? 0,
              );

              if (med == null) {
                ph.medicines.add(m);
              } else {
                int idx = ph.medicines.indexWhere((x) => x.id == med.id);
                if (idx != -1) ph.medicines[idx] = m;
              }

              ph.save();
              Navigator.pop(c);
            },
            child: const Text("SAVE PRODUCT", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final filteredList = ph.medicines
        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Inventory / Product Master"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 30),
            onPressed: () => _showForm(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.purple[50],
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Product Name...",
                prefixIcon: const Icon(Icons.search, color: Colors.purple),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),

          // Product List
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("No Products Found", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: filteredList.length,
                    itemBuilder: (c, i) {
                      final item = filteredList[i];
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          title: Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Pack: ${item.packing} | HSN: ${item.hsnCode} | GST: ${item.gst}%"),
                              Row(
                                children: [
                                  Text("Stock: ", style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
                                  Text("${item.stock}", style: TextStyle(color: item.stock <= 5 ? Colors.red : Colors.green, fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 15),
                                  Text("Cost: ₹${item.purRate.toStringAsFixed(2)}", style: const TextStyle(color: Colors.blueGrey, fontSize: 12)),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("MRP", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                              Text("₹${item.mrp.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple, fontSize: 16)),
                            ],
                          ),
                          onTap: () => _showForm(med: item),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  // --- Helper Widgets for Form ---

  Widget _inputHeader(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String label, {bool isNum = false, Color? labelColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: labelColor),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      ),
    );
  }
}
