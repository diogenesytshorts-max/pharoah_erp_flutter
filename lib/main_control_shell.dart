void _handleNavigation(BuildContext context, PharoahManager ph, ModuleAction action) {
  // A. LEVEL 1: Category Change (State Swap)
  if (action.navModule != null && !action.navModule!.startsWith("GO_")) {
    ph.updateModule(action.navModule!);
  } 
  
  // B. LEVEL 2: Actual File Navigation (Navigator Push)
  else if (action.navModule != null) {
    Widget? target;
    
    switch (action.navModule) {
      // Billing Links
      case "GO_SALE": target = const SaleEntryView(); break;
      case "GO_PURCHASE": target = const PurchaseEntryView(); break;
      case "GO_CHALLAN": target = const ChallanDashboard(); break;
      
      // Inventory Links
      case "GO_STOCK": target = const ItemLedgerSearchView(); break; // Example
      case "GO_SHORTAGE": target = const ShortageRegister(); break;
      
      // Accounts Links
      case "GO_DAYBOOK": target = const DaybookView(); break;
      case "GO_LEDGERS": target = const LedgerReportsView(); break;
      case "GO_RECEIPT": target = const VoucherEntryView(type: "Receipt"); break;
      case "GO_PAYMENT": target = const VoucherEntryView(type: "Payment"); break;

      // Masters Links
      case "GO_M_PARTY": target = const PartyMasterView(); break;
      case "GO_M_ITEM": target = const ProductMasterView(); break;
      case "GO_M_BATCH": target = const BatchMasterView(); break;
      case "GO_M_ROUTE": target = const RouteMasterView(); break;
      case "GO_M_STAFF": target = const SystemUserMasterView(); break;

      // GST Links
      case "GO_GST_1": target = const GSTReportDetailView(reportType: "GSTR-1"); break;
      case "GO_GST_RECON": target = const GSTReconciliationView(); break;
    }

    if (target != null) {
      Navigator.push(context, MaterialPageRoute(builder: (c) => target!));
    }
  }
}
