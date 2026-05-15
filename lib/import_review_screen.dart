// FILE: lib/import_review_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'party_master.dart';
import 'product_master.dart';
import 'batch_sync_engine.dart';

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
  Party? matchedParty; // The actual linked Party object
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _processMirrorLogic();
  }

  // ===========================================================================
  // 1. DATA PARSER (WITH SAFETY GUARDS)
  // ===========================================================================
  void _processMirrorLogic() {
    try {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      final data = widget.csvData;

      if (data.length < 2) {
        setState(() { errorMessage = "File is empty or invalid."; isLoading = false; });
        return;
      }

      var r1 = data[1];
      // Basic validation for 36 columns
      if (r1.length < 18) {
        setState(() { errorMessage = "CSV structure mismatch. Need at least 18 columns."; isLoading = false; });
        return;
      }

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

      // ATTEMPT AUTO-LINK PARTY
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
      setState(() { errorMessage = "Critical Error: $e"; isLoading = false; });
    }
  }

  // ===========================================================================
  // 2. INTERACTIVE ACTIONS (LINK & CREATE)
  // ===========================================================================
  
  void _linkPartyManual() async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView(isSelectionMode: true)));
    if (res != null && res is Party) { setState(() => matchedParty = res); }
  }

  void _createPartyAuto(PharoahManager ph) async {
    final res = await Navigator.push(context, MaterialPageRoute(
      builder: (c) => PartyMasterView(isSelectionMode: true, preFillData: partyInfoInFile)
    ));
    if (res != null && res is Party) { setState(() => matchedParty = res); }
  }

  void _linkProductManual(int index) async {
    final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView(isSelectionMode: true)));
    if (res != null && res is Medicine) {
      setState(() {
        reviewedItems[index]['match'] = res;
        reviewedItems[index]['isSelected'] = true;
        reviewedItems[index]['status'] = 'exact';
      });
    }
  }

  void _createProductAuto(int index) async {
    final res = await Navigator.push(context, MaterialPageRoute(
      builder: (c) => ProductMasterView(isSelectionMode: true, preFillData: reviewedItems[index])
    ));
    if (res != null && res is Medicine) {
      setState(() {
        reviewedItems[index]['match'] = res;
        reviewedItems[index]['isSelected'] = true;
        reviewedItems[index]['status'] = 'exact';
      });
    }
  }

  void _finalizeImport(PharoahManager ph) async {
    if (matchedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please Link or Create the Party first!"), backgroundColor: Colors.red));
      return;
    }
    if (reviewedItems.any((it) => it['isSelected'] && it['match'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link or Create all selected products!"), backgroundColor: Colors.red));
      return;
    }

    if (widget.importType == "PURCHASE") {
      List<PurchaseItem> finalItems = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        ph.registerBatchActivity(ph: ph, productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['purRateInFile']);
        finalItems.add(PurchaseItem(
          id: DateTime.now().toString() + m.id, srNo: finalItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], purchaseRate: it['purRateInFile'],
          gstRate: it['gstPer'], total: it['total']
        ));
      }
      ph.finalizePurchase(
        internalNo: "IMP-PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        billNo: partyInfoInFile['billNo'], date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']), 
        party: matchedParty!, items: finalItems, total: finalItems.fold(0.0, (s, i) => s + i.total), 
        mode: "CREDIT", sourceTag: "P2P"
      );
    } 
    else {
      List<BillItem> finalItems = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        ph.registerBatchActivity(ph: ph, productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['saleRateInFile']);
        finalItems.add(BillItem(
          id: DateTime.now().toString() + m.id, srNo: finalItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], rate: it['saleRateInFile'],
          gstRate: it['gstPer'], total: it['total']
        ));
      }
      double gross = finalItems.fold(0.0, (s, i) => s + i.total);
      await ph.finalizeSale(
        billNo: partyInfoInFile['billNo'], date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']),
        party: matchedParty!, items: finalItems, 
        total: (gross - partyInfoInFile['extraDisc'] + partyInfoInFile['roundOff']), 
        mode: "CREDIT", sourceTag: "P2P",
        extraDiscount: partyInfoInFile['extraDisc'], roundOff: partyInfoInFile['roundOff']
      );
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Mirroring Complete!"), backgroundColor: Colors.green));
  }

  // ===========================================================================
  // 3. UI BUILDERS
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (errorMessage != null) return Scaffold(body: Center(child: Text(errorMessage!, style: const TextStyle(color: Colors.red))));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(title: Text("${widget.exchangeMode} Review"), backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildPartyMappingCard(ph),
          const Padding(padding: EdgeInsets.all(15), child: Align(alignment: Alignment.centerLeft, child: Text("REVIEW TRANSACTION ITEMS", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)))),
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: reviewedItems.length, itemBuilder: (c, i) => _buildItemRow(i)),
          const SizedBox(height: 120),
        ]),
      ),
      bottomNavigationBar: _buildBottomBar(ph),
    );
  }

  Widget _buildPartyMappingCard(PharoahManager ph) {
    bool isMatched = matchedParty != null;
    return Container(
      margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: isMatched ? Colors.green : Colors.red, width: 2)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(partyInfoInFile['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          Text("Inv: ${partyInfoInFile['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
        ]),
        const Divider(),
        if (isMatched) 
          ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.check_circle, color: Colors.green), title: Text("Matched to: ${matchedParty!.name}"), subtitle: Text("${matchedParty!.city} | ${matchedParty!.gst}"), trailing: TextButton(onPressed: () => setState(() => matchedParty = null), child: const Text("CHANGE")))
        else 
          Column(children: [
            const Text("This party is not recognized in your Master Data.", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: _linkPartyManual, child: const Text("MAP TO EXISTING"))),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => _createPartyAuto(ph), child: const Text("CREATE NEW"))),
            ])
          ]),
      ]),
    );
  }

  Widget _buildItemRow(int i) {
    var it = reviewedItems[i];
    bool isMatched = it['match'] != null;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isMatched ? Colors.green.shade200 : Colors.red.shade200)),
      child: ExpansionTile(
        leading: Checkbox(value: it['isSelected'], activeColor: Colors.green, onChanged: (v) => setState(() => it['isSelected'] = v!)),
        title: Text(it['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isMatched ? Colors.black87 : Colors.red)),
        subtitle: Text("Batch: ${it['batch']} | Exp: ${it['exp']} | Price: ${it['purRateInFile']}", style: const TextStyle(fontSize: 10)),
        children: [
          if (!isMatched) 
            Padding(padding: const EdgeInsets.all(10), child: Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _linkProductManual(i), child: const Text("MAP", style: TextStyle(fontSize: 11)))),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () => _createProductAuto(i), child: const Text("CREATE", style: TextStyle(fontSize: 11)))),
            ]))
          else
            ListTile(dense: true, leading: const Icon(Icons.link, color: Colors.green), title: Text("Linked to: ${it['match'].name}"))
        ],
      ),
    );
  }

  Widget _buildBottomBar(PharoahManager ph) {
    double total = reviewedItems.where((it) => it['isSelected']).fold(0.0, (sum, it) => sum + (it['total'] as double));
    double disc = partyInfoInFile['extraDisc'];
    double ro = partyInfoInFile['roundOff'];
    double net = total - disc + ro;

    return Container(
      padding: const EdgeInsets.all(20), color: Colors.white,
      decoration: const BoxDecoration(boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -5))]),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text("Gross: ₹${total.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          Text("Disc: ₹${disc.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.red, fontWeight: FontWeight.bold)),
          Text("RO: ${ro.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, color: Colors.blueGrey)),
        ]),
        const Divider(),
        Row(children: [
          Expanded(child: Text("NET PAYABLE: ₹${net.toStringAsFixed(2)}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.indigo))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15)),
            onPressed: () => _finalizeImport(ph),
            child: const Text("FINALIZE MIRROR", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ]),
      ]),
    );
  }
}
