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

  // List of Indian States for GST compliance
  final List<String> states = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", 
    "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", 
    "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", 
    "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", 
    "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal"
  ];

  void _showForm({Party? party}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    // Form Controllers
    final nameC = TextEditingController(text: party?.name ?? "");
    final phoneC = TextEditingController(text: party?.phone ?? "");
    final addrC = TextEditingController(text: party?.address ?? "");
    final cityC = TextEditingController(text: party?.city ?? "");
    final routeC = TextEditingController(text: party?.route ?? "");
    final emailC = TextEditingController(text: party?.email ?? "");
    final dlC = TextEditingController(text: party?.dl ?? "");
    final gstC = TextEditingController(text: party?.gst ?? "");
    final balC = TextEditingController(text: party?.openingBalance.toString() ?? "0.0");
    String selectedState = party?.state ?? ph.companyState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(party == null ? Icons.person_add : Icons.edit_note, color: Colors.teal),
            const SizedBox(width: 10),
            Text(party == null ? "Create New Party" : "Update Party Details"),
          ],
        ),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInputLabel("FIRM / CUSTOMER NAME"),
                _textField(nameC, "Enter Firm Name", icon: Icons.business),
                
                Row(
                  children: [
                    Expanded(child: _textField(phoneC, "Phone No", icon: Icons.phone, isNum: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(emailC, "Email ID", icon: Icons.email)),
                  ],
                ),

                _buildInputLabel("ADDRESS & LOCATION"),
                _textField(addrC, "Full Address", icon: Icons.location_on),
                
                StatefulBuilder(builder: (context, setDialogState) {
                  return DropdownButtonFormField<String>(
                    value: selectedState,
                    decoration: const InputDecoration(labelText: "State", border: OutlineInputBorder()),
                    items: states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedState = v!),
                  );
                }),
                
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _textField(cityC, "City")),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(routeC, "Route")),
                  ],
                ),

                _buildInputLabel("GST & STATUTORY"),
                Row(
                  children: [
                    Expanded(child: _textField(gstC, "GSTIN (15-Digit)", labelColor: Colors.blue)),
                    const SizedBox(width: 10),
                    Expanded(child: _textField(dlC, "Drug License")),
                  ],
                ),

                _buildInputLabel("ACCOUNTING"),
                _textField(balC, "Opening Balance (₹)", isNum: true, icon: Icons.account_balance_wallet),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (nameC.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Party Name is mandatory!")));
                return;
              }

              final p = Party(
                id: party?.id ?? DateTime.now().toString(),
                name: nameC.text.trim().toUpperCase(),
                phone: phoneC.text.trim(),
                email: emailC.text.trim().toLowerCase(),
                address: addrC.text.trim(),
                city: cityC.text.trim().toUpperCase(),
                state: selectedState,
                route: routeC.text.trim().toUpperCase(),
                gst: gstC.text.trim().isNotEmpty ? gstC.text.trim().toUpperCase() : "N/A",
                dl: dlC.text.trim().isNotEmpty ? dlC.text.trim().toUpperCase() : "N/A",
                openingBalance: double.tryParse(balC.text) ?? 0.0,
                rateType: "A",
              );

              if (party == null) {
                ph.parties.add(p);
                ph.addLog("MASTER", "New Party added: ${p.name}");
              } else {
                int idx = ph.parties.indexWhere((x) => x.id == party.id);
                if (idx != -1) ph.parties[idx] = p;
                ph.addLog("MASTER", "Party updated: ${p.name}");
              }

              ph.save();
              Navigator.pop(c);
            },
            child: const Text("SAVE PARTY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final filteredList = ph.parties
        .where((p) => p.name.toLowerCase().contains(search.toLowerCase()) || p.city.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Party / Ledger Master"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_1, size: 28), onPressed: () => _showForm()),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // Professional Search Bar
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.teal.shade50,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by Name or City...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),

          // Party List
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("No Parties found. Add a new customer or supplier."))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: item.isB2B ? Colors.blue.shade100 : Colors.teal.shade100,
                            child: Icon(item.isB2B ? Icons.business_rounded : Icons.person, color: item.isB2B ? Colors.blue.shade800 : Colors.teal.shade800),
                          ),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${item.city} | ${item.state}", style: const TextStyle(fontSize: 12)),
                              Text("GST: ${item.gst}", style: TextStyle(fontSize: 11, color: item.isB2B ? Colors.blue : Colors.grey)),
                            ],
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: item.isB2B ? Colors.blue.shade50 : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  item.isB2B ? "B2B" : "B2C",
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: item.isB2B ? Colors.blue.shade700 : Colors.grey.shade700),
                                ),
                              ),
                              const SizedBox(height: 5),
                              const Icon(Icons.edit_note, color: Colors.grey, size: 18),
                            ],
                          ),
                          onTap: () => _showForm(party: item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- UI Helpers ---

  Widget _buildInputLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
      ),
    );
  }

  Widget _textField(TextEditingController ctrl, String label, {bool isNum = false, IconData? icon, Color? labelColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
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
