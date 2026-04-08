import 'package:flutter/material.dart';
import 'widgets.dart';
import 'product_master.dart';
import 'party_master.dart';
import 'sale_entry_view.dart';
import 'sale_bill_modify_view.dart';
import 'user_master_view.dart';
import 'file_management_view.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback onLogout;
  const DashboardView({super.key, required this.onLogout});

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(children: [
        Container(padding: const EdgeInsets.only(top: 50, left: 25, right: 25, bottom: 20), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)]), child: Row(children: [
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("PHAROAH ERP", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)), Text("Business Management System", style: TextStyle(fontSize: 12, color: Colors.grey))]),
          const Spacer(),
          CircleAvatar(backgroundColor: Colors.red, child: IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.white), onPressed: onLogout))
        ])),
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.4, children: const [
            StatWidget(title: "NET SALES", value: "₹ 0.00", period: "Today", icon: "trending_up", color: Colors.green),
            StatWidget(title: "PURCHASE", value: "₹ 0.00", period: "Today", icon: "shopping_cart", color: Colors.orange),
            StatWidget(title: "CASH", value: "₹ 0.00", period: "Today", icon: "payments", color: Colors.blue),
            StatWidget(title: "STOCK", value: "₹ 0.00", period: "Annually", icon: "inventory_2", color: Colors.purple),
          ]),
          const SizedBox(height: 30),
          GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 15, mainAxisSpacing: 15, children: [
            ActionIconBtn(title: "New Sale", icon: Icons.add_box, color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleEntryView()))),
            ActionIconBtn(title: "Parties", icon: Icons.people, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView()))),
            ActionIconBtn(title: "Inventory", icon: Icons.medication, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView()))),
            ActionIconBtn(title: "Modify Bill", icon: Icons.edit_document, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleBillModifyView()))),
            ActionIconBtn(title: "Files", icon: Icons.folder, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView()))),
            ActionIconBtn(title: "Settings", icon: Icons.settings, color: Colors.red, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout)))),
          ]),
        ]))),
      ]),
    );
  }
}
