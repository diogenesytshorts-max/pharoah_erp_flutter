// FILE: lib/challans/challan_dashboard.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ChallanDashboard extends StatefulWidget {
  const ChallanDashboard({super.key});

  @override
  State<ChallanDashboard> createState() => _ChallanDashboardState();
}

class _ChallanDashboardState extends State<ChallanDashboard> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Challans & Returns Hub"),
        backgroundColor: Colors.orange.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- TOP ACTION CARDS ---
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                _actionCard("SALE CHALLAN", "Outward Entry", Icons.local_shipping, Colors.blueGrey, () {}),
                _actionCard("PUR. CHALLAN", "Inward Entry", Icons.inventory_2, Colors.amber.shade800, () {}),
                _actionCard("SALE RETURN", "Credit Note", Icons.assignment_return, Colors.red.shade700, () {}),
                _actionCard("PUR. RETURN", "Debit Note", Icons.remove_shopping_cart, Colors.deepOrange, () {}),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // --- PENDING CHALLANS SECTION ---
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "PENDING FOR BILLING",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1),
                      ),
                      TextButton.icon(
                        onPressed: () {}, 
                        icon: const Icon(Icons.bolt, size: 16),
                        label: const Text("CONVERT ALL", style: TextStyle(fontSize: 11)),
                      )
                    ],
                  ),
                  Expanded(
                    child: _buildPlaceholderList(), // Abhi ke liye empty list UI
                  ),
                ],
              ),
            ),
          ),
          
          // --- BOTTOM INFO ---
          _buildSummaryBar(),
        ],
      ),
    );
  }

  Widget _actionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.2), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 13)),
            Text(sub, style: TextStyle(color: color.withOpacity(0.7), fontSize: 9, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderList() {
    return ListView.builder(
      itemCount: 3,
      itemBuilder: (c, i) => Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        child: ListTile(
          leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.document_scanner, color: Colors.white, size: 18)),
          title: Text("Sample Challan #${i+101}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          subtitle: const Text("Party: Demo Medical Store | Date: 24/04/2026", style: TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 12),
        ),
      ),
    );
  }

  Widget _buildSummaryBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sumItem("Unbilled", "₹0.00", Colors.blueGrey),
          _sumItem("Returns", "₹0.00", Colors.red),
        ],
      ),
    );
  }

  Widget _sumItem(String label, String val, Color c) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: c)),
      ],
    );
  }
}
