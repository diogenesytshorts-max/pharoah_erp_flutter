// FILE: lib/challans/challan_dashboard.dart (Replace Full)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'sale_challan_view.dart';
import 'challan_to_bill_converter.dart';
import '../returns/sale_return_view.dart'; // NAYA IMPORT

class ChallanDashboard extends StatefulWidget {
  const ChallanDashboard({super.key});

  @override
  State<ChallanDashboard> createState() => _ChallanDashboardState();
}

class _ChallanDashboardState extends State<ChallanDashboard> {
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<SaleChallan> pendingChallans = ph.saleChallans.where((c) => c.status == "Pending").toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(
        title: const Text("Challans & Returns Hub"),
        backgroundColor: Colors.orange.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
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
                _actionCard("SALE CHALLAN", "Outward Entry", Icons.local_shipping, Colors.blueGrey, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleChallanView()));
                }),
                _actionCard("PUR. CHALLAN", "Inward Entry", Icons.inventory_2, Colors.amber.shade800, () {
                  // Future
                }),
                
                // UPDATED: SALE RETURN BUTTON CONNECTED
                _actionCard("SALE RETURN", "Credit Note (Sellable)", Icons.assignment_return, Colors.red.shade700, () {
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleReturnView()));
                }),
                
                _actionCard("BRK/EXP RET", "Breakage Entry", Icons.remove_shopping_cart, Colors.deepOrange, () {
                  // Future: Expiry/Breakage specific button as requested
                }),
              ],
            ),
          ),

          const SizedBox(height: 10),

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
                      Text(
                        "PENDING FOR BILLING (${pendingChallans.length})",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1),
                      ),
                      if (pendingChallans.isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (c) => const ChallanToBillConverter()));
                          }, 
                          icon: const Icon(Icons.bolt, size: 16),
                          label: const Text("CONVERT TO BILL", style: TextStyle(fontSize: 11)),
                        )
                    ],
                  ),
                  Expanded(
                    child: pendingChallans.isEmpty 
                      ? _buildEmptyState()
                      : ListView.builder(
                          itemCount: pendingChallans.length,
                          itemBuilder: (c, i) => _challanTile(pendingChallans[i]),
                        ),
                  ),
                ],
              ),
            ),
          ),
          
          _buildSummaryBar(pendingChallans),
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
            Text(title, style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 12)),
            Text(sub, style: TextStyle(color: color.withOpacity(0.7), fontSize: 8, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _challanTile(SaleChallan ch) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
      child: ListTile(
        leading: const CircleAvatar(backgroundColor: Colors.blueGrey, child: Icon(Icons.document_scanner, color: Colors.white, size: 18)),
        title: Text(ch.billNo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("Party: ${ch.partyName}\nAmount: ₹${ch.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
        onTap: () {},
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_off_outlined, size: 50, color: Colors.grey.shade300),
          const SizedBox(height: 10),
          const Text("No pending challans found.", style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildSummaryBar(List<SaleChallan> list) {
    double total = list.fold(0, (sum, item) => sum + item.totalAmount);
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _sumItem("Total Unbilled", "₹${total.toStringAsFixed(2)}", Colors.blueGrey),
          _sumItem("Pending Count", "${list.length}", Colors.orange.shade900),
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
