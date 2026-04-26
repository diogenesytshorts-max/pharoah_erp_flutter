// FILE: lib/inventory_intel/shortage_register.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';

class ShortageRegister extends StatefulWidget {
  const ShortageRegister({super.key});

  @override
  State<ShortageRegister> createState() => _ShortageRegisterState();
}

class _ShortageRegisterState extends State<ShortageRegister> {
  String searchQuery = "";
  String? filterCompany;

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // 1. Filter Shortage List
    List<ShortageItem> list = ph.shortages.where((s) {
      bool matchesSearch = s.medicineName.toLowerCase().contains(searchQuery.toLowerCase());
      bool matchesCompany = filterCompany == null || s.companyName == filterCompany;
      return matchesSearch && matchesCompany;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Shortage & Order Register"),
        backgroundColor: Colors.red.shade900,
        foregroundColor: Colors.white,
        actions: [
          // --- AUTO INTELLIGENCE SCAN BUTTON ---
          IconButton(
            icon: const Icon(Icons.psychology_alt_rounded),
            tooltip: "Run Smart Scan",
            onPressed: () {
              ph.runAutoShortageScan();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Intelligence Scan Complete! Required stocks updated."), backgroundColor: Colors.indigo)
              );
            },
          )
        ],
      ),
      body: Column(
        children: [
          _buildTopFilters(ph),
          
          Expanded(
            child: list.isEmpty 
              ? _buildEmptyState() 
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  itemBuilder: (c, i) => _buildShortageCard(ph, list[i]),
                ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showManualAddDialog(ph),
        backgroundColor: Colors.red.shade900,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text("ADD MANUAL SHORTAGE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildTopFilters(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.red.shade900,
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: "Search Shortage Items...",
              hintStyle: const TextStyle(color: Colors.white60),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true, fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShortageCard(PharoahManager ph, ShortageItem item) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        title: Row(
          children: [
            Text(item.medicineName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Spacer(),
            _sourceBadge(item.source),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text("Stock: ${item.currentStock.toInt()} | Avg Monthly: ${_calcAvg(ph, item)}", style: const TextStyle(fontSize: 11)),
            if (item.customerName.isNotEmpty) 
              Text("Demand By: ${item.customerName}", style: const TextStyle(fontSize: 11, color: Colors.indigo, fontWeight: FontWeight.bold)),
          ],
        ),
        trailing: Container(
          width: 80,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
          child: Column(
            children: [
              const Text("ORDER", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.red)),
              Text(item.qtyRequired.toInt().toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.red)),
            ],
          ),
        ),
        onLongPress: () => ph.deleteShortage(item.id),
      ),
    );
  }

  Widget _sourceBadge(String src) {
    bool isAuto = src == "Auto";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: isAuto ? Colors.blue.shade50 : Colors.orange.shade50, borderRadius: BorderRadius.circular(5)),
      child: Text(isAuto ? "SYSTEM" : "MANUAL", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isAuto ? Colors.blue.shade800 : Colors.orange.shade900)),
    );
  }

  String _calcAvg(PharoahManager ph, ShortageItem it) {
    double avg = ph.calculateAvgMonthlySale(it.medicineId);
    return avg.toStringAsFixed(1);
  }

  void _showManualAddDialog(PharoahManager ph) {
    final qtyC = TextEditingController();
    final custC = TextEditingController();
    Medicine? selectedMed;
    String medSearch = "";

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Add Manual Shortage"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedMed == null) ...[
                  TextField(
                    decoration: const InputDecoration(hintText: "Search Medicine...", border: OutlineInputBorder()),
                    onChanged: (v) => setDialogState(() => medSearch = v),
                  ),
                  SizedBox(
                    height: 150,
                    child: ListView(
                      children: ph.medicines.where((m) => m.name.toLowerCase().contains(medSearch.toLowerCase())).map((m) => ListTile(
                        title: Text(m.name),
                        onTap: () => setDialogState(() => selectedMed = m),
                      )).toList(),
                    ),
                  )
                ] else ...[
                  ListTile(
                    tileColor: Colors.grey.shade100,
                    title: Text(selectedMed!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setDialogState(() => selectedMed = null)),
                  ),
                  const SizedBox(height: 15),
                  TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Requirement Qty", border: OutlineInputBorder())),
                  const SizedBox(height: 10),
                  TextField(controller: custC, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: "Customer Name (Optional)", border: OutlineInputBorder())),
                ]
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: selectedMed == null ? null : () {
                ph.addManualShortage(med: selectedMed!, qty: double.tryParse(qtyC.text) ?? 1, cust: custC.text);
                Navigator.pop(c);
              },
              child: const Text("ADD TO LIST"),
            )
          ],
        );
      }),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text("Shortage list is clear. All stocks are healthy!", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
