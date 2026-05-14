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

  const ImportReviewScreen({
    super.key, 
    required this.csvData, 
    required this.importType,
  });

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  List<Map<String, dynamic>> reviewedItems = [];
  Map<String, dynamic> partyInfoInFile = {};
  bool isLocalState = true;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _processMirrorLogic();
  }

  // ===========================================================================
  // 1. MIRROR ENGINE: 36-COLUMN PARSER
  // ===========================================================================
  void _processMirrorLogic() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final data = widget.csvData;
    if (data.length < 2) return;

    var r1 = data[1]; // First Data Row
    
    // Column 2-10: ALWAYS THE EXTERNAL PARTY (Dwarika)
    partyInfoInFile = {
      'name': r1[2].toString().trim().toUpperCase(),
      'gst': r1[3].toString().trim().toUpperCase(),
      'dl': r1[4].toString().trim().toUpperCase(),
      'pan': r1[5].toString().trim().toUpperCase(),
      'mobile': r1[6].toString().trim(),
      'email': r1[7].toString().trim().toLowerCase(),
      'address': r1[8].toString().trim().toUpperCase(),
      'city': r1[9].toString().trim().toUpperCase(),
      'state': r1[10].toString().trim(),
      'billNo': r1[1].toString(),
      'date': r1[0].toString(),
      'extraDisc': double.tryParse(r1[34].toString()) ?? 0.0,
      'roundOff': double.tryParse(r1[35].toString()) ?? 0.0,
    };

    String myState = ph.activeCompany?.state.trim().toLowerCase() ?? "rajasthan";
    isLocalState = myState == partyInfoInFile['state'].toString().trim().toLowerCase();

    reviewedItems.clear();
    for (int i = 1; i < data.length; i++) {
      var row = data[i];
      if (row.length < 34) continue;

      String csvName = row[18].toString().toUpperCase().trim();
      String csvPack = row[19].toString().toUpperCase().trim();

      // NATURAL KEY MATCHING (Name + Packing)
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
        'hsn': row[20].toString(),
        'mfg': row[21].toString().toUpperCase(),
        'salt': row[22].toString().toUpperCase(),
        'form': row[23].toString().toUpperCase(),
        'isNaco': row[24].toString().toUpperCase() == "YES",
        'isH1': row[25].toString().toUpperCase() == "YES",
        'batch': row[26].toString().trim(), // CASE PRESERVED (aQ14256BBc)
        'exp': row[27].toString(),
        'qty': double.tryParse(row[28].toString()) ?? 0.0,
        'free': double.tryParse(row[29].toString()) ?? 0.0,
        'mrp': double.tryParse(row[30].toString()) ?? 0.0,
        'purRateInFile': double.tryParse(row[31].toString()) ?? 0.0,
        'saleRateInFile': double.tryParse(row[32].toString()) ?? 0.0,
        'gstPer': double.tryParse(row[33].toString()) ?? 12.0,
        'match': match, 
        'isSelected': match != null,
        'status': match == null ? 'new' : 'exact',
      });
    }
    setState(() => isLoading = false);
  }

  // ===========================================================================
  // 2. FINAL ACTION: COPY-PASTE TO DATABASE
  // ===========================================================================
  void _finalizeImport(PharoahManager ph) async {
    if (reviewedItems.any((it) => it['isSelected'] && it['match'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please Link or Create all products!")));
      return;
    }

    // A. PARTY SYNC (Dwarika check)
    Party targetParty;
    try {
      targetParty = ph.parties.firstWhere((p) => 
        (p.gst.isNotEmpty && p.gst == partyInfoInFile['gst']) || p.name == partyInfoInFile['name']
      );
    } catch (e) {
      // Auto-Create Dwarika if missing
      targetParty = Party(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: partyInfoInFile['name'],
        gst: partyInfoInFile['gst'],
        dl: partyInfoInFile['dl'],
        pan: partyInfoInFile['pan'],
        phone: partyInfoInFile['mobile'],
        email: partyInfoInFile['email'],
        address: partyInfoInFile['address'],
        city: partyInfoInFile['city'],
        state: partyInfoInFile['state'],
        group: widget.importType == "PURCHASE" ? "Sundry Creditors" : "Sundry Debtors"
      );
      ph.parties.add(targetParty);
    }

    // B. TRANSACTION SYNC
    if (widget.importType == "PURCHASE") {
      List<PurchaseItem> finalItems = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        
        // Master Update (MFG/Salt Link)
        String mfgId = ph.getOrCreateCompany(it['mfg']);
        String saltId = ph.getOrCreateSalt(it['salt']);
        int mIdx = ph.medicines.indexWhere((med) => med.id == m.id);
        if(mIdx != -1) {
          ph.medicines[mIdx].companyId = mfgId; 
          ph.medicines[mIdx].saltId = saltId;
          ph.medicines[mIdx].purRate = it['purRateInFile'];
          ph.medicines[mIdx].mrp = it['mrp'];
        }

        // Register Batch (As-Is Case)
        ph.registerBatchActivity(productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['purRateInFile']);

        finalItems.add(PurchaseItem(
          id: DateTime.now().toString() + m.id, srNo: finalItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], purchaseRate: it['purRateInFile'],
          gstRate: it['gstPer'], total: it['total']
        ));
      }

      ph.finalizePurchase(
        internalNo: "IMP-PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        billNo: partyInfoInFile['billNo'], 
        date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']), 
        party: targetParty, items: finalItems, 
        total: finalItems.fold(0.0, (s, i) => s + i.total), 
        mode: "CREDIT", sourceTag: "P2P"
      );
    } 
    else {
      // SALE IMPORT
      List<BillItem> finalItems = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        
        ph.registerBatchActivity(productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['saleRateInFile']);
        
        finalItems.add(BillItem(
          id: DateTime.now().toString() + m.id, srNo: finalItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], rate: it['saleRateInFile'],
          gstRate: it['gstPer'], total: it['total']
        ));
      }

      double gross = finalItems.fold(0.0, (s, i) => s + i.total);
      await ph.finalizeSale(
        billNo: partyInfoInFile['billNo'], 
        date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']),
        party: targetParty, items: finalItems, 
        total: (gross - partyInfoInFile['extraDisc'] + partyInfoInFile['roundOff']), 
        mode: "CREDIT", sourceTag: "P2P",
        extraDiscount: partyInfoInFile['extraDisc'], 
        roundOff: partyInfoInFile['roundOff']
      );
    }

    await ph.save(); 
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Bill Mirrored Successfully!"), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(title: Text("C2C Review: ${widget.importType}"), backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildPartyBanner(),
          const Padding(padding: EdgeInsets.all(15), child: Align(alignment: Alignment.centerLeft, child: Text("ITEMS VERIFICATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey)))),
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: reviewedItems.length, itemBuilder: (c, i) => _buildItemRow(reviewedItems[i])),
          const SizedBox(height: 100),
        ]),
      ),
      bottomNavigationBar: _buildBottomBar(ph),
    );
  }

  Widget _buildPartyBanner() => Container(
    margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(partyInfoInFile['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.indigo)),
        Text("Inv: ${partyInfoInFile['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ]),
      const Divider(),
      Text("GST: ${partyInfoInFile['gst']} | City: ${partyInfoInFile['city']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      Text("Address: ${partyInfoInFile['address']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]),
  );

  Widget _buildItemRow(Map<String, dynamic> it) {
    bool isMatch = it['status'] == 'exact';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: it['isSelected'] ? Colors.green.shade200 : Colors.grey.shade300)),
      child: ListTile(
        leading: Checkbox(value: it['isSelected'], activeColor: Colors.green, onChanged: (v) => setState(() => it['isSelected'] = v!)),
        title: Text(it['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text("Batch: ${it['batch']} | Exp: ${it['exp']} | MRP: ${it['mrp']}", style: const TextStyle(fontSize: 9, color: Colors.blueGrey)),
        trailing: it['match'] == null ? IconButton(icon: const Icon(Icons.add_box_rounded, color: Colors.red), onPressed: () async {
          // NAYA: Pre-fill data for Product Master
          final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => ProductMasterView(isSelectionMode: true, preFillData: it)));
          if (res != null) setState(() { it['match'] = res; it['isSelected'] = true; it['status'] = 'exact'; });
        }) : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _buildBottomBar(PharoahManager ph) {
    double total = reviewedItems.where((it) => it['isSelected']).fold(0.0, (sum, it) => sum + it['total']);
    double net = total - partyInfoInFile['extraDisc'] + partyInfoInFile['roundOff'];
    return Container(
      padding: const EdgeInsets.all(20), color: Colors.white,
      child: Row(children: [
        Expanded(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("NET PAYABLE", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
          Text("₹${net.toStringAsFixed(2)}", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.indigo)),
        ])),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
          onPressed: () => _finalizeImport(ph),
          child: const Text("FINALIZE MIRROR", style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ]),
    );
  }
}
