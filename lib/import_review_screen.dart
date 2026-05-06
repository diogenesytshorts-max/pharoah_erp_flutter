// FILE: lib/import_review_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'party_master.dart';
import 'product_master.dart';

class ImportReviewScreen extends StatefulWidget {
  final List<List<dynamic>> csvData; // Raw rows from CSV
  final String importType; // SALE or PURCHASE

  const ImportReviewScreen({
    super.key, 
    required this.csvData, 
    required this.importType
  });

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  // Mapping logic ke liye temporary items list
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
  // CORE LOGIC: CSV DATA KO SYSTEM SE MATCH KARNA
  // ===========================================================================
  void _processCsvLogic() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    final data = widget.csvData;
    if (data.length < 2) return;

    // Header se Sender Info nikalna (Row 1)
    var firstRow = data[1];
    senderInfo = {
      'name': firstRow[2].toString().toUpperCase(),
      'gst': firstRow[3].toString().toUpperCase(),
      'state': firstRow[4].toString(),
      'billNo': firstRow[1].toString(),
      'date': firstRow[0].toString(),
      'dl': firstRow.length > 18 ? firstRow[18].toString() : "N/A",
      'pan': firstRow.length > 19 ? firstRow[19].toString() : "N/A",
      'city': firstRow.length > 20 ? firstRow[20].toString() : "N/A",
    };

    // Tax Recognition: Shop State vs Sender State
    String shopState = ph.activeCompany?.state.trim().toLowerCase() ?? "rajasthan";
    isLocalSale = shopState == senderInfo['state'].toString().trim().toLowerCase();

    // Items Processing
    reviewedItems.clear();
    for (int i = 1; i < data.length; i++) {
      var row = data[i];
      if (row.length < 10) continue;

      String csvItemName = row[5].toString().toUpperCase().trim();
      String csvPack = row[7].toString().toUpperCase().trim();

      // Smart Matching Pass 1: Name + Packing
      Medicine? match;
      try {
        match = ph.medicines.firstWhere((m) => 
          m.name.toUpperCase() == csvItemName && m.packing.toUpperCase() == csvPack
        );
      } catch (e) {
        // Pass 2: Only Name
        try {
          match = ph.medicines.firstWhere((m) => m.name.toUpperCase() == csvItemName);
        } catch (e) { match = null; }
      }

      reviewedItems.add({
        'csvName': csvItemName,
        'csvPack': csvPack,
        'batch': row[8].toString(),
        'exp': row[9].toString(),
        'hsn': row[10].toString(),
        'qty': double.tryParse(row[11].toString()) ?? 0,
        'free': double.tryParse(row[12].toString()) ?? 0,
        'mrp': double.tryParse(row[13].toString()) ?? 0,
        'rate': double.tryParse(row[14].toString()) ?? 0,
        'gst': double.tryParse(row[16].toString().replaceAll('%', '')) ?? 12,
        'total': double.tryParse(row[17].toString()) ?? 0,
        'match': match, // Local Database Object
        'status': match != null ? (match.packing == csvPack ? 'matched' : 'suggested') : 'new',
        'isSelected': match != null ? true : false,
        'salt': row.length > 21 ? row[21].toString() : "N/A",
        'flags': row.length > 22 ? row[22].toString() : "N/A",
      });
    }

