// FILE: lib/import_review_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'party_master.dart';
import 'product_master.dart';
import 'batch_sync_engine.dart'; // NAYA: Batch yaad rakhne ke liye

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
  bool isLocalSale = true;
  bool selectAll = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _processCsvLogic();
  }

  // ===========================================================================
  // CORE ENGINE: 29-COLUMN EXTRACTION (BATCH CASE PRESERVED)
  // ===========================================================================
  void _processCsvLogic() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final data = widget.csvData;
    if (data.length < 2) return;

    var row1 = data[1];
    senderInfo = {
      'name': row1[2].toString().toUpperCase(),
      'gst': row1[3].toString().toUpperCase(),
      'state': row1[4].toString(),
      'billNo': row1[1].toString(),
      'date': row1[0].toString(),
      'dl': row1.length > 18 ? row1[18].toString() : "N/A",
      'pan': row1.length > 19 ? row1[19].toString() : "N/A",
      'city': row1.length > 20 ? row1[20].toString() : "N/A",
      'phone': row1.length > 21 ? row1[21].toString() : "N/A",
      'email': row1.length > 22 ? row1[22].toString() : "N/A",
      'address': row1.length > 23 ? row1[23].toString() : "N/A",
      'sender_state': row1.length > 26 ? row1[26].toString() : "Rajasthan",
      'extraDiscount': row1.length > 27 ? double.tryParse(row1[27].toString()) ?? 0.0 : 0.0,
      'roundOff': row1.length > 28 ? double.tryParse(row1[28].toString()) ?? 0.0 : 0.0,
    };

    String myState = ph.activeCompany?.state.trim().toLowerCase() ?? "rajasthan";
    isLocalSale = myState == senderInfo['sender_state'].toString().trim().toLowerCase();

    reviewedItems.clear();
    for (int i = 1; i < data.length; i++) {
      var row = data[i];
      if (row.length < 17) continue;

      String csvItemName = row[5].toString().toUpperCase().trim();
      String csvPack = row[7].toString().toUpperCase().trim();

      Medicine? match;
      try {
        match = ph.medicines.firstWhere((m) => 
          m.name.toUpperCase() == csvItemName && m.packing.toUpperCase() == csvPack
        );
      } catch (e) {
        try {
          match = ph.medicines.firstWhere((m) => m.name.toUpperCase() == csvItemName);
        } catch (e) { match = null; }
      }

      reviewedItems.add({
        'csvName': csvItemName,
        'csvPack': csvPack,
        'batch': row[8].toString().trim(), // FIXED: No toUpperCase here
        'exp': row[9].toString(),
        'hsn': row[10].toString(),
        'qty': double.tryParse(row[11].toString()) ?? 0,
        'free': double.tryParse(row[12].toString()) ?? 0,
        'mrp': double.tryParse(row[13].toString()) ?? 0,
        'rate': double.tryParse(row[14].toString()) ?? 0,
        'gst': double.tryParse(row[16].toString().replaceAll('%', '')) ?? 12,
        'total': double.tryParse(row[17].toString()) ?? 0,
        'manufacturer': row[6].toString().toUpperCase(),
        'match': match, 
        'status': match != null ? (match.packing == csvPack ? 'matched' : 'suggested') : 'new',
        'isSelected': match != null ? true : false,
        'salt': row.length > 24 ? row[24].toString().toUpperCase() : "N/A",
        'flags': row.length > 25 ? row[25].toString().toUpperCase() : "NORMAL",
      });
    }
    setState(() => isLoading = false);
  }

  // ===========================================================================
  // FINAL SAVE: BATCH MEMORY + DASHBOARD SYNC + MASTER MAPPING
  // ===========================================================================
  void _finalizeAndSave(PharoahManager ph) async {
    bool hasUnresolved = reviewedItems.any((it) => it['isSelected'] && it['status'] == 'new');
    if (hasUnresolved) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link or create all red items first!"), backgroundColor: Colors.red));
      return;
    }

    Party targetParty;
    try {
      targetParty = ph.parties.firstWhere((p) => p.gst == senderInfo['gst'] || p.name == senderInfo['name']);
    } catch (e) {
      targetParty = ph.parties[0];
    }

    if (widget.importType == "SALE") {
      List<BillItem> finalSaleItems = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        
        // --- 1. NAYA: AUTO-LINK COMPANY & SALT FOR SALE IMPORT ---
        String mfgId = ph.getOrCreateCompany(it['manufacturer']);
        String saltId = ph.getOrCreateSalt(it['salt']);
        
        // Medicine Master ko update karna taaki Company/Salt save ho jaye
        int mIdx = ph.medicines.indexWhere((med) => med.id == m.id);
        if(mIdx != -1) {
          ph.medicines[mIdx].companyId = mfgId;
          ph.medicines[mIdx].saltId = saltId;
        }

        // --- 2. NAYA: BATCH REGISTRATION (TAAKI SYSTEM BATCH YAAD RAKHE) ---
        BatchSyncEngine.registerBatchActivity(
          ph: ph, 
          productKey: m.identityKey, 
          batchNo: it['batch'], 
          exp: it['exp'], 
          packing: m.packing, 
          mrp: it['mrp'], 
          rate: it['rate']
        );

        // Tax Calculation
        double taxableVal = it['rate'] * it['qty'];
        double totalLineTax = it['total'] - taxableVal;
        double cgst = isLocalSale ? totalLineTax / 2 : 0;
        double sgst = isLocalSale ? totalLineTax / 2 : 0;
        double igst = isLocalSale ? 0 : totalLineTax;

        finalSaleItems.add(BillItem(
          id: DateTime.now().millisecondsSinceEpoch.toString() + m.id, 
          srNo: finalSaleItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], rate: it['rate'],
          gstRate: it['gst'], total: it['total'],
          cgst: cgst, sgst: sgst, igst: igst,
        ));
      }

      // --- 3. NAYA: AWAIT FINALIZE & FORCE SAVE ---
      await ph.finalizeSale(
        billNo: senderInfo['billNo'], 
        date: DateFormat('dd/MM/yyyy').parse(senderInfo['date']),
        party: targetParty, items: finalSaleItems, 
        total: (finalSaleItems.fold(0.0, (s, i) => s + i.total) - senderInfo['extraDiscount'] + senderInfo['roundOff']), 
        mode: "CREDIT",
        extraDiscount: senderInfo['extraDiscount'], 
        roundOff: senderInfo['roundOff'],
      );
    } 
    else {
      // PURCHASE IMPORT LOGIC
      List<PurchaseItem> finalPurchaseItems = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        ph.getOrCreateCompany(it['manufacturer']); ph.getOrCreateSalt(it['salt']);

        // Register Batch Memory for Purchase
        BatchSyncEngine.registerBatchActivity(ph: ph, productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['rate']);

        finalPurchaseItems.add(PurchaseItem(
          id: DateTime.now().millisecondsSinceEpoch.toString() + m.id, 
          srNo: finalPurchaseItems.length + 1,
          medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'],
          hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], purchaseRate: it['rate'],
          gstRate: it['gst'], total: it['total'],
        ));
      }
      ph.finalizePurchase(
        internalNo: "P2P-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
        billNo: senderInfo['billNo'], date: DateFormat('dd/MM/yyyy').parse(senderInfo['date']),
        entryDate: DateTime.now(), party: targetParty, items: finalPurchaseItems,
        total: finalPurchaseItems.fold(0.0, (s, i) => s + i.total), mode: "CREDIT"
      );
    }

    // Aakhri step: Poora master data save karna Dashboard sync ke liye
    await ph.save(); 

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Import Sync Complete: Batch & Dashboard Updated!"), backgroundColor: Colors.green));
  }

  // --- OTHERS (UI & HELPERS) ---
  void _editPartyDetail() async {
    await Navigator.push(context, MaterialPageRoute(builder: (c) => PartyMasterView(isSelectionMode: true, preFillData: {'name': senderInfo['name'], 'gst': senderInfo['gst'], 'state': senderInfo['sender_state'], 'city': senderInfo['city'], 'dl': senderInfo['dl'], 'pan': senderInfo['pan'], 'phone': senderInfo['phone'], 'email': senderInfo['email'], 'address': senderInfo['address']})));
    _processCsvLogic(); 
  }

  void _createProduct(Map<String, dynamic> item) async {
    await Navigator.push(context, MaterialPageRoute(builder: (c) => ProductMasterView(isSelectionMode: true, preFillData: {'name': item['csvName'], 'packing': item['csvPack'], 'hsn': item['hsn'], 'gst': item['gst'], 'company': item['manufacturer'], 'salt': item['salt'], 'flags': item['flags']})));
    _processCsvLogic(); 
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(title: Text("P2P Review (${widget.importType})", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white),
      body: SingleChildScrollView(child: Column(children: [_buildTopHeader(), _buildPartyCard(), _buildActionStrip(), ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 12), itemCount: reviewedItems.length, itemBuilder: (c, i) => _buildItemRow(reviewedItems[i])), const SizedBox(height: 20), _buildBottomSummary(ph)])));
  }

  Widget _buildTopHeader() => Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), color: Colors.blue.shade900, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_tag("BILL DATE:", senderInfo['date'], Icons.receipt_long), _tag("IMPORT DATE:", DateFormat('dd/MM/yyyy').format(DateTime.now()), Icons.computer)]));
  Widget _tag(String l, String d, IconData i) => Row(children: [Icon(i, size: 12, color: Colors.white70), const SizedBox(width: 5), Text("$l $d", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold))]);
  Widget _buildPartyCard() => Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: Row(children: [const CircleAvatar(radius: 25, backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.business, color: Color(0xFF0D47A1))), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Flexible(child: Text(senderInfo['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15), overflow: TextOverflow.ellipsis)), const SizedBox(width: 5), IconButton(onPressed: _editPartyDetail, icon: const Icon(Icons.edit_note, color: Colors.blue, size: 22))]), Text("GST: ${senderInfo['gst']} | DL: ${senderInfo['dl']}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), Text(isLocalSale ? "MODE: LOCAL (CGST+SGST)" : "MODE: INTERSTATE (IGST)", style: TextStyle(fontSize: 10, color: isLocalSale ? Colors.green : Colors.indigo, fontWeight: FontWeight.bold))])), Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(senderInfo['billNo'], style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey)), const Text("P2P SYNC", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold))])]));
  Widget _buildActionStrip() => Padding(padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), child: Row(children: [Checkbox(value: selectAll, activeColor: const Color(0xFF0D47A1), onChanged: (v) { setState(() { selectAll = v!; for (var it in reviewedItems) if(it['status'] != 'new') it['isSelected'] = v; }); }), const Text("SELECT ALL MATCHED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)), const Spacer(), _dot(Colors.green, "OK"), _dot(Colors.orange, "MAP"), _dot(Colors.red, "NEW")]));
  Widget _dot(Color c, String l) => Row(children: [Container(margin: const EdgeInsets.only(left: 8), width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)), const SizedBox(width: 3), Text(l, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold))]);
  Widget _buildItemRow(Map<String, dynamic> it) { Color statusColor = it['status'] == 'matched' ? Colors.green : (it['status'] == 'suggested' ? Colors.orange : Colors.red); Medicine? m = it['match']; return Card(elevation: 0, margin: const EdgeInsets.only(bottom: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: it['isSelected'] ? statusColor : Colors.grey.shade200, width: it['isSelected'] ? 2 : 1)), child: ExpansionTile(leading: Checkbox(value: it['isSelected'], activeColor: statusColor, onChanged: (v) => setState(() => it['isSelected'] = v!)), title: Text(it['csvName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(padding: const EdgeInsets.all(5), margin: const EdgeInsets.only(top: 5), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(5)), child: Text("Batch: ${it['batch']} | Exp: ${it['exp']} | MRP: ₹${it['mrp']} | Rate: ₹${it['rate']} | GST: ${it['gst']}%", style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey))), const SizedBox(height: 5), Text(it['status'] == 'new' ? "New Product: Action Required" : "System Match: ${m?.name} (${m?.packing})", style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold))]), trailing: _buildRowAction(it, statusColor))); }
  Widget _buildRowAction(Map<String, dynamic> it, Color c) { if (it['status'] == 'matched' && it['isSelected']) return const Icon(Icons.check_circle, color: Colors.green); return Row(mainAxisSize: MainAxisSize.min, children: [if(it['status'] != 'matched') IconButton(icon: const Icon(Icons.link_rounded, color: Colors.blue, size: 22), onPressed: () async { final Medicine? linkedMed = await Navigator.push(context, MaterialPageRoute(builder: (c) => ProductMasterView(isSelectionMode: true))); if (linkedMed != null) setState(() { it['match'] = linkedMed; it['status'] = 'matched'; it['isSelected'] = true; }); }), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: c, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(50, 30)), onPressed: it['status'] == 'new' ? () => _createProduct(it) : () => setState(() => it['isSelected'] = true), child: Text(it['status'] == 'new' ? "CREATE" : "OK", style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)))]); }
  Widget _buildBottomSummary(PharoahManager ph) { double itemTotal = reviewedItems.where((it) => it['isSelected']).fold(0.0, (sum, it) => sum + it['total']); double extraDisc = senderInfo['extraDiscount'] ?? 0.0; double netPayable = itemTotal - extraDisc + (senderInfo['roundOff'] ?? 0.0); return Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25)), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))]), child: Column(children: [_row("Items Gross Total", itemTotal), if (extraDisc > 0) _row("Extra Discount (-)", extraDisc), _row("Round Off", senderInfo['roundOff'] ?? 0.0), const Divider(height: 25), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("NET PAYABLE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)), Text("₹${netPayable.toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1)))]), const SizedBox(height: 15), ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => _finalizeAndSave(ph), icon: const Icon(Icons.cloud_upload_rounded), label: Text("FINALIZE IMPORT", style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)))])); }
  Widget _row(String l, double v) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))]));
}
