import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';
import 'product_master.dart';
import 'party_master.dart';
import 'sale_entry_view.dart';
import 'sale_bill_number.dart';
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

    // --- CALCULATIONS ---
    // 1. Today's Net Sales
    double todaySales = ph.sales.where((s) {
      return s.status == "Active" &&
          s.date.day == now.day &&
          s.date.month == now.month &&
          s.date.year == now.year;
    }).fold(0.0, (sum, item) => sum + item.totalAmount);

    // 2. Today's Total Purchase
    double todayPurchase = ph.purchases.where((p) {
      return p.date.day == now.day &&
          p.date.month == now.month &&
          p.date.year == now.year;
    }).fold(0.0, (sum, item) => sum + item.totalAmount);

    // 3. Total Stock Valuation (Cost Price)
    double totalStockValue = ph.medicines.fold(0.0, (sum, med) {
      return sum + (med.stock * med.purRate);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // --- HEADER SECTION ---
          Container(
            padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 30),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 5)),
              ],
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "PHAROAH ERP",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0D47A1),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "FY: ${ph.currentFY} | Live Business Monitor",
                      style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  onPressed: onLogout,
                )
              ],
            ),
          ),

          // --- MAIN CONTENT ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "TODAY'S SUMMARY",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1),
                  ),
                  const SizedBox(height: 15),

                  // --- STAT CARDS GRID ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.3,
                    children: [
                      StatWidget(
                        title: "NET SALES",
                        value: "₹${todaySales.toStringAsFixed(0)}",
                        period: "Today",
                        icon: "trending_up",
                        color: Colors.green,
                      ),
                      StatWidget(
                        title: "PURCHASE",
                        value: "₹${todayPurchase.toStringAsFixed(0)}",
                        period: "Today",
                        icon: "shopping_cart",
                        color: Colors.orange,
                      ),
                      StatWidget(
                        title: "STOCK VALUE",
                        value: "₹${totalStockValue.toStringAsFixed(0)}",
                        period: "Total",
                        icon: "inventory_2",
                        color: Colors.purple,
                      ),
                      StatWidget(
                        title: "BILLS",
                        value: "${ph.sales.length}",
                        period: "Active",
                        icon: "payments",
                        color: Colors.blue,
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),
                  const Text(
                    "QUICK ACTIONS",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1),
                  ),
                  const SizedBox(height: 15),

                  // --- ACTION BUTTONS GRID ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.85,
                    children: [
                      ActionIconBtn(
                        title: "New Sale",
                        icon: Icons.add_shopping_cart_rounded,
                        color: Colors.green,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleEntryView())),
                      ),
                      ActionIconBtn(
                        title: "Purchase",
                        icon: Icons.file_download_outlined,
                        color: Colors.orange,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseEntryView())),
                      ),
                      ActionIconBtn(
                        title: "Pur. Reg",
                        icon: Icons.history_edu_rounded,
                        color: Colors.deepOrange,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseModifyView())),
                      ),
                      ActionIconBtn(
                        title: "Sales Edit",
                        icon: Icons.edit_note_rounded,
                        color: Colors.blue,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleBillModifyView())),
                      ),
                      ActionIconBtn(
                        title: "Inventory",
                        icon: Icons.inventory_2_rounded,
                        color: Colors.purple,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView())),
                      ),
                      ActionIconBtn(
                        title: "Parties",
                        icon: Icons.people_alt_rounded,
                        color: Colors.teal,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView())),
                      ),
                      ActionIconBtn(
                        title: "More",
                        icon: Icons.widgets_rounded,
                        color: Colors.indigo,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MoreFeaturesView(onLogout: onLogout))),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                  const Center(
                    child: Text(
                      "Powered by Rawat Systems",
                      style: TextStyle(color: Colors.grey, fontSize: 10),
                    ),
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
