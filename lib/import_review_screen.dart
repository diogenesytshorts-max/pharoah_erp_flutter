// FILE: lib/import_review_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'party_master.dart';
import 'product_master.dart';
import 'logic/pharoah_numbering_engine.dart';

class ImportReviewScreen extends StatefulWidget {
  final List<List<dynamic>> csvData; 
  final String importType; // "SALE" or "PURCHASE"
  final String exchangeMode; // "C2C" or "C2V"

  const ImportReviewScreen({
    super.key, 
    required this.csvData, 
    required this.importType,
    required this.exchangeMode,
  });

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  List<Map<String, dynamic>> reviewedItems = [];
  Map<String, dynamic> partyInfoInFile = {};
  Party? matchedParty; 
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _processMirrorLogic();
  }

  // ===========================================================================
  // 1. CORE PARSER (Aligning 36 Columns)
  // ===========================================================================
  void _processMirrorLogic() {
    try {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      final data = widget.csvData;

      if (data.length < 2) {
        setState(() { errorMessage = "File is empty."; isLoading = false; });
        return;
      }

      var r1 = data[1]; 
      if (r1.length < 18) {
        setState(() { errorMessage = "Invalid CSV: Minimum 18 columns required."; isLoading = false; });
        return;
      }

      // Party Data Snapshot (Dwarika)
      partyInfoInFile = {
        'name': r1[2]?.toString().trim().toUpperCase() ?? "UNKNOWN",
        'gst': r1[3]?.toString().trim().toUpperCase() ?? "",
        'dl': r1[4]?.toString().trim().toUpperCase() ?? "",
        'pan': r1[5]?.toString().trim().toUpperCase() ?? "",
        'mobile': r1[6]?.toString().trim() ?? "",
        'email': r1[7]?.toString().trim().toLowerCase() ?? "",
        'address': r1[8]?.toString().trim().toUpperCase() ?? "",
        'city': r1[9]?.toString().trim().toUpperCase() ?? "",
        'state': r1[10]?.toString().trim() ?? "Rajasthan",
        'billNo': r1[1]?.toString() ?? "DRAFT",
        'date': r1[0]?.toString() ?? DateFormat('dd/MM/yyyy').format(DateTime.now()),
        'extraDisc': r1.length > 34 ? (double.tryParse(r1[34].toString()) ?? 0.0) : 0.0,
        'roundOff': r1.length > 35 ? (double.tryParse(r1[35].toString()) ?? 0.0) : 0.0,
      };

      // Auto-match Party
      try {
        matchedParty = ph.parties.firstWhere((p) => 
          (p.gst.isNotEmpty && p.gst == partyInfoInFile['gst']) || p.name == partyInfoInFile['name']
        );
      } catch (e) { matchedParty = null; }

      reviewedItems.clear();
      for (int i = 1; i < data.length; i++) {
        var row = data[i];
        if (row.length < 18) continue;

        String csvName = row[18]?.toString().toUpperCase().trim() ?? "UNKNOWN";
        String csvPack = row[19]?.toString().toUpperCase().trim() ?? "N/A";

        Medicine? match;
        try {
          match = ph.medicines.firstWhere((m) => 
            m.name.trim().toUpperCase() == csvName && m.packing.trim().toUpperCase() == csvPack
          );
        } catch (e) {
          try { match = ph.medicines.firstWhere((m) => m.name.trim().toUpperCase() == csvName); } 
          catch (e) { match = null; }
        }

        reviewedItems.add({
          'name': csvName, 
          'pack': csvPack, 
          'hsn': row[20]?.toString() ?? "3004",
          'mfg': row[21]?.toString().toUpperCase() ?? "N/A",
          'salt': row[22]?.toString().toUpperCase() ?? "N/A",
          'form': row[23]?.toString().toUpperCase() ?? "TAB",
          'isNaco': row[24]?.toString().toUpperCase() == "YES",
          'isH1': row[25]?.toString().toUpperCase() == "YES",
          'batch': row[26]?.toString().trim() ?? "AUTO",
          'exp': row[27]?.toString() ?? "12/26",
          'qty': double.tryParse(row[28]?.toString() ?? '0') ?? 0.0,
          'free': double.tryParse(row[29]?.toString() ?? '0') ?? 0.0,
          'mrp': double.tryParse(row[30]?.toString() ?? '0') ?? 0.0,
          'purRateInFile': double.tryParse(row[31]?.toString() ?? '0') ?? 0.0,
          'saleRateInFile': double.tryParse(row[32]?.toString() ?? '0') ?? 0.0,
          'gstPer': double.tryParse(row[33]?.toString() ?? '12') ?? 12.0,
          'match': match, 
          'isSelected': match != null,
          'status': match == null ? 'new' : 'exact',
          'total': double.tryParse(row[17]?.toString() ?? '0') ?? 0.0,
        });
      }
      setState(() => isLoading = false);
    } catch (e) {
      setState(() { errorMessage = "Parser Error: $e"; isLoading = false; });
    }
  }

  // ===========================================================================
  // 2. ADVANCED BULK RESOLVER (SEQUENTIAL ID LOGIC: 6, 7, 8...)
  // ===========================================================================
  void _autoResolveAllNewProducts(PharoahManager ph) async {
    List<int> newIndices = [];
    for (int i = 0; i < reviewedItems.length; i++) {
      if (reviewedItems[i]['status'] == 'new') newIndices.add(i);
    }

    if (newIndices.isEmpty) return;

    setState(() => isLoading = true);

    // Get the base number just ONCE from the engine
    String startNoStr = await PharoahNumberingEngine.getNextNumber(
      type: "PRODUCT", companyID: ph.activeCompany!.id, prefix: "PH-", startFrom: 10001, currentList: ph.medicines,
    );
    int currentNum = int.parse(startNoStr.replaceAll("PH-", ""));

    for (int idx in newIndices) {
      var it = reviewedItems[idx];
      
      // Auto-Generate Unique Sequential ID
      String generatedSysId = "PH-$currentNum";
      
      final newMed = Medicine(
        id: DateTime.now().millisecondsSinceEpoch.toString() + idx.toString(),
        systemId: generatedSysId,
        name: it['name'],
        packing: it['pack'],
        hsnCode: it['hsn'],
        gst: it['gstPer'],
        mrp: it['mrp'],
        purRate: it['purRateInFile'],
        rateA: it['saleRateInFile'],
        drugForm: it['form'],
        isNarcotic: it['isNaco'],
        isScheduleH1: it['isH1'],
        companyId: ph.getOrCreateCompany(it['mfg']),
        saltId: ph.getOrCreateSalt(it['salt']),
      );

      ph.addMedicine(newMed);
      
      // Update local state row
      it['match'] = newMed;
      it['status'] = 'exact';
      it['isSelected'] = true;

      currentNum++; // Increment for next item
    }

    await ph.save(); 
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ Created ${newIndices.length} new products sequentially."), backgroundColor: Colors.indigo));
  }

  // ===========================================================================
  // 3. UI & MANUAL ACTIONS
  // ===========================================================================
  
  void _linkParty() async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView(isSelectionMode: true)));
    if (res != null && res is Party) setState(() => matchedParty = res);
  }

  void _createParty(PharoahManager ph) async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => PartyMasterView(isSelectionMode: true, preFillData: partyInfoInFile)));
    if (res != null && res is Party) setState(() => matchedParty = res);
  }

  void _linkItem(int i) async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView(isSelectionMode: true)));
    if (res != null && res is Medicine) {
      setState(() { reviewedItems[i]['match'] = res; reviewedItems[i]['isSelected'] = true; reviewedItems[i]['status'] = 'exact'; });
    }
  }

  void _createItem(int i) async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => ProductMasterView(isSelectionMode: true, preFillData: reviewedItems[i])));
    if (res != null && res is Medicine) {
      setState(() { reviewedItems[i]['match'] = res; reviewedItems[i]['isSelected'] = true; reviewedItems[i]['status'] = 'exact'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (errorMessage != null) return Scaffold(body: Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))));

    int newCount = reviewedItems.where((it) => it['status'] == 'new').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA),
      appBar: AppBar(title: Text("${widget.exchangeMode} Mirror"), backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white),
      body: Column(
        children: [
          _buildPartyMappingCard(ph),
          
          if (newCount > 0) 
            _buildBulkAlertBanner(ph, newCount),

          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 20),
              itemCount: reviewedItems.length, 
              itemBuilder: (c, i) => _buildItemRow(i)
            ),
          ),
          _buildSummaryFooter(ph),
        ],
      ),
    );
  }

  Widget _buildPartyMappingCard(PharoahManager ph) {
    bool isOk = matchedParty != null;
    return Container(
      margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: isOk ? Colors.green : Colors.red, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(partyInfoInFile['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: Color(0xFF1A237E))),
          Text("Ref: ${partyInfoInFile['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
        ]),
        const Divider(height: 25),
        if (isOk) 
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle, color: Colors.green, size: 28), title: Text(matchedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text("${matchedParty!.city} | ${matchedParty!.gst}"), trailing: IconButton(icon: const Icon(Icons.edit_note, color: Colors.blue), onPressed: () => setState(() => matchedParty = null)))
        else 
          Column(children: [
            const Text("Party not recognized. Choose action:", style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: _linkParty, icon: const Icon(Icons.link, size: 16), label: const Text("LINK"))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => _createParty(ph), icon: const Icon(Icons.add, size: 16), label: const Text("CREATE"))),
            ])
          ]),
      ]),
    );
  }

  Widget _buildBulkAlertBanner(PharoahManager ph, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12), padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.orange.shade200)),
      child: Row(children: [
        Icon(Icons.auto_fix_high_rounded, color: Colors.orange.shade900, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text("Found $count new items. Resolve all sequentially?", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange.shade900))),
        ElevatedButton(onPressed: () => _autoResolveAllNewProducts(ph), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 12)), child: const Text("AUTO-CREATE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
      ]),
    );
  }

  Widget _buildItemRow(int i) {
    var it = reviewedItems[i];
    bool isOk = it['match'] != null;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0), elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: isOk ? Colors.green.shade100 : Colors.red.shade100, width: 1.5)),
      child: ExpansionTile(
        leading: Checkbox(value: it['isSelected'], activeColor: Colors.green, onChanged: (v) => setState(() => it['isSelected'] = v!)),
        title: Text(it['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isOk ? Colors.black87 : Colors.red)),
        subtitle: Text("Batch: ${it['batch']} | Exp: ${it['exp']} | Price: ₹${it['purRateInFile']}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
        children: [
          if (!isOk) Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _linkItem(i), child: const Text("MAP TO EXISTING"))),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(onPressed: () => _createItem(i), child: const Text("CREATE NEW"))),
          ]))
          else ListTile(dense: true, leading: const Icon(Icons.link, color: Colors.green), title: Text("Linked to Master ID: ${it['match'].systemId}"))
        ],
      ),
    );
  }

  Widget _buildSummaryFooter(PharoahManager ph) {
    double gross = reviewedItems.where((it) => it['isSelected']).fold(0.0, (sum, it) => sum + (it['total'] as double));
    double disc = partyInfoInFile['extraDisc'];
    double ro = partyInfoInFile['roundOff'];
    double net = gross - disc + ro;

    return Container(
      padding: const EdgeInsets.all(20), color: Colors.white,
      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _sumText("GROSS", "₹${gross.toStringAsFixed(2)}", Colors.black),
          _sumText("DISC (-)", "₹${disc.toStringAsFixed(2)}", Colors.red),
          _sumText("RO", ro.toStringAsFixed(2), Colors.blueGrey),
        ]),
        const Divider(height: 25),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text("NET PAYABLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
            Text("₹${net.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1A237E))),
          ])),
          SizedBox(height: 55, child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A237E), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: () => _finalizeMirror(ph),
            child: const Text("FINALIZE MIRROR", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          )),
        ]),
      ]),
    );
  }

  Widget _sumText(String l, String v, Color c) => Column(children: [Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.grey)), Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: c))]);

  void _finalizeMirror(PharoahManager ph) async {
    if (matchedParty == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link Party first!"), backgroundColor: Colors.red)); return; }
    if (reviewedItems.any((it) => it['isSelected'] && it['match'] == null)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link all Items first!"), backgroundColor: Colors.red)); return; }

    setState(() => isLoading = true);

    if (widget.importType == "PURCHASE") {
      List<PurchaseItem> items = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        ph.registerBatchActivity(productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['purRateInFile']);
        items.add(PurchaseItem(id: DateTime.now().toString()+m.id, srNo: items.length+1, medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'], hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], purchaseRate: it['purRateInFile'], gstRate: it['gstPer'], total: it['total']));
      }
      ph.finalizePurchase(internalNo: "IMP-PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}", billNo: partyInfoInFile['billNo'], date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']), party: matchedParty!, items: items, total: items.fold(0, (s, e)=>s+e.total), mode: "CREDIT", sourceTag: "P2P");
    } else {
      List<BillItem> items = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        ph.registerBatchActivity(productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['saleRateInFile']);
        items.add(BillItem(id: DateTime.now().toString()+m.id, srNo: items.length+1, medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'], hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], rate: it['saleRateInFile'], gstRate: it['gstPer'], total: it['total']));
      }
      double total = items.fold(0.0, (s, e)=>s+e.total) - partyInfoInFile['extraDisc'] + partyInfoInFile['roundOff'];
      await ph.finalizeSale(billNo: partyInfoInFile['billNo'], date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']), party: matchedParty!, items: items, total: total, mode: "CREDIT", sourceTag: "P2P", extraDiscount: partyInfoInFile['extraDisc'], roundOff: partyInfoInFile['roundOff']);
    }

    await ph.save();
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Import Mirroring Success!"), backgroundColor: Colors.green));
  }
}
