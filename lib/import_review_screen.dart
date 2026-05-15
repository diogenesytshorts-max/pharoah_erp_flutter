// FILE: lib/import_review_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'party_master.dart';
import 'product_master.dart';
import 'batch_sync_engine.dart';
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

  @override
  void initState() {
    super.initState();
    _processUniversalLogic();
  }

  // ===========================================================================
  // 1. DATA PARSER & MATH VALIDATION (Aligning 36 Columns)
  // ===========================================================================
  void _processUniversalLogic() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final data = widget.csvData;

    if (data.length < 2) return;
    var r1 = data[1];

    // Extraction of Party Details (Dwarika/Sender)
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

    // Auto-match Party Logic
    try {
      matchedParty = ph.parties.firstWhere((p) =>
          (p.gst.isNotEmpty && p.gst == partyInfoInFile['gst']) || p.name == partyInfoInFile['name']);
    } catch (e) { matchedParty = null; }

    reviewedItems.clear();
    for (int i = 1; i < data.length; i++) {
      var row = data[i];
      if (row.length < 34) continue;

      String csvName = row[18]?.toString().toUpperCase().trim() ?? "UNKNOWN";
      String csvPack = row[19]?.toString().toUpperCase().trim() ?? "N/A";
      double qty = double.tryParse(row[28]?.toString() ?? '0') ?? 0.0;
      double rate = double.tryParse(row[32]?.toString() ?? '0') ?? 0.0;
      double gstPer = double.tryParse(row[33]?.toString() ?? '12') ?? 12.0;
      double csvTotal = double.tryParse(row[17]?.toString() ?? '0') ?? 0.0;

      // Real-time System Check (Problem Fix)
      double taxable = qty * rate;
      double taxAmt = taxable * (gstPer / 100);
      double systemTotal = double.parse((taxable + taxAmt).toStringAsFixed(2));

      Medicine? match;
      try {
        match = ph.medicines.firstWhere((m) => m.name == csvName && m.packing == csvPack);
      } catch (e) {
        try { match = ph.medicines.firstWhere((m) => m.name == csvName); } catch (e) { match = null; }
      }

      reviewedItems.add({
        'name': csvName, 'pack': csvPack, 'hsn': row[20]?.toString() ?? "3004",
        'mfg': row[21]?.toString().toUpperCase() ?? "N/A", 'salt': row[22]?.toString().toUpperCase() ?? "N/A",
        'form': row[23]?.toString().toUpperCase() ?? "TAB", 'isNaco': row[24]?.toString() == "YES",
        'isH1': row[25]?.toString() == "YES", 'batch': row[26]?.toString().trim() ?? "AUTO",
        'exp': row[27]?.toString() ?? "12/26", 'qty': qty, 'free': double.tryParse(row[29]?.toString() ?? '0') ?? 0.0,
        'mrp': double.tryParse(row[30]?.toString() ?? '0') ?? 0.0, 'purRate': double.tryParse(row[31]?.toString() ?? '0') ?? 0.0,
        'rate': rate, 'gstPer': gstPer, 'csvTotal': csvTotal, 'sysTotal': systemTotal,
        'match': match, 'isSelected': match != null, 'status': match == null ? 'new' : 'exact',
        'isFixed': false, // One-Tap Fix state
      });
    }
    setState(() => isLoading = false);
  }

  // ===========================================================================
  // 2. THE ONE-TAP MATH FIXER
  // ===========================================================================
  void _autoFixRow(int index) {
    setState(() {
      reviewedItems[index]['isFixed'] = true;
      reviewedItems[index]['sysTotal'] = reviewedItems[index]['csvTotal'];
    });
  }

  // ===========================================================================
  // 3. UI SECTIONS (PRO ANALYTICS LOOK)
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text("MIRROR AUDIT ENGINE"), backgroundColor: const Color(0xFF1E293B), foregroundColor: Colors.white),
      body: Column(children: [
        _buildPartyCard(),
        _buildMismatchBanner(),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(15), itemCount: reviewedItems.length, itemBuilder: (c, i) => _buildItemRow(i))),
        _buildAnalyticsFooter(ph),
      ]),
    );
  }

  Widget _buildPartyCard() {
    bool isOk = matchedParty != null;
    return InkWell(
      onTap: () => _showPartyVerificationSheet(),
      child: Container(
        margin: const EdgeInsets.all(15), padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15), border: Border.all(color: isOk ? Colors.blueAccent : Colors.redAccent)),
        child: Row(children: [
          CircleAvatar(backgroundColor: isOk ? Colors.blue : Colors.redAccent, child: const Icon(Icons.business, color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(partyInfoInFile['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            Text("GST: ${partyInfoInFile['gst']} | DL: ${partyInfoInFile['dl']}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const Text("TAP TO VERIFY & CREATE", style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
          ])),
          Icon(isOk ? Icons.verified : Icons.error_outline, color: isOk ? Colors.greenAccent : Colors.orange),
        ]),
      ),
    );
  }

  Widget _buildMismatchBanner() {
    int mParties = reviewedItems.where((it) => (it['sysTotal'] - it['csvTotal']).abs() > 0.1 && !it['isFixed']).length;
    if (mParties == 0) return const SizedBox();
    return Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 8), color: Colors.redAccent.withOpacity(0.2), child: Text("⚠️ $mParties Items have calculation mismatch!", textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)));
  }

  Widget _buildItemRow(int i) {
    var it = reviewedItems[i];
    bool hasErr = (it['sysTotal'] - it['csvTotal']).abs() > 0.1 && !it['isFixed'];
    Color statusColor = it['status'] == 'new' ? Colors.orange : (hasErr ? Colors.redAccent : Colors.greenAccent);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: statusColor.withOpacity(0.5))),
      child: Column(children: [
        ListTile(
          leading: Checkbox(value: it['isSelected'], activeColor: Colors.green, onChanged: (v) => setState(() => it['isSelected'] = v!)),
          title: Text(it['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
          subtitle: Wrap(spacing: 5, children: [
            _badge("PACK: ${it['pack']}", Colors.blueGrey),
            _badge("BATCH: ${it['batch']}", Colors.indigo),
            _badge("EXP: ${it['exp']}", Colors.deepPurple),
          ]),
          trailing: it['match'] == null 
            ? ElevatedButton(onPressed: () async {
                final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => ProductMasterView(isSelectionMode: true, preFillData: it)));
                if(res != null) setState(() { it['match'] = res; it['status'] = 'exact'; it['isSelected'] = true; });
              }, style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, minimumSize: const Size(60, 30)), child: const Text("LINK", style: TextStyle(fontSize: 10)))
            : const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
        ),
        Container(
          padding: const EdgeInsets.all(12), color: Colors.black26,
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            _metric("CSV TOTAL", it['csvTotal']),
            const Icon(Icons.sync_alt, color: Colors.white24, size: 16),
            _metric("SYS CALC", it['sysTotal'], color: hasErr ? Colors.redAccent : Colors.greenAccent),
            if (hasErr) ElevatedButton(onPressed: () => _autoFixRow(i), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 8)), child: const Text("FIX", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)))
          ]),
        )
      ]),
    );
  }

  // ===========================================================================
  // 4. ACTION MODALS & SAVE
  // ===========================================================================

  void _showPartyVerificationSheet() {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("VERIFY PARTY DETAILS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(color: Colors.white10, height: 30),
          _detailRow("NAME", partyInfoInFile['name']),
          _detailRow("GSTIN", partyInfoInFile['gst']),
          _detailRow("DL NO", partyInfoInFile['dl']),
          _detailRow("ADDR", "${partyInfoInFile['address']}, ${partyInfoInFile['city']}"),
          _detailRow("STATE", partyInfoInFile['state']),
          const SizedBox(height: 30),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () async {
              final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView(isSelectionMode: true)));
              if(res != null) { setState(() => matchedParty = res); Navigator.pop(c); }
            }, child: const Text("LINK EXISTING"))),
            const SizedBox(width: 15),
            Expanded(child: ElevatedButton(onPressed: () async {
               final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => PartyMasterView(isSelectionMode: true, preFillData: partyInfoInFile)));
               if(res != null) { setState(() => matchedParty = res); Navigator.pop(c); }
            }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text("CREATE NEW"))),
          ])
        ]),
      ),
    );
  }

  Widget _buildAnalyticsFooter(PharoahManager ph) {
    double sysTotal = reviewedItems.where((e)=>e['isSelected']).fold(0.0, (s, e)=>s+e['sysTotal']);
    double csvTotal = reviewedItems.where((e)=>e['isSelected']).fold(0.0, (s, e)=>s+e['csvTotal']);
    double diff = sysTotal - csvTotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _footCol("SYS NET", sysTotal),
          _footCol("CSV NET", csvTotal),
          _footCol("DIFF", diff, color: diff.abs() > 0.1 ? Colors.redAccent : Colors.greenAccent),
        ]),
        const Divider(color: Colors.white10, height: 25),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(
          onPressed: () => _handleFinalImport(ph),
          icon: const Icon(Icons.cloud_done),
          label: const Text("FINALIZE & SAVE BILL", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        ))
      ]),
    );
  }

  // --- FINAL SAVE LOGIC ---
  void _handleFinalImport(PharoahManager ph) async {
    if (matchedParty == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link/Create Party first!"))); return; }
    if (reviewedItems.any((it) => it['isSelected'] && it['match'] == null)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link all products first!"))); return; }

    setState(() => isLoading = true);
    
    // Logic: Force system to use fixed prices to avoid re-update in register
    if (widget.importType == "PURCHASE") {
      List<PurchaseItem> items = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        // Mirror Batch Registry
        ph.registerBatchActivity(productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['rate']);
        
        items.add(PurchaseItem(
          id: DateTime.now().toString() + m.id, srNo: items.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], purchaseRate: it['rate'],
          gstRate: it['gstPer'], total: it['sysTotal']
        ));
      }
      ph.finalizePurchase(
        internalNo: "P2P-PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        billNo: partyInfoInFile['billNo'], date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']),
        party: matchedParty!, items: items, total: items.fold(0, (s, e)=>s+e.total), mode: "CREDIT", sourceTag: "P2P"
      );
    } else {
      // Logic for SALE IMPORT (C2C)
      List<BillItem> items = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        items.add(BillItem(
          id: DateTime.now().toString() + m.id, srNo: items.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], rate: it['rate'],
          gstRate: it['gstPer'], total: it['sysTotal']
        ));
      }
      ph.finalizeSale(
        billNo: partyInfoInFile['billNo'], date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']),
        party: matchedParty!, items: items, total: items.fold(0, (s, e)=>s+e.total), mode: "CREDIT",
        sourceTag: "P2P", extraDiscount: partyInfoInFile['extraDisc'], roundOff: partyInfoInFile['roundOff']
      );
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Data Mirrored Successfully!"), backgroundColor: Colors.green));
  }

  // --- UI ATOMS ---
  Widget _badge(String t, Color c) => Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(t, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)));
  Widget _metric(String l, double v, {Color color = Colors.white70}) => Column(children: [Text(l, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900))]);
  Widget _footCol(String l, double v, {Color color = Colors.white70}) => Column(children: [Text(l, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))]);
  Widget _detailRow(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Text("$l: ", style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)), Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))]));
}
