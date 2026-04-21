import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';
import 'product_master.dart';
import 'party_master.dart';
import 'sale_entry_view.dart';
import 'sale_summary_view.dart';
import 'purchase/purchase_entry_view.dart';
import 'purchase/purchase_summary_view.dart';
import 'data_exchange_view.dart';
import 'accounts_menu_view.dart';
import 'more_features_view.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback onLogout;
  const DashboardView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final now = DateTime.now();

    double todaySales = ph.sales.where((s) => s.status == "Active" && _isSameDay(s.date, now)).fold(0.0, (sum, s) => sum + s.totalAmount);
    double todayPur = ph.purchases.where((p) => _isSameDay(p.date, now)).fold(0.0, (sum, p) => sum + p.totalAmount);
    double stockVal = ph.medicines.fold(0.0, (sum, m) => sum + (m.stock * m.purRate));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // HEADER
          Container(
            padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 25),
            decoration: const BoxDecoration(
              color: Color(0xFF0D47A1),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))
            ),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("PHAROAH ERP", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Text("FY: ${ph.currentFY} | Dashboard", style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ]),
              const Spacer(),
              IconButton(icon: const Icon(Icons.power_settings_new, color: Colors.white), onPressed: onLogout)
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // STATS SECTION
                  Row(children: [
                    Expanded(child: StatWidget(title: "TODAY SALE", value: "₹${todaySales.toStringAsFixed(0)}", period: "Today", icon: "trending_up", color: Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: StatWidget(title: "TODAY PUR", value: "₹${todayPur.toStringAsFixed(0)}", period: "Today", icon: "shopping_cart", color: Colors.orange)),
                  ]),
                  const SizedBox(height: 12),
                  StatWidget(title: "TOTAL STOCK VALUE", value: "₹${stockVal.toStringAsFixed(0)}", period: "Current", icon: "inventory_2", color: Colors.purple),
                  
                  const SizedBox(height: 25),

                  // PRIMARY ACTIONS (BILLING)
                  const Text("QUICK ENTRIES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 15),
                  Row(children: [
                    Expanded(child: _entryButton(context, "NEW SALE", Icons.add_shopping_cart, Colors.blue.shade700, const SaleEntryView())),
                    const SizedBox(width: 15),
                    Expanded(child: _entryButton(context, "PURCHASE", Icons.downloading_rounded, Colors.orange.shade800, const PurchaseEntryView())),
                  ]),

                  const SizedBox(height: 25),

                  // MODULES GRID
                  const Text("MANAGEMENT MODULES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 15),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                    children: [
                      ActionIconBtn(title: "Accounts", icon: Icons.account_balance_wallet, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AccountsMenuView()))),
                      ActionIconBtn(title: "Sale Reg", icon: Icons.description_outlined, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleSummaryView()))),
                      ActionIconBtn(title: "Pur Reg", icon: Icons.history_rounded, color: Colors.brown, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseSummaryView()))),
                      ActionIconBtn(title: "Inventory", icon: Icons.inventory_2, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView()))),
                      ActionIconBtn(title: "Data Hub", icon: Icons.cloud_sync, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DataExchangeView()))),
                      ActionIconBtn(title: "Settings", icon: Icons.settings, color: Colors.grey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MoreFeaturesView(onLogout: onLogout)))),
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

  Widget _entryButton(BuildContext context, String label, IconData icon, Color color, Widget target) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => target)),
      child: Container(
        height: 80,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: Colors.white, size: 28),
          const SizedBox(height: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
        ]),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) => d1.day == d2.day && d1.month == d2.month && d1.year == d2.year;
}
