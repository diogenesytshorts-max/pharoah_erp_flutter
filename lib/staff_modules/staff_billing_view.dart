// FILE: lib/staff_modules/staff_billing_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'staff_item_entry_card.dart';

class StaffBillingView extends StatefulWidget {
  final Party party;
  final String billNo;
  final DateTime billDate;
  final String mode;

  const StaffBillingView({
    super.key,
    required this.party,
    required this.billNo,
    required this.billDate,
    required this.mode,
  });

  @override
  State<StaffBillingView> createState() => _StaffBillingViewState();
}

class _StaffBillingViewState extends State<StaffBillingView> {
  List<BillItem> items = [];
  double get totalAmt => items.fold(0, (sum, it) => sum + it.total);

  void _showItemSearch(PharoahManager ph) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (c) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          children: [
            const Padding(padding: EdgeInsets.all(15), child: Text("SELECT PRODUCT", style: TextStyle(fontWeight: FontWeight.bold))),
            Expanded(
              child: ListView.builder(
                itemCount: ph.medicines.length,
                itemBuilder: (c, i) => ListTile(
                  title: Text(ph.medicines[i].name),
                  subtitle: Text("Pack: ${ph.medicines[i].packing} | Stock: ${ph.medicines[i].stock}"),
                  onTap: () {
                    Navigator.pop(context);
                    _showEntryCard(ph.medicines[i]);
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showEntryCard(Medicine med) {
    showDialog(
      context: context,
      builder: (c) => StaffItemEntryCard(
        med: med,
        srNo: items.length + 1,
        onAdd: (newItem) {
          setState(() { items.add(newItem); });
          Navigator.pop(context);
        },
        onCancel: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F8E9),
      appBar: AppBar(
        title: Text("Invoice: ${widget.billNo}"),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: items.isEmpty ? null : () => _handleFinish(ph),
            child: const Text("FINISH", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.party.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(DateFormat('dd/MM/yy').format(widget.billDate)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: items.length,
              itemBuilder: (c, i) => Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                child: ListTile(
                  title: Text(items[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Batch: ${items[i].batch} | Qty: ${items[i].qty.toInt()}"),
                  trailing: Text("₹${items[i].total.toStringAsFixed(2)}"),
                ),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("GRAND TOTAL", style: TextStyle(fontWeight: FontWeight.bold)),
                Text("₹${totalAmt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.teal)),
              ],
            ),
          )
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showItemSearch(ph),
        backgroundColor: Colors.teal.shade700,
        label: const Text("ADD ITEM"),
        icon: const Icon(Icons.add),
      ),
    );
  }

  void _handleFinish(PharoahManager ph) {
    ph.finalizeSale(
      billNo: widget.billNo,
      date: widget.billDate,
      party: widget.party,
      items: items,
      total: totalAmt,
      mode: widget.mode,
    );
    Navigator.pop(context);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Bill Saved Successfully!"), backgroundColor: Colors.green));
  }
}
