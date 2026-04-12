import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'import_resolver_widgets.dart';
import 'package:intl/intl.dart';

class ImportVerificationView extends StatefulWidget {
  final List<List<dynamic>> csvData;
  final String importType;

  const ImportVerificationView({super.key, required this.csvData, required this.importType});

  @override
  State<ImportVerificationView> createState() => _ImportVerificationViewState();
}

class _ImportVerificationViewState extends State<ImportVerificationView> {
  List<Map<String, dynamic>> processedRows = [];
  bool isProcessing = true;

  @override
  void initState() {
    super.initState();
    _initializeImport();
  }

  void _initializeImport() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    List<Map<String, dynamic>> temp = [];

    for (int i = 1; i < widget.csvData.length; i++) {
      var row = widget.csvData[i];
      if (row.length < 5) continue;

      String pName = row[2].toString().toUpperCase().trim();
      String iName = row[5].toString().toUpperCase().trim();

      bool partyExists = ph.parties.any((p) => p.name.trim().toUpperCase() == pName);
      bool itemExists = ph.medicines.any((m) => m.name.trim().toUpperCase() == iName);

      temp.add({
        'data': row,
        'partyOk': partyExists,
        'itemOk': itemExists,
        'status': (partyExists && itemExists) ? "READY" : "ERROR",
      });
    }

    setState(() {
      processedRows = temp;
      isProcessing = false;
    });
  }

  // --- CONSOLIDATED IMPORT LOGIC (Grouping items by Bill No) ---
  void _finalizeImport(PharoahManager ph) {
    // 1. Grouping Rows by Bill Number
    Map<String, List<Map<String, dynamic>>> groupedBills = {};
    for (var row in processedRows) {
      String billNo = row['data'][1].toString(); // Index 1 is Bill No
      if (!groupedBills.containsKey(billNo)) groupedBills[billNo] = [];
      groupedBills[billNo]!.add(row);
    }

    // 2. Process each Grouped Bill
    groupedBills.forEach((billNo, rows) {
      var firstRow = rows[0]['data'];
      DateTime dt = DateFormat('dd/MM/yyyy').parse(firstRow[0].toString());
      String pName = firstRow[2].toString().toUpperCase();
      Party billParty = ph.parties.firstWhere((p) => p.name.toUpperCase() == pName);

      if (widget.importType == "SALE") {
        List<BillItem> billItems = [];
        double grandTotal = 0;

        for (var r in rows) {
          var d = r['data'];
          double rate = double.tryParse(d[10].toString()) ?? 0;
          double qty = double.tryParse(d[9].toString()) ?? 0;
          double total = double.tryParse(d[12].toString()) ?? 0;

          billItems.add(BillItem(
            id: "${DateTime.now().millisecondsSinceEpoch}_${d[5]}",
            srNo: billItems.length + 1,
            medicineID: ph.medicines.firstWhere((m) => m.name.toUpperCase() == d[5].toString().toUpperCase()).id,
            name: d[5].toString(),
            packing: "N/A",
            batch: d[6].toString(),
            exp: d[7].toString(),
            hsn: d[8].toString(),
            mrp: rate * 1.2,
            qty: qty,
            rate: rate,
            gstRate: double.tryParse(d[11].toString()) ?? 12,
            total: total,
          ));
          grandTotal += total;
        }

        ph.finalizeSale(billNo: billNo, date: dt, party: billParty, items: billItems, total: grandTotal, mode: "CREDIT");
      } 
      else {
        // --- PURCHASE IMPORT CONSOLIDATION ---
        List<PurchaseItem> purItems = [];
        double grandTotal = 0;

        for (var r in rows) {
          var d = r['data'];
          double rate = double.tryParse(d[9].toString()) ?? 0; // Purchase Rate Index
          double qty = double.tryParse(d[7].toString()) ?? 0;
          double total = double.tryParse(d[11].toString()) ?? 0;

          purItems.add(PurchaseItem(
            id: "${DateTime.now().millisecondsSinceEpoch}_${d[4]}",
            srNo: purItems.length + 1,
            medicineID: ph.medicines.firstWhere((m) => m.name.toUpperCase() == d[4].toString().toUpperCase()).id,
            name: d[4].toString(),
            packing: "N/A",
            batch: d[5].toString(),
            exp: d[6].toString(),
            hsn: "N/A",
            mrp: rate * 1.2,
            qty: qty,
            freeQty: double.tryParse(d[8].toString()) ?? 0,
            purchaseRate: rate,
            gstRate: double.tryParse(d[10].toString()) ?? 12,
            total: total,
          ));
          grandTotal += total;
        }
        ph.finalizePurchase(internalNo: "IMP-$billNo", billNo: billNo, date: dt, party: billParty, items: purItems, total: grandTotal, mode: "CREDIT");
      }
    });

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Import Successful! Bills Consolidated."), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    int readyCount = processedRows.where((r) => r['status'] == "READY").length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Verify ${widget.importType}s"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (readyCount == processedRows.length && processedRows.isNotEmpty)
            IconButton(icon: const Icon(Icons.cloud_done), onPressed: () => _finalizeImport(ph))
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.amber.shade50,
            child: Row(children: [
              const Icon(Icons.info_outline, color: Colors.orange),
              const SizedBox(width: 10),
              Text("Verified: $readyCount / ${processedRows.length} rows", style: const TextStyle(fontWeight: FontWeight.bold))
            ]),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: processedRows.length,
              itemBuilder: (c, i) {
                var row = processedRows[i];
                var d = row['data'];
                bool ok = row['status'] == "READY";

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  color: ok ? Colors.white : Colors.red.shade50,
                  child: ListTile(
                    title: Text("${d[2]} | Bill: ${d[1]}", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Item: ${widget.importType == 'SALE' ? d[5] : d[4]} | Qty: ${widget.importType == 'SALE' ? d[9] : d[7]}"),
                    trailing: ok 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(onPressed: () => _fixError(i, ph), child: const Text("FIX")),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _fixError(int index, PharoahManager ph) async {
    var rowData = processedRows[index]['data'];
    if (!processedRows[index]['partyOk']) {
      Party? p = await ImportResolver.showPartyFixer(context, rowData[2].toString(), "");
      if (p != null) { ph.parties.add(p); ph.save(); _initializeImport(); }
    } else if (!processedRows[index]['itemOk']) {
      String itemName = widget.importType == "SALE" ? rowData[5].toString() : rowData[4].toString();
      Medicine? m = await ImportResolver.showItemFixer(context, itemName, 0, 12);
      if (m != null) { ph.medicines.add(m); ph.save(); _initializeImport(); }
    }
  }
}
