import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../app_date_logic.dart';
import '../pharoah_date_controller.dart';
import '../logic/pharoah_numbering_engine.dart';
import '../pdf/sale_invoice_pdf.dart';
import '../pdf/purchase_pdf.dart';
import '../pdf/bulk_pdf_service.dart';
import '../billing_view.dart';
import '../purchase/purchase_billing_view.dart';

class ChallanStitcherWizard extends StatefulWidget {
  const ChallanStitcherWizard({super.key});

  @override
  State<ChallanStitcherWizard> createState() => _ChallanStitcherWizardState();
}

class _ChallanStitcherWizardState extends State<ChallanStitcherWizard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // --- FLOW CONTROL ---
  String funnelStep = "MODE"; // MODE, ROUTE, PARTY, REVIEW
  String selectionMode = "NONE"; 
  bool isProcessing = false;
  double progressValue = 0.0;
  String progressText = "";

  // --- DATA SELECTION ---
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
    setState(() { funnelStep = "MODE"; selectionMode = "NONE"; selectedRoute = null; selectedPartyNames.clear(); draftBills.clear(); });
  }

  // ===========================================================================
  // ⚡ ATOMIC BATCH LOGIC (SAVES DISK FROM FREEZING)
  // ===========================================================================
  
  Future<void> _handleBatchSave(PharoahManager ph) async {
    var selected = draftBills.where((b) => b['isSelected'] && b['status'] == 'DRAFT').toList();
    if (selected.isEmpty) return;

    setState(() { isProcessing = true; progressValue = 0.1; progressText = "Preparing Batch..."; });

    bool isSale = _tabController.index == 0;
    
    if (isSale) {
      // --- SALES BATCH ---
      List<Sale> batchToSave = [];
      var series = ph.getDefaultSeries("SALE");
      String startNoStr = await PharoahNumberingEngine.getNextNumber(type: "SALE", companyID: ph.activeCompany!.id, prefix: series.prefix, startFrom: series.startNumber, currentList: ph.sales);
      int nextNum = int.parse(startNoStr.replaceAll(series.prefix, ""));

      for (var b in selected) {
        String finalBillNo = "${series.prefix}$nextNum";
        batchToSave.add(Sale(
          id: DateTime.now().millisecondsSinceEpoch.toString() + finalBillNo,
          billNo: finalBillNo,
          date: b['date'],
          partyName: b['party'].name,
          partyGstin: b['party'].gst,
          partyState: b['party'].state,
          items: b['items'].cast<BillItem>(),
          totalAmount: b['total'],
          paymentMode: "CREDIT",
          linkedChallanIds: b['challanIds']
        ));
        nextNum++;
      }
      await ph.finalizeBatchSales(batchToSave);
      _updateLocalStatus(batchToSave, true);
    } else {
      // --- PURCHASE BATCH ---
      List<Purchase> purBatch = [];
      for (var b in selected) {
        String pNo = await PharoahNumberingEngine.getNextNumber(type: "PURCHASE", companyID: ph.activeCompany!.id, prefix: "PUR-", startFrom: 1, currentList: ph.purchases);
        purBatch.add(Purchase(
          id: DateTime.now().millisecondsSinceEpoch.toString() + pNo,
          internalNo: pNo, billNo: "BATCH-CONV", 
          date: b['date'], entryDate: DateTime.now(),
          distributorName: b['party'].name,
          items: b['items'].cast<PurchaseItem>(),
          totalAmount: b['total'], paymentMode: "CREDIT"
        ));
      }
      await ph.finalizeBatchPurchases(purBatch);
      _updateLocalStatus(purBatch, false);
    }

    setState(() { isProcessing = false; progressValue = 0.0; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Batch Saved Successfully!"), backgroundColor: Colors.green));
  }

  void _updateLocalStatus(List<dynamic> savedBatch, bool isSale) {
    setState(() {
      for (var b in draftBills) {
        if (b['isSelected'] && b['status'] == 'DRAFT') {
          b['status'] = 'SAVED';
          try {
            var saved = savedBatch.firstWhere((s) => (isSale ? s.partyName : s.distributorName) == b['party'].name);
            b['billNo'] = isSale ? saved.billNo : saved.internalNo;
          } catch(e) {}
        }
      }
    });
  }

  // ===========================================================================
  // 📁 ZIP EXPORT ENGINE
  // ===========================================================================

  Future<void> _handleZipExport(PharoahManager ph) async {
    var selected = draftBills.where((b) => b['isSelected']).toList();
    if (selected.isEmpty) return;

    if (selected.any((b) => b['status'] == 'DRAFT')) await _handleBatchSave(ph);

    List<Map<String, dynamic>> finalPayload = [];
    for (var draft in selected) {
      try {
        final saleOrPur = _tabController.index == 0 
            ? ph.sales.firstWhere((s) => s.billNo == draft['billNo'])
            : ph.purchases.firstWhere((p) => p.internalNo == draft['billNo']);
        finalPayload.add({'saleObj': saleOrPur, 'party': draft['party'], 'billNo': draft['billNo']});
      } catch (e) { continue; }
    }

    setState(() { isProcessing = true; progressValue = 0.0; progressText = "Generating Zip..."; });
    try {
      String path = await BulkPdfService.createBillsZip(
        selectedDrafts: finalPayload, 
        shop: ph.activeCompany!, 
        onProgress: (v, n) => setState(() { progressValue = v; progressText = "Packing: $n"; })
      );
      setState(() => isProcessing = false);
      await Share.shareXFiles([XFile(path)], subject: 'Invoices_Batch');
    } catch (e) { setState(() => isProcessing = false); }
  }

  // ===========================================================================
  // 🖥️ UI BUILDERS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    bool isSale = _tabController.index == 0;
    Color primaryColor = isSale ? const Color(0xFF0D47A1) : const Color(0xFFE65100);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text(isSale ? "SALE BATCH CONVERTER" : "PURCHASE BATCH CONVERTER", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5,
        bottom: TabBar(controller: _tabController, labelColor: primaryColor, unselectedLabelColor: Colors.grey, indicatorColor: primaryColor, tabs: const [Tab(text: "OUTWARD"), Tab(text: "INWARD")]),
      ),
      body: Stack(children: [
        _buildStepContent(ph, primaryColor),
        if (isProcessing) _buildOverlay(primaryColor),
      ]),
    );
  }

  Widget _buildStepContent(PharoahManager ph, Color color) {
    if (funnelStep == "MODE") return _stepMode(ph, color);
    if (funnelStep == "ROUTE") return _stepRoute(ph, color);
    if (funnelStep == "PARTY") return _stepParty(ph, color);
    if (funnelStep == "REVIEW") return _stepBatchReview(ph, color);
    return const SizedBox();
  }

  // --- STEP UI HELPERS ---
  Widget _stepMode(PharoahManager ph, Color color) {
    return Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        _modeCard("MONTHLY BATCH", "Select a month from Apr to Mar", Icons.calendar_month, color, () => _showMonthPicker(ph.currentFY)),
        const SizedBox(height: 25),
        _modeCard("RANDOM RANGE", "Custom dates in current FY", Icons.date_range, Colors.blueGrey.shade800, () => _pickRandom(ph.currentFY)),
    ])));
  }

  Widget _stepRoute(PharoahManager ph, Color color) {
    return Column(children: [
      _header("STEP 2: SELECT ROUTE (OR SKIP)"),
      ListTile(tileColor: Colors.white, leading: const Icon(Icons.done_all, color: Colors.green), title: const Text("SKIP & SHOW ALL ROUTES", style: TextStyle(fontWeight: FontWeight.bold)), onTap: () => setState(() { selectedRoute = null; funnelStep = "PARTY"; })),
      Expanded(child: ListView.builder(itemCount: ph.routes.length, itemBuilder: (c, i) => Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(leading: Icon(Icons.map, color: color), title: Text(ph.routes[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () => setState(() { selectedRoute = ph.routes[i].name; funnelStep = "PARTY"; }))))),
    ]);
  }

  Widget _stepParty(PharoahManager ph, Color color) {
    bool isSale = _tabController.index == 0;
    final list = ph.parties.where((p) {
      bool hasPend = isSale ? ph.saleChallans.any((c)=>c.partyName==p.name && c.status=="Pending") : ph.purchaseChallans.any((c)=>c.distributorName==p.name && c.status=="Pending");
      return hasPend && (selectedRoute == null || p.route == selectedRoute) && p.name.toLowerCase().contains(partySearch.toLowerCase());
    }).toList();

    return Column(children: [
      _header("STEP 3: SELECT PARTIES TO CONVERT"),
      Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        Expanded(child: TextField(decoration: const InputDecoration(hintText: "Search Party...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v)=>setState(()=>partySearch=v))),
        const SizedBox(width: 10),
        TextButton(onPressed: () => setState(() => selectedPartyNames = list.map((e)=>e.name).toList()), child: const Text("SELECT ALL")),
      ])),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => CheckboxListTile(activeColor: color, value: selectedPartyNames.contains(list[i].name), title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), onChanged: (v) => setState(() { v! ? selectedPartyNames.add(list[i].name) : selectedPartyNames.remove(list[i].name); })))),
      if(selectedPartyNames.isNotEmpty) Container(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(double.infinity, 55)), onPressed: () => _generateDrafts(ph), child: const Text("CONVERT SELECTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
    ]);
  }

  Widget _stepBatchReview(PharoahManager ph, Color color) {
    bool allSel = draftBills.every((b) => b['isSelected']);
    return Column(children: [
      Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
        Checkbox(value: allSel, onChanged: (v) => setState(() { for(var b in draftBills) { b['isSelected'] = v; } })),
        const Text("SEL ALL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10)),
        const Spacer(),
        _bulkBtn("SAVE ALL", Icons.save, Colors.blue.shade700, () => _handleBatchSave(ph)),
        const SizedBox(width: 8),
        _bulkBtn("ZIP PDF", Icons.folder_zip, Colors.green.shade700, () => _handleZipExport(ph)),
      ])),
      Expanded(child: ListView.builder(itemCount: draftBills.length, padding: const EdgeInsets.all(12), itemBuilder: (c, i) {
        final b = draftBills[i]; bool isSaved = b['status'] == 'SAVED';
        return Container(margin: const EdgeInsets.only(bottom: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: isSaved ? Colors.green : Colors.grey.shade300, width: 1.5)), child: Column(children: [
          ListTile(leading: Checkbox(value: b['isSelected'], onChanged: isSaved ? null : (v) => setState(() => b['isSelected'] = v)), title: Text(b['party'].name, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), subtitle: Text("${isSaved ? b['billNo'] : 'DRAFT'} | ₹${b['total'].toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)), trailing: Icon(isSaved ? Icons.check_circle : Icons.pending, color: isSaved ? Colors.green : Colors.orange)),
          const Divider(height: 1),
          Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
            _iconAct(Icons.remove_red_eye, "VIEW", Colors.blue, () => _viewDraft(b)),
            _iconAct(Icons.edit_note, "EDIT", Colors.orange.shade800, () => _editDraft(b)),
            _iconAct(isSaved ? Icons.verified : Icons.save, "SAVE", isSaved ? Colors.green : Colors.grey, () => _saveSingle(ph, i)),
            _iconAct(Icons.print, "PDF", Colors.teal, () => _printSingle(ph, i)),
            _iconAct(Icons.delete, "DEL", Colors.red, () => setState(() => draftBills.removeAt(i))),
          ]))
        ]));
      }))
    ]);
  }

  // ===========================================================================
  // ⚡ LOGIC WRAPPERS
  // ===========================================================================

  void _generateDrafts(PharoahManager ph) {
    setState(() => isProcessing = true);
    List<Map<String, dynamic>> temp = []; bool isSale = _tabController.index == 0;
    for (var pName in selectedPartyNames) {
      var pObj = ph.parties.firstWhere((p) => p.name == pName);
      var chs = isSale ? ph.saleChallans.where((c)=>c.partyName==pName && c.status=="Pending").toList() : ph.purchaseChallans.where((c)=>c.distributorName==pName && c.status=="Pending").toList();
      if(chs.isEmpty) continue;
      List<dynamic> items = [];
      for(var c in chs) { 
        var actualCh = isSale ? (c as SaleChallan) : (c as PurchaseChallan);
        for(var it in actualCh.items) { items.add(it.copyWith(sourceChallanNo: "${actualCh.billNo}")); } 
      }
      temp.add({'party': pObj, 'billNo': 'DRAFT', 'date': toDate, 'items': items, 'total': items.fold(0.0, (s, i)=>s+i.total), 'status': 'DRAFT', 'isSelected': true, 'challanIds': chs.map((c)=> isSale ? (c as SaleChallan).id : (c as PurchaseChallan).id).toList()});
    }
    setState(() { draftBills = temp; funnelStep = "REVIEW"; isProcessing = false; });
  }

  Future<void> _saveSingle(PharoahManager ph, int i) async {
    setState(() => isProcessing = true);
    var b = draftBills[i]; bool isSale = _tabController.index == 0;
    if(isSale) {
      var ser = ph.getDefaultSeries("SALE");
      String no = await PharoahNumberingEngine.getNextNumber(type: "SALE", companyID: ph.activeCompany!.id, prefix: ser.prefix, startFrom: ser.startNumber, currentList: ph.sales);
      await ph.finalizeSale(billNo: no, date: b['date'], party: b['party'], items: b['items'].cast<BillItem>(), total: b['total'], mode: "CREDIT", linkedIds: b['challanIds'].cast<String>());
      setState(() { draftBills[i]['status'] = 'SAVED'; draftBills[i]['billNo'] = no; });
    } else {
      String no = await PharoahNumberingEngine.getNextNumber(type: "PURCHASE", companyID: ph.activeCompany!.id, prefix: "PUR-", startFrom: 1, currentList: ph.purchases);
      ph.finalizePurchase(internalNo: no, billNo: "CONV", date: b['date'], entryDate: DateTime.now(), party: b['party'], items: b['items'].cast<PurchaseItem>(), total: b['total'], mode: "CREDIT");
      setState(() { draftBills[i]['status'] = 'SAVED'; draftBills[i]['billNo'] = no; });
    }
    setState(() => isProcessing = false);
  }

  void _printSingle(PharoahManager ph, int i) async {
    if(draftBills[i]['status'] == 'DRAFT') await _saveSingle(ph, i);
    var b = draftBills[i];
    if(_tabController.index == 0) {
      var s = ph.sales.firstWhere((s) => s.billNo == b['billNo']);
      await SaleInvoicePdf.generate(s, b['party'], ph.activeCompany!);
    } else {
      var p = ph.purchases.firstWhere((p) => p.internalNo == b['billNo']);
      await PurchasePdf.generate(p, b['party'], ph.activeCompany!);
    }
  }

  void _viewDraft(Map<String, dynamic> b) {
    if (_tabController.index == 0) Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(party: b['party'], billNo: "DRAFT", billDate: b['date'], mode: "CREDIT", existingItems: b['items'].cast<BillItem>(), isReadOnly: true)));
    else Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: b['party'], internalNo: "DRAFT", distBillNo: "", billDate: b['date'], entryDate: DateTime.now(), mode: "CREDIT", existingItems: b['items'].cast<PurchaseItem>(), isReadOnly: true)));
  }

  void _editDraft(Map<String, dynamic> b) {
    if (_tabController.index == 0) Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(party: b['party'], billNo: "DRAFT", billDate: b['date'], mode: "CREDIT", existingItems: b['items'].cast<BillItem>())));
    else Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: b['party'], internalNo: "DRAFT", distBillNo: "", billDate: b['date'], entryDate: DateTime.now(), mode: "CREDIT", existingItems: b['items'].cast<PurchaseItem>())));
  }

  void _showMonthPicker(String fy) {
    showModalBottomSheet(context: context, builder: (c) => ListView(children: fyMonths.map((m) => ListTile(title: Text(m, style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () { Navigator.pop(c); _setDt(m, fy); })).toList()));
  }

  void _setDt(String m, String fy) {
    int yr = int.parse(fy.split('-')[0]); if(yr < 2000) yr+=2000;
    int idx = fyMonths.indexOf(m); int tM = idx+4; if(tM>12) { tM-=12; yr++; }
    setState(() { fromDate = DateTime(yr, tM, 1); toDate = DateTime(yr, tM+1, 0); funnelStep = "ROUTE"; selectionMode = "MONTHLY"; });
  }

  void _pickRandom(String fy) async {
    DateTime? s = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: DateTime.now());
    if(s==null) return;
    DateTime? e = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: s);
    if(e!=null) setState(() { fromDate = s; toDate = e; funnelStep = "ROUTE"; selectionMode = "RANDOM"; });
  }

  Widget _modeCard(String t, String s, IconData i, Color c, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.1), width: 2)), child: Row(children: [Icon(i, size: 40, color: c), const SizedBox(width: 20), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)), Text(s, style: const TextStyle(fontSize: 12, color: Colors.grey))])), const Icon(Icons.arrow_forward_ios, size: 16)])));
  Widget _header(String t) => Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.grey.shade200, child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)));
  Widget _iconAct(IconData i, String l, Color c, VoidCallback onTap) => InkWell(onTap: onTap, child: Column(children: [Icon(i, color: c, size: 22), Text(l, style: TextStyle(fontSize: 8, color: c, fontWeight: FontWeight.bold))]));
  Widget _bulkBtn(String l, IconData i, Color c, VoidCallback onTap) => ElevatedButton.icon(onPressed: onTap, icon: Icon(i, size: 14), label: Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white));
  Widget _overlay(Color c) => Container(color: Colors.black87, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(value: progressValue > 0 ? progressValue : null, color: c), const SizedBox(height: 20), Text(progressText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])));
}
