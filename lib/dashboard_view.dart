import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: Column(
        children: [
          // --- HEADER SECTION ---
          Container(
            padding: const EdgeInsets.only(top: 50, left: 25, right: 25, bottom: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PHAROAH ERP", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blue)),
                    const Text("Financial Overview", style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const Spacer(),
                // Logout Button
                CircleAvatar(
                  backgroundColor: Colors.red,
                  child: IconButton(
                    icon: const Icon(Icons.power_settings_new, color: Colors.white),
                    onPressed: () {
                      // Logout logic here
                    },
                  ),
                )
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STAT CARDS GRID ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.4,
                    children: const [
                      StatWidget(title: "NET SALES", value: "₹ 0.00", period: "Today", icon: "trending_up", color: Colors.green),
                      StatWidget(title: "PURCHASE", value: "₹ 0.00", period: "Today", icon: "shopping_cart", color: Colors.orange),
                      StatWidget(title: "CASH IN HAND", value: "₹ 0.00", period: "Today", icon: "payments", color: Colors.blue),
                      StatWidget(title: "STOCK VALUE", value: "₹ 0.00", period: "Annually", icon: "inventory_2", color: Colors.purple),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Text("QUICK ACTIONS", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 15),

                  // --- QUICK ACTIONS GRID ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    children: [
                      ActionIconBtn(title: "New Sale", icon: Icons.add_box, color: Colors.green, onTap: () {}),
                      ActionIconBtn(title: "Parties", icon: Icons.people, color: Colors.blue, onTap: () {}),
                      ActionIconBtn(title: "Inventory", icon: Icons.medication, color: Colors.orange, onTap: () {}),
                      ActionIconBtn(title: "Modify Bill", icon: Icons.edit_document, color: Colors.orange, onTap: () {}),
                      ActionIconBtn(title: "Ledger", icon: Icons.menu_book, color: Colors.blue, onTap: () {}),
                      ActionIconBtn(title: "Settings", icon: Icons.manage_accounts, color: Colors.red, onTap: () {}),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
