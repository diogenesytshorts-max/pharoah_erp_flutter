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

  // --- PRODUCT ENTRY & EDIT FORM ---
  void _showForm({Medicine? med}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    // Initializing controllers with existing data or empty strings
    final nameC = TextEditingController(text: med?.name ?? "");
    final packC = TextEditingController(text: med?.packing ?? "");
    final hsnC = TextEditingController(text: med?.hsnCode ?? "");
    final gstC = TextEditingController(text: med?.gst.toString() ?? "12.0");
    final mrpC = TextEditingController(text: med?.mrp.toString() ?? "");
    
    // Core Rates for Valuation and Sales
    final pRC = TextEditingController(text: med?.purRate.toString() ?? "");
    final rAC = TextEditingController(text: med?.rateA.toString() ?? "");
    final rBC = TextEditingController(text: med?.rateB.toString() ?? "");
    final rCC = TextEditingController(text: med?.rateC.toString() ?? "");
    
    // Inventory
    final stC = TextEditingController(text: med?.stock.toString() ?? "0");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(med == null ? Icons.add_box_rounded : Icons.edit_square, color: Colors.purple.shade700),
            const SizedBox(width: 10),
            Text(med == null ? "Add New Product" : "Update Product"),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sectionHeader("BASIC DETAILS"),
                _textField(nameC, "Product / Medicine Name", icon: Icons.medication),
                Row(
                  children: [
                    Expanded(child: _textField(packC, "Packing")),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(hsnC, "HSN Code")),
                  ],
                ),
                Row(
                  children: [
                    Expanded(child: _textField(gstC, "GST %", isNum: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(mrpC, "MRP (₹)", isNum: true, labelColor: Colors.purple)),
                  ],
                ),

                const Divider(height: 30, thickness: 1),

                _sectionHeader("PURCHASE & SELLING RATES"),
                // Critical for Stock Valuation Logic
                _textField(pRC, "Purchase Rate (Cost Price)", isNum: true, labelColor: Colors.red, icon: Icons.shopping_bag),
                
                Row(
                  children: [
                    Expanded(child: _textField(rAC, "Rate A", isNum: true)),
                    const SizedBox(width: 5),
                    Expanded(child: _textField(rBC, "Rate B", isNum: true)),
                    const SizedBox(width: 5),
                    Expanded(child: _textField(rCC, "Rate C", isNum: true)),
                  ],
                ),

                const Divider(height: 30, thickness: 1),

                _sectionHeader("INVENTORY CONTROL"),
                _textField(stC, "Current Stock Balance", isNum: true, icon: Icons.inventory, labelColor: Colors.blue.shade800),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple.shade700,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              if (nameC.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Product Name is required!")));
                return;
              }

              final m = Medicine(
                id: med?.id ?? DateTime.now().toString(),
                name: nameC.text.trim().toUpperCase(),
                packing: packC.text.trim().toUpperCase(),
                hsnCode: hsnC.text.trim(),
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
                ph.addLog("MASTER", "New Product Added: ${m.name}");
              } else {
                int idx = ph.medicines.indexWhere((x) => x.id == med.id);
                if (idx != -1) ph.medicines[idx] = m;
                ph.addLog("MASTER", "Product Updated: ${m.name}");
              }

              ph.save();
              Navigator.pop(c);
            },
            child: const Text("SAVE PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Real-time filtering logic
    final filteredList = ph.medicines
        .where((m) => m.name.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Inventory / Stock Master"),
        backgroundColor: Colors.purple.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, size: 30),
            onPressed: () => _showForm(),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Professional Search Bar
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.purple.shade50,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by Product Name...",
                prefixIcon: const Icon(Icons.search, color: Colors.purple),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),

          // Main Product List
          Expanded(
            child: filteredList.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text("No products found in inventory.", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      bool isLowStock = item.stock <= 5;

                      return Card(
                        elevation: 2,
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
                              Text("Pack: ${item.packing} | HSN: ${item.hsnCode}"),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Text("Stock: ", style: TextStyle(fontSize: 12)),
                                  Text(
                                    "${item.stock}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold, 
                                      color: isLowStock ? Colors.red : Colors.green.shade700
                                    ),
                                  ),
                                  const SizedBox(width: 15),
                                  Text(
                                    "Cost: ₹${item.purRate.toStringAsFixed(2)}",
                                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text("MRP", style: TextStyle(fontSize: 10, color: Colors.grey)),
                              Text(
                                "₹${item.mrp.toStringAsFixed(2)}",
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple.shade700, fontSize: 16),
                              ),
                            ],
                          ),
                          onTap: () => _showForm(med: item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPER WIDGETS ---

  Widget _sectionHeader(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          title,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1),
        ),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String label, {bool isNum = false, IconData? icon, Color? labelColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(fontSize: 12, color: labelColor),
          prefixIcon: icon != null ? Icon(icon, size: 18) : null,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}
