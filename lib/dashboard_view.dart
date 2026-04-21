import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';
import 'product_master.dart';
import 'party_master.dart';
import 'sale_entry_view.dart';
import 'sale_bill_modify_view.dart';
import 'purchase/purchase_entry_view.dart';
import 'purchase/purchase_summary_view.dart';
import 'more_features_view.dart';
import 'sale_summary_view.dart';
import 'data_exchange_view.dart';
import 'accounting_views.dart';
import 'ledger_reports_view.dart';
import 'daybook_view.dart';
import 'profit_loss_view.dart';
import 'item_ledger_view.dart';

class DashboardView extends StatelessWidget {
  final VoidCallback onLogout;
  const DashboardView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final now = DateTime.now();

    // Stats Calculations
    double todaySales = ph.sales.where((s) => s.status == "Active" && _isSameDay(s.date, now)).fold(0.0, (sum, s) => sum + s.totalAmount);
    double todayPur = ph.purchases.where((p) => _isSameDay(p.date, now)).fold(0.0, (sum, p) => sum + p.totalAmount);
    double stockVal = ph.medicines.fold(0.0, (sum, m) => sum + (m.stock * m.purRate));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 25),
            decoration: const BoxDecoration(color: Color(0xFF0D47A1), borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text("PHAROAH ERP", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                Text("FY: ${ph.currentFY} | Dashboard", style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ]),
              const Spacer(),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white), onPressed: onLogout)
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- STATS GRID ---
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
                    children: [
                      StatWidget(title: "TODAY SALE", value: "₹${todaySales.toStringAsFixed(0)}", period: "Today", icon: "trending_up", color: Colors.green),
                      StatWidget(title: "TODAY PUR", value: "₹${todayPur.toStringAsFixed(0)}", period: "Today", icon: "shopping_cart", color: Colors.orange),
                      StatWidget(title: "STOCK VALUE", value: "₹${stockVal.toStringAsFixed(0)}", period: "Total", icon: "inventory_2", color: Colors.purple),
                      StatWidget(title: "NET PROFIT", value: "VIEW", period: "Analysis", icon: "payments", color: Colors.blue),
                    ],
                  ),
                  const SizedBox(height: 25),

                  // --- CASH & ACCOUNTING ---
                  const Text("ACCOUNTING & CASH", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: ActionIconBtn(title: "Receipt", icon: Icons.add_chart, color: Colors.green, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoucherEntryView(type: "Receipt"))))),
                    const SizedBox(width: 8),
                    Expanded(child: ActionIconBtn(title: "Payment", icon: Icons.analytics, color: Colors.red, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const VoucherEntryView(type: "Payment"))))),
                    const SizedBox(width: 8),
                    Expanded(child: ActionIconBtn(title: "Daybook", icon: Icons.menu_book, color: Colors.blueGrey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DaybookView())))),
                    const SizedBox(width: 8),
                    Expanded(child: ActionIconBtn(title: "Khaata", icon: Icons.people, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const LedgerReportsView())))),
                  ]),
                  const SizedBox(height: 25),

                  // --- MAIN ACTIONS ---
                  const Text("BUSINESS OPERATIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9,
                    children: [
                      ActionIconBtn(title: "New Sale", icon: Icons.add_shopping_cart, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleEntryView()))),
                      ActionIconBtn(title: "Stock-In", icon: Icons.downloading, color: Colors.orange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseEntryView()))),
                      ActionIconBtn(title: "Inventory", icon: Icons.inventory, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView()))),
                      ActionIconBtn(title: "Sale Reg", icon: Icons.assessment, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleSummaryView()))),
                      ActionIconBtn(title: "Pur Reg", icon: Icons.history, color: Colors.brown, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseSummaryView()))),
                      ActionIconBtn(title: "P & L", icon: Icons.pie_chart, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProfitLossView()))),
                      ActionIconBtn(title: "Ledgers", icon: Icons.contact_page, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView()))),
                      ActionIconBtn(title: "Stock Trk", icon: Icons.track_changes, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ItemLedgerSearchView()))),
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
  bool _isSameDay(DateTime d1, DateTime d2) => d1.day == d2.day && d1.month == d2.month && d1.year == d2.year;
}
