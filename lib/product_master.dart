import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class ProductMasterView extends StatefulWidget {
  final bool isSelectionMode; // NAYA
  const ProductMasterView({super.key, this.isSelectionMode = false});

  @override State<ProductMasterView> createState() => _ProductMasterViewState();
}

class _ProductMasterViewState extends State<ProductMasterView> {
  String searchQuery = "";
  String? filterCompanyId;

  final List<String> drugForms = ["TAB", "CAP", "SYP", "INJ", "IV", "PCS", "EXT", "OINT", "DROP"];
  final List<String> storageOptions = ["Room Temp", "Refrigerated (2-8°C)", "Cool Place"];

  @override
  void initState() {
    super.initState();
    if (widget.isSelectionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showProductForm();
      });
    }
  }

  void _showSearchablePicker({
    required String title,
    required List<dynamic> items,
    required Function(dynamic) onSelected,
    required VoidCallback onQuickAdd,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        String localSearch = "";
        return StatefulBuilder(builder: (context, setPickerState) {
          final filtered = items.where((item) => item.name.toLowerCase().contains(localSearch.toLowerCase())).toList();

          return AlertDialog(
            title: Text("Select $title"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: "Search $title...",
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (v) => setPickerState(() => localSearch = v),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: filtered.isEmpty 
                      ? Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Text("No $title found."),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: filtered.length,
                          itemBuilder: (c, i) => ListTile(
                            title: Text(filtered[i].name),
                            onTap: () {
                              onSelected(filtered[i]);
                              Navigator.pop(context);
                            },
                          ),
                        ),
                  ),
                  const Divider(),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      onQuickAdd();
                    },
                    icon: const Icon(Icons.add),
                    label: Text("ADD NEW ${title.toUpperCase()}"),
                  )
                ],
              ),
            ),
          );
        });
      },
    );
  }

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

  void _showProductForm({Medicine? med}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    final nameC = TextEditingController(text: med?.name);
    final packC = TextEditingController(text: med?.packing);
    final rackC = TextEditingController(text: med?.rackNo);
    final hsnC = TextEditingController(text: med?.hsnCode);
    final reorderC = TextEditingController(text: med?.reorderLevel.toString() ?? "0");
    final gstC = TextEditingController(text: med?.gst.toString() ?? "12");
    
    String selForm = med?.drugForm ?? "TAB";
    bool naco = med?.isNarcotic ?? false;
    bool schH1 = med?.isScheduleH1 ?? false;
    String selStore = med?.storageCondition ?? "Room Temp";
    
    String? companyId = med?.companyId;
    String? saltId = med?.saltId;
    String companyName = companyId != null && companyId.isNotEmpty 
        ? ph.companies.firstWhere((c) => c.id == companyId, orElse: () => Company(id: "", name: "")).name 
        : "Tap to Select Company";
    String saltName = saltId != null && saltId.isNotEmpty 
        ? ph.salts.firstWhere((s) => s.id == saltId, orElse: () => Salt(id: "", name: "")).name 
        : "Tap to Select Salt";

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
                  Row(children: [
                    Expanded(child: _input(packC, "Packing *", Icons.inventory)),
                    const SizedBox(width: 10),
                    Expanded(child: DropdownButtonFormField<String>(
                      value: selForm,
                      decoration: const InputDecoration(labelText: "Drug Form", border: OutlineInputBorder()),
                      items: drugForms.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                      onChanged: (v) => setDialogState(() => selForm = v!),
                    )),
                  ]),
                  const SizedBox(height: 15),
                  _searchableField(
                    label: "Company",
                    value: companyName,
                    icon: Icons.business,
                    onTap: () => _showSearchablePicker(
                      title: "Company",
                      items: ph.companies,
                      onSelected: (val) => setDialogState(() { companyId = val.id; companyName = val.name; }),
                      onQuickAdd: () => _quickAddCompany(ph),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _searchableField(
                    label: "Salt / Composition",
                    value: saltName,
                    icon: Icons.science,
                    onTap: () => _showSearchablePicker(
                      title: "Salt",
                      items: ph.salts,
                      onSelected: (val) => setDialogState(() { saltId = val.id; saltName = val.name; }),
                      onQuickAdd: () => _quickAddSalt(ph),
                    ),
                  ),
                  _section("LEGAL & STORAGE"),
                  Row(children: [
                    Expanded(child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Narcotic", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      value: naco, 
                      onChanged: (v) => setDialogState(() => naco = v)
                    )),
                    Expanded(child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text("Sch. H1", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      value: schH1, 
                      onChanged: (v) => setDialogState(() => schH1 = v)
                    )),
                  ]),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selStore,
                    decoration: const InputDecoration(labelText: "Storage Condition", border: OutlineInputBorder(), prefixIcon: Icon(Icons.thermostat)),
                    items: storageOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setDialogState(() => selStore = v!),
                  ),
                  _section("TAX & INVENTORY"),
                  Row(children: [
                    Expanded(child: _input(hsnC, "HSN Code", Icons.tag)),
                    const SizedBox(width: 10),
                    Expanded(child: _input(gstC, "GST %", Icons.percent, isNum: true)),
                  ]),
                  Row(children: [
                    Expanded(child: _input(rackC, "Rack No", Icons.grid_3x3)),
                    const SizedBox(width: 10),
                    Expanded(child: _input(reorderC, "Min. Stock", Icons.warning_amber, isNum: true)),
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
                String newUniqueCode = med?.uniqueCode ?? "ITEM-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}";

                final newItem = Medicine(
                  id: med?.id ?? DateTime.now().toString(),
                  uniqueCode: newUniqueCode,
                  name: nameC.text.toUpperCase(),
                  packing: packC.text.toUpperCase(),
                  companyId: companyId ?? "",
                  saltId: saltId ?? "",
                  rackNo: rackC.text.toUpperCase(),
                  hsnCode: hsnC.text.toUpperCase().isEmpty ? "N/A" : hsnC.text.toUpperCase(),
                  reorderLevel: double.tryParse(reorderC.text) ?? 0.0,
                  gst: double.tryParse(gstC.text) ?? 12.0,
                  stock: med?.stock ?? 0.0,
                  drugForm: selForm,
                  isNarcotic: naco,
                  isScheduleH1: schH1,
                  storageCondition: selStore,
                  mrp: med?.mrp ?? 0, purRate: med?.purRate ?? 0, rateA: med?.rateA ?? 0, rateB: med?.rateB ?? 0, rateC: med?.rateC ?? 0,
                );

                if(med == null) ph.medicines.add(newItem);
                else { int i = ph.medicines.indexWhere((x)=>x.id==med.id); ph.medicines[i] = newItem; }
                ph.save(); 

                // NAYA logic selection return ke liye
                if (widget.isSelectionMode) {
                  Navigator.pop(c); // dialog
                  Navigator.pop(context, newItem); // screen return with item
                } else {
                  Navigator.pop(c);
                }
              }, 
              child: const Text("SAVE PRODUCT")
            )
          ],
        );
      }),
    );
  }

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.medicines.where((m) => 
      m.name.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("Inventory / Item Master"), backgroundColor: Colors.purple, foregroundColor: Colors.white),
      body: Column(children: [
        Container(padding: const EdgeInsets.all(15), color: Colors.purple.shade50, child: TextField(
          decoration: InputDecoration(
            hintText: "Search Product...", prefixIcon: const Icon(Icons.search, color: Colors.purple), 
            filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
          ), 
          onChanged: (v) => setState(() => searchQuery = v)
        )),
        Expanded(child: ListView.builder(
          itemCount: list.length, 
          itemBuilder: (c, i) {
            final m = list[i];
            return Card(
              elevation: 2, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), 
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: m.isNarcotic ? Colors.red.shade100 : Colors.purple.shade50,
                  child: Icon(m.drugForm == "INJ" ? Icons.colorize : Icons.medication, color: m.isNarcotic ? Colors.red : Colors.purple),
                ),
                title: Text("${m.name} - ${m.drugForm}", style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("Pack: ${m.packing} | Stock: ${m.stock} | Rack: ${m.rackNo}"),
                trailing: m.isScheduleH1 ? const Icon(Icons.report_problem, color: Colors.orange, size: 18) : null,
                onTap: () => _showProductForm(med: m),
              ),
            );
          }
        ))
      ]),
      floatingActionButton: FloatingActionButton(onPressed: () => _showProductForm(), child: const Icon(Icons.add), backgroundColor: Colors.purple, foregroundColor: Colors.white),
    );
  }

  Widget _section(String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Align(alignment: Alignment.centerLeft, child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1))));
  
  Widget _input(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 12), 
    child: TextField(
      controller: ctrl, keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, 
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: const OutlineInputBorder())
    )
  );

  Widget _searchableField({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
        child: Row(
          children: [
            Icon(icon, color: Colors.grey, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            )),
            const Icon(Icons.arrow_drop_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
