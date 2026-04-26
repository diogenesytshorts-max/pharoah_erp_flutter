// FILE: lib/challans/challan_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'sale_challan_view.dart';
import 'purchase_challan_view.dart';
import 'challan_to_bill_converter.dart';
import '../returns/sale_return_view.dart';
import '../returns/expiry_breakage_return_view.dart';
import '../returns/purchase_return_view.dart'; // Ensure this file exists
import '../returns/purchase_breakage_return_view.dart'; // Ensure this file exists

class ChallanDashboard extends StatefulWidget {
  const ChallanDashboard({super.key});

  @override
  State<ChallanDashboard> createState() => _ChallanDashboardState();
}

class _ChallanDashboardState extends State<ChallanDashboard> {
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<SaleChallan> pendingSales = ph.saleChallans.where((c) => c.status == "Pending").toList();
    List<PurchaseChallan> pendingPurc = ph.purchaseChallans.where((c) => c.status == "Pending").toList();

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
                  Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseChallanView()));
                }),
                _actionCard("SALE RETURN", "Credit Note", Icons.assignment_return, Colors.red.shade700, () {
                   Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleReturnView()));
                }),
                _actionCard("PUR. RETURN", "Debit Note Options", Icons.remove_shopping_cart, Colors.brown.shade800, () {
                  _showPurchaseReturnOptions(context);
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
                        "PENDING CHALLANS (${pendingSales.length + pendingPurc.length})",
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1),
                      ),
                      if (pendingSales.isNotEmpty)
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
                    child: (pendingSales.isEmpty && pendingPurc.isEmpty)
                      ? _buildEmptyState()
                      : _buildChallanList(pendingSales, pendingPurc),
                  ),
                ],
              ),
            ),
          ),
          
          _buildSummaryBar(pendingSales, pendingPurc),
        ],
      ),
    );
  }

  // --- RE-ADDED: PURCHASE RETURN MODAL ---
  void _showPurchaseReturnOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (c) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(title: Text("Select Return Category", style: TextStyle(fontWeight: FontWeight.bold))),
          ListTile(
            leading: const Icon(Icons.check_circle, color: Colors.green),
            title: const Text("Sellable Return (Good Stock)"),
            onTap: () { Navigator.pop(c); Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseReturnView())); },
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep, color: Colors.brown),
            title: const Text("Expiry / Breakage Return (Dead Stock)"),
            onTap: () { Navigator.pop(c); Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseBreakageReturnView())); },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildChallanList(List<SaleChallan> sales, List<PurchaseChallan> purc) {
    return ListView(
      children: [
        ...sales.map((ch) => _challanTile(ch.billNo, ch.partyName, ch.totalAmount, Colors.blueGrey, "S")),
        ...purc.map((ch) => _challanTile(ch.billNo, ch.distributorName, ch.totalAmount, Colors.amber.shade800, "P")),
      ],
    );
  }

  Widget _challanTile(String no, String party, double amt, Color c, String tag) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: c.withOpacity(0.2))),
      child: ListTile(
        leading: CircleAvatar(backgroundColor: c.withOpacity(0.1), child: Text(tag, style: TextStyle(color: c, fontWeight: FontWeight.bold))),
        title: Text(no, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text("Party: $party\nAmount: ₹${amt.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 12),
      ),
    );
  }

  Widget _actionCard(String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.2), width: 1.5)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 28), Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)), Text(sub, style: const TextStyle(fontSize: 8))]),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey.shade300), const SizedBox(height: 10), const Text("No pending challans found.", style: TextStyle(color: Colors.grey, fontSize: 12))]));
  }

  Widget _buildSummaryBar(List<SaleChallan> sales, List<PurchaseChallan> purc) {
    double totalS = sales.fold(0, (sum, item) => sum + item.totalAmount);
    double totalP = purc.fold(0, (sum, item) => sum + item.totalAmount);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(children: [const Text("Unbilled Sales", style: TextStyle(fontSize: 10)), Text("₹${totalS.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
          Column(children: [const Text("Unbilled Pur.", style: TextStyle(fontSize: 10)), Text("₹${totalP.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold))]),
        ],
      ),
    );
  }
}
