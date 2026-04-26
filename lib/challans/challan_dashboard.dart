import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import 'sale_challan_view.dart';
import 'purchase_challan_view.dart';
import 'challan_to_bill_converter.dart';
import '../returns/sale_return_view.dart';
import '../returns/expiry_breakage_return_view.dart';

class ChallanDashboard extends StatefulWidget {
  const ChallanDashboard({super.key});
  @override State<ChallanDashboard> createState() => _ChallanDashboardState();
}

class _ChallanDashboardState extends State<ChallanDashboard> {
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<SaleChallan> pendingSales = ph.saleChallans.where((c) => c.status == "Pending").toList();
    List<PurchaseChallan> pendingPurc = ph.purchaseChallans.where((c) => c.status == "Pending").toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      appBar: AppBar(title: const Text("Challans & Returns Hub"), backgroundColor: Colors.orange.shade900),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: GridView.count(
              shrinkWrap: true, crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.4,
              children: [
                _actionCard("SALE CHALLAN", Icons.local_shipping, Colors.blueGrey, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleChallanView()))),
                _actionCard("PUR. CHALLAN", Icons.inventory_2, Colors.amber.shade800, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseChallanView()))),
                _actionCard("SALE RETURN", Icons.assignment_return, Colors.red.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleReturnView()))),
                _actionCard("BRK/EXP RET", Icons.delete_sweep_rounded, Colors.red.shade900, () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ExpiryBreakageReturnView()))),
              ],
            ),
          ),
          Expanded(
            child: (pendingSales.isEmpty && pendingPurc.isEmpty) 
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inventory_2_outlined, size: 50, color: Colors.grey.shade300), const Text("No pending challans found.")]))
              : ListView(children: [
                  ...pendingSales.map((ch) => ListTile(title: Text(ch.billNo), subtitle: Text(ch.partyName), trailing: Text("₹${ch.totalAmount}"))),
                  ...pendingPurc.map((ch) => ListTile(title: Text(ch.billNo), subtitle: Text(ch.distributorName), trailing: Text("₹${ch.totalAmount}"))),
                ]),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(String t, IconData i, Color c, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: c.withOpacity(0.2))), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(i, color: c, size: 28), Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: c, fontSize: 12))])));
}