    setState(() => isLoading = false);
  }

  // ===========================================================================
  // NAVIGATION: MASTER SCREENS KO PRE-FILL KE SAATH KHOLNA
  // ===========================================================================
  void _editPartyDetail() async {
    // Reviewer se Party Master par bhej rahe hain details ke saath
    await Navigator.push(context, MaterialPageRoute(
      builder: (c) => PartyMasterView(
        isSelectionMode: true,
        preFillData: {
          'name': senderInfo['name'],
          'gst': senderInfo['gst'],
          'state': senderInfo['state'],
          'city': senderInfo['city'],
          'dl': senderInfo['dl'],
          'pan': senderInfo['pan'],
        },
      )
    ));
    _processCsvLogic(); // Wapas aane par re-scan
  }

  void _createProduct(Map<String, dynamic> item) async {
    // Distributor ka data Product Master ko bhejna
    await Navigator.push(context, MaterialPageRoute(
      builder: (c) => ProductMasterView(
        isSelectionMode: true,
        preFillData: {
          'name': item['csvName'],
          'packing': item['csvPack'],
          'hsn': item['hsn'],
          'gst': item['gst'],
          'company': item['manufacturer'], // Enriched field from CSV
          'salt': item['salt'],           // Enriched field from CSV
        },
      )
    ));
    _processCsvLogic(); // Wapas aane par status "Green" ho jayega
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFFF1F3F6),
      appBar: AppBar(
        title: const Text("Verify Pharoah Data Exchange", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildDateHeader(),
          _buildPartyCard(),
          _buildActionStrip(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: reviewedItems.length,
              itemBuilder: (c, i) => _buildItemRow(reviewedItems[i]),
            ),
          ),
          _buildBottomSummary(),
        ],
      ),
    );
  }

  // --- UI COMPONENTS ---

  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: Colors.blue.shade900,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _dateLabel("BILL DATE:", senderInfo['date'], Icons.receipt_long),
          _dateLabel("ENTRY DATE:", DateFormat('dd/MM/yyyy').format(DateTime.now()), Icons.computer),
        ],
      ),
    );
  }

  Widget _dateLabel(String l, String d, IconData i) => Row(children: [
    Icon(i, size: 12, color: Colors.white70),
    const SizedBox(width: 5),
    Text("$l $d", style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
  ]);

  Widget _buildPartyCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
      child: Row(
        children: [
          const CircleAvatar(radius: 25, backgroundColor: Color(0xFFE3F2FD), child: Icon(Icons.business, color: Color(0xFF0D47A1))),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Flexible(child: Text(senderInfo['name'], style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15), overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 5),
                  IconButton(onPressed: _editPartyDetail, icon: const Icon(Icons.edit_note, color: Colors.blue, size: 22)),
                ]),
                Text("GST: ${senderInfo['gst']} | DL: ${senderInfo['dl']}", style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
                Text(isLocalSale ? "LOCAL TRANSACTION (CGST+SGST)" : "INTERSTATE (IGST DETECTED)", style: TextStyle(fontSize: 10, color: isLocalSale ? Colors.green : Colors.indigo, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(senderInfo['billNo'], style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blueGrey)),
            const Text("PHAROAH-P2P", style: TextStyle(fontSize: 8, color: Colors.grey, fontWeight: FontWeight.bold)),
          ])
        ],
      ),
    );
  }

  Widget _buildActionStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Row(
        children: [
          Checkbox(
            value: selectAll, 
            activeColor: const Color(0xFF0D47A1),
            onChanged: (v) {
              setState(() {
                selectAll = v!;
                for (var it in reviewedItems) if(it['status'] != 'new') it['isSelected'] = v;
              });
            }
          ),
          const Text("SELECT ALL MATCHED", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blueGrey)),
          const Spacer(),
          const Text("COLOR GUIDE:", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
          _dot(Colors.green), _dot(Colors.orange), _dot(Colors.red),
        ],
      ),
    );
  }

  Widget _dot(Color c) => Container(margin: const EdgeInsets.only(left: 5), width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle));

  Widget _buildItemRow(Map<String, dynamic> it) {
    Color statusColor = it['status'] == 'matched' ? Colors.green : (it['status'] == 'suggested' ? Colors.orange : Colors.red);
    Medicine? m = it['match'];

    return Card(
      elevation: 0, margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: it['isSelected'] ? statusColor : Colors.grey.shade200, width: it['isSelected'] ? 2 : 1)),
      child: ExpansionTile(
        leading: Checkbox(value: it['isSelected'], activeColor: statusColor, onChanged: (v) => setState(() => it['isSelected'] = v!)),
        title: Text(it['csvName'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // SUB-ROW METADATA
          Container(
            padding: const EdgeInsets.all(5), margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(5)),
            child: Text(
              "B: ${it['batch']} | Exp: ${it['exp']} | MRP: ${it['mrp']} | Rate: ${it['rate']} | GST: ${it['gst']}% | HSN: ${it['hsn']}",
              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.blueGrey),
            ),
          ),
          const SizedBox(height: 5),
          Text(it['status'] == 'new' ? "New Product: Link or Create" : "System Match: ${m?.name} (${m?.packing})", style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold)),
        ]),
        trailing: _buildRowAction(it, statusColor),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: InputDecoration(hintText: "Search your master to link...", prefixIcon: const Icon(Icons.search, size: 18), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildRowAction(Map<String, dynamic> it, Color c) {
    if (it['status'] == 'matched' && it['isSelected']) return const Icon(Icons.check_circle, color: Colors.green);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if(it['status'] != 'matched') IconButton(icon: const Icon(Icons.link_rounded, color: Colors.blue, size: 22), onPressed: () {}),
      ElevatedButton(
        style: ElevatedButton.styleFrom(backgroundColor: c, padding: const EdgeInsets.symmetric(horizontal: 10), minimumSize: const Size(50, 30)),
        onPressed: () => setState(() => it['isSelected'] = true),
        child: Text(it['status'] == 'new' ? "CREATE" : "OK", style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.bold)),
      )
    ]);
  }

  Widget _buildBottomSummary() {
    double taxable = reviewedItems.where((it) => it['isSelected']).fold(0.0, (sum, it) => sum + (it['rate'] * it['qty']));
    double gstTotal = reviewedItems.where((it) => it['isSelected']).fold(0.0, (sum, it) => sum + (it['total'] - (it['rate'] * it['qty'])));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, -5))]),
      child: SafeArea(
        child: Column(
          children: [
            _summaryRow("Total Taxable", taxable),
            _summaryRow(isLocalSale ? "CGST + SGST" : "IGST (Integrated)", gstTotal),
            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text("NET PAYABLE", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
              Text("₹${(taxable + gstTotal).toStringAsFixed(2)}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF0D47A1))),
            ]),
            const SizedBox(height: 15),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0D47A1), foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () {
                // Final Save Logic will be connected in next step
              },
              icon: const Icon(Icons.cloud_upload_rounded),
              label: const Text("FINALIZE & SAVE PURCHASE", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            )
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String l, double v) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      Text("₹${v.toStringAsFixed(2)}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    ]),
  );
}
