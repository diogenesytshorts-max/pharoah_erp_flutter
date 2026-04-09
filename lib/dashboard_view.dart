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
import 'more_features_view.dart';
import 'dart:math';

class DashboardView extends StatelessWidget {
  final VoidCallback onLogout;
  const DashboardView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    // Manager access for real-time data
    final ph = Provider.of<PharoahManager>(context);
    final now = DateTime.now();

    // --- 1. CALCULATION: NET SALES (Today) ---
    // Sum of all Active sale bills created today
    double todaySales = ph.sales.where((s) {
      return s.status == "Active" &&
          s.date.day == now.day &&
          s.date.month == now.month &&
          s.date.year == now.year;
    }).fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 2. CALCULATION: PURCHASE (Today) ---
    // Sum of all purchase entries created today
    double todayPurchase = ph.purchases.where((p) {
      return p.date.day == now.day &&
          p.date.month == now.month &&
          p.date.year == now.year;
    }).fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 3. CALCULATION: CASH IN HAND (Today) ---
    // Sum of active sale bills where payment mode is 'CASH'
    double todayCash = ph.sales.where((s) {
      return s.status == "Active" &&
          s.paymentMode == "CASH" &&
          s.date.day == now.day &&
          s.date.month == now.month &&
          s.date.year == now.year;
    }).fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 4. CALCULATION: STOCK VALUATION (At Cost Price) ---
    // Stock Quantity multiplied by the latest Purchase Rate
    double totalStockValue = ph.medicines.fold(0.0, (sum, med) {
      double stockQty = med.stock > 0 ? med.stock.toDouble() : 0.0;
      return sum + (stockQty * med.purRate);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // --- HEADER SECTION (Professional Style) ---
          Container(
            padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 30),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(40),
                bottomRight: Radius.circular(40),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
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
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0D47A1),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "FY: ${ph.currentFY}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Business Manager Live",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                // Logout Action
                GestureDetector(
                  onTap: onLogout,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: const Icon(Icons.power_settings_new, color: Colors.red, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // --- MAIN SCROLLABLE CONTENT ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Business Summary Label
                  const Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 15),
                    child: Text(
                      "BUSINESS OVERVIEW",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  // --- STAT CARDS GRID (2x2) ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.25,
                    children: [
                      StatWidget(
                        title: "NET SALES",
                        value: "₹${todaySales.toStringAsFixed(2)}",
                        period: "Today",
                        icon: "trending_up",
                        color: Colors.green,
                      ),
                      StatWidget(
                        title: "PURCHASE",
                        value: "₹${todayPurchase.toStringAsFixed(2)}",
                        period: "Today",
                        icon: "shopping_cart",
                        color: Colors.orange,
                      ),
                      StatWidget(
                        title: "CASH IN HAND",
                        value: "₹${todayCash.toStringAsFixed(2)}",
                        period: "Today",
                        icon: "payments",
                        color: Colors.blue,
                      ),
                      StatWidget(
                        title: "STOCK VALUE",
                        value: "₹${totalStockValue.toStringAsFixed(0)}",
                        period: "At Cost",
                        icon: "inventory_2",
                        color: Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // Actions Label
                  const Padding(
                    padding: EdgeInsets.only(left: 5, bottom: 15),
                    child: Text(
                      "QUICK ACTIONS",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),

                  // --- ACTION BUTTONS GRID (3 columns) ---
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
                        icon: Icons.add_shopping_cart,
                        color: Colors.green,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleEntryView())),
                      ),
                      ActionIconBtn(
                        title: "Purchase",
                        icon: Icons.file_download,
                        color: Colors.orange,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseEntryView())),
                      ),
                      ActionIconBtn(
                        title: "Bills/Edit",
                        icon: Icons.edit_note_rounded,
                        color: Colors.blue,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleBillModifyView())),
                      ),
                      ActionIconBtn(
                        title: "Inventory",
                        icon: Icons.inventory_2_outlined,
                        color: Colors.purple,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView())),
                      ),
                      ActionIconBtn(
                        title: "Parties",
                        icon: Icons.people_alt_rounded,
                        color: Colors.teal,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView())),
                      ),
                      // MORE FEATURES BUTTON
                      ActionIconBtn(
                        title: "More",
                        icon: Icons.widgets_rounded,
                        color: Colors.indigo,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MoreFeaturesView(onLogout: onLogout))),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Branding Section
                  Center(
                    child: Column(
                      children: [
                        const Divider(indent: 80, endIndent: 80),
                        const SizedBox(height: 10),
                        Text(
                          "Pharoah ERP Premium v1.0.5",
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Secured Digital Billing System",
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
