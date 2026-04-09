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
    final ph = Provider.of<PharoahManager>(context);
    final now = DateTime.now();

    // --- 1. NET SALES (Today's Active Bills - Cash + Credit) ---
    double todaySales = ph.sales
        .where((s) => 
            s.date.day == now.day && 
            s.date.month == now.month && 
            s.date.year == now.year && 
            s.status == "Active")
        .fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 2. PURCHASE (Today's Total Stock Inward) ---
    double todayPurchase = ph.purchases
        .where((p) => 
            p.date.day == now.day && 
            p.date.month == now.month && 
            p.date.year == now.year)
        .fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 3. CASH (Today's Cash Collection - Only Sale Bills with CASH mode) ---
    double todayCash = ph.sales
        .where((s) => 
            s.date.day == now.day && 
            s.date.month == now.month && 
            s.date.year == now.year && 
            s.status == "Active" && 
            s.paymentMode == "CASH")
        .fold(0.0, (sum, item) => sum + item.totalAmount);

    // --- 4. STOCK VALUE (Total Inventory Value at Rate A) ---
    // Hum Rate A ko valuation standard maan rahe hain.
    double totalStockValue = ph.medicines.fold(0.0, (sum, med) {
      double stockQty = med.stock > 0 ? med.stock.toDouble() : 0.0;
      return sum + (stockQty * med.rateA);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      body: Column(
        children: [
          // Header Section
          Container(
            padding: const EdgeInsets.only(top: 50, left: 25, right: 25, bottom: 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("PHAROAH ERP", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue)),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 5),
                        Text("FY: ${ph.currentFY}", style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onLogout,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red[50], shape: BoxShape.circle),
                    child: const Icon(Icons.power_settings_new, color: Colors.red),
                  ),
                )
              ],
            ),
          ),

          // Main Dashboard Scrollable Area
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
                    childAspectRatio: 1.3,
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
                        period: "At Rate A",
                        icon: "inventory_2",
                        color: Colors.purple,
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                  const Text("QUICK ACTIONS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey, fontSize: 16)),
                  const SizedBox(height: 15),

                  // --- ACTION BUTTONS GRID ---
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
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
                        icon: Icons.group,
                        color: Colors.teal,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView())),
                      ),
                      ActionIconBtn(
                        title: "Settings",
                        icon: Icons.settings,
                        color: Colors.blueGrey,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                      ),
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
