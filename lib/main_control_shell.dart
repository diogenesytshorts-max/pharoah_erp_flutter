import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'widgets.dart';

// --- HAR MODULE KI PURANI FILES KO LINK KARNA ---
import 'sale_entry_view.dart';
import 'purchase/purchase_entry_view.dart';
import 'challans/challan_dashboard.dart';
import 'returns/sale_return_view.dart';
import 'returns/purchase_return_view.dart';
import 'item_ledger_view.dart';
import 'inventory_intel/shortage_register.dart';
import 'inventory_intel/stock_health_reports.dart';
import 'daybook_view.dart';
import 'ledger_reports_view.dart';
import 'accounting_views.dart';
import 'party_master.dart';
import 'product_master.dart';
import 'batch_master_view.dart';
import 'route_master_view.dart';
import 'administration/system_user_master_view.dart';
import 'company_master_view.dart';
import 'gst_report_detail_view.dart';
import 'gst_reconciliation_view.dart';
import 'pharoah_ai_vision.dart';

class MainControlShell extends StatefulWidget {
  const MainControlShell({super.key});

  @override
  State<MainControlShell> createState() => _MainControlShellState();
}

class _MainControlShellState extends State<MainControlShell> {
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // --- DYNAMIC CONTENT SELECTION ---
    // Manager ki state ke hisab se buttons chun-na
    List<ModuleAction> currentActions;
    String currentTitle;

    switch (ph.activeModule) {
      case "BILLING":
        currentActions = ph.billingActions;
        currentTitle = "BILLING & BILL MODIFY";
        break;
      case "INVENTORY":
        currentActions = ph.inventoryActions;
        currentTitle = "STOCK & ANALYTICS";
        break;
      case "ACCOUNTS":
        currentActions = ph.accountsActions;
        currentTitle = "CASH & BANK ACCOUNTS";
        break;
      case "MASTERS":
        currentActions = ph.mastersActions;
        currentTitle = "BUSINESS MASTERS";
        break;
      case "GST":
        currentActions = ph.gstActions;
        currentTitle = "GST COMPLIANCE";
        break;
      case "AI":
        // Seedha AI Screen par bhej denge yahan grid ki zaroorat nahi
        currentActions = [];
        currentTitle = "AI VISION TOOLS";
        break;
      default:
        currentActions = ph.mainMenuActions;
        currentTitle = "MAIN DASHBOARD";
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      
      // --- 1. HEADER (Traditional Look) ---
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ph.activeCompany?.name ?? "PHAROAH ERP", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("FY: ${ph.currentFY} • ${ph.activeModule}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
          ],
        ),
        actions: [
          // Home/Back Button logic
          if (ph.activeModule != "HOME")
            IconButton(
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () => ph.updateModule("HOME"),
              tooltip: "Back to Menu",
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
                  // --- 2. LIVE KPI STRIP (Purane StatWidgets) ---
                  _buildKpiStrip(ph),

                  const SizedBox(height: 30),

                  // --- 3. DYNAMIC SECTION TITLE ---
                  Text(currentTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2)),
                  const SizedBox(height: 15),

                  // --- 4. THE SMART GRID (Rendering Buttons) ---
                  PharoahSmartGrid(
                    actions: currentActions,
                    onActionTap: (action) => _handleNavigation(context, ph, action),
                  ),
                ],
              ),
            ),
          ),

          // --- 5. ALERTS BAR (Zone 3) ---
          _buildAlertsBar(),
        ],
      ),

      // --- 6. BOTTOM NAVIGATION ---
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: const Color(0xFF0D47A1),
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          if (index == 0) ph.updateModule("HOME");
          // Reports aur Settings ke liye bhi yahan logic add ho sakta hai
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: "Menu"),
          BottomNavigationBarItem(icon: Icon(Icons.analytics_outlined), label: "Reports"),
          BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), label: "Settings"),
        ],
      ),
    );
  }

  // ===========================================================================
  // LOGIC: NAVIGATION HANDLER
  // ===========================================================================
  void _handleNavigation(BuildContext context, PharoahManager ph, ModuleAction action) {
    // A. Agar category button hai (jaise Billing), toh sirf UI badlo
    if (action.navModule != null && !action.navModule!.startsWith("GO_")) {
      if (action.navModule == "AI") {
         Navigator.push(context, MaterialPageRoute(builder: (c) => const PharoahAiVision()));
      } else {
         ph.updateModule(action.navModule!);
      }
    } 
    // B. Agar Action button hai (jaise New Sale), toh asli file kholo
    else if (action.navModule != null) {
      Widget? target;
      switch (action.navModule) {
        // Billing
        case "GO_SALE": target = const SaleEntryView(); break;
        case "GO_PURCHASE": target = const PurchaseEntryView(); break;
        case "GO_CHALLAN": target = const ChallanDashboard(); break;
        // Inventory
        case "GO_STOCK": target = const ItemLedgerSearchView(); break;
        case "GO_SHORTAGE": target = const ShortageRegister(); break;
        case "GO_STOCK_HEALTH": target = const StockHealthReports(); break;
        case "GO_ITEM_LEDGER": target = const ItemLedgerSearchView(); break;
        // Accounts
        case "GO_DAYBOOK": target = const DaybookView(); break;
        case "GO_LEDGERS": target = const LedgerReportsView(); break;
        case "GO_RECEIPT": target = const VoucherEntryView(type: "Receipt"); break;
        case "GO_PAYMENT": target = const VoucherEntryView(type: "Payment"); break;
        // Masters
        case "GO_M_PARTY": target = const PartyMasterView(); break;
        case "GO_M_ITEM": target = const ProductMasterView(); break;
        case "GO_M_BATCH": target = const BatchMasterView(); break;
        case "GO_M_ROUTE": target = const RouteMasterView(); break;
        case "GO_M_STAFF": target = const SystemUserMasterView(); break;
        case "GO_M_COMP": target = const CompanyMasterView(); break;
        // GST
        case "GO_GST_1": target = const GSTReportDetailView(reportType: "GSTR-1"); break;
        case "GO_GST_3B": target = const GSTReportDetailView(reportType: "GSTR-3B"); break;
        case "GO_GST_RECON": target = const GSTReconciliationView(); break;
      }
      
      if (target != null) {
        Navigator.push(context, MaterialPageRoute(builder: (c) => target!));
      }
    }
  }

  // --- KPI STRIP BUILDER ---
  Widget _buildKpiStrip(PharoahManager ph) {
    return Column(children: [
      Row(children: [
        Expanded(child: StatWidget(title: "TODAY SALE", value: "Checked", period: "Live", icon: "trending_up", color: Colors.green)),
        const SizedBox(width: 12),
        Expanded(child: StatWidget(title: "TODAY PUR", value: "Checked", period: "Live", icon: "shopping_cart", color: Colors.orange)),
      ]),
    ]);
  }

  // --- ALERTS BAR BUILDER ---
  Widget _buildAlertsBar() {
    return Container(
      width: double.infinity, padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 15),
      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade100)),
      child: const Row(children: [
          Icon(Icons.notification_important_rounded, color: Colors.red, size: 20),
          SizedBox(width: 10),
          Text("System Alert: 5 Items near expiry!", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
      ]),
    );
  }
}
