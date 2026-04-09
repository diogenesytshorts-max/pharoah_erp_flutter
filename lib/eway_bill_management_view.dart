import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class EWayBillManagementView extends StatefulWidget {
  const EWayBillManagementView({super.key});
  @override State<EWayBillManagementView> createState() => _EWayBillManagementViewState();
}

class _EWayBillManagementViewState extends State<EWayBillManagementView> {
  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    // Filter bills above ₹50,000
    List<Sale> highValueBills = ph.sales.where((s) => s.totalAmount >= 50000 && s.status == "Active").toList();

    return Scaffold(
      appBar: AppBar(title: const Text("E-Way Bill & E-Invoicing"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: Column(
        children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(15), color: Colors.indigo.shade50,
            child: Text("Total ${highValueBills.length} bills found above ₹50,000 threshold.", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
          ),
          Expanded(
            child: highValueBills.isEmpty 
              ? const Center(child: Text("No high-value bills found."))
              : ListView.builder(
                  itemCount: highValueBills.length,
                  itemBuilder: (c, i) {
                    final s = highValueBills[i];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: ListTile(
                        title: Text(s.partyName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Inv: ${s.billNo} | Amt: ₹${s.totalAmount.toStringAsFixed(2)}"),
                        trailing: ElevatedButton(
                          onPressed: () => _showTransportDialog(context, s),
                          child: const Text("GENERATE JSON"),
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

  void _showTransportDialog(BuildContext context, Sale sale) {
    final tNameC = TextEditingController(text: sale.transporterName);
    final tIdC = TextEditingController(text: sale.transporterId);
    final vNoC = TextEditingController(text: sale.vehicleNo);

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Transport Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: tNameC, decoration: const InputDecoration(labelText: "Transporter Name")),
            TextField(controller: tIdC, decoration: const InputDecoration(labelText: "Transporter ID (GSTIN)")),
            TextField(controller: vNoC, decoration: const InputDecoration(labelText: "Vehicle Number (e.g. RJ14GB1234)")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              // Update Sale Object
              sale.transporterName = tNameC.text;
              sale.transporterId = tIdC.text;
              sale.vehicleNo = vNoC.text;
              Provider.of<PharoahManager>(context, listen: false).save();
              Navigator.pop(c);
              _generatePortalJson(sale);
            }, 
            child: const Text("EXPORT JSON"),
          )
        ],
      ),
    );
  }

  void _generatePortalJson(Sale s) {
    // Standard GST Portal E-Way Bill Schema (Simplified)
    Map<String, dynamic> ewayJson = {
      "version": "1.0.0",
      "billLists": [{
        "userGstin": "YOUR_GSTIN",
        "supplyType": "Outward",
        "subSupplyType": "Supply",
        "docType": "Invoice",
        "docNo": s.billNo,
        "docDate": DateFormat('dd/MM/yyyy').format(s.date),
        "fromGstin": "YOUR_GSTIN",
        "toGstin": s.invoiceType == "B2B" ? "PARTY_GSTIN" : "URP",
        "totalValue": s.totalAmount,
        "transporterId": s.transporterId,
        "transporterName": s.transporterName,
        "vehicleNo": s.vehicleNo,
        "itemList": s.items.map((it) => {
          "itemDesc": it.name,
          "hsnCode": it.hsn,
          "quantity": it.qty,
          "taxableAmount": it.total - (it.cgst + it.sgst + it.igst),
          "gstRate": it.gstRate
        }).toList()
      }]
    };

    String jsonString = const JsonEncoder.withIndent('  ').convert(ewayJson);
    Share.share(jsonString, subject: 'E-Way Bill JSON - ${s.billNo}');
  }
}
