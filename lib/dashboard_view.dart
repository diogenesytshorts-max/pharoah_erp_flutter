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
import 'dart:math';

class DashboardView extends StatelessWidget {
  final VoidCallback onLogout;
  const DashboardView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    // Access Manager for Data
    final ph = Provider.of<PharoahManager>(context);
    final now = DateTime.now();

    // --- 1. LIVE CALCULATION: NET SALES (Today) ---
    // Sirf Active bills aur aaj ki date wale
    double todaySales = ph.sales.where((s) {
      return s.status == "Active" &&
          s.date.day == now.day &&
          s.date.month == now.month &&
          s.date.year == now.year;
    }).fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 2. LIVE CALCULATION: PURCHASE (Today) ---
    // Aaj ki total kharidari
    double todayPurchase = ph.purchases.where((p) {
      return p.date.day == now.day &&
          p.date.month == now.month &&
          p.date.year == now.year;
    }).fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 3. LIVE CALCULATION: CASH IN HAND (Today) ---
    // Sirf wo sales jinka paymentMode "CASH" hai
    double todayCash = ph.sales.where((s) {
      return s.status == "Active" &&
          s.paymentMode == "CASH" &&
          s.date.day == now.day &&
          s.date.month == now.month &&
          s.date.year == now.year;
    }).fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 4. LIVE CALCULATION: STOCK VALUE (COST PRICE) ---
    // Stock Qty * Purchase Rate (purRate)
    double totalStockValue = ph.medicines.fold(0.0, (sum, med) {
      double stockQty = med.stock > 0 ? med.stock.toDouble() : 0.0;
      return sum + (stockQty * med.purRate);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // --- CUSTOM APP BAR / HEADER ---
          Container(
            padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 25),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(35),
                bottomRight: Radius.circular(35),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.1),
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
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A237E),
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            "FY: ${ph.currentFY}",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          "Business Manager",
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                // Logout Button with UI feedback
                GestureDetector(
                  onTap: onLogout,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: const Icon(Icons.power_settings_new, color: Colors.red, size: 26),
                  ),
                ),
              ],
            ),
          ),

          // --- DASHBOARD CONTENT ---
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section Title
                  const Text(
                    "OVERVIEW",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- STAT CARDS GRID ---
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
                        title: "STOCK (VAL)",
                        value: "₹${totalStockValue.toStringAsFixed(0)}",
                        period: "At Cost",
                        icon: "inventory_2",
                        color: Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // Quick Actions Title
                  const Text(
                    "QUICK ACTIONS",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // --- ACTION BUTTONS GRID ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.9,
                    children: [
                      ActionIconBtn(
                        title: "Sale",
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
                        title: "Reports",
                        icon: Icons.assessment,
                        color: Colors.blue,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleBillModifyView())),
                      ),
                      ActionIconBtn(
                        title: "Inventory",
                        icon: Icons.inventory_2,
                        color: Colors.purple,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView())),
                      ),
                      ActionIconBtn(
                        title: "Parties",
                        icon: Icons.groups_rounded,
                        color: Colors.teal,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView())),
                      ),
                      ActionIconBtn(
                        title: "Settings",
                        icon: Icons.settings_suggest,
                        color: Colors.blueGrey,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  
                  // Bottom Branding / Version
                  const Center(
                    child: Column(
                      children: [
                        Text("Pharoah ERP v1.0.4", style: TextStyle(color: Colors.grey, fontSize: 10)),
                        Text("Powered by Rawat Systems", style: TextStyle(color: Colors.grey, fontSize: 10)),
                      ],
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
