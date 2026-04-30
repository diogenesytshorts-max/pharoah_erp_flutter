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
  DateTime fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime toDate = DateTime.now();
  Party? selectedParty;
  List<String> selectedChallanIds = [];
  String partySearch = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          selectedParty = null;
          selectedChallanIds.clear();
          partySearch = "";
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    bool isSaleMode = _tabController.index == 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("CONVERT CHALLAN TO BILL", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: isSaleMode ? Colors.indigo.shade900 : Colors.orange.shade900,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [Tab(text: "SALE CHALLANS"), Tab(text: "PURCHASE CHALLANS")],
        ),
      ),
      body: Column(
        children: [
          _buildHeader(ph, isSaleMode),
          Expanded(
            child: selectedParty == null 
              ? _buildPlaceholder("Search and select a ${isSaleMode ? 'Customer' : 'Supplier'} to continue")
              : _buildChallanList(ph, isSaleMode),
          ),
          if (selectedChallanIds.isNotEmpty) _buildBottomBar(ph, isSaleMode),
        ],
      ),
    );
  }

  Widget _buildHeader(PharoahManager ph, bool isSale) {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Column(
        children: [
          Row(children: [
            Expanded(child: _dateTile("FROM", fromDate, (d) => setState(() => fromDate = d), ph.currentFY)),
            const SizedBox(width: 10),
            Expanded(child: _dateTile("TO", toDate, (d) => setState(() => toDate = d), ph.currentFY)),
          ]),
          const SizedBox(height: 15),
          if (selectedParty == null)
            TextField(
              decoration: InputDecoration(
                hintText: isSale ? "Search Customer..." : "Search Supplier...",
                prefixIcon: const Icon(Icons.person_search),
                border: const OutlineInputBorder()
              ),
              onChanged: (v) => setState(() => partySearch = v),
            )
          else
            ListTile(
              tileColor: (isSale ? Colors.indigo : Colors.orange).withOpacity(0.05),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSale ? Colors.indigo : Colors.orange)),
              leading: Icon(Icons.person, color: isSale ? Colors.indigo : Colors.orange),
              title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() { selectedParty = null; selectedChallanIds.clear(); })),
            ),
          
          if (selectedParty == null && partySearch.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 150),
              child: ListView(
                shrinkWrap: true,
                children: ph.parties.where((p) => p.name.toLowerCase().contains(partySearch.toLowerCase())).map((p) => ListTile(title: Text(p.name), onTap: () => setState(() { selectedParty = p; partySearch = ""; }))).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChallanList(PharoahManager ph, bool isSale) {
    final List<dynamic> rawList = isSale ? ph.saleChallans : ph.purchaseChallans;
    
    final list = rawList.where((dynamic c) {
      String pName = isSale ? (c as SaleChallan).partyName : (c as PurchaseChallan).distributorName;
      DateTime cDate = isSale ? (c as SaleChallan).date : (c as PurchaseChallan).date;
      String cStatus = isSale ? (c as SaleChallan).status : (c as PurchaseChallan).status;

      return pName == selectedParty!.name && 
             cStatus == "Pending" &&
             cDate.isAfter(fromDate.subtract(const Duration(days: 1))) && 
             cDate.isBefore(toDate.add(const Duration(days: 1)));
    }).toList();

    if (list.isEmpty) return _buildPlaceholder("No pending challans found for this date range.");

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("PENDING CHALLANS (${list.length})", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              TextButton(onPressed: () => setState(() => selectedChallanIds = list.map((dynamic e) => e.id as String).toList()), child: const Text("SELECT ALL")),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: list.length,
            padding: const EdgeInsets.symmetric(horizontal: 15),
            itemBuilder: (c, i) {
              final dynamic ch = list[i];
              final isSel = selectedChallanIds.contains(ch.id);
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15), 
                  side: BorderSide(color: isSel ? (isSale ? Colors.indigo : Colors.orange) : Colors.grey.shade200, width: 2)
                ),
                child: CheckboxListTile(
                  value: isSel,
                  activeColor: isSale ? Colors.indigo : Colors.orange,
                  title: Text(ch.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Date: ${DateFormat('dd/MM/yy').format(ch.date)}"),
                  secondary: Text("₹${ch.totalAmount.toStringAsFixed(0)}", style: TextStyle(fontWeight: FontWeight.w900, color: isSale ? Colors.indigo : Colors.orange)),
                  onChanged: (v) { setState(() { v! ? selectedChallanIds.add(ch.id) : selectedChallanIds.remove(ch.id); }); },
                ),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildBottomBar(PharoahManager ph, bool isSale) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: isSale ? Colors.indigo.shade900 : Colors.orange.shade900, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        onPressed: () => _handleConversion(ph, isSale),
        child: Text("CONVERT ${selectedChallanIds.length} CHALLANS", style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _handleConversion(PharoahManager ph, bool isSale) async {
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    String nextBillNo = "";
    if (isSale) {
      var series = ph.getDefaultSeries("SALE");
      nextBillNo = await PharoahNumberingEngine.getNextNumber(
        type: "SALE",
        companyID: ph.activeCompany!.id,
        prefix: series.prefix,
        startFrom: series.startNumber,
        currentList: ph.sales,
      );

      List<BillItem> merged = [];
      List<SaleChallan> selected = ph.saleChallans.where((c) => selectedChallanIds.contains(c.id)).toList();
      for (var ch in selected) {
        for (var it in ch.items) {
          merged.add(it.copyWith(sourceChallanNo: "${ch.billNo} (${DateFormat('dd/MM').format(ch.date)})"));
        }
      }
      Navigator.pop(context);
    // Smart Date Logic: Current FY ke range ki date lega
      DateTime smartBillDate = PharoahDateController.getInitialBillDate(ph.currentFY);

      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (c) => BillingView(
        party: selectedParty!, 
        billNo: nextBillNo, 
        billDate: smartBillDate, 
        mode: "CREDIT", 
        existingItems: merged, 
        linkedChallanIds: selectedChallanIds,
      )));
      nextBillNo = await PharoahNumberingEngine.getNextNumber(
        type: "PURCHASE",
        companyID: ph.activeCompany!.id,
        prefix: "PUR-",
        startFrom: 1,
        currentList: ph.purchases,
      );

      List<PurchaseItem> merged = [];
      List<PurchaseChallan> selected = ph.purchaseChallans.where((c) => selectedChallanIds.contains(c.id)).toList();
      for (var ch in selected) {
        for (var it in ch.items) {
          merged.add(it.copyWith(srNo: merged.length + 1));
        }
      }
      Navigator.pop(context);
      Navigator.push(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(distributor: selectedParty!, internalNo: nextBillNo, distBillNo: "", billDate: DateTime.now(), entryDate: DateTime.now(), mode: "CREDIT", existingItems: merged)));
    }
  }

  Widget _dateTile(String l, DateTime d, Function(DateTime) onPick, String fy) => InkWell(
    onTap: () async { DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: fy, initialDate: d); if(p!=null) onPick(p); },
    child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey)), Text(DateFormat('dd/MM/yy').format(d), style: const TextStyle(fontWeight: FontWeight.bold))])),
  );

  Widget _buildPlaceholder(String t) => Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(t, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))));
}
