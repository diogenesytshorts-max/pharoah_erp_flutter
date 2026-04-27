// FILE: lib/party_master.dart (Replacement Code - FIXED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class PartyMasterView extends StatefulWidget {
  final bool isSelectionMode; 
  const PartyMasterView({super.key, this.isSelectionMode = false});

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

    // Auto-extract PAN from GSTIN
    gstC.addListener(() {
      if (gstC.text.length >= 12) {
        String extractedPan = gstC.text.substring(2, 12).toUpperCase();
        if (panC.text != extractedPan) {
          panC.text = extractedPan;
        }
      }
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        // Fetch and cast the active SALE series list
        final List<NumberingSeries> activeSeries = ph.getSeriesByType("SALE")
            .where((s) => s.isActive).toList();

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(party == null ? "Create New Party/Ledger" : "Update Party Details"),
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
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedGroup,
                          decoration: const InputDecoration(labelText: "Account Group", border: OutlineInputBorder()),
                          items: ["Sundry Debtors", "Sundry Creditors"].map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(),
                          onChanged: (v) => selectedGroup = v!,
                        ),
                      ),
                    ],
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
                  
                  // DROPDOWN: Link Billing Series (FIXED TYPE)
                  DropdownButtonFormField<String>(
                    value: selectedSeriesId.isEmpty ? null : selectedSeriesId,
                    decoration: const InputDecoration(labelText: "Default Billing Series", border: OutlineInputBorder(), prefixIcon: Icon(Icons.layers_outlined)),
                    items: activeSeries.map((s) => DropdownMenuItem<String>(
                      value: s.id, 
                      child: Text("${s.name} (${s.prefix})", style: const TextStyle(fontSize: 13))
                    )).toList(),
                    onChanged: (v) => selectedSeriesId = v!,
                    hint: const Text("Select Series (Optional)"),
                  ),

                  const SizedBox(height: 15),
                  
                  DropdownButtonFormField<String>(
                    value: selectedPriceLevel,
                    decoration: const InputDecoration(labelText: "Default Pricing Level", border: OutlineInputBorder()),
                    items: ["A", "B", "C"].map((e) => DropdownMenuItem(value: e, child: Text("Apply Rate $e"))).toList(),
                    onChanged: (v) => selectedPriceLevel = v!,
                  ),
                  
                  const SizedBox(height: 10),

                  DropdownButtonFormField<String>(
                    value: selectedRoute.isEmpty ? null : selectedRoute,
                    decoration: const InputDecoration(labelText: "Assigned Route / Area", border: OutlineInputBorder()),
                    items: ph.routes.map((r) => DropdownMenuItem(value: r.name, child: Text(r.name))).toList(),
                    onChanged: (v) => selectedRoute = v!,
                    hint: const Text("Select Route"),
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

                if (party == null) {
                  ph.parties.add(newParty);
                } else {
                  int idx = ph.parties.indexWhere((p) => p.id == party.id);
                  if (idx != -1) ph.parties[idx] = newParty;
                }

                ph.save();

                if (widget.isSelectionMode) {
                  Navigator.pop(c);
                  Navigator.pop(context, newParty); 
                } else {
                  Navigator.pop(c);
                }
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
                hintText: "Search by Name or City...",
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
                            backgroundColor: p.group == "Sundry Debtors" ? Colors.green.shade100 : Colors.orange.shade100,
                            child: Icon(Icons.person, color: p.group == "Sundry Debtors" ? Colors.green : Colors.orange),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${p.group} | ${p.city} | ${p.route}"),
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

  Widget _sectionTitle(String title) => Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1))));

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) => Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(12))));

  void _confirmDelete(PharoahManager ph, Party p) {
    if (p.name == "CASH") return;
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Party?"), content: Text("Are you sure you want to delete '${p.name}'?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")), ElevatedButton(onPressed: () { ph.deleteParty(p.id); Navigator.pop(c); }, child: const Text("YES, DELETE"))]));
  }
}
