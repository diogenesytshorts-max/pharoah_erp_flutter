// FILE: lib/gateway/company_list_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import 'company_registry_model.dart';
import 'multi_setup_view.dart';
import 'export_service.dart'; 

class CompanyListScreen extends StatefulWidget {
  const CompanyListScreen({super.key});

  @override
  State<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends State<CompanyListScreen> {
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Filtering companies based on search
    final list = ph.companiesRegistry.where((c) => 
      c.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
      c.id.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Pharoah ERP Gateway", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        actions: [
          // IMPORT BACKUP
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: () async {
              bool success = await ExportService(ph).importCompany();
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Backup Imported!")));
              }
            },
          ),
          // ADD NEW BUSINESS
          IconButton(
            icon: const Icon(Icons.add_business_rounded, size: 28),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (c) => const MultiSetupView(isFirstRun: false)));
            },
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
                hintText: "Search your business...",
                hintStyle: const TextStyle(color: Colors.white60),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),

          // --- REGISTERED COMPANIES LIST ---
          Expanded(
            child: list.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final comp = list[i];
                      bool isWholesale = comp.businessType == "WHOLESALE";

                      return Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(color: Colors.grey.shade200)
                        ),
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
                              const SizedBox(height: 5),
                              _typeBadge(comp.businessType, isWholesale),
                            ],
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                          onTap: () {
                            // Seedha active company set karo, password LoginView me puchenge
                            ph.activeCompany = comp;
                            ph.notifyListeners();
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(String type, bool isW) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isW ? Colors.blue.shade100 : Colors.green.shade100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(type, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isW ? Colors.blue.shade900 : Colors.green.shade900)),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.storefront_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("No registered businesses found.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
