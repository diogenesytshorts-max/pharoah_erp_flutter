// FILE: lib/challans/purchase_challan_register.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pharoah_date_controller.dart';
import '../app_date_logic.dart';
import 'purchase_challan_view.dart';
import '../pdf/purchase_challan_pdf.dart';

class PurchaseChallanRegister extends StatefulWidget {
  const PurchaseChallanRegister({super.key});

  @override
  State<PurchaseChallanRegister> createState() => _PurchaseChallanRegisterState();
}

class _PurchaseChallanRegisterState extends State<PurchaseChallanRegister> {
  String searchQuery = "";
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      // Smart Date Selection from FY
      toDate = AppDateLogic.getSmartDate(ph.currentFY);
      fromDate = toDate.subtract(const Duration(days: 30));
      DateTime fyStart = AppDateLogic.getFYStart(ph.currentFY);
      if (fromDate.isBefore(fyStart)) fromDate = fyStart;
      _isInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // LOGIC: Filter Purchase Challans
    final list = ph.purchaseChallans.reversed.where((ch) {
      bool matchesSearch = ch.distributorName.toLowerCase().contains(searchQuery.toLowerCase()) || 
                           ch.billNo.toLowerCase().contains(searchQuery.toLowerCase()) ||
                           ch.internalNo.toLowerCase().contains(searchQuery.toLowerCase());
      bool matchesDate = ch.date.isAfter(fromDate.subtract(const Duration(days: 1))) && 
                         ch.date.isBefore(toDate.add(const Duration(days: 1)));
      return matchesSearch && matchesDate;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFFDF8F1), // Very light amber
      appBar: AppBar(
        title: const Text("Purchase Challan Register", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        backgroundColor: Colors.amber.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterPanel(ph),
          Expanded(
            child: list.isEmpty 
              ? const Center(child: Text("No Inward Challans found."))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  itemBuilder: (context, index) => _buildChallanCard(list[index], ph),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel(PharoahManager ph) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.shade900,
        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Column(
        children: [
          TextField(
            style: const TextStyle(color: Colors.white),
            onChanged: (v) => setState(() => searchQuery = v),
            decoration: InputDecoration(
              hintText: "Search Supplier or Bill No...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
              prefixIcon: const Icon(Icons.search, color: Colors.white70),
              filled: true, fillColor: Colors.white.withOpacity(0.15),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _dateChip("FROM: ${DateFormat('dd/MM/yy').format(fromDate)}", () async {
                DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: ph.currentFY, initialDate: fromDate);
                if(p != null) setState(() => fromDate = p);
              }),
              const SizedBox(width: 10),
              _dateChip("TO: ${DateFormat('dd/MM/yy').format(toDate)}", () async {
                DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: ph.currentFY, initialDate: toDate);
                if(p != null) setState(() => toDate = p);
              }),
            ],
          )
        ],
      ),
    );
  }

  Widget _dateChip(String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.calendar_month, size: 12, color: Colors.white70),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChallanCard(PurchaseChallan ch, PharoahManager ph) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: () => _showActionMenu(ch, ph),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.inventory_2_rounded, color: Colors.amber.shade900),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ch.distributorName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text("Bill: ${ch.billNo} • ID: ${ch.internalNo}", style: const TextStyle(color: Colors.grey, fontSize: 11)),
                    Text(DateFormat('dd MMMM yyyy').format(ch.date), style: TextStyle(color: Colors.amber.shade900, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text("₹${ch.totalAmount.toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.amber.shade900)),
                  const SizedBox(height: 5),
                  _statusBadge(ch.status),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    bool isPending = status == "Pending";
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isPending ? Colors.blue.shade50 : Colors.green.shade50,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(status.toUpperCase(), style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: isPending ? Colors.blue.shade900 : Colors.green.shade900)),
    );
  }

  void _showActionMenu(PurchaseChallan ch, PharoahManager ph) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(ch.distributorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const Divider(),
            _menuTile(Icons.visibility, "View Items (Inward)", Colors.blue, () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseChallanView(existingRecord: ch, isReadOnly: true)));
            }),
            _menuTile(Icons.edit, "Modify Inward Note", Colors.orange, () {
              Navigator.pop(c);
              Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseChallanView(existingRecord: ch)));
            }),
            _menuTile(Icons.print, "Print Inward PDF", Colors.teal, () {
              Navigator.pop(c);
              if(ph.activeCompany != null) {
                final party = ph.parties.firstWhere((p) => p.name == ch.distributorName, orElse: () => Party(id: '0', name: ch.distributorName));
                PurchaseChallanPdf.generate(ch, party, ph.activeCompany!);
              }
            }),
            _menuTile(Icons.delete_forever, "Delete Record", Colors.red, () => _confirmDelete(ch, ph)),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(IconData icon, String t, Color c, VoidCallback onTap) => 
      ListTile(leading: Icon(icon, color: c), title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), onTap: onTap);

  void _confirmDelete(PurchaseChallan ch, PharoahManager ph) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Delete Purchase Challan?"),
        content: const Text("Warning: This will remove the inward record and reverse stock entry."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () {
            ph.deletePurchaseChallan(ch.id);
            Navigator.pop(c);
            Navigator.pop(context);
          }, child: const Text("YES, DELETE", style: TextStyle(color: Colors.white))),
        ],
      ),
    );
  }
}
