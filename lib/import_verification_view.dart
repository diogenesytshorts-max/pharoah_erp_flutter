import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'import_resolver_widgets.dart';
import 'package:intl/intl.dart';
import 'sale_bill_number.dart'; // Series increment karne ke liye

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

  // --- CSV DATA KO VERIFY KARNA ---
  void _initializeImport() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    List<Map<String, dynamic>> temp = [];

    // Header skip karke rows process karein
    for (int i = 1; i < widget.csvData.length; i++) {
      var row = widget.csvData[i];
      if (row.length < 5) continue;

      // Index mapping (As per CsvEngine): 
      // 0:Date, 1:BillNo, 2:Party, 5:ItemName(Sale)/4:ItemName(Pur)
      String pName = row[2].toString().toUpperCase().trim();
      String iName = widget.importType == "SALE" 
          ? row[5].toString().toUpperCase().trim() 
          : row[4].toString().toUpperCase().trim();

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

  // --- FINAL IMPORT & SERIES UPDATE ---
  void _finalizeImport(PharoahManager ph) async {
    // 1. Bills ko Bill Number ke hisab se group karein
    Map<String, List<Map<String, dynamic>>> groupedBills = {};
    for (var row in processedRows) {
      String billNo = row['data'][1].toString();
      if (!groupedBills.containsKey(billNo)) groupedBills[billNo] = [];
      groupedBills[billNo]!.add(row);
    }

    // 2. Har bill ko process aur save karein
    for (var entry in groupedBills.entries) {
      String billNo = entry.key;
      var rows = entry.value;
      var firstRow = rows[0]['data'];

      // Date parsing
      DateTime dt;
      try {
        dt = DateFormat('dd/MM/yyyy').parse(firstRow[0].toString());
      } catch (e) {
        dt = DateTime.now();
      }

      String pName = firstRow[2].toString().toUpperCase();
      Party billParty = ph.parties.firstWhere((p) => p.name.toUpperCase() == pName.trim());

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

        // Bill Save karein
        ph.finalizeSale(billNo: billNo, date: dt, party: billParty, items: billItems, total: grandTotal, mode: "CREDIT");
        
        // --- FIX: SERIES UPDATE KARNA ---
        await SaleBillNumber.incrementIfNecessary(billNo);
      } 
      else {
        // PURCHASE IMPORT LOGIC
        List<PurchaseItem> purItems = [];
        double grandTotal = 0;

        for (var r in rows) {
          var d = r['data'];
          double rate = double.tryParse(d[9].toString()) ?? 0;
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
    }

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Import Successful! Bill Series Updated."), backgroundColor: Colors.green));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    int readyCount = processedRows.where((r) => r['status'] == "READY").length;
    bool allOk = readyCount == processedRows.length && processedRows.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("Verify ${widget.importType} Details"),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (allOk)
            TextButton.icon(
              onPressed: () => _finalizeImport(ph), 
              icon: const Icon(Icons.cloud_done, color: Colors.white),
              label: const Text("IMPORT ALL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          // Info Banner
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.teal.shade50,
            child: Row(children: [
              Icon(Icons.info_outline, color: Colors.teal.shade800),
              const SizedBox(width: 10),
              Text("Total Items to process: ${processedRows.length} ($readyCount Ready)", style: const TextStyle(fontWeight: FontWeight.bold))
            ]),
          ),
          
          // Row Preview List
          Expanded(
            child: isProcessing 
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
              itemCount: processedRows.length,
              itemBuilder: (c, i) {
                var row = processedRows[i];
                var d = row['data'];
                bool ok = row['status'] == "READY";

                // Index details logic
                String showBillNo = d[1].toString();
                String showDate = d[0].toString();
                String showParty = d[2].toString();
                String showItem = widget.importType == "SALE" ? d[5].toString() : d[4].toString();
                String showQty = widget.importType == "SALE" ? d[9].toString() : d[7].toString();

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  elevation: 2,
                  color: ok ? Colors.white : Colors.red.shade50,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("BILL: $showBillNo", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.blue)),
                            Text("DATE: $showDate", style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        const Divider(height: 20),
                        Text("PARTY: $showParty", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 5),
                        Text("PRODUCT: $showItem", style: TextStyle(color: Colors.grey.shade800, fontSize: 13)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("QTY: $showQty", style: const TextStyle(fontWeight: FontWeight.bold)),
                            ok 
                            ? const Icon(Icons.check_circle, color: Colors.green, size: 28)
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                                onPressed: () => _fixError(i, ph), 
                                child: const Text("FIX ERROR")
                              ),
                          ],
                        )
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- MISSING MASTER DATA FIXING ---
  void _fixError(int index, PharoahManager ph) async {
    var rowData = processedRows[index]['data'];
    if (!processedRows[index]['partyOk']) {
      // Party missing
      Party? p = await ImportResolver.showPartyFixer(context, rowData[2].toString(), "");
      if (p != null) { ph.parties.add(p); ph.save(); _initializeImport(); }
    } else if (!processedRows[index]['itemOk']) {
      // Medicine missing
      String itemName = widget.importType == "SALE" ? rowData[5].toString() : rowData[4].toString();
      Medicine? m = await ImportResolver.showItemFixer(context, itemName, 0, 12);
      if (m != null) { ph.medicines.add(m); ph.save(); _initializeImport(); }
    }
  }
}
