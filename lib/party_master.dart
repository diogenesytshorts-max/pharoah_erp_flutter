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
    final gstC = TextEditingController(text: party?.gst ?? "");
    String selectedState = party?.state ?? ph.companyState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(party == null ? "Add New Party" : "Update Party Details"),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(nameC, "Firm Name (Mandatory)", Icons.business),
                _textField(phoneC, "Mobile Number", Icons.phone, isNum: true),
                _textField(addrC, "Full Address", Icons.location_on),
                StatefulBuilder(builder: (context, setDialogState) {
                  return DropdownButtonFormField<String>(
                    value: selectedState,
                    decoration: const InputDecoration(labelText: "State", border: OutlineInputBorder()),
                    items: states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedState = v!),
                  );
                }),
                const SizedBox(height: 10),
                _textField(cityC, "City", Icons.location_city),
                _textField(gstC, "GSTIN (15-Digit)", Icons.receipt_long),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              if (nameC.text.trim().isEmpty) return;

              final p = Party(
                id: party?.id ?? DateTime.now().toString(),
                name: nameC.text.trim().toUpperCase(),
                phone: phoneC.text.trim(),
                address: addrC.text.trim(),
                city: cityC.text.trim().toUpperCase(),
                state: selectedState,
                gst: gstC.text.trim().isNotEmpty ? gstC.text.trim().toUpperCase() : "N/A",
              );

              if (party == null) {
                ph.parties.add(p);
              } else {
                int idx = ph.parties.indexWhere((x) => x.id == party.id);
                if (idx != -1) ph.parties[idx] = p;
              }

              ph.save();
              Navigator.pop(c);
            },
            child: const Text("SAVE PARTY", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, PharoahManager ph, Party p) {
    if (p.name == "CASH") {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Default CASH party cannot be deleted!")));
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ph.deleteParty(p.id);
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Party deleted successfully!")));
            },
            child: const Text("YES, DELETE", style: TextStyle(color: Colors.white)),
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
        actions: [
          IconButton(icon: const Icon(Icons.person_add_alt_1, size: 28), onPressed: () => _showForm()),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.teal.shade50,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search by Name or City...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("No parties found."))
                : ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final item = filteredList[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: Colors.teal.shade100, child: const Icon(Icons.person, color: Colors.teal)),
                          title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("${item.city} | GST: ${item.gst}"),
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

  Widget _textField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
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
