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
  final String importType;
  final String exchangeMode;

  const ImportReviewScreen({super.key, required this.csvData, required this.importType, required this.exchangeMode});

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

  void _processUniversalLogic() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final data = widget.csvData;
    if (data.length < 2) return;
    
    var r1 = data[1];
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
      'extraDisc': r1.length > 35 ? (double.tryParse(r1[35].toString()) ?? 0.0) : 0.0,
      'roundOff': r1.length > 36 ? (double.tryParse(r1[36].toString()) ?? 0.0) : 0.0,
    };

    try {
      matchedParty = ph.parties.firstWhere((p) => p.gst == partyInfoInFile['gst'] || p.name == partyInfoInFile['name']);
    } catch (e) { matchedParty = null; }

    reviewedItems.clear();
    for (int i = 1; i < data.length; i++) {
      var row = data[i];
      if (row.length < 34) continue;

      double qty = double.tryParse(row[28].toString()) ?? 0.0;
      double rate = double.tryParse(row[32].toString()) ?? 0.0;
      double gstPer = double.tryParse(row[33].toString()) ?? 12.0;
      double csvTotal = double.tryParse(row[34].toString()) ?? 0.0;

      double taxable = qty * rate;
      double taxAmt = taxable * (gstPer / 100);
      double systemTotal = double.parse((taxable + taxAmt).toStringAsFixed(2));

      bool isLocal = partyInfoInFile['state'].toString().toLowerCase() == (ph.activeCompany?.state.toLowerCase() ?? "rajasthan");

      Medicine? match;
      try { match = ph.medicines.firstWhere((m) => m.name == row[18].toString().toUpperCase()); } catch(e) { match = null; }

      reviewedItems.add({
        'name': row[18].toString().toUpperCase(), 'pack': row[19].toString(), 'batch': row[26].toString(), 'exp': row[27].toString(),
        'qty': qty, 'free': double.tryParse(row[29].toString()) ?? 0.0, 'hsn': row[20].toString(), 'mrp': double.tryParse(row[30].toString()) ?? 0.0,
        'rate': rate, 'gstPer': gstPer, 'csvTotal': csvTotal, 'sysTotal': systemTotal,
        'match': match, 'isSelected': match != null, 'status': match == null ? 'new' : 'exact',
        'isFixed': false, 'taxable': taxable, 'cgst': isLocal ? taxAmt/2 : 0.0, 'sgst': isLocal ? taxAmt/2 : 0.0, 'igst': isLocal ? 0.0 : taxAmt,
      });
    }
    setState(() => isLoading = false);
  }

  void _showQuickPartyPicker(PharoahManager ph) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) {
        String search = "";
        return StatefulBuilder(builder: (context, setPickerState) {
          final list = ph.parties.where((p) => p.name.toLowerCase().contains(search.toLowerCase())).toList();
          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Text("SELECT PARTY FROM SYSTEM", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              TextField(
                style: const TextStyle(color: Colors.white), autofocus: true,
                decoration: InputDecoration(hintText: "Search Party Name...", hintStyle: TextStyle(color: Colors.white24), prefixIcon: const Icon(Icons.search, color: Colors.blueAccent), filled: true, fillColor: Colors.white10, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
                onChanged: (v) => setPickerState(() => search = v),
              ),
              Expanded(child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (c, i) => ListTile(
                  title: Text(list[i].name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text("${list[i].city} | GST: ${list[i].gst}", style: const TextStyle(color: Colors.white54, fontSize: 11)),
                  onTap: () { setState(() => matchedParty = list[i]); Navigator.pop(context); },
                ),
              ))
            ]),
          );
        });
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    if (isLoading) return const Scaffold(backgroundColor: Color(0xFF0F172A), body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(title: const Text("MIRROR AUDIT ENGINE"), backgroundColor: const Color(0xFF1E293B)),
      body: Column(children: [
        _buildPartyCard(),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(12), itemCount: reviewedItems.length, itemBuilder: (c, i) => _buildRow(i))),
        _buildAnalyticsFooter(ph),
      ]),
    );
  }

  Widget _buildPartyCard() {
    bool isOk = matchedParty != null;
    return InkWell(
      onTap: () => _showPartyVerifySheet(),
      child: Container(
        margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(15), border: Border.all(color: isOk ? Colors.blueAccent : Colors.redAccent)),
        child: Row(children: [
          CircleAvatar(backgroundColor: isOk ? Colors.blue : Colors.redAccent, child: const Icon(Icons.business, color: Colors.white)),
          const SizedBox(width: 15),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(partyInfoInFile['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            Text("Mob: ${partyInfoInFile['mobile']} | GST: ${partyInfoInFile['gst']}", style: const TextStyle(color: Colors.white54, fontSize: 10)),
            const Text("VIEW & MANAGE DETAILS", style: TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold)),
          ])),
          Icon(isOk ? Icons.verified : Icons.error_outline, color: isOk ? Colors.greenAccent : Colors.orange),
        ]),
      ),
    );
  }

  Widget _buildRow(int i) {
    var it = reviewedItems[i];
    bool hasErr = (it['sysTotal'] - it['csvTotal']).abs() > 0.1 && !it['isFixed'];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(10), border: Border.all(color: hasErr ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.3))),
      child: Column(children: [
        Row(children: [
          Expanded(child: Text(it['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          _badge("PK: ${it['pack']}", Colors.blueGrey),
        ]),
        const SizedBox(height: 8),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _metric("CSV TOTAL", it['csvTotal']),
          _metric("SYS CALC", it['sysTotal'], color: hasErr ? Colors.redAccent : Colors.greenAccent),
          if (hasErr) ElevatedButton(onPressed: () => setState(() { it['isFixed'] = true; it['sysTotal'] = it['csvTotal']; }), style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, minimumSize: const Size(50, 28)), child: const Text("FIX", style: TextStyle(fontSize: 9)))
        ])
      ]),
    );
  }

  void _showPartyVerifySheet() {
    showModalBottomSheet(
      context: context, backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(25),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("SENDER VERIFICATION", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          const Divider(color: Colors.white10, height: 30),
          _detailRow("NAME", partyInfoInFile['name']),
          _detailRow("MOBILE", partyInfoInFile['mobile']),
          _detailRow("GSTIN", partyInfoInFile['gst']),
          _detailRow("STATE", partyInfoInFile['state']),
          const SizedBox(height: 30),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(c); _showQuickPartyPicker(Provider.of<PharoahManager>(context, listen: false)); }, child: const Text("LINK EXISTING"))),
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
      decoration: const BoxDecoration(color: Color(0xFF1E293B), borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _footStat("NET SYSTEM", sysTotal),
          _footStat("NET CSV", csvTotal),
          _footStat("DIFF", diff, color: diff.abs() > 0.1 ? Colors.redAccent : Colors.greenAccent),
        ]),
        const Divider(color: Colors.white10, height: 25),
        SizedBox(width: double.infinity, height: 55, child: ElevatedButton.icon(
          onPressed: () => _handleFinalImport(ph),
          icon: const Icon(Icons.cloud_done),
          label: const Text("FINALIZE & MIRROR DATA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
        ))
      ]),
    );
  }

  void _handleFinalImport(PharoahManager ph) async {
    if (matchedParty == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link/Create Party first!"))); return; }
    if (reviewedItems.any((it) => it['isSelected'] && it['match'] == null)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link all products first!"))); return; }

    setState(() => isLoading = true);
    double finalSysTotal = reviewedItems.where((e)=>e['isSelected']).fold(0.0, (s, e)=>s+e['sysTotal']);

    if (widget.importType == "PURCHASE") {
      List<PurchaseItem> items = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        ph.registerBatchActivity(productKey: m.identityKey, batchNo: it['batch'], exp: it['exp'], packing: m.packing, mrp: it['mrp'], rate: it['rate']);
        items.add(PurchaseItem(id: DateTime.now().toString() + m.id, srNo: items.length + 1, medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'], hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], purchaseRate: it['rate'], gstRate: it['gstPer'], total: it['sysTotal']));
      }
      ph.finalizePurchase(internalNo: "MIR-PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}", billNo: partyInfoInFile['billNo'], date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']), entryDate: DateTime.now(), party: matchedParty!, items: items, total: items.fold(0, (s, e)=>s+e.total), mode: "CREDIT", sourceTag: "P2P");
    } else {
      List<BillItem> items = [];
      for (var it in reviewedItems.where((e) => e['isSelected'])) {
        Medicine m = it['match'];
        items.add(BillItem(id: DateTime.now().toString() + m.id, srNo: items.length + 1, medicineID: m.id, name: m.name, packing: m.packing, batch: it['batch'], exp: it['exp'], hsn: it['hsn'], mrp: it['mrp'], qty: it['qty'], freeQty: it['free'], rate: it['rate'], gstRate: it['gstPer'], cgst: it['cgst'], sgst: it['sgst'], igst: it['igst'], total: it['sysTotal']));
      }
      await ph.finalizeSale(billNo: partyInfoInFile['billNo'], date: DateFormat('dd/MM/yyyy').parse(partyInfoInFile['date']), party: matchedParty!, items: items, total: (finalSysTotal - partyInfoInFile['extraDisc'] + partyInfoInFile['roundOff']), mode: "CREDIT", sourceTag: "P2P", extraDiscount: partyInfoInFile['extraDisc'], roundOff: partyInfoInFile['roundOff']);
    }
    
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ C2C Data Sync Successful!"), backgroundColor: Colors.green));
  }

  Widget _badge(String t, Color c) => Container(margin: const EdgeInsets.only(left: 5), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(4)), child: Text(t, style: TextStyle(color: c, fontSize: 8, fontWeight: FontWeight.bold)));
  Widget _metric(String l, double v, {Color color = Colors.white70}) => Column(children: [Text(l, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w900))]);
  Widget _footStat(String l, double v, {Color color = Colors.white70}) => Column(children: [Text(l, style: const TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold)), Text("₹${v.toStringAsFixed(2)}", style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold))]);
  Widget _detailRow(String l, String v) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [Text("$l: ", style: const TextStyle(color: Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)), Expanded(child: Text(v, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)))]));
}
