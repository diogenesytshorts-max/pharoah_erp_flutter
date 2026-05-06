// FILE: lib/party_master.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class PartyMasterView extends StatefulWidget {
  final bool isSelectionMode; 
  final Map<String, dynamic>? preFillData; // NAYA: CSV se aane wala data
  
  const PartyMasterView({super.key, this.isSelectionMode = false, this.preFillData});
  // ...

  @override
  State<PartyMasterView> createState() => _PartyMasterViewState();
}

class _PartyMasterViewState extends State<PartyMasterView> {
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    if (widget.isSelectionMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showPartyForm();
      });
    }
  }

  // ===========================================================================
  // NAYA HELPER: SEARCHABLE STATE PICKER WITH FREQUENCY SORTING
  // ===========================================================================
  void _showStateSearchPicker(BuildContext context, PharoahManager ph, Function(String) onSelect) {
    showDialog(
      context: context,
      builder: (context) {
        String localSearch = "";
        return StatefulBuilder(builder: (context, setPickerState) {
          // Manager se frequency sorted list mangwana
          final sortedList = ph.getSortedStates();
          // Search filter apply karna
          final filtered = sortedList.where((s) => s.toLowerCase().contains(localSearch.toLowerCase())).toList();

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text("Select State / Place of Supply", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: "Search State (e.g. Haryana)",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setPickerState(() => localSearch = v),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 350,
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemBuilder: (c, i) {
                        String stateName = filtered[i];
                        // Check if this is a top-used state (count > 0 in manager)
                        bool isFrequent = (ph.parties.where((p) => p.state == stateName).length) > 0;
                        
                        return ListTile(
                          title: Text(stateName, style: TextStyle(fontWeight: isFrequent ? FontWeight.bold : FontWeight.normal)),
                          trailing: isFrequent ? const Icon(Icons.stars_rounded, color: Colors.orange, size: 18) : null,
                          onTap: () {
                            onSelect(stateName);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        });
      },
    );
  }

  // --- ADD / EDIT FORM DIALOG ---
  void _showPartyForm({Party? party}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    final nameC = TextEditingController(text: party?.name);
    final phoneC = TextEditingController(text: party?.phone);
    final emailC = TextEditingController(text: party?.email);
    final addressC = TextEditingController(text: party?.address);
    final cityC = TextEditingController(text: party?.city);
    final gstC = TextEditingController(text: party?.gst);
    final panC = TextEditingController(text: party?.pan);
    final dlC = TextEditingController(text: party?.dl);
    final dlExpC = TextEditingController(text: party?.dlExp);
    final transportC = TextEditingController(text: party?.transport);
    final opBalC = TextEditingController(text: party?.opBal.toString() ?? "0.0");
    final creditLimitC = TextEditingController(text: party?.creditLimit.toString() ?? "0.0");
    final creditDaysC = TextEditingController(text: party?.creditDays.toString() ?? "0");

    String selectedGroup = party?.group ?? "Sundry Debtors";
    String selectedPriceLevel = party?.priceLevel ?? "A";
    String selectedRoute = (party?.route != null && party!.route.isNotEmpty) ? party.route : "";
    String selectedSeriesId = party?.defaultSeriesId ?? "";
    String selectedState = party?.state ?? pf?['state'] ?? "Rajasthan";
    // NAYA: Selected State management
    String selectedState = party?.state ?? "Rajasthan";

    gstC.addListener(() {
      if (gstC.text.length >= 12) {
        String extractedPan = gstC.text.substring(2, 12).toUpperCase();
        if (panC.text != extractedPan) { panC.text = extractedPan; }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        final List<NumberingSeries> activeSeries = ph.getSeriesByType("SALE").where((s) => s.isActive).toList();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(party == null ? "Create New Party" : "Update Party"),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _sectionTitle("BASIC INFORMATION"),
                  _inputField(nameC, "Party/Firm Name *", Icons.business),
                  _inputField(phoneC, "Mobile Number", Icons.phone, isNum: true),
                  _inputField(emailC, "Email Address", Icons.email),
                  _inputField(addressC, "Full Address", Icons.location_on),
                  
                  Row(
                    children: [
                      Expanded(child: _inputField(cityC, "City", Icons.location_city)),
                      const SizedBox(width: 10),
                      // NAYA: Searchable State Field
                      Expanded(child: _searchableBox(
                        label: "State / Supply Place",
                        value: selectedState,
                        icon: Icons.map_outlined,
                        onTap: () => _showStateSearchPicker(context, ph, (val) => setDialogState(() => selectedState = val)),
                      )),
                    ],
                  ),
                  
                  const SizedBox(height: 15),
                  DropdownButtonFormField<String>(
                    value: selectedGroup,
                    decoration: const InputDecoration(labelText: "Account Group", border: OutlineInputBorder()),
                    items: ["Sundry Debtors", "Sundry Creditors"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => selectedGroup = v!,
                  ),

                  const SizedBox(height: 20),
                  _sectionTitle("TAX & LICENSES"),
                  _inputField(gstC, "GSTIN Number", Icons.receipt_long),
                  _inputField(panC, "PAN Card", Icons.badge_outlined),
                  Row(
                    children: [
                      Expanded(child: _inputField(dlC, "Drug License (DL)", Icons.medical_services)),
                      const SizedBox(width: 10),
                      Expanded(child: _inputField(dlExpC, "DL Expiry", Icons.event_busy)),
                    ],
                  ),
                  
                  const SizedBox(height: 20),
                  _sectionTitle("BILLING & AUTOMATION"),
                  
                  DropdownButtonFormField<String>(
                    value: selectedSeriesId.isEmpty ? null : selectedSeriesId,
                    decoration: const InputDecoration(labelText: "Default Billing Series", border: OutlineInputBorder(), prefixIcon: Icon(Icons.layers_outlined)),
                    items: activeSeries.map((s) => DropdownMenuItem<String>(value: s.id, child: Text("${s.name} (${s.prefix})"))).toList(),
                    onChanged: (v) => selectedSeriesId = v!,
                    hint: const Text("Select Series"),
                  ),

                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        value: selectedPriceLevel,
                        decoration: const InputDecoration(labelText: "Pricing Level", border: OutlineInputBorder()),
                        items: ["A", "B", "C"].map((e) => DropdownMenuItem(value: e, child: Text("Rate $e"))).toList(),
                        onChanged: (v) => selectedPriceLevel = v!,
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: DropdownButtonFormField<String>(
                        value: selectedRoute.isEmpty ? null : selectedRoute,
                        decoration: const InputDecoration(labelText: "Route / Area", border: OutlineInputBorder()),
                        items: ph.routes.map((r) => DropdownMenuItem(value: r.name, child: Text(r.name))).toList(),
                        onChanged: (v) => selectedRoute = v!,
                        hint: const Text("Select Route"),
                      )),
                    ],
                  ),
                  _inputField(opBalC, "Opening Balance (₹)", Icons.account_balance_wallet, isNum: true),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () {
                if (nameC.text.trim().isEmpty) return;

                final newParty = Party(
                  id: party?.id ?? DateTime.now().toString(),
                  name: nameC.text.trim().toUpperCase(),
                  group: selectedGroup,
                  phone: phoneC.text.trim(),
                  email: emailC.text.trim().toLowerCase(),
                  address: addressC.text.trim(),
                  city: cityC.text.trim().toUpperCase(),
                  state: selectedState, // NAYA: Value mapped from picker
                  gst: gstC.text.trim().toUpperCase(),
                  pan: panC.text.trim().toUpperCase(),
                  dl: dlC.text.trim().toUpperCase(),
                  dlExp: dlExpC.text.trim(),
                  creditLimit: double.tryParse(creditLimitC.text) ?? 0.0,
                  creditDays: int.tryParse(creditDaysC.text) ?? 0,
                  priceLevel: selectedPriceLevel,
                  route: selectedRoute,
                  transport: transportC.text.trim(),
                  opBal: double.tryParse(opBalC.text) ?? 0.0,
                  defaultSeriesId: selectedSeriesId, 
                );

                if (party == null) ph.parties.add(newParty);
                else { int idx = ph.parties.indexWhere((p) => p.id == party.id); if (idx != -1) ph.parties[idx] = newParty; }

                ph.save();
                if (widget.isSelectionMode) { Navigator.pop(c); Navigator.pop(context, newParty); } 
                else { Navigator.pop(c); }
              },
              child: const Text("SAVE PARTY"),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final filteredList = ph.parties.where((p) => 
      p.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
      p.city.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(title: const Text("Party Master"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.indigo.shade50,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Name or City...",
                prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("No parties found."))
                : ListView.builder(
                    itemCount: filteredList.length,
                    padding: const EdgeInsets.all(10),
                    itemBuilder: (context, index) {
                      final p = filteredList[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: p.group == "Sundry Debtors" ? Colors.green.shade50 : Colors.orange.shade50,
                            child: Icon(Icons.person, color: p.group == "Sundry Debtors" ? Colors.green : Colors.orange),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${p.group} | ${p.city}, ${p.state}"),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showPartyForm(party: p)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDelete(ph, p)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPartyForm(),
        backgroundColor: Colors.indigo,
        icon: const Icon(Icons.add),
        label: const Text("ADD NEW PARTY", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _sectionTitle(String title) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1))));

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 18), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(10))));

  // NAYA: Box style trigger for searchable picker
  Widget _searchableBox({required String label, required String value, required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
        child: Row(children: [
          Icon(icon, color: Colors.grey, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
            Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
          ])),
          const Icon(Icons.arrow_drop_down, color: Colors.grey),
        ]),
      ),
    );
  }

  void _confirmDelete(PharoahManager ph, Party p) {
    if (p.name == "CASH") return;
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Party?"), content: Text("Are you sure you want to delete '${p.name}'?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")), ElevatedButton(onPressed: () { ph.deleteParty(p.id); Navigator.pop(c); }, child: const Text("YES, DELETE"))]));
  }
}
