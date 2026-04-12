import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'import_resolver_widgets.dart';
import 'package:intl/intl.dart';

class ImportVerificationView extends StatefulWidget {
  final List<List<dynamic>> csvData;
  final String importType; // "SALE" or "PURCHASE"

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

  // CSV rows ko app ke samajhne layak objects mein badalna
  void _initializeImport() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    List<Map<String, dynamic>> temp = [];

    // Pehli row (Header) chhod kar loop chalana
    for (int i = 1; i < widget.csvData.length; i++) {
      var row = widget.csvData[i];
      if (row.length < 5) continue; // Galat row skip karein

      String pName = row[2].toString().toUpperCase();
      String iName = row[5].toString().toUpperCase();

      // Check if Party and Medicine Exist
      bool partyExists = ph.parties.any((p) => p.name == pName);
      bool itemExists = ph.medicines.any((m) => m.name == iName);

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

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    int readyCount = processedRows.where((r) => r['status'] == "READY").length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Verify ${widget.importType} Import"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (readyCount == processedRows.length && processedRows.isNotEmpty)
            TextButton(
              onPressed: () => _finalizeImport(ph),
              child: const Text("IMPORT ALL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.amber.shade100,
            child: Row(
              children: [
                const Icon(Icons.info, color: Colors.orange),
                const SizedBox(width: 10),
                Text("Ready: $readyCount / ${processedRows.length} Records", style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: processedRows.length,
              itemBuilder: (c, i) {
                var item = processedRows[i];
                var rowData = item['data'];
                bool isOk = item['status'] == "READY";

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  child: ListTile(
                    title: Text("${rowData[2]} (Bill: ${rowData[1]})", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Item: ${rowData[5]} | Qty: ${rowData[9]} | Amt: ₹${rowData[12]}"),
                    trailing: isOk 
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : ElevatedButton(
                          onPressed: () => _fixError(i, ph),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                          child: const Text("FIX"),
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

  // Error ko wahin thik karne ka logic
  void _fixError(int index, PharoahManager ph) async {
    var row = processedRows[index]['data'];

    // 1. Agar Party nahi hai
    if (!processedRows[index]['partyOk']) {
      Party? newP = await ImportResolver.showPartyFixer(context, row[2].toString(), row[3].toString());
      if (newP != null) {
        ph.parties.add(newP);
        ph.save();
        _initializeImport(); // Refresh
      }
    } 
    // 2. Agar Item nahi hai
    else if (!processedRows[index]['itemOk']) {
      Medicine? newM = await ImportResolver.showItemFixer(context, row[5].toString(), double.tryParse(row[10].toString()) ?? 0, double.tryParse(row[11].toString()) ?? 12);
      if (newM != null) {
        ph.medicines.add(newM);
        ph.save();
        _initializeImport(); // Refresh
      }
    }
  }

  // Final Save Logic
  void _finalizeImport(PharoahManager ph) {
    for (var rowMap in processedRows) {
      var row = rowMap['data'];
      
      // Models banana CSV data se
      if (widget.importType == "SALE") {
        ph.finalizeSale(
          billNo: row[1].toString(),
          date: DateFormat('dd/MM/yyyy').parse(row[0].toString()),
          party: ph.parties.firstWhere((p) => p.name == row[2].toString()),
          items: [
            BillItem(
              id: DateTime.now().toString(),
              srNo: 1,
              medicineID: ph.medicines.firstWhere((m) => m.name == row[5].toString()).id,
              name: row[5].toString(),
              packing: "N/A",
              batch: row[6].toString(),
              exp: row[7].toString(),
              hsn: row[8].toString(),
              mrp: double.tryParse(row[10].toString()) ?? 0,
              qty: double.tryParse(row[9].toString()) ?? 0,
              rate: double.tryParse(row[10].toString()) ?? 0,
              gstRate: double.tryParse(row[11].toString()) ?? 0,
              total: double.tryParse(row[12].toString()) ?? 0,
            )
          ],
          total: double.tryParse(row[12].toString()) ?? 0,
          mode: "CREDIT",
        );
      }
      // Purchase ka logic bhi isi tarah replicate hoga...
    }

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Data Successfully Imported!"), backgroundColor: Colors.green));
    Navigator.pop(context);
  }
}
