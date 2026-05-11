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
  // 1. THE BRAIN: DYNAMIC OFFSET PARSER (Corrects Party vs Company)
  // ===========================================================================
  void _processUniversalCsv() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final data = widget.csvData;
    if (data.length < 2) return;

    var r1 = data[1]; // First Data Row
    
    // logic: Purchase Import means User A (Sender) is my Distributor.
    // Sale Import means User A (Sender) is the Customer.
    // In both cases, we need the "Other Party's" details.
    
    // COLUMNS: 2=Name, 3=GST, 4=DL, 5=PAN, 6=Mob, 7=Email, 8=Addr, 9=City, 10=State
    // Hum hamesha Sender (Col 2 se 10) par focus karenge kyunki wahi dusri Party hai.
    
    senderInfo = {
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
      'extraDiscount': double.tryParse(r1[34].toString()) ?? 0.0,
      'roundOff': double.tryParse(r1[35].toString()) ?? 0.0,
    };

    reviewedItems.clear();
    for (int i = 1; i < data.length; i++) {
      var row = data[i];
      if (row.length < 34) continue;

      String csvName = row[18].toString().toUpperCase().trim();
      String csvPack = row[19].toString().toUpperCase().trim();

      // CASE INSENSITIVE SMART MATCH
      Medicine? match;
      try {
        match = ph.medicines.firstWhere((m) => 
          m.name.trim().toUpperCase() == csvName && 
          m.packing.trim().toUpperCase() == csvPack
        );
      } catch (e) {
        try { 
          match = ph.medicines.firstWhere((m) => m.name.trim().toUpperCase() == csvName); 
        } catch (e) { match = null; }
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
        'batch': row[26].toString().trim(), // Case preserved
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
  // 2. THE ACTION: SYNC MASTER & SAVE WITH [P2P-IMP] TAG
  // ===========================================================================
  void _finalizeImport(PharoahManager ph) async {
    if (reviewedItems.any((it) => it['isSelected'] && it['match'] == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link or Create all selected products first!"), backgroundColor: Colors.red));
      return;
    }

    // A. Get or Create Party (Automatic Supplier/Customer Management)
    // Always searching by GSTIN to avoid Name Typos (Patidar vs PATIDAR)
    Party targetParty;
    try {
      targetParty = ph.parties.firstWhere((p) => 
        p.gst.trim().toUpperCase() == senderInfo['gst'] || 
        p.name.trim().toUpperCase() == senderInfo['name']
      );
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
        
        // --- LIVE MASTER SYNC (Company, Salt, Flags) ---
        String mfgId = ph.getOrCreateCompany(it['mfg']);
        String saltId = ph.getOrCreateSalt(it['salt']);
        
        int mIdx = ph.medicines.indexWhere((med) => med.id == m.id);
        if(mIdx != -1) {
          ph.medicines[mIdx].companyId = mfgId;
          ph.medicines[mIdx].saltId = saltId;
          ph.medicines[mIdx].isNarcotic = it['isNaco'];
          ph.medicines[mIdx].isScheduleH1 = it['isH1'];
          ph.medicines[mIdx].purRate = it['purRate'];
          ph.medicines[mIdx].mrp = it['mrp'];
          ph.medicines[mIdx].hsnCode = it['hsn'];
        }

        // REGISTER BATCH INDIVIDUALLY (Handles Price/MRP Change)
        BatchSyncEngine.registerBatchActivity(ph: ph, productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['purRate']);

        finalItems.add(PurchaseItem(
          id: DateTime.now().toString() + m.id, srNo: finalItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], purchaseRate: it['purRate'],
          gstRate: it['gstPer'], total: (it['purRate'] * it['qty']) * (1 + it['gstPer'] / 100)
        ));
      }

      ph.finalizePurchase(
        internalNo: "P2P-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        billNo: "${senderInfo['billNo']} [P2P-IMP]", // IMPORT TAG
        date: DateFormat('dd/MM/yyyy').parse(senderInfo['date']), entryDate: DateTime.now(),
        party: targetParty, items: finalItems, total: finalItems.fold(0, (s, i) => s + i.total), mode: "CREDIT"
      );
    } 
    else {
      // SALE IMPORT LOGIC
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
        billNo: "${senderInfo['billNo']} [P2P-IMP]", // IMPORT TAG
        date: DateFormat('dd/MM/yyyy').parse(senderInfo['date']),
        party: targetParty, items: finalItems, total: (finalItems.fold(0, (s, i) => s + i.total) - senderInfo['extraDiscount'] + senderInfo['roundOff']), mode: "CREDIT", extraDiscount: senderInfo['extraDiscount'], roundOff: senderInfo['roundOff'],
      );
    }

    await ph.save(); 
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ P2P Import Sync Complete! All Details Mapped."), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(title: Text("P2P ${widget.importType} Review"), backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildSenderHeader(),
          ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: reviewedItems.length, itemBuilder: (c, i) => _buildItemRow(reviewedItems[i])),
          const SizedBox(height: 100),
        ]),
      ),
      bottomNavigationBar: _buildBottomBar(ph),
    );
  }

  Widget _buildSenderHeader() => Container(
    margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.indigo.withOpacity(0.2))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(senderInfo['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.indigo)),
        Text(senderInfo['billNo'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
      ]),
      const Divider(),
      Text("GST: ${senderInfo['gst']} | DL: ${senderInfo['dl']}", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
      Text("PAN: ${senderInfo['pan']} | Mob: ${senderInfo['mobile']}", style: const TextStyle(fontSize: 10, color: Colors.blueGrey)),
      Text("Addr: ${senderInfo['address']}, ${senderInfo['city']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
    ]),
  );

  Widget _buildItemRow(Map<String, dynamic> it) {
    bool isMatch = it['status'] == 'exact';
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), border: Border.all(color: it['isSelected'] ? Colors.green.shade200 : Colors.grey.shade300)),
      child: ListTile(
        leading: Checkbox(value: it['isSelected'], activeColor: Colors.green, onChanged: (v) => setState(() => it['isSelected'] = v!)),
        title: Text(it['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text("Batch: ${it['batch']} | MRP: ${it['mrp']} | P.Rate: ${it['purRate']}", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
          Row(children: [
            if (it['isH1']) _badge("H1", Colors.red),
            if (it['isNaco']) _badge("NRX", Colors.orange),
            Text(isMatch ? "System Match Found" : "New Item Detected", style: TextStyle(fontSize: 10, color: isMatch ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
          ]),
        ]),
        trailing: it['match'] == null ? IconButton(icon: const Icon(Icons.add_box_rounded, color: Colors.red), onPressed: () async {
          // 🔥 SMART AUTO-FILL CALL
          final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => ProductMasterView(isSelectionMode: true, preFillData: it)));
          if (res != null) setState(() { it['match'] = res; it['isSelected'] = true; it['status'] = 'exact'; });
        }) : const Icon(Icons.check_circle, color: Colors.green),
      ),
    );
  }

  Widget _badge(String t, Color c) => Container(margin: const EdgeInsets.only(right: 5), padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4)), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 7, fontWeight: FontWeight.bold)));

  Widget _buildBottomBar(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(20), color: Colors.white,
    child: ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade900, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: () => _finalizeImport(ph),
      icon: const Icon(Icons.sync_alt_rounded),
      label: const Text("IMPORT & UPDATE DASHBOARD", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
    ),
  );
}
