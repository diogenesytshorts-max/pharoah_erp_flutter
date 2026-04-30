import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../app_date_logic.dart';
import '../pharoah_date_controller.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../pdf/sale_invoice_pdf.dart';
import '../pdf/purchase_pdf.dart';
import '../billing_view.dart';
import '../purchase/purchase_billing_view.dart';

class ChallanStitcherWizard extends StatefulWidget {
  const ChallanStitcherWizard({super.key});

  @override
  State<ChallanStitcherWizard> createState() => _ChallanStitcherWizardState();
}

class _ChallanStitcherWizardState extends State<ChallanStitcherWizard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // --- STATE CONTROL ---
  String selectionMode = "NONE"; // NONE, MONTHLY, RANDOM
  String funnelStep = "MODE"; // MODE, ROUTE, PARTY, REVIEW
  bool isProcessing = false;
  double progressValue = 0.0;
  String progressText = "";

  DateTime fromDate = DateTime.now();
  DateTime toDate = DateTime.now();
  
  String? selectedRoute;
  List<String> selectedPartyNames = [];
  List<Map<String, dynamic>> draftBills = []; 
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
      selectedPartyNames.clear();
      draftBills.clear();
    });
  }

  // ===========================================================================
  // LOGIC: DATE & BATCH GENERATION
  // ===========================================================================

  void _setMonthlyDates(String month, String currentFY) {
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
      funnelStep = "ROUTE";
    });
  }

  Future<void> _generateDraftBills(PharoahManager ph) async {
    setState(() => isProcessing = true);
    List<Map<String, dynamic>> tempDrafts = [];
    bool isSale = _tabController.index == 0;

    for (String pName in selectedPartyNames) {
      final partyObj = ph.parties.firstWhere((p) => p.name == pName);
      
      // Filter Pending Challans
      List<dynamic> partyChallans = isSale 
          ? ph.saleChallans.where((c) => c.partyName == pName && c.status == "Pending" && 
            c.date.isAfter(fromDate.subtract(const Duration(days: 1))) && c.date.isBefore(toDate.add(const Duration(days: 1)))).toList()
          : ph.purchaseChallans.where((c) => c.distributorName == pName && c.status == "Pending" &&
            c.date.isAfter(fromDate.subtract(const Duration(days: 1))) && c.date.isBefore(toDate.add(const Duration(days: 1)))).toList();

      if (partyChallans.isEmpty) continue;

      // Assign Smart Draft Number
      String draftNo = "DRAFT-${tempDrafts.length + 1}";
      
      List<dynamic> combinedItems = [];
      for (var ch in partyChallans) {
        for (var it in ch.items) {
          String ref = "${ch.billNo} (${DateFormat('dd/MM').format(ch.date)})";
          combinedItems.add(it.copyWith(sourceChallanNo: ref));
        }
      }

      tempDrafts.add({
        'id': DateTime.now().millisecondsSinceEpoch.toString() + pName,
        'party': partyObj,
        'billNo': draftNo,
        'date': toDate,
        'items': combinedItems,
        'total': combinedItems.fold(0.0, (sum, it) => sum + it.total),
        'status': 'DRAFT', // DRAFT, SAVED
        'isSelected': true,
        'challanIds': partyChallans.map((c) => c.id).toList(),
      });
    }

    setState(() {
      draftBills = tempDrafts;
      funnelStep = "REVIEW";
      isProcessing = false;
    });
  }

  // ===========================================================================
  // MAIN BUILDER
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    bool isSaleMode = _tabController.index == 0;
    
    // THEMES: Indigo for Sale, Amber/Rust for Purchase (High Contrast)
    Color primaryColor = isSaleMode ? const Color(0xFF1A237E) : const Color(0xFFBF360C);
    Color surfaceColor = isSaleMode ? const Color(0xFFF0F2F9) : const Color(0xFFFFF8E1);

    return Scaffold(
      backgroundColor: surfaceColor,
      appBar: AppBar(
        title: Text(isSaleMode ? "SALE BATCH CONVERTER" : "PURCHASE BATCH CONVERTER", 
             style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 15)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leading: funnelStep == "MODE" ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => funnelStep = "MODE")),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          tabs: const [Tab(text: "OUTWARD (SALE)"), Tab(text: "INWARD (PUR)")],
        ),
      ),
      body: Stack(
        children: [
          _buildFunnelBody(ph, primaryColor),
          if (isProcessing) _buildProcessingOverlay(primaryColor),
        ],
      ),
    );
  }

  Widget _buildFunnelBody(PharoahManager ph, Color color) {
    if (funnelStep == "MODE") return _buildModeSelection(ph, color);
    if (funnelStep == "ROUTE") return _buildRouteSelection(ph, color);
    if (funnelStep == "PARTY") return _buildPartySelection(ph, color);
    if (funnelStep == "REVIEW") return _buildBatchReview(ph, color);
    return const Center(child: CircularProgressIndicator());
  }

  // --- STEP 1: MODE SELECTION ---
  Widget _buildModeSelection(PharoahManager ph, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _modeCard("1. MONTHLY BATCH", "Convert all challans of a specific month", Icons.calendar_view_month, color, () {
               _showMonthPicker(ph.currentFY);
            }),
            const SizedBox(height: 25),
            _modeCard("2. RANDOM RANGE", "Choose custom dates within current FY", Icons.date_range, Colors.blueGrey.shade800, () {
               _showRandomDatePicker(ph.currentFY);
            }),
          ],
        ),
      ),
    );
  }

  // --- STEP 2: ROUTE SELECTION ---
  Widget _buildRouteSelection(PharoahManager ph, Color color) {
    return Column(
      children: [
        _funnelHeader("STEP 2: FILTER BY ROUTE (OPTIONAL)", color),
        ListTile(
          tileColor: Colors.green.shade600,
          leading: const Icon(Icons.done_all, color: Colors.white),
          title: const Text("SKIP & SHOW ALL ROUTES", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          onTap: () => setState(() { selectedRoute = null; funnelStep = "PARTY"; }),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: ph.routes.length,
            itemBuilder: (c, i) => Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              child: ListTile(
                leading: Icon(Icons.map, color: color),
                title: Text(ph.routes[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                onTap: () => setState(() { selectedRoute = ph.routes[i].name; funnelStep = "PARTY"; }),
              ),
            ),
          ),
        )
      ],
    );
  }

  // --- STEP 3: PARTY MULTI-SELECT ---
  Widget _buildPartySelection(PharoahManager ph, Color color) {
    final isSale = _tabController.index == 0;
    final pendingParties = ph.parties.where((p) {
      bool hasPending = isSale 
          ? ph.saleChallans.any((c) => c.partyName == p.name && c.status == "Pending")
          : ph.purchaseChallans.any((c) => c.distributorName == p.name && c.status == "Pending");
      bool matchesRoute = selectedRoute == null || p.route == selectedRoute;
      bool matchesSearch = p.name.toLowerCase().contains(partySearch.toLowerCase());
      return hasPending && matchesRoute && matchesSearch;
    }).toList();

    return Column(
      children: [
        _funnelHeader("STEP 3: SELECT PARTIES TO STITCH", color),
        Container(
          padding: const EdgeInsets.all(15), color: Colors.white,
          child: Row(children: [
            Expanded(child: TextField(
              decoration: const InputDecoration(hintText: "Search Party Name...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
              onChanged: (v) => setState(() => partySearch = v),
            )),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  if (selectedPartyNames.length == pendingParties.length) selectedPartyNames.clear();
                  else selectedPartyNames = pendingParties.map((p) => p.name).toList();
                });
              }, 
              icon: Icon(selectedPartyNames.length == pendingParties.length ? Icons.deselect : Icons.select_all),
              label: Text(selectedPartyNames.length == pendingParties.length ? "NONE" : "ALL"),
            )
          ]),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: pendingParties.length,
            itemBuilder: (c, i) {
              final p = pendingParties[i];
              final isSelected = selectedPartyNames.contains(p.name);
              return CheckboxListTile(
                activeColor: color,
                value: isSelected,
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text("${p.city} | ${p.route}"),
                onChanged: (v) {
                  setState(() { v! ? selectedPartyNames.add(p.name) : selectedPartyNames.remove(p.name); });
                },
              );
            },
          ),
        ),
        if (selectedPartyNames.isNotEmpty)
          _bottomActionBtn("GENERATE ${selectedPartyNames.length} DRAFT BILLS", color, () => _generateDraftBills(ph)),
      ],
    );
  }

  // --- STEP 4: BATCH REVIEW SCREEN ---
  Widget _buildBatchReview(PharoahManager ph, Color color) {
    bool allSelected = draftBills.every((b) => b['isSelected']);
    int savedCount = draftBills.where((b) => b['status'] == 'SAVED').length;

    return Column(
      children: [
        // Top Summary & Bulk Actions
        Container(
          padding: const EdgeInsets.all(15), color: Colors.white,
          child: Row(children: [
            Checkbox(value: allSelected, onChanged: (v) {
              setState(() { for (var b in draftBills) { b['isSelected'] = v; } });
            }),
            const Text("SEL ALL", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            const Spacer(),
            _bulkBtn("SAVE", Icons.save, Colors.blue, () => _handleBulkAction(ph, "SAVE")),
            const SizedBox(width: 8),
            _bulkBtn("ZIP", Icons.folder_zip, Colors.green, () => _handleBulkAction(ph, "PRINT")),
            const SizedBox(width: 8),
            _bulkBtn("DEL", Icons.delete, Colors.red, () => setState(() => draftBills.removeWhere((b) => b['isSelected']))),
          ]),
        ),

        if (savedCount > 0)
          Container(width: double.infinity, padding: const EdgeInsets.all(8), color: Colors.green.shade100, 
            child: Text("✅ $savedCount Bills successfully saved to database.", textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green))),

        Expanded(
          child: ListView.builder(
            itemCount: draftBills.length,
            itemBuilder: (c, i) {
              final b = draftBills[i];
              bool isSaved = b['status'] == 'SAVED';
              return Card(
                elevation: 0, margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSaved ? Colors.green : Colors.grey.shade300)),
                child: Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    children: [
                      Row(children: [
                        Checkbox(value: b['isSelected'], onChanged: isSaved ? null : (v) => setState(() => b['isSelected'] = v)),
                        Expanded(child: Text(b['party'].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                        Text("₹${b['total'].toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                      ]),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _rowAction(Icons.edit, "Edit", Colors.blue, () => _editDraft(ph, b, i)),
                          _rowAction(isSaved ? Icons.check_circle : Icons.cloud_upload, "Save", isSaved ? Colors.green : Colors.orange, () => _saveSingleDraft(ph, i)),
                          _rowAction(Icons.print, "Print", Colors.teal, () => _printSingleDraft(ph, i)),
                          _rowAction(Icons.email, "Mail", Colors.purple, () {}),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // ACTION HANDLERS
  // ===========================================================================

  Future<void> _saveSingleDraft(PharoahManager ph, int index) async {
    final b = draftBills[index];
    if (b['status'] == 'SAVED') return;

    setState(() { isProcessing = true; progressText = "Saving ${b['party'].name}..."; });

    bool isSale = _tabController.index == 0;
    String finalNo;

    if (isSale) {
      var series = ph.getDefaultSeries("SALE");
      finalNo = await PharoahNumberingEngine.getNextNumber(type: "SALE", companyID: ph.activeCompany!.id, prefix: series.prefix, startFrom: series.startNumber, currentList: ph.sales);
      ph.finalizeSale(billNo: finalNo, date: b['date'], party: b['party'], items: b['items'].cast<BillItem>(), total: b['total'], mode: "CREDIT", linkedIds: b['challanIds']);
    } else {
      finalNo = await PharoahNumberingEngine.getNextNumber(type: "PURCHASE", companyID: ph.activeCompany!.id, prefix: "PUR-", startFrom: 1, currentList: ph.purchases);
      ph.finalizePurchase(internalNo: finalNo, billNo: "", date: b['date'], party: b['party'], items: b['items'].cast<PurchaseItem>(), total: b['total'], mode: "CREDIT");
    }

    setState(() {
      draftBills[index]['status'] = 'SAVED';
      draftBills[index]['billNo'] = finalNo;
      isProcessing = false;
    });
  }

  void _handleBulkAction(PharoahManager ph, String action) async {
    var selected = draftBills.where((b) => b['isSelected'] && b['status'] == 'DRAFT').toList();
    if (selected.isEmpty && action == "SAVE") return;

    setState(() { isProcessing = true; progressValue = 0.0; });

    for (int i = 0; i < draftBills.length; i++) {
      if (draftBills[i]['isSelected'] && draftBills[i]['status'] == 'DRAFT') {
        setState(() { 
          progressText = "$action-ing ${draftBills[i]['party'].name}..."; 
          progressValue = (i + 1) / draftBills.length;
        });
        await _saveSingleDraft(ph, i);
        if (action == "PRINT") await _printSingleDraft(ph, i);
      }
    }

    setState(() { isProcessing = false; progressValue = 0.0; });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Bulk $action Complete!")));
  }

  Future<void> _printSingleDraft(PharoahManager ph, int index) async {
    if (draftBills[index]['status'] == 'DRAFT') await _saveSingleDraft(ph, index);
    final b = draftBills[index];
    if (ph.activeCompany == null) return;

    if (_tabController.index == 0) {
      final saleObj = ph.sales.firstWhere((s) => s.billNo == b['billNo']);
      await SaleInvoicePdf.generate(saleObj, b['party'], ph.activeCompany!);
    } else {
      final purObj = ph.purchases.firstWhere((p) => p.internalNo == b['billNo']);
      await PurchasePdf.generate(purObj, b['party'], ph.activeCompany!);
    }
  }

  void _editDraft(PharoahManager ph, Map<String, dynamic> b, int index) {
    if (_tabController.index == 0) {
      Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(party: b['party'], billNo: "TEMP", billDate: b['date'], mode: "CREDIT", existingItems: b['items'].cast<BillItem>())));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: b['party'], internalNo: "TEMP", distBillNo: "", billDate: b['date'], entryDate: DateTime.now(), mode: "CREDIT", existingItems: b['items'].cast<PurchaseItem>())));
    }
  }

  // --- UI COMPONENTS ---

  Widget _modeCard(String t, String s, IconData i, Color c, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.3), width: 2), boxShadow: [BoxShadow(color: c.withOpacity(0.1), blurRadius: 10)]),
        child: Row(children: [
          Icon(i, size: 40, color: c),
          const SizedBox(width: 20),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)),
            Text(s, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
          ])),
          Icon(Icons.arrow_forward_ios, size: 16, color: c),
        ]),
      ),
    );
  }

  Widget _funnelHeader(String title, Color c) => Container(width: double.infinity, padding: const EdgeInsets.all(15), color: c, child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1)));

  Widget _bulkBtn(String l, IconData i, Color c, VoidCallback onTap) => ElevatedButton.icon(onPressed: onTap, icon: Icon(i, size: 14), label: Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 10)));

  Widget _rowAction(IconData i, String l, Color c, VoidCallback onTap) => InkWell(onTap: onTap, child: Column(children: [Icon(i, color: c, size: 18), Text(l, style: TextStyle(fontSize: 9, color: c, fontWeight: FontWeight.bold))]));

  Widget _bottomActionBtn(String label, Color color, VoidCallback onTap) => Padding(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: onTap, child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));

  Widget _buildProcessingOverlay(Color color) {
    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(value: progressValue > 0 ? progressValue : null, color: color),
            const SizedBox(height: 20),
            Text(progressText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            if (progressValue > 0) Text("${(progressValue * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _showMonthPicker(String fy) {
    showModalBottomSheet(context: context, builder: (c) => ListView(children: fyMonths.map((m) => ListTile(title: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(c); _setMonthlyDates(m, fy); })).toList()));
  }

  void _showRandomDatePicker(String fy) async {
    DateTime? start = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: AppDateLogic.getFYStart(fy));
    if (start == null) return;
    DateTime? end = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: start);
    if (end != null) {
      setState(() { fromDate = start; toDate = end; selectionMode = "RANDOM"; funnelStep = "ROUTE"; });
    }
  }
}
