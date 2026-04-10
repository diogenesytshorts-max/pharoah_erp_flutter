import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';
import 'product_master.dart';
import 'party_master.dart';
import 'sale_entry_view.dart';
import 'sale_bill_modify_view.dart';
import 'user_master_view.dart';
import 'purchase/purchase_entry_view.dart';
import 'purchase/purchase_modify_view.dart';
import 'more_features_view.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback onLogout;
  const DashboardView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final now = DateTime.now();

    double todaySales = ph.sales.where((s) => s.status == "Active" && s.date.day == now.day && s.date.month == now.month && s.date.year == now.year).fold(0.0, (sum, item) => sum + item.totalAmount);
    double todayPurchase = ph.purchases.where((p) => p.date.day == now.day && p.date.month == now.month && p.date.year == now.year).fold(0.0, (sum, item) => sum + item.totalAmount);
    double totalStockValue = ph.medicines.fold(0.0, (sum, med) => sum + (med.stock * med.purRate));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 30),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40))),
            child: Row(children: [
              const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("PHAROAH ERP", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF0D47A1))), Text("Business Dashboard", style: TextStyle(fontSize: 12, color: Colors.grey))]),
              const Spacer(),
              IconButton(icon: const Icon(Icons.logout, color: Colors.red), onPressed: onLogout)
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(children: [
                GridView.count(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.3,
                  children: [
                    StatWidget(title: "TODAY SALE", value: "₹${todaySales.toStringAsFixed(0)}", period: "Today", icon: "trending_up", color: Colors.green),
                    StatWidget(title: "PURCHASE", value: "₹${todayPurchase.toStringAsFixed(0)}", period: "Today", icon: "shopping_cart", color: Colors.orange),
                    StatWidget(title: "STOCK VALUE", value: "₹${totalStockValue.toStringAsFixed(0)}", period: "Total", icon: "inventory_2", color: Colors.purple),
                    StatWidget(title: "BILLS", value: "${ph.sales.length}", period: "Total", icon: "payments", color: Colors.blue),
                  ],
                ),
                const SizedBox(height: 30),
                GridView.count(
                  shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.85,
                  children: [
                    ActionIconBtn(title: "New Sale", icon: Icons.add_shopping_cart, color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleEntryView()))),
                    ActionIconBtn(title: "Purchase", icon: Icons.downloading, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseEntryView()))),
                    ActionIconBtn(title: "Pur. Reg", icon: Icons.history, color: Colors.deepOrange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseModifyView()))),
                    ActionIconBtn(title: "Sales Edit", icon: Icons.edit_document, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleBillModifyView()))),
                    ActionIconBtn(title: "Inventory", icon: Icons.inventory_2, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView()))),
                    ActionIconBtn(title: "Parties", icon: Icons.people, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView()))),
                    ActionIconBtn(title: "More", icon: Icons.apps, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MoreFeaturesView(onLogout: onLogout)))),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
