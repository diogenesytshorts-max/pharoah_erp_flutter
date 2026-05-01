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
  String funnelStep = "MODE"; 
  String selectionMode = "NONE"; 
  bool isProcessing = false;
  double progressValue = 0.0;
  String progressText = "";

  // --- DATA ---
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
    setState(() { funnelStep = "MODE"; selectedRoute = null; selectedPartyNames.clear(); draftBills.clear(); selectionMode = "NONE"; });
  }

  // ===========================================================================
  // ⚡ LOGIC WRAPPERS
  // ===========================================================================

  void _generateDrafts(PharoahManager ph) {
    setState(() => isProcessing = true);
    List<Map<String, dynamic>> temp = []; 
    bool isSale = _tabController.index == 0;

    for (var pName in selectedPartyNames) {
      var pObj = ph.parties.firstWhere((p) => p.name == pName);
      
      var chs = isSale 
          ? ph.saleChallans.where((c) => c.partyName == pName && c.status == "Pending" && c.date.isAfter(fromDate.subtract(const Duration(days: 1))) && c.date.isBefore(toDate.add(const Duration(days: 1)))).toList()
          : ph.purchaseChallans.where((c) => c.distributorName == pName && c.status == "Pending" && c.date.isAfter(fromDate.subtract(const Duration(days: 1))) && c.date.isBefore(toDate.add(const Duration(days: 1)))).toList();

      if(chs.isEmpty) continue;

      List<dynamic> items = [];
      for(var c in chs) { 
        if (isSale) {
          SaleChallan actual = c as SaleChallan;
          for(var it in actual.items) { items.add(it.copyWith(sourceChallanNo: actual.billNo)); }
        } else {
          PurchaseChallan actual = c as PurchaseChallan;
          for(var it in actual.items) { items.add(it.copyWith(sourceChallanNo: actual.billNo)); }
        }
      }

      temp.add({
        'party': pObj, 
        'billNo': 'DRAFT', 
        'date': toDate, 
        'items': items, 
        'total': items.fold(0.0, (s, i) => s + i.total), 
        'status': 'DRAFT', 
        'isSelected': true, 
        'challanIds': chs.map((c) => isSale ? (c as SaleChallan).id : (c as PurchaseChallan).id).toList()
      });
    }

    setState(() { 
      draftBills = temp; 
      funnelStep = "REVIEW"; 
      isProcessing = false; 
    });
  }

  Future<void> _saveSingle(PharoahManager ph, int i) async {
    var b = draftBills[i]; 
    if (b['status'] == 'SAVED') return;
    
    bool isSale = _tabController.index == 0;
    String finalNo;

    if(isSale) {
      var ser = ph.getDefaultSeries("SALE");
      finalNo = await PharoahNumberingEngine.getNextNumber(type: "SALE", companyID: ph.activeCompany!.id, prefix: ser.prefix, startFrom: ser.startNumber, currentList: ph.sales);
      await ph.finalizeSale(billNo: finalNo, date: b['date'], party: b['party'], items: b['items'].cast<BillItem>(), total: b['total'], mode: "CREDIT", linkedIds: b['challanIds'].cast<String>());
    } else {
      finalNo = await PharoahNumberingEngine.getNextNumber(type: "PURCHASE", companyID: ph.activeCompany!.id, prefix: "PUR-", startFrom: 1, currentList: ph.purchases);
      ph.finalizePurchase(internalNo: finalNo, billNo: "CONV", date: b['date'], entryDate: DateTime.now(), party: b['party'], items: b['items'].cast<PurchaseItem>(), total: b['total'], mode: "CREDIT");
    }

    setState(() { 
      draftBills[i]['status'] = 'SAVED'; 
      draftBills[i]['billNo'] = finalNo; 
    });
  }

  Future<void> _handleBatchSave(PharoahManager ph) async {
    setState(() { isProcessing = true; progressText = "Saving all..."; });
    for(int i = 0; i < draftBills.length; i++) { 
      if(draftBills[i]['isSelected'] && draftBills[i]['status'] == 'DRAFT') {
        await _saveSingle(ph, i);
      }
    }
    setState(() => isProcessing = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Batch Save Done!")));
  }

  Future<void> _handleZipExport(PharoahManager ph) async {
    var selected = draftBills.where((b) => b['isSelected']).toList();
    if (selected.isEmpty) return;

    if (selected.any((b) => b['status'] == 'DRAFT')) await _handleBatchSave(ph);

    setState(() { isProcessing = true; progressValue = 0.0; progressText = "Generating PDFs..."; });
    try {
      List<Map<String, dynamic>> payload = [];
      for (var d in selected) {
        final obj = _tabController.index == 0 
          ? ph.sales.firstWhere((s) => s.billNo == d['billNo'])
          : ph.purchases.firstWhere((p) => p.internalNo == d['billNo']);
        payload.add({'saleObj': obj, 'party': d['party'], 'billNo': d['billNo']});
      }
      String p = await BulkPdfService.createBillsZip(selectedDrafts: payload, shop: ph.activeCompany!, onProgress: (v, n) => setState(() { progressValue = v; progressText = "Packing: $n"; }));
      setState(() => isProcessing = false);
      await Share.shareXFiles([XFile(p)], subject: 'Batch_Print_Folder');
    } catch (e) { setState(() => isProcessing = false); }
  }

  // ===========================================================================
  // 🖥️ UI BUILDER
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    bool isSale = _tabController.index == 0;
    Color color = isSale ? const Color(0xFF0D47A1) : const Color(0xFFBF360C);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(
        title: Text(isSale ? "SALE CONVERTER" : "PURCHASE CONVERTER", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
        backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0.5,
        leading: funnelStep == "MODE" ? null : IconButton(icon: const Icon(Icons.arrow_back_ios_new, size: 20), onPressed: () => setState(() => funnelStep = "MODE")),
        bottom: TabBar(controller: _tabController, labelColor: color, indicatorColor: color, tabs: const [Tab(text: "OUTWARD"), Tab(text: "INWARD")]),
      ),
      body: Stack(children: [
        _buildStepContent(ph, color),
        if (isProcessing) _buildOverlay(color),
      ]),
    );
  }

  Widget _buildStepContent(PharoahManager ph, Color color) {
    if (funnelStep == "MODE") return _stepMode(ph, color);
    if (funnelStep == "ROUTE") return _stepRoute(ph, color);
    if (funnelStep == "PARTY") return _stepParty(ph, color);
    if (funnelStep == "REVIEW") return _stepReview(ph, color);
    return const SizedBox();
  }

  Widget _stepMode(PharoahManager ph, Color color) => Center(child: Padding(padding: const EdgeInsets.all(30.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    _modeCard("MONTHLY BATCH", "Automatic Apr-Mar logic", Icons.calendar_month, color, () => _showMonthPicker(ph.currentFY)),
    const SizedBox(height: 20),
    _modeCard("RANDOM RANGE", "Custom selection", Icons.date_range, Colors.blueGrey, () => _pickRandom(ph.currentFY)),
  ])));

  Widget _stepRoute(PharoahManager ph, Color color) => Column(children: [
    _header("STEP 2: FILTER BY ROUTE"),
    ListTile(tileColor: Colors.white, leading: const Icon(Icons.done_all, color: Colors.green), title: const Text("SKIP / ALL ROUTES"), onTap: () => setState(() { selectedRoute = null; funnelStep = "PARTY"; })),
    Expanded(child: ListView.builder(itemCount: ph.routes.length, itemBuilder: (c, i) => ListTile(tileColor: Colors.white, title: Text(ph.routes[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), onTap: () => setState(() { selectedRoute = ph.routes[i].name; funnelStep = "PARTY"; }))))
  ]);

  Widget _stepParty(PharoahManager ph, Color color) {
    bool isSale = _tabController.index == 0;
    final list = ph.parties.where((p) {
      bool hasPend = isSale ? ph.saleChallans.any((c)=>c.partyName==p.name && c.status=="Pending") : ph.purchaseChallans.any((c)=>c.distributorName==p.name && c.status=="Pending");
      return hasPend && (selectedRoute == null || p.route == selectedRoute) && p.name.toLowerCase().contains(partySearch.toLowerCase());
    }).toList();
    return Column(children: [
      _header("STEP 3: SELECT PARTIES"),
      Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
        Expanded(child: TextField(decoration: const InputDecoration(hintText: "Search Party..."), onChanged: (v)=>setState(()=>partySearch=v))),
        TextButton(onPressed: () => setState(() => selectedPartyNames = list.map((e)=>e.name).toList()), child: const Text("SELECT ALL")),
      ])),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => CheckboxListTile(activeColor: color, value: selectedPartyNames.contains(list[i].name), title: Text(list[i].name, style: const TextStyle(fontWeight: FontWeight.bold)), onChanged: (v) => setState(() { v! ? selectedPartyNames.add(list[i].name) : selectedPartyNames.remove(list[i].name); })))),
      if(selectedPartyNames.isNotEmpty) Container(padding: const EdgeInsets.all(20), child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: color, minimumSize: const Size(double.infinity, 50)), onPressed: () => _generateDrafts(ph), child: const Text("CONVERT SELECTED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
    ]);
  }

  Widget _stepReview(PharoahManager ph, Color color) {
    bool allSel = draftBills.every((b) => b['isSelected']);
    return Column(children: [
      Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [
        Checkbox(value: allSel, onChanged: (v) => setState(() { for(var b in draftBills) { if(b['status']=='DRAFT') b['isSelected'] = v; } })),
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
            _iconAct(Icons.delete_outline, "DEL", Colors.red, () => setState(() => draftBills.removeAt(i))),
          ]))
        ]));
      }))
    ]);
  }

  // --- HELPERS ---
  Widget _modeCard(String t, String s, IconData i, Color c, VoidCallback onTap) => InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withOpacity(0.1), width: 2)), child: Row(children: [Icon(i, size: 40, color: c), const SizedBox(width: 20), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: c)), Text(s, style: const TextStyle(fontSize: 12, color: Colors.grey))])), const Icon(Icons.arrow_forward_ios, size: 16)])));
  Widget _header(String t) => Container(width: double.infinity, padding: const EdgeInsets.all(12), color: Colors.grey.shade200, child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)));
  Widget _iconAct(IconData i, String l, Color c, VoidCallback onTap) => InkWell(onTap: onTap, child: Column(children: [Icon(i, color: c, size: 22), Text(l, style: TextStyle(fontSize: 8, color: c, fontWeight: FontWeight.bold))]));
  Widget _bulkBtn(String l, IconData i, Color c, VoidCallback onTap) => ElevatedButton.icon(onPressed: onTap, icon: Icon(i, size: 14), label: Text(l, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)), style: ElevatedButton.styleFrom(backgroundColor: c, foregroundColor: Colors.white));
  Widget _buildOverlay(Color c) => Container(color: Colors.black87, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [CircularProgressIndicator(value: progressValue > 0 ? progressValue : null, color: c), const SizedBox(height: 20), Text(progressText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])));

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
    showModalBottomSheet(context: context, builder: (c) => ListView(children: fyMonths.map((m) => ListTile(title: Text(m), onTap: () { Navigator.pop(c); _setDates(m, fy); })).toList()));
  }

  void _setDates(String m, String fy) {
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
}
