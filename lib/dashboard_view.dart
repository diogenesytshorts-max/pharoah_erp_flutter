import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';
import 'party_master.dart';
import 'product_master.dart';
import 'route_master_view.dart';
import 'sale_entry_view.dart';
import 'sale_summary_view.dart';
import 'purchase/purchase_entry_view.dart';
import 'purchase/purchase_summary_view.dart';
import 'accounts_menu_view.dart';
import 'data_exchange_view.dart';
import 'more_features_view.dart';

// Note: Ye views hum agle steps mein create karenge, abhi navigation ready rakhte hain
class PlaceholderView extends StatelessWidget {
  final String title;
  const PlaceholderView(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)));
}

class DashboardView extends StatelessWidget {
  final VoidCallback onLogout;
  const DashboardView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final now = DateTime.now();

    // Stats Calculation
    double todaySales = ph.sales.where((s) => s.status == "Active" && _isSameDay(s.date, now)).fold(0.0, (sum, s) => sum + s.totalAmount);
    double todayPur = ph.purchases.where((p) => _isSameDay(p.date, now)).fold(0.0, (sum, p) => sum + p.totalAmount);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // --- 1. PROFESSIONAL HEADER ---
          _buildHeader(ph, onLogout),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 2. TODAY'S BUSINESS SNAPSHOT ---
                  Row(
                    children: [
                      Expanded(child: StatWidget(title: "TODAY SALE", value: "₹${todaySales.toStringAsFixed(0)}", period: "Today", icon: "trending_up", color: Colors.green)),
                      const SizedBox(width: 12),
                      Expanded(child: StatWidget(title: "TODAY PUR", value: "₹${todayPur.toStringAsFixed(0)}", period: "Today", icon: "shopping_cart", color: Colors.orange)),
                    ],
                  ),
                  
                  const SizedBox(height: 25),

                  // --- 3. PRIMARY ENTRIES (BIG BUTTONS) ---
                  const Text("QUICK TRANSACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _bigEntryButton(context, "NEW SALE", Icons.add_shopping_cart, Colors.blue.shade700, const SaleEntryView())),
                      const SizedBox(width: 15),
                      Expanded(child: _bigEntryButton(context, "PURCHASE ENTRY", Icons.downloading_rounded, Colors.orange.shade800, const PurchaseEntryView())),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // --- 4. MASTER HUB (THE 6 CORE MASTERS) ---
                  const Text("MASTER HUB", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))],
                      border: Border.all(color: Colors.grey.shade100)
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _masterIconBtn(context, "Parties", Icons.people_alt_rounded, Colors.indigo, const PartyMasterView()),
                            _masterIconBtn(context, "Item Master", Icons.inventory_2_rounded, Colors.purple, const ProductMasterView()),
                            _masterIconBtn(context, "Routes", Icons.map_rounded, Colors.teal, const RouteMasterView()),
                          ],
                        ),
                        const SizedBox(height: 25),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _masterIconBtn(context, "Companies", Icons.business_rounded, Colors.brown, const PlaceholderView("Company Master")),
                            _masterIconBtn(context, "Salts", Icons.science_rounded, Colors.deepOrange, const PlaceholderView("Salt Master")),
                            _masterIconBtn(context, "Drug Types", Icons.verified_user_rounded, Colors.cyan, const PlaceholderView("Drug Type Master")),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // --- 5. MANAGEMENT & REGISTERS ---
                  const Text("REPORTS & UTILITIES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.85,
                    children: [
                      ActionIconBtn(title: "Accounts", icon: Icons.account_balance_wallet, color: Colors.green.shade700, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AccountsMenuView()))),
                      ActionIconBtn(title: "Sale Reg", icon: Icons.description_outlined, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleSummaryView()))),
                      ActionIconBtn(title: "Pur Reg", icon: Icons.history_rounded, color: Colors.brown, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseSummaryView()))),
                      ActionIconBtn(title: "Data Hub", icon: Icons.cloud_sync_rounded, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DataExchangeView()))),
                      ActionIconBtn(title: "Settings", icon: Icons.settings_rounded, color: Colors.grey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MoreFeaturesView(onLogout: onLogout)))),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildHeader(PharoahManager ph, VoidCallback onLogout) {
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 25),
      decoration: const BoxDecoration(
        color: Color(0xFF0D47A1),
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("PHAROAH ERP", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              Text("Financial Year: ${ph.currentFY}", style: const TextStyle(fontSize: 11, color: Colors.white70)),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 28),
            onPressed: onLogout,
          )
        ],
      ),
    );
  }

  Widget _bigEntryButton(BuildContext context, String label, IconData icon, Color color, Widget target) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => target)),
      child: Container(
        height: 85,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _masterIconBtn(BuildContext context, String label, IconData icon, Color color, Widget target) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => target)),
      child: SizedBox(
        width: 80,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label, 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black87)
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) => d1.day == d2.day && d1.month == d2.month && d1.year == d2.year;
}
