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
  String searchQuery = "";
  String? filterCompanyId;

  // --- 1. QUICK ADD DIALOGS ---
  void _quickAddCompany(PharoahManager ph) {
    final cC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Quick Add Company"),
      content: TextField(controller: cC, decoration: const InputDecoration(labelText: "Company Name"), textCapitalization: TextCapitalization.characters),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
        ElevatedButton(onPressed: () {
          if(cC.text.isNotEmpty) {
            ph.addCompany(Company(id: DateTime.now().toString(), name: cC.text.toUpperCase()));
            Navigator.pop(c);
          }
        }, child: const Text("ADD"))
      ],
    ));
  }

  void _quickAddSalt(PharoahManager ph) {
    final sC = TextEditingController();
    showDialog(context: context, builder: (c) => AlertDialog(
      title: const Text("Quick Add Salt"),
      content: TextField(controller: sC, decoration: const InputDecoration(labelText: "Salt Name"), textCapitalization: TextCapitalization.characters),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
        ElevatedButton(onPressed: () {
          if(sC.text.isNotEmpty) {
            ph.addSalt(Salt(id: DateTime.now().toString(), name: sC.text.toUpperCase()));
            Navigator.pop(c);
          }
        }, child: const Text("ADD"))
      ],
    ));
  }

  // --- 2. MAIN PRODUCT FORM ---
  void _showProductForm({Medicine? med}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    final nameC = TextEditingController(text: med?.name);
    final packC = TextEditingController(text: med?.packing);
    final rackC = TextEditingController(text: med?.rackNo);
    final convC = TextEditingController(text: med?.conversion.toString() ?? "1");
    final reorderC = TextEditingController(text: med?.reorderLevel.toString() ?? "0");
    final gstC = TextEditingController(text: med?.gst.toString() ?? "12");
    
    // Pricing (Optional)
    final mrpC = TextEditingController(text: med?.mrp == 0 ? "" : med?.mrp.toString());
    final purRC = TextEditingController(text: med?.purRate == 0 ? "" : med?.purRate.toString());
    final rAC = TextEditingController(text: med?.rateA == 0 ? "" : med?.rateA.toString());
    final rBC = TextEditingController(text: med?.rateB == 0 ? "" : med?.rateB.toString());
    final rCC = TextEditingController(text: med?.rateC == 0 ? "" : med?.rateC.toString());

    String? selCompany = med?.companyId.isEmpty ?? true ? null : med?.companyId;
    String? selSalt = med?.saltId.isEmpty ?? true ? null : med?.saltId;
    String? selDType = med?.drugTypeId.isEmpty ?? true ? null : med?.drugTypeId;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(med == null ? "Add New Product" : "Edit Product"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _section("PRIMARY DETAILS"),
                  _input(nameC, "Product Name *", Icons.medication),
                  _input(packC, "Packing (e.g. 10 TAB / 100ML) *", Icons.inventory),
                  
                  // Company Dropdown with Quick Add
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: selCompany,
                      decoration: const InputDecoration(labelText: "Company / Mfr", border: OutlineInputBorder()),
                      items: ph.companies.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontSize: 10)))).toList(),
                      onChanged: (v) => setDialogState(() => selCompany = v),
                    )),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.brown), onPressed: () => _quickAddCompany(ph)),
                  ]),
                  const SizedBox(height: 10),

                  // Salt Dropdown with Quick Add
                  Row(children: [
                    Expanded(child: DropdownButtonFormField<String>(
                      value: selSalt,
                      decoration: const InputDecoration(labelText: "Salt / Composition", border: OutlineInputBorder()),
                      items: ph.salts.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name, style: const TextStyle(fontSize: 10)))).toList(),
                      onChanged: (v) => setDialogState(() => selSalt = v),
                    )),
                    IconButton(icon: const Icon(Icons.add_circle, color: Colors.deepOrange), onPressed: () => _quickAddSalt(ph)),
                  ]),
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: selDType,
                    decoration: const InputDecoration(labelText: "Drug Category", border: OutlineInputBorder()),
                    items: ph.drugTypes.map((e) => DropdownMenuItem(value: e.id, child: Text(e.name))).toList(),
                    onChanged: (v) => setDialogState(() => selDType = v),
                  ),

                  _section("INVENTORY & UNIT"),
                  Row(children: [
                    Expanded(child: _input(convC, "1 Box = ? Units", Icons.unfold_more, isNum: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _input(rackC, "Rack / Shelf No", Icons.grid_view)),
                  ]),
                  _input(reorderC, "Min. Stock Level (Alert)", Icons.warning_amber, isNum: true),

                  _section("PRICING & TAX (OPTIONAL)"),
                  Row(children: [
                    Expanded(child: _input(gstC, "GST %", Icons.percent, isNum: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _input(mrpC, "MRP ₹", Icons.currency_rupee, isNum: true)),
                  ]),
                  _input(purRC, "Purchase Rate (Cost) ₹", Icons.shopping_cart, isNum: true),
                  Row(children: [
                    Expanded(child: _input(rAC, "Rate A", Icons.label, isNum: true)),
                    const SizedBox(width: 5),
                    Expanded(child: _input(rBC, "Rate B", Icons.label, isNum: true)),
                    const SizedBox(width: 5),
                    Expanded(child: _input(rCC, "Rate C", Icons.label, isNum: true)),
                  ]),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () {
                if(nameC.text.isEmpty || packC.text.isEmpty) return;
                final newItem = Medicine(
                  id: med?.id ?? DateTime.now().toString(),
                  name: nameC.text.toUpperCase(),
                  packing: packC.text.toUpperCase(),
                  companyId: selCompany ?? "",
                  saltId: selSalt ?? "",
                  drugTypeId: selDType ?? "",
                  rackNo: rackC.text.toUpperCase(),
                  conversion: int.tryParse(convC.text) ?? 1,
                  reorderLevel: double.tryParse(reorderC.text) ?? 0.0,
                  gst: double.tryParse(gstC.text) ?? 12.0,
                  mrp: double.tryParse(mrpC.text) ?? 0.0,
                  purRate: double.tryParse(purRC.text) ?? 0.0,
                  rateA: double.tryParse(rAC.text) ?? 0.0,
                  rateB: double.tryParse(rBC.text) ?? 0.0,
                  rateC: double.tryParse(rCC.text) ?? 0.0,
                  stock: med?.stock ?? 0.0,
                );
                if(med == null) ph.medicines.add(newItem);
                else { int i = ph.medicines.indexWhere((x)=>x.id==med.id); ph.medicines[i] = newItem; }
                ph.save(); Navigator.pop(c);
              }, 
              child: const Text("SAVE PRODUCT")
            )
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // Logic: Filter by search and company
    final list = ph.medicines.where((m) {
      bool matchSearch = m.name.toLowerCase().contains(searchQuery.toLowerCase());
      bool matchCompany = filterCompanyId == null || m.companyId == filterCompanyId;
      return matchSearch && matchCompany;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Inventory / Item Master"),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // SEARCH & FILTER BAR
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.purple.shade50,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search Product...",
                    prefixIcon: const Icon(Icons.search, color: Colors.purple),
                    filled: true, fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    contentPadding: EdgeInsets.zero
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: const Text("ALL COMPANIES"),
                          selected: filterCompanyId == null,
                          onSelected: (v) => setState(() => filterCompanyId = null),
                        ),
                      ),
                      ...ph.companies.take(15).map((c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c.name),
                          selected: filterCompanyId == c.id,
                          onSelected: (v) => setState(() => filterCompanyId = v ? c.id : null),
                        ),
                      )),
                    ],
                  ),
                )
              ],
            ),
          ),

          // PRODUCT LIST
          Expanded(
            child: list.isEmpty 
              ? const Center(child: Text("No items found."))
              : ListView.builder(
                  itemCount: list.length,
                  padding: const EdgeInsets.all(10),
                  itemBuilder: (c, i) {
                    final m = list[i];
                    final companyName = ph.companies.firstWhere((co) => co.id == m.companyId, orElse: () => Company(id: "", name: "No Company")).name;
                    bool isLowStock = m.stock <= m.reorderLevel;

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isLowStock ? Colors.red.shade50 : Colors.purple.shade50,
                          child: Icon(Icons.medication, color: isLowStock ? Colors.red : Colors.purple),
                        ),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Pack: ${m.packing} | $companyName\nStock: ${m.stock} | Rack: ${m.rackNo}"),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text("MRP", style: TextStyle(fontSize: 9, color: Colors.grey)),
                            Text("₹${m.mrp.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                          ],
                        ),
                        onTap: () => _showProductForm(med: m),
                      ),
                    );
                  },
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showProductForm(),
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("NEW PRODUCT", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _section(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Align(alignment: Alignment.centerLeft, child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1))));

  Widget _input(ctrl, label, icon, {bool isNum = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: ctrl,
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(12)),
    ),
  );
}
