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

  // --- FORM DIALOG (ADD / EDIT) ---
  void _showForm({Party? party}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    // Form Controllers initialized with existing data or blank
    final nameC = TextEditingController(text: party?.name ?? "");
    final phoneC = TextEditingController(text: party?.phone ?? "");
    final addrC = TextEditingController(text: party?.address ?? "");
    final cityC = TextEditingController(text: party?.city ?? "");
    final gstC = TextEditingController(text: party?.gst ?? "");
    final dlC = TextEditingController(text: party?.dl ?? "");
    final emailC = TextEditingController(text: party?.email ?? "");
    String selectedState = party?.state ?? ph.companyState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(party == null ? "Add New Party" : "Edit Party Details"),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _inputField(nameC, "Firm Name (Mandatory)", Icons.business),
                _inputField(phoneC, "Mobile Number", Icons.phone, isNum: true),
                _inputField(emailC, "Email Address", Icons.email),
                _inputField(addrC, "Full Office Address", Icons.location_on),
                
                // State Selector
                StatefulBuilder(builder: (context, setDialogState) {
                  return DropdownButtonFormField<String>(
                    value: selectedState,
                    decoration: const InputDecoration(labelText: "State (For GST/POS)", border: OutlineInputBorder()),
                    items: states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedState = v!),
                  );
                }),
                const SizedBox(height: 12),
                
                _inputField(cityC, "City", Icons.location_city),
                
                Row(
                  children: [
                    Expanded(child: _inputField(gstC, "GSTIN No.", Icons.receipt_long)),
                    const SizedBox(width: 8),
                    Expanded(child: _inputField(dlC, "Drug License", Icons.medical_services)),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            onPressed: () {
              if (nameC.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name is required!")));
                return;
              }

              final p = Party(
                id: party?.id ?? DateTime.now().toString(),
                name: nameC.text.trim().toUpperCase(),
                phone: phoneC.text.trim(),
                address: addrC.text.trim(),
                city: cityC.text.trim().toUpperCase(),
                state: selectedState,
                gst: gstC.text.trim().isNotEmpty ? gstC.text.trim().toUpperCase() : "N/A",
                dl: dlC.text.trim().isNotEmpty ? dlC.text.trim().toUpperCase() : "N/A",
                email: emailC.text.trim().toLowerCase().isNotEmpty ? emailC.text.trim() : "N/A",
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
            child: const Text("SAVE PARTY"),
          ),
        ],
      ),
    );
  }

  // --- DELETE CONFIRMATION ---
  void _confirmDelete(BuildContext context, PharoahManager ph, Party p) {
    if (p.name == "CASH") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot delete default CASH party!")));
      return;
    }

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Party?"),
        content: Text("Are you sure you want to delete '${p.name}'? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              ph.deleteParty(p.id);
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Party Deleted Successfully!")));
            },
            child: const Text("YES, DELETE"),
          )
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
          // Search Section
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.teal.shade50,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Party by Name or City...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          
          // Party List
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("No records found."))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.teal.shade100, child: const Icon(Icons.person, color: Colors.teal)),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("${item.city} | DL: ${item.dl}"),
                              Text("GST: ${item.gst}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showForm(party: item)),
                              IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _confirmDelete(context, ph, item)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // --- REUSABLE INPUT FIELD ---
  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.all(12),
        ),
      ),
    );
  }
}
