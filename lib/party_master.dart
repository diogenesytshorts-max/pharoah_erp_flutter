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
  String searchText = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final filteredParties = ph.parties.where((p) => 
      searchText.isEmpty ? true : p.name.toLowerCase().contains(searchText.toLowerCase())
    ).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Party Master"),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.blue, size: 28),
            onPressed: () => _showPartyForm(context),
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
                hintText: "Search Party Name...",
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
              itemCount: filteredParties.length,
              itemBuilder: (context, index) {
                final party = filteredParties[index];
                return ListTile(
                  leading: CircleAvatar(child: Text(party.name[0])),
                  title: Text(party.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("City: ${party.city} | Phone: ${party.phone}"),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showPartyForm(context, party: party),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- ADD/EDIT PARTY FORM ---
  void _showPartyForm(BuildContext context, {Party? party}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final nameController = TextEditingController(text: party?.name ?? "");
    final phoneController = TextEditingController(text: party?.phone ?? "");
    final addressController = TextEditingController(text: party?.address ?? "");
    final cityController = TextEditingController(text: party?.city ?? "");
    final gstController = TextEditingController(text: party?.gst ?? "");

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(party == null ? "New Party Entry" : "Edit Party Details", 
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: "Firm Name")),
              TextField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone Number"), keyboardType: TextInputType.phone),
              TextField(controller: addressController, decoration: const InputDecoration(labelText: "Full Address")),
              TextField(controller: cityController, decoration: const InputDecoration(labelText: "City")),
              TextField(controller: gstController, decoration: const InputDecoration(labelText: "GSTIN Number")),
              const SizedBox(height: 25),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                onPressed: () {
                  if(nameController.text.isEmpty) return;
                  
                  final newParty = Party(
                    id: party?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                    name: nameController.text.toUpperCase(),
                    phone: phoneController.text,
                    address: addressController.text,
                    city: cityController.text,
                    gst: gstController.text.toUpperCase(),
                  );

                  if (party == null) {
                    ph.parties.add(newParty);
                  } else {
                    int idx = ph.parties.indexWhere((p) => p.id == party.id);
                    ph.parties[idx] = newParty;
                  }
                  ph.save();
                  Navigator.pop(context);
                },
                child: const Text("SAVE PARTY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
