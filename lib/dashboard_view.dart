import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'inventory_logic_center.dart';
import 'widgets.dart';
import 'sale_entry_view.dart';
import 'purchase/purchase_entry_view.dart';
import 'accounts_menu_view.dart';
import 'master_hub_view.dart';
import 'sale_summary_view.dart';
import 'purchase/purchase_summary_view.dart';
import 'data_exchange_view.dart';
import 'more_features_view.dart';
import 'app_date_logic.dart'; // Aapka purana logic connection

class DashboardView extends StatelessWidget {
  final VoidCallback onLogout;
  const DashboardView({super.key, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // --- NAYA: MULTI-COMPANY INFO ---
    final compName = ph.activeCompany?.name ?? "PHAROAH ERP";
    final compID = ph.activeCompany?.id ?? "N/A";
    final businessType = ph.activeCompany?.businessType ?? "WHOLESALE";

    // --- PURANA SMART DATE LOGIC ---
    // Agar user purane saal mein hai (Audit Mode), toh 'today' us saal ki 31st March hogi.
    DateTime workingDate = AppDateLogic.getSmartDate(ph.currentFY);

    double todaySales = ph.sales
        .where((s) => s.status == "Active" && _isSameDay(s.date, workingDate))
        .fold(0.0, (sum, s) => sum + s.totalAmount);
    
    double todayPur = ph.purchases
        .where((p) => _isSameDay(p.date, workingDate))
        .fold(0.0, (sum, p) => sum + p.totalAmount);
        
    double stockVal = InventoryLogicCenter.calculateTotalStockValue(
      batchHistory: ph.batchHistory, 
      medicines: ph.medicines
    );

    // --- PURANA AUDIT MODE CHECK ---
    bool isPastYear = !AppDateLogic.isValidInFY(DateTime.now(), ph.currentFY);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      body: Column(
        children: [
          // --- HEADER SECTION (MERGED LOGIC) ---
          Container(
            padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 25),
            decoration: BoxDecoration(
              // NAYA: Color change based on Audit Mode (Purple) or Normal (Blue)
              color: isPastYear ? Colors.purple.shade900 : const Color(0xFF0D47A1),
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30))
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isPastYear ? "AUDIT: $compName" : compName, 
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Row(
                      children: [
                        Text("ID: $compID", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(color: isPastYear ? Colors.orange : Colors.blue.shade300, borderRadius: BorderRadius.circular(4)),
                          child: Text(businessType, style: const TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      ],
                    ),
                    Text("Working Year: ${ph.currentFY}", style: const TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
                const Spacer(),
                // --- SWITCH COMPANY ICON (Updated from Power Icon) ---
                IconButton(
                  icon: const Icon(Icons.swap_horizontal_circle_outlined, color: Colors.white, size: 32), 
                  onPressed: onLogout, // Session clear karke dukan selection par le jayega
                  tooltip: "Switch Company",
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
                  // --- PURANA DATE INDICATOR ---
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 5),
                    child: Row(
                      children: [
                        Icon(isPastYear ? Icons.history_toggle_off : Icons.calendar_today, size: 14, color: Colors.blueGrey),
                        const SizedBox(width: 5),
                        Text(
                          isPastYear ? "Showing data for: ${AppDateLogic.format(workingDate)}" : "Today: ${AppDateLogic.format(workingDate)}",
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),

                  // --- STATS WITH DYNAMIC TITLES ---
                  Row(children: [
                    Expanded(child: StatWidget(
                      title: isPastYear ? "LAST DAY SALE" : "TODAY SALE", 
                      value: "₹${todaySales.toStringAsFixed(0)}", 
                      period: isPastYear ? "FY Final" : "Today", 
                      icon: "trending_up", 
                      color: isPastYear ? Colors.purple : Colors.green
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: StatWidget(
                      title: isPastYear ? "LAST DAY PUR" : "TODAY PUR", 
                      value: "₹${todayPur.toStringAsFixed(0)}", 
                      period: isPastYear ? "FY Final" : "Today", 
                      icon: "shopping_cart", 
                      color: Colors.orange
                    )),
                  ]),
                  
                  const SizedBox(height: 12),
                  StatWidget(
                    title: isPastYear ? "CLOSING STOCK VALUE" : "TOTAL STOCK VALUE", 
                    value: "₹${stockVal.toStringAsFixed(0)}", 
                    period: "Calculated", 
                    icon: "inventory_2", 
                    color: isPastYear ? Colors.deepPurple : Colors.indigo
                  ),
                  
                  const SizedBox(height: 30),
                  const Text("DAILY TRANSACTIONS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _bigEntryButton(context, "NEW SALE", Icons.add_shopping_cart, Colors.blue.shade700, const SaleEntryView())),
                    const SizedBox(width: 15),
                    Expanded(child: _bigEntryButton(context, "PURCHASE ENTRY", Icons.downloading_rounded, Colors.orange.shade800, const PurchaseEntryView())),
                  ]),
                  
                  const SizedBox(height: 30),
                  _buildMasterHubGateway(context),
                  
                  const SizedBox(height: 30),
                  const Text("REPORTS & UTILITIES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1)),
                  const SizedBox(height: 12),
                  GridView.count(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.9,
                    children: [
                      ActionIconBtn(title: "Accounts", icon: Icons.account_balance_wallet, color: Colors.green.shade700, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AccountsMenuView()))),
                      ActionIconBtn(title: "Sale Reg", icon: Icons.description_outlined, color: Colors.blue, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleSummaryView()))),
                      ActionIconBtn(title: "Pur Reg", icon: Icons.history_rounded, color: Colors.brown, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseSummaryView()))),
                      ActionIconBtn(title: "Data Hub", icon: Icons.cloud_sync_rounded, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DataExchangeView()))),
                      ActionIconBtn(title: "Settings", icon: Icons.settings_rounded, color: Colors.grey, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => MoreFeaturesView(onLogout: onLogout)))),
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

  Widget _bigEntryButton(BuildContext context, String label, IconData icon, Color color, Widget target) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => target)),
      child: Container(
        height: 85,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: Colors.white, size: 28), const SizedBox(height: 8), Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))]),
      ),
    );
  }

  Widget _buildMasterHubGateway(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MasterHubView())),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.indigo.shade800, Colors.indigo.shade500]), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
        child: const Row(children: [
          Icon(Icons.stars_rounded, color: Colors.white, size: 42),
          SizedBox(width: 18),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("MASTER HUB", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), Text("Manage Parties, Items, Companies & more", style: TextStyle(color: Colors.white70, fontSize: 11))])),
          Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 18),
        ]),
      ),
    );
  }

  bool _isSameDay(DateTime d1, DateTime d2) => d1.day == d2.day && d1.month == d2.month && d1.year == d2.year;
}
