// FILE: lib/inventory_intel/purchase_order_builder.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';

class PurchaseOrderBuilder extends StatefulWidget {
  const PurchaseOrderBuilder({super.key});

  @override
  State<PurchaseOrderBuilder> createState() => _PurchaseOrderBuilderState();
}

class _PurchaseOrderBuilderState extends State<PurchaseOrderBuilder> {
  Party? selectedDistributor;
  List<String> selectedShortageIds = [];
  Map<String, double> finalOrderQtys = {}; // To store manually adjusted quantities
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    // Initialize qtys from shortage list
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      for (var s in ph.shortages) {
        finalOrderQtys[s.id] = s.qtyRequired;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Purchase Order Builder"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- 1. DISTRIBUTOR SELECTOR ---
          _buildDistributorHeader(ph),

          if (selectedDistributor != null) ...[
            // --- 2. SHORTAGE SELECTION LIST ---
            _buildItemsSelectionList(ph),

            // --- 3. GENERATE ACTION BAR ---
            if (selectedShortageIds.isNotEmpty) _buildActionBar(),
          ] else
            Expanded(child: _buildEmptyState("Please select a Distributor to build an order")),
        ],
      ),
    );
  }

  Widget _buildDistributorHeader(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.white,
      child: selectedDistributor == null
          ? TextField(
              decoration: const InputDecoration(
                hintText: "Select Distributor to order from...", 
                prefixIcon: Icon(Icons.business_center), 
                border: OutlineInputBorder()
              ),
              onChanged: (v) => setState(() => searchQuery = v),
              // Simulating a simple search for UI flow
              onTap: () => _showDistributorPicker(ph),
              readOnly: true,
            )
          : ListTile(
              tileColor: Colors.blue.shade50,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.blue.shade200)),
              leading: const Icon(Icons.business, color: Colors.blue),
              title: Text(selectedDistributor!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(selectedDistributor!.city),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedDistributor = null)),
            ),
    );
  }

  void _showDistributorPicker(PharoahManager ph) {
    showModalBottomSheet(
      context: context,
      builder: (c) => ListView(
        children: ph.parties.where((p) => p.group == "Sundry Creditors").map((p) => ListTile(
          title: Text(p.name),
          subtitle: Text(p.city),
          onTap: () {
            setState(() => selectedDistributor = p);
            Navigator.pop(c);
          },
        )).toList(),
      ),
    );
  }

  Widget _buildItemsSelectionList(PharoahManager ph) {
    if (ph.shortages.isEmpty) return Expanded(child: _buildEmptyState("Shortage list is empty. Nothing to order."));

    return Expanded(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("SELECT ITEMS & ADJUST QTY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (selectedShortageIds.length == ph.shortages.length) selectedShortageIds.clear();
                      else selectedShortageIds = ph.shortages.map((s) => s.id).toList();
                    });
                  },
                  child: Text(selectedShortageIds.length == ph.shortages.length ? "UNSELECT ALL" : "SELECT ALL"),
                )
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: ph.shortages.length,
              padding: const EdgeInsets.symmetric(horizontal: 15),
              itemBuilder: (c, i) {
                final s = ph.shortages[i];
                final isSelected = selectedShortageIds.contains(s.id);
                
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade200)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: isSelected, 
                          onChanged: (v) {
                            setState(() { v! ? selectedShortageIds.add(s.id) : selectedShortageIds.remove(s.id); });
                          }
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.medicineName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text("Stock: ${s.currentStock.toInt()} | Avg: ${ph.calculateAvgMonthlySale(s.medicineId).toStringAsFixed(1)}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                        // Quantity Editor
                        Container(
                          width: 70,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(5)),
                          child: TextFormField(
                            initialValue: s.qtyRequired.toInt().toString(),
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                            onChanged: (v) {
                              finalOrderQtys[s.id] = double.tryParse(v) ?? 0;
                            },
                            decoration: const InputDecoration(border: InputBorder.none, isDense: true),
                          ),
                        )
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

  Widget _buildActionBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55)),
        onPressed: () => _generateOrderSummary(),
        icon: const Icon(Icons.send_rounded),
        label: const Text("GENERATE & SHARE ORDER", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _generateOrderSummary() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    String orderText = "*PURCHASE ORDER*\n";
    orderText += "Distributor: ${selectedDistributor!.name}\n";
    orderText += "Date: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}\n";
    orderText += "--------------------------\n";

    int count = 1;
    for (var sid in selectedShortageIds) {
      final item = ph.shortages.firstWhere((x) => x.id == sid);
      double qty = finalOrderQtys[sid] ?? item.qtyRequired;
      if (qty > 0) {
        orderText += "$count. ${item.medicineName} -> Qty: ${qty.toInt()}\n";
        count++;
      }
    }
    
    orderText += "--------------------------\n";
    orderText += "Please supply as soon as possible.\nGenerated via Pharoah ERP.";

    // Show a preview dialog before sharing
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Order Preview"),
        content: SingleChildScrollView(child: Text(orderText, style: const TextStyle(fontFamily: 'monospace', fontSize: 12))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CLOSE")),
          ElevatedButton(
            onPressed: () {
              // Future: Use share_plus to send to WhatsApp
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Copying to clipboard and opening share...")));
            },
            child: const Text("SHARE ON WHATSAPP"),
          )
        ],
      ),
    );
  }

  Widget _buildEmptyState(String msg) {
    return Center(child: Text(msg, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic)));
  }
}
