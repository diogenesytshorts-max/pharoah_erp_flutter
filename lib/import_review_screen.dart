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
    required this.importType
  });

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  List<Map<String, dynamic>> reviewedItems = [];
  Map<String, dynamic> senderInfo = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _processUniversalCsv();
  }

  // ===========================================================================
  // 1. THE BRAIN: 36-COLUMN UNIVERSAL PARSER
  // ===========================================================================
  void _processUniversalCsv() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final data = widget.csvData;
    if (data.length < 2) return;

    var r1 = data[1]; // First Data Row
    
    // Mapping Sender (Supplier/Customer) from 36-column Map
    senderInfo = {
      'name': r1[2].toString().toUpperCase(),
      'gst': r1[3].toString().toUpperCase(),
      'dl': r1[4].toString().toUpperCase(),
      'pan': r1[5].toString().toUpperCase(),
      'mobile': r1[6].toString(),
      'email': r1[7].toString(),
      'address': r1[8].toString(),
      'city': r1[9].toString(),
      'state': r1[10].toString(),
      'billNo': r1[1].toString(),
      'date': r1[0].toString(),
      'extraDiscount': double.tryParse(r1[34].toString()) ?? 0.0,
      'roundOff': double.tryParse(r1[35].toString()) ?? 0.0,
    };

    reviewedItems.clear();
    for (int i = 1; i < data.length; i++) {
      var row = data[i];
      if (row.length < 33) continue;

      String csvName = row[18].toString().toUpperCase().trim();
      String csvPack = row[19].toString().toUpperCase().trim();

      // SMART MATCH: Name + Packing
      Medicine? match;
      try {
        match = ph.medicines.firstWhere((m) => 
          m.name.toUpperCase() == csvName && m.packing.toUpperCase() == csvPack
        );
      } catch (e) {
        try { match = ph.medicines.firstWhere((m) => m.name.toUpperCase() == csvName); } 
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
        'batch': row[26].toString().trim(),
        'exp': row[27].toString(),
        'qty': double.tryParse(row[28].toString()) ?? 0.0,
        'free': double.tryParse(row[29].toString()) ?? 0.0,
        'mrp': double.tryParse(row[30].toString()) ?? 0.0,
        'purRate': double.tryParse(row[31].toString()) ?? 0.0,
        'saleRate': double.tryParse(row[32].toString()) ?? 0.0,
        'gstPer': double.tryParse(row[33].toString()) ?? 12.0,
        'match': match,
        'isSelected': match != null,
        'status': match == null ? 'new' : (match.packing == csvPack ? 'exact' : 'mismatch'),
      });
    }
    setState(() => isLoading = false);
  }

  // ===========================================================================
  // 2. THE ACTION: SYNC MASTER & FINALIZE BILL
  // ===========================================================================
  void _finalizeImport(PharoahManager ph) async {
    // A. Verify all selected items are linked
    if (reviewedItems.any((it) => it['isSelected'] && it['match'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please Link or Create all selected products first!"), backgroundColor: Colors.red));
      return;
    }

    // B. Get or Create Party (Automatic Supplier/Customer Management)
    Party targetParty;
    try {
      targetParty = ph.parties.firstWhere((p) => p.gst == senderInfo['gst'] || p.name == senderInfo['name']);
    } catch (e) {
      targetParty = Party(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: senderInfo['name'],
        gst: senderInfo['gst'],
        dl: senderInfo['dl'],
        pan: senderInfo['pan'],
        phone: senderInfo['mobile'],
        email: senderInfo['email'],
        address: senderInfo['address'],
        city: senderInfo['city'],
        state: senderInfo['state'],
        group: widget.importType == "PURCHASE" ? "Sundry Creditors" : "Sundry Debtors"
      );
      ph.parties.add(targetParty);
    }

    if (widget.importType == "PURCHASE") {
      List<PurchaseItem> finalItems = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        
        // --- LIVE MASTER SYNC ---
        String mfgId = ph.getOrCreateCompany(it['mfg']);
        String saltId = ph.getOrCreateSalt(it['salt']);
        
        // Update Medicine Master with Latest Pharma Info
        int mIdx = ph.medicines.indexWhere((med) => med.id == m.id);
        if(mIdx != -1) {
          ph.medicines[mIdx].companyId = mfgId;
          ph.medicines[mIdx].saltId = saltId;
          ph.medicines[mIdx].isNarcotic = it['isNaco'];
          ph.medicines[mIdx].isScheduleH1 = it['isH1'];
          ph.medicines[mIdx].purRate = it['purRate'];
          ph.medicines[mIdx].mrp = it['mrp'];
        }

        // REGISTER BATCH CONFLICT (Safe Pricing)
        BatchSyncEngine.registerBatchActivity(ph: ph, productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['purRate']);

        finalItems.add(PurchaseItem(
          id: DateTime.now().toString() + m.id, srNo: finalItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], purchaseRate: it['purRate'],
          gstRate: it['gstPer'], total: (it['purRate'] * it['qty']) * (1 + it['gstPer'] / 100)
        ));
      }

      ph.finalizePurchase(
        internalNo: "P2P-PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        billNo: senderInfo['billNo'], partyId: targetParty.id,
        date: DateFormat('dd/MM/yyyy').parse(senderInfo['date']), entryDate: DateTime.now(),
        party: targetParty, items: finalItems, total: finalItems.fold(0, (s, i) => s + i.total), mode: "CREDIT"
      );
    } 
    else {
      // SALE IMPORT LOGIC (Same logic, different model)
      List<BillItem> finalItems = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        BatchSyncEngine.registerBatchActivity(ph: ph, productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['saleRate']);
        
        finalItems.add(BillItem(
          id: DateTime.now().toString() + m.id, srNo: finalItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], rate: it['saleRate'],
          gstRate: it['gstPer'], total: (it['saleRate'] * it['qty']) * (1 + it['gstPer'] / 100)
        ));
      }

      await ph.finalizeSale(
        billNo: senderInfo['billNo'], date: DateFormat('dd/MM/yyyy').parse(senderInfo['date']),
        party: targetParty, items: finalItems, total: finalItems.fold(0, (s, i) => s + i.total), mode: "CREDIT"
      );
    }

    await ph.save(); 
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Universal P2P Sync Complete! Dashboard Updated."), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(title: Text("P2P Bill Review (${widget.importType})"), backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildSenderCard(),
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: reviewedItems.length, itemBuilder: (c, i) => _buildItemRow(reviewedItems[i])),
          const SizedBox(height: 100),
        ]),
      ),
      bottomNavigationBar: _buildBottomBar(ph),
    );
  }

  Widget _buildSenderCard() => Container(
    margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo.withOpacity(0.1))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(senderInfo['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.indigo)),
        Text("Inv: ${senderInfo['billNo']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ]),
      const Divider(),
      Text("GST: ${senderInfo['gst']} | DL: ${senderInfo['dl']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      Text("Address: ${senderInfo['address']}, ${senderInfo['city']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]),
  );

  Widget _buildItemRow(Map<String, dynamic> it) {
    bool isMatch = it['status'] == 'exact';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: Checkbox(value: it['isSelected'], onChanged: (v) => setState(() => it['isSelected'] = v!)),
        title: Text(it['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Batch: ${it['batch']} | MRP: ${it['mrp']} | Rate: ${it['purRate']}", style: const TextStyle(fontSize: 9)),
          Row(children: [
            if (it['isH1']) _badge("H1", Colors.red),
            if (it['isNaco']) _badge("NRX", Colors.orange),
            Text(isMatch ? "Matched in System" : "New Item - Link Required", style: TextStyle(fontSize: 10, color: isMatch ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
          ]),
        ]),
        trailing: it['match'] == null ? IconButton(icon: const Icon(Icons.add_link, color: Colors.blue), onPressed: () async {
          final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => ProductMasterView(isSelectionMode: true)));
          if (res != null) setState(() { it['match'] = res; it['isSelected'] = true; it['status'] = 'exact'; });
        }) : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(margin: const EdgeInsets.only(right: 5), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)));

  Widget _buildBottomBar(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(20), color: Colors.white,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55)),
      onPressed: () => _finalizeImport(ph),
      icon: const Icon(Icons.cloud_download),
      label: const Text("FINALIZE & SYNC DATA", style: TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}
