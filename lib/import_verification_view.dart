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

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    int readyCount = processedRows.where((r) => r['status'] == "READY").length;

    return Scaffold(
      appBar: AppBar(
        title: Text("Verify ${widget.importType}"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          if (readyCount == processedRows.length && processedRows.isNotEmpty)
            IconButton(icon: const Icon(Icons.save_alt), onPressed: () => _finalizeImport(ph))
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
              Text("Verified: $readyCount / ${processedRows.length}", style: const TextStyle(fontWeight: FontWeight.bold))
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
                    subtitle: Text("Item: ${d[5]} | Qty: ${d[9]} | Total: ₹${d[12]}"),
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
      Party? p = await ImportResolver.showPartyFixer(context, rowData[2].toString(), rowData[3].toString());
      if (p != null) { ph.parties.add(p); ph.save(); _initializeImport(); }
    } else if (!processedRows[index]['itemOk']) {
      Medicine? m = await ImportResolver.showItemFixer(context, rowData[5].toString(), double.tryParse(rowData[10].toString()) ?? 0, 12);
      if (m != null) { ph.medicines.add(m); ph.save(); _initializeImport(); }
    }
  }

  void _finalizeImport(PharoahManager ph) {
    for (var r in processedRows) {
      var d = r['data'];
      DateTime dt = DateFormat('dd/MM/yyyy').parse(d[0].toString());
      
      if (widget.importType == "SALE") {
        ph.finalizeSale(
          billNo: d[1].toString(),
          date: dt,
          party: ph.parties.firstWhere((p) => p.name.toUpperCase() == d[2].toString().toUpperCase()),
          items: [BillItem(id: DateTime.now().toString(), srNo: 1, medicineID: ph.medicines.firstWhere((m) => m.name.toUpperCase() == d[5].toString().toUpperCase()).id, name: d[5].toString(), packing: "N/A", batch: d[6].toString(), exp: d[7].toString(), hsn: d[8].toString(), mrp: double.tryParse(d[10].toString()) ?? 0, qty: double.tryParse(d[9].toString()) ?? 0, rate: double.tryParse(d[10].toString()) ?? 0, gstRate: double.tryParse(d[11].toString()) ?? 0, total: double.tryParse(d[12].toString()) ?? 0)],
          total: double.tryParse(d[12].toString()) ?? 0,
          mode: "CREDIT"
        );
      }
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Import Successful!"), backgroundColor: Colors.green));
  }
}
