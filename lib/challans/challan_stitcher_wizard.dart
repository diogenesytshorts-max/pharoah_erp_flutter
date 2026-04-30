// FILE: lib/challans/challan_stitcher_wizard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pharoah_date_controller.dart';
import '../billing_view.dart';
import '../purchase/purchase_billing_view.dart';
import '../logic/pharoah_numbering_engine.dart'; // <--- YE MISSING THA (FIXED)

class ChallanStitcherWizard extends StatefulWidget {
  const ChallanStitcherWizard({super.key});

  @override
  State<ChallanStitcherWizard> createState() => _ChallanStitcherWizardState();
}

class _ChallanStitcherWizardState extends State<ChallanStitcherWizard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // --- STATE CONTROL ---
  String selectionMode = "NONE"; // NONE, MONTHLY, RANDOM
  String funnelStep = "MODE"; // MODE, ROUTE, PARTY, ITEMS
  
  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  
  String? selectedRoute;
  Party? selectedParty;
  List<String> selectedChallanIds = [];
  String partySearch = "";

  final List<String> fyMonths = ["April", "May", "June", "July", "August", "September", "October", "November", "December", "January", "February", "March"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() { if(_tabController.indexIsChanging) _resetWizard(); });
  }

  void _resetWizard() {
    setState(() {
      selectionMode = "NONE";
      funnelStep = "MODE";
      selectedRoute = null;
      selectedParty = null;
      selectedChallanIds.clear();
    });
  }

  // --- LOGIC: FY AWARE MONTHLY DATES ---
  void _setMonthlyDates(String month, String currentFY) {
    try {
      int startYear = int.parse(currentFY.split('-')[0]);
      if (startYear < 2000) startYear += 2000;

      int monthIdx = fyMonths.indexOf(month);
      int targetMonth = (monthIdx + 4); 
      int targetYear = startYear;

      if (targetMonth > 12) {
        targetMonth -= 12; 
        targetYear++; 
      }

      setState(() {
        fromDate = DateTime(targetYear, targetMonth, 1);
        toDate = DateTime(targetYear, targetMonth + 1, 0);
        selectionMode = "MONTHLY";
        funnelStep = "ROUTE"; // Next Step
      });
    } catch (e) {
      debugPrint("Date Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    bool isSaleMode = _tabController.index == 0;
    
    // UI COLORS (High Contrast)
    Color primaryColor = isSaleMode ? const Color(0xFF1A237E) : const Color(0xFFBF360C); // Deep Indigo vs Deep Amber/Rust
    Color surfaceColor = isSaleMode ? const Color(0xFFF0F2F9) : const Color(0xFFFFF8E1);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(isSaleMode ? "SALE BILL STITCHER" : "PURCHASE BILL STITCHER", 
             style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 16)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leading: funnelStep != "MODE" ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => funnelStep = "MODE")) : null,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          tabs: const [Tab(text: "OUTWARD (SALE)"), Tab(text: "INWARD (PUR)")],
        ),
      ),
      body: _buildFunnelBody(ph, primaryColor),
    );
  }

  Widget _buildFunnelBody(PharoahManager ph, Color color) {
    if (funnelStep == "MODE") return _buildModeSelection(ph, color);
    if (funnelStep == "ROUTE") return _buildRouteSelection(ph, color);
    if (funnelStep == "PARTY") return _buildPartySelection(ph, color);
    return const Center(child: Text("Loading..."));
  }

  // --- STEP 1: MODE SELECTION ---
  Widget _buildModeSelection(PharoahManager ph, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeCard("1. MONTHLY BATCH", "Convert challans of a specific month", Icons.calendar_view_month, color, () {
               _showMonthPicker(ph.currentFY);
            }),
            const SizedBox(height: 20),
            _modeCard("2. RANDOM RANGE", "Pick custom dates from April to March", Icons.date_range, Colors.blueGrey.shade800, () {
               setState(() { selectionMode = "RANDOM"; funnelStep = "ROUTE"; });
            }),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: ROUTE SELECTION (Optional) ---
  Widget _buildRouteSelection(PharoahManager ph, Color color) {
    return Column(
      children: [
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20), color: color.withOpacity(0.1),
          child: const Text("STEP 2: SELECT ROUTE / AREA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1)),
        ),
        ListTile(
          tileColor: Colors.green.shade50,
          leading: const Icon(Icons.Done_all, color: Colors.green),
          title: const Text("SKIP / ALL ROUTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
          onTap: () => setState(() { selectedRoute = null; funnelStep = "PARTY"; }),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: ph.routes.length,
            itemBuilder: (c, i) => ListTile(
              leading: const Icon(Icons.map_outlined),
              title: Text(ph.routes[i].name),
              onTap: () => setState(() { selectedRoute = ph.routes[i].name; funnelStep = "PARTY"; }),
            ),
          ),
        )
      ],
    );
  }

  // --- STEP 3: PARTY SELECTION (Smart Filter) ---
  Widget _buildPartySelection(PharoahManager ph, Color color) {
    // Logic: Sirf wahi parties jinpe pending challan hai + Route filter
    final pendingParties = ph.parties.where((p) {
      bool hasPending = (_tabController.index == 0) 
          ? ph.saleChallans.any((c) => c.partyName == p.name && c.status == "Pending")
          : ph.purchaseChallans.any((c) => c.distributorName == p.name && c.status == "Pending");
      
      bool matchesRoute = selectedRoute == null || p.route == selectedRoute;
      return hasPending && matchesRoute;
    }).toList();

    return Column(
      children: [
        Container(padding: const EdgeInsets.all(15), color: Colors.white, child: TextField(
          decoration: const InputDecoration(hintText: "Search Party...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
          onChanged: (v) => setState(() => partySearch = v),
        )),
        Expanded(
          child: ListView.builder(
            itemCount: pendingParties.length,
            itemBuilder: (c, i) => ListTile(
              leading: const CircleAvatar(child: Icon(Icons.person)),
              title: Text(pendingParties[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(pendingParties[i].city),
              onTap: () {
                // Yahan Step 4 (Review) par bhejenge next step mein
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Selected: ${pendingParties[i].name}")));
              },
            ),
          ),
        )
      ],
    );
  }

  // --- HELPER UI ---
  Widget _modeCard(String t, String s, IconData i, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.3), width: 2)),
        child: Row(children: [
          Icon(i, size: 40, color: c),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
            Text(s, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 16),
        ]),
      ),
    );
  }

  void _showMonthPicker(String fy) {
    showModalBottomSheet(
      context: context,
      builder: (c) => ListView(
        children: fyMonths.map((m) => ListTile(
          title: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)),
          onTap: () { Navigator.pop(c); _setMonthlyDates(m, fy); },
        )).toList(),
      ),
    );
  }
}
