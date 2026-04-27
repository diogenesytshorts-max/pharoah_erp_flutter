// FILE: lib/batch_master_view.dart (Replacement Code - FIXED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class BatchMasterView extends StatefulWidget {
  const BatchMasterView({super.key});

  @override
  State<BatchMasterView> createState() => _BatchMasterViewState();
}

class _BatchMasterViewState extends State<BatchMasterView> {
  Medicine? selectedMed;
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Filtering medicines for the top search bar
    List<Medicine> filteredMeds = ph.medicines.where((m) => 
      m.name.toLowerCase().contains(searchQuery.toLowerCase()) || 
      m.systemId.toLowerCase().contains(searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Central Batch Master"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- 1. MEDICINE SELECTOR SECTION ---
          _buildMedicineSearchSection(ph, filteredMeds),

          // --- 2. BATCHES LIST SECTION ---
          Expanded(
            child: selectedMed == null 
              ? _buildEmptyState() 
              : _buildBatchList(ph, selectedMed!),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicineSearchSection(PharoahManager ph, List<Medicine> filteredMeds) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("SELECT PRODUCT TO MANAGE BATCHES", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
          const SizedBox(height: 10),
          if (selectedMed == null)
            TextField(
              decoration: InputDecoration(
                hintText: "Search by Name or System ID (e.g. PH-10001)...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true, fillColor: Colors.grey.shade50,
              ),
              onChanged: (v) => setState(() => searchQuery = v),
            )
          else
            ListTile(
              tileColor: Colors.indigo.withOpacity(0.05),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12), 
                side: BorderSide(color: Colors.indigo.shade200)
              ),
              leading: const Icon(Icons.medication, color: Colors.indigo),
              title: Text(selectedMed!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("ID: ${selectedMed!.systemId} | Total Stock: ${selectedMed!.stock}"),
              trailing: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() => selectedMed = null)),
            ),
          
          if (selectedMed == null && searchQuery.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: filteredMeds.length,
                itemBuilder: (c, i) => ListTile(
                  title: Text(filteredMeds[i].name),
                  subtitle: Text(filteredMeds[i].systemId),
                  onTap: () => setState(() { selectedMed = filteredMeds[i]; searchQuery = ""; }),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBatchList(PharoahManager ph, Medicine med) {
    List<BatchInfo> batches = ph.batchHistory[med.identityKey] ?? [];

    if (batches.isEmpty) {
      return const Center(child: Text("No batch history found for this item."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: batches.length,
      itemBuilder: (c, i) {
        final b = batches[i];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Text(b.batch, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.indigo)),
                        if (b.isShell) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(5)), child: const Text("UNVERIFIED", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.orange))),
                      ]),
                      Text("Expiry: ${b.exp} | MRP: ₹${b.mrp}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ]),
                    _stockBadge(b.qty),
                  ],
                ),
                const Divider(height: 25),
                Row(
                  children: [
                    _actionBtn("ADJUST STOCK", Icons.exposure, Colors.orange, () => _showAdjustmentDialog(ph, med, b)),
                    const SizedBox(width: 10),
                    _actionBtn("EDIT INFO", Icons.edit_note, Colors.blue, () => _showEditMetadataDialog(ph, med, b)),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  // --- POPUP: STOCK ADJUSTMENT (+/-) ---
  void _showAdjustmentDialog(PharoahManager ph, Medicine med, BatchInfo b) {
    final qtyC = TextEditingController();
    String reason = "Breakage";

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          title: const Text("Adjust Batch Stock"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Adjusting: ${b.batch}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              TextField(
                controller: qtyC,
                keyboardType: const TextInputType.numberWithOptions(signed: true, decimal: true),
                decoration: const InputDecoration(labelText: "Quantity Change (e.g. -5 or +2)", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: reason,
                decoration: const InputDecoration(labelText: "Select Reason", border: OutlineInputBorder()),
                items: ["Breakage", "Shortage", "Sample Given", "Returned", "Stock Correction"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                onChanged: (v) => setDialogState(() => reason = v!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
              onPressed: () {
                double val = double.tryParse(qtyC.text) ?? 0;
                if (val == 0) return;
                ph.adjustBatchStock(medId: med.identityKey, batchNo: b.batch, adjQty: val, reason: reason);
                Navigator.pop(c);
              },
              child: const Text("UPDATE STOCK", style: TextStyle(color: Colors.white)),
            )
          ],
        );
      }),
    );
  }

  // --- POPUP: EDIT METADATA (Expiry, MRP etc) ---
  void _showEditMetadataDialog(PharoahManager ph, Medicine med, BatchInfo b) {
    final expC = TextEditingController(text: b.exp);
    final mrpC = TextEditingController(text: b.mrp.toString());
    final rateC = TextEditingController(text: b.rate.toString());

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Update Batch Info"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: expC, decoration: const InputDecoration(labelText: "Expiry (MM/YY)", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: mrpC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "MRP", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: rateC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Purchase Rate", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              ph.updateBatchMetadata(
                medId: med.identityKey, 
                batchNo: b.batch, 
                newExp: expC.text, 
                newMrp: double.tryParse(mrpC.text) ?? 0, 
                newRate: double.tryParse(rateC.text) ?? 0
              );
              Navigator.pop(c);
            },
            child: const Text("SAVE CHANGES"),
          )
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _stockBadge(double qty) {
    bool isNeg = qty < 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: isNeg ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: isNeg ? Colors.red.shade200 : Colors.green.shade200)),
      child: Column(children: [
        Text(isNeg ? "SHORTAGE" : "IN STOCK", style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isNeg ? Colors.red : Colors.green)),
        Text(qty.toInt().toString(), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: isNeg ? Colors.red.shade900 : Colors.green.shade900)),
      ]),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 16, color: color),
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        style: OutlinedButton.styleFrom(side: BorderSide(color: color.withOpacity(0.5)), padding: const EdgeInsets.symmetric(vertical: 12)),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 15),
          const Text("Search a product to manage its inventory history.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}
