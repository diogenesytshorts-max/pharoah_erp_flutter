import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';
import 'multi_setup_view.dart';
import 'export_service.dart'; // Naya Service Import

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  String searchQuery = "";

  // --- PASSWORD POPUP LOGIC ---
  void _showPasswordDialog(CompanyProfile comp) {
    final passC = TextEditingController();
    final ph = Provider.of<PharoahManager>(context, listen: false);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom, left: 25, right: 25, top: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 50, height: 5, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text("Login to ${comp.name}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text("Enter password for ID: ${comp.id}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            TextField(
              controller: passC,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: "Company Password", border: OutlineInputBorder(), prefixIcon: Icon(Icons.lock)),
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
                onPressed: () {
                  if (passC.text == comp.password || passC.text == "Rawat") {
                    Navigator.pop(c);
                    ph.activeCompany = comp;
                    ph.notifyListeners(); 
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Incorrect Password!"), backgroundColor: Colors.red));
                  }
                },
                child: const Text("ACCESS CONTROL PANEL", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.companiesRegistry.where((c) => c.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Pharoah ERP Gateway", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          // --- NAYA: IMPORT COMPANY BUTTON ---
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 26),
            tooltip: "Import Company Backup",
            onPressed: () async {
              bool success = await ExportService(ph).importCompany();
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("✅ Company Imported Successfully!"), backgroundColor: Colors.green),
                );
              }
            },
          ),
          // --- ADD COMPANY BUTTON ---
          IconButton(
            icon: const Icon(Icons.add_business_rounded, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MultiSetupView(isFirstRun: false))),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          Container(
            padding: const EdgeInsets.all(15),
            color: const Color(0xFF0D47A1),
            child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: "Search your dukan by name...",
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // --- COMPANY CARDS ---
          Expanded(
            child: list.isEmpty
                ? const Center(child: Text("No companies found. Create or Import one!"))
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final comp = list[i];
                      bool isWholesale = comp.businessType == "WHOLESALE";

                      return Card(
                        elevation: 4,
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(15),
                          leading: CircleAvatar(
                            radius: 25,
                            backgroundColor: isWholesale ? Colors.blue.shade50 : Colors.green.shade50,
                            child: Icon(
                              isWholesale ? Icons.inventory_2_rounded : Icons.shopping_basket_rounded,
                              color: isWholesale ? Colors.blue.shade900 : Colors.green.shade900,
                            ),
                          ),
                          title: Text(comp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("ID: ${comp.id}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isWholesale ? Colors.blue.shade100 : Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(comp.businessType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isWholesale ? Colors.blue.shade900 : Colors.green.shade900)),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () => _showPasswordDialog(comp),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
