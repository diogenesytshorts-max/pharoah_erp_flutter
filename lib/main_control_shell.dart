import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'widgets.dart';
import 'app_date_logic.dart';

// --- IMPORTS FOR NAVIGATION (Inko check kar lein ki paths sahi hain) ---
import 'sale_entry_view.dart';
import 'purchase/purchase_entry_view.dart';
import 'challans/challan_dashboard.dart';
import 'returns/sale_return_view.dart';
import 'returns/purchase_return_view.dart';

class MainControlShell extends StatefulWidget {
  const MainControlShell({super.key});

  @override
  State<MainControlShell> createState() => _MainControlShellState();
}

class _MainControlShellState extends State<MainControlShell> {
  
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Logic: Decide which list of buttons to show
    List<ModuleAction> displayActions;
    String displayTitle;

    if (ph.activeModule == "HOME") {
      displayActions = ph.mainMenuActions;
      displayTitle = "MAIN BUSINESS MODULES";
    } else if (ph.activeModule == "BILLING") {
      displayActions = ph.billingActions;
      displayTitle = "BILLING & TRANSACTIONS";
    } else {
      // Default fallback
      displayActions = ph.mainMenuActions;
      displayTitle = "PHAROAH ERP";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FD),
      
      // --- 1. HEADER (The Top Bar) ---
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ph.activeCompany?.name ?? "PHAROAH ERP", 
                 style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Financial Year: ${ph.currentFY}", 
                 style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        actions: [
          // Back button logic: Sirf tab dikhega jab hum kisi category ke andar honge
          if (ph.activeModule != "HOME")
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              tooltip: "Back to Main Menu",
              onPressed: () => ph.updateModule("HOME"),
            ),
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
        ],
      ),

      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- 2. KPI STRIP (Original StatWidgets - LIVE DATA) ---
                  _buildLiveKpiStrip(ph),

                  const SizedBox(height: 35),

                  // --- 3. DYNAMIC TITLE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(displayTitle, 
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey, letterSpacing: 1)),
                      if (ph.activeModule != "HOME")
                        const Icon(Icons.auto_awesome_motion_rounded, size: 16, color: Colors.grey),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // --- 4. WORK AREA (The Smart Grid) ---
                  PharoahSmartGrid(
                    actions: displayActions,
                    onActionTap: (action) => _handleNavigation(context, ph, action),
                  ),

                ],
              ),
            ),
          ),

          // --- 5. ZONE 3: ALERTS (Static for now, will link later) ---
          _buildAlertsSection(),
        ],
      ),
      
      // --- 6. BOTTOM NAVIGATION ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF0D47A1),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "Menu"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: "Reports"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: "Settings"),
        ],
      ),
    );
  }

  // ===========================================================================
  // PRIVATE BUILDERS & LOGIC
  // ===========================================================================

  Widget _buildLiveKpiStrip(PharoahManager ph) {
    // Current date filter for Stats
    DateTime now = DateTime.now();
    double todaySales = ph.sales
        .where((s) => s.status == "Active" && s.date.day == now.day)
        .fold(0.0, (sum, s) => sum + s.totalAmount);

    return Column(
      children: [
        Row(children: [
          Expanded(child: StatWidget(title: "TODAY SALE", value: "₹${todaySales.toStringAsFixed(0)}", period: "Live", icon: "trending_up", color: Colors.green)),
          const SizedBox(width: 12),
          Expanded(child: StatWidget(title: "STOCK VAL", value: "Checked", period: "Real-time", icon: "inventory_2", color: Colors.purple)),
        ]),
      ],
    );
  }

  Widget _buildAlertsSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: const Row(
        children: [
          Icon(Icons.notification_important_rounded, color: Colors.red, size: 20),
          SizedBox(width: 10),
          Text("System Alert: 5 Items near expiry!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
        ],
      ),
    );
  }

  void _handleNavigation(BuildContext context, PharoahManager ph, ModuleAction action) {
    // A. Module Switching (Level 1 to Level 2)
    if (action.navModule != null && !action.navModule!.startsWith("GO_")) {
      ph.updateModule(action.navModule!);
    } 
    // B. Actual Screen Navigation (Level 2 to View)
    else {
      Widget? target;
      switch (action.navModule) {
        case "GO_SALE": target = const SaleEntryView(); break;
        case "GO_PURCHASE": target = const PurchaseEntryView(); break;
        case "GO_CHALLAN": target = const ChallanDashboard(); break;
        case "GO_RETURNS": target = const SaleReturnView(); break; // Just example
      }
      
      if (target != null) {
        Navigator.push(context, MaterialPageRoute(builder: (c) => target!));
      }
    }
  }
}
