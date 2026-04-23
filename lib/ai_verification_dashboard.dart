import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'purchase/purchase_billing_view.dart';
import 'billing_view.dart';
import 'party_master.dart';

class AiVerificationDashboard extends StatefulWidget {
  final List<File> images;
  final Map<String, dynamic> aiData;
  final String mode; // "PURCHASE" or "SALE"

  const AiVerificationDashboard({
    super.key,
    required this.images,
    required this.aiData,
    required this.mode,
  });

  @override
  State<AiVerificationDashboard> createState() => _AiVerificationDashboardState();
}

class _AiVerificationDashboardState extends State<AiVerificationDashboard> {
  late TextEditingController billNoC;
  late TextEditingController partyNameC;
  Party? matchedParty;
  List<dynamic> extractedItems = [];

  @override
  void initState() {
    super.initState();
    // AI se aaya hua data controllers mein daalna
    billNoC = TextEditingController(text: widget.aiData['billNo'] ?? "");
    partyNameC = TextEditingController(text: widget.aiData['partyName'] ?? "");
    if (widget.aiData['items'] != null) {
      extractedItems = widget.aiData['items'];
    }
    
    // Auto-match Party (Agar AI ne jo naam nikala wo master me hua to auto-select ho jayega)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _attemptPartyMatch();
    });
  }

  void _attemptPartyMatch() {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    String aiParty = partyNameC.text.trim().toLowerCase();
    
    try {
      matchedParty = ph.parties.firstWhere((p) => p.name.toLowerCase() == aiParty);
      setState(() {});
    } catch (e) {
      matchedParty = null;
    }
  }

  void _proceedToBilling() {
    if (matchedParty == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select or create a Party first!"), backgroundColor: Colors.orange));
      return;
    }

    final ph = Provider.of<PharoahManager>(context, listen: false);
    
    if (widget.mode == "PURCHASE") {
      // Create Dummy Items from AI data (to be edited in final screen)
      List<PurchaseItem> pItems = extractedItems.asMap().entries.map((e) {
        var it = e.value;
        return PurchaseItem(
          id: DateTime.now().toString(), srNo: e.key + 1, medicineID: "temp",
          name: it['name'] ?? "Unknown Item", packing: "N/A", batch: "NA", exp: "12/99", hsn: "0000",
          mrp: 0, qty: (it['qty'] ?? 1).toDouble(), purchaseRate: (it['rate'] ?? 0).toDouble(),
          gstRate: 12, total: (it['total'] ?? 0).toDouble()
        );
      }).toList();

      String intNo = "PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}";

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => PurchaseBillingView(
        distributor: matchedParty!, internalNo: intNo, distBillNo: billNoC.text,
        billDate: DateTime.now(), entryDate: DateTime.now(), mode: "CREDIT",
        existingItems: pItems, // AI Items pre-filled!
      )));
    } else {
      // Same logic for SALE
      List<BillItem> sItems = extractedItems.asMap().entries.map((e) {
        var it = e.value;
        return BillItem(
          id: DateTime.now().toString(), srNo: e.key + 1, medicineID: "temp",
          name: it['name'] ?? "Unknown Item", packing: "N/A", batch: "NA", exp: "12/99", hsn: "0000",
          mrp: 0, qty: (it['qty'] ?? 1).toDouble(), rate: (it['rate'] ?? 0).toDouble(),
          gstRate: 12, total: (it['total'] ?? 0).toDouble()
        );
      }).toList();

      Navigator.pushReplacement(context, MaterialPageRoute(builder: (c) => BillingView(
        party: matchedParty!, billNo: billNoC.text, billDate: DateTime.now(), mode: "CASH",
        existingItems: sItems,
      )));
    }
  }

  @override
  Widget build(BuildContext context) {
    Color themeColor = widget.mode == "PURCHASE" ? Colors.orange.shade800 : Colors.blue.shade900;
    bool isOffline = widget.aiData['status'] == "OFFLINE";

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text("Verify AI Data"), backgroundColor: themeColor, foregroundColor: Colors.white),
      body: Column(
        children: [
          // 1. IMAGE PREVIEW (Horizontal scroll if multiple)
          Container(
            height: 150, color: Colors.black,
            child: ListView.builder(
              scrollDirection: Axis.horizontal, itemCount: widget.images.length,
              itemBuilder: (c, i) => Padding(
                padding: const EdgeInsets.all(8.0),
                child: Image.file(widget.images[i], fit: BoxFit.contain),
              ),
            ),
          ),

          // 2. AI STATUS ALERT
          Container(
            padding: const EdgeInsets.all(10), color: isOffline ? Colors.orange.shade100 : Colors.green.shade100,
            child: Row(children: [
              Icon(isOffline ? Icons.warning_amber : Icons.check_circle, color: isOffline ? Colors.orange : Colors.green),
              const SizedBox(width: 10),
              Expanded(child: Text(widget.aiData['message'] ?? "", style: TextStyle(fontWeight: FontWeight.bold, color: isOffline ? Colors.orange.shade900 : Colors.green.shade900, fontSize: 12))),
            ]),
          ),

          // 3. DATA VERIFICATION FORM
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("HEADER DETAILS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 10),
                  TextField(controller: billNoC, decoration: const InputDecoration(labelText: "Bill / Invoice No", border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
                  const SizedBox(height: 15),

                  // SMART PARTY MAPPING
                  Container(
                    padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: matchedParty != null ? Colors.green : Colors.red)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text("Extracted Party: ${partyNameC.text}", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(height: 5),
                      matchedParty != null 
                        ? Row(children: [const Icon(Icons.check_circle, color: Colors.green), const SizedBox(width: 10), Text("Matched: ${matchedParty!.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))])
                        : ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade50, foregroundColor: Colors.red),
                            icon: const Icon(Icons.add_business), label: const Text("PARTY NOT FOUND - CREATE NEW"),
                            onPressed: () async {
                              final res = await Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView(isSelectionMode: true)));
                              if (res != null && res is Party) setState(() { matchedParty = res; partyNameC.text = res.name; });
                            },
                          )
                    ]),
                  ),

                  const SizedBox(height: 25),
                  Text("EXTRACTED ITEMS (${extractedItems.length})", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  
                  // ITEMS LIST OR OFFLINE RAW TEXT
                  isOffline 
                  ? Container(
                      margin: const EdgeInsets.top: 10, padding: const EdgeInsets.all(15), color: Colors.yellow.shade50,
                      child: Text(widget.aiData['raw_text'] ?? "No text found", style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                    )
                  : ListView.builder(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      itemCount: extractedItems.length,
                      itemBuilder: (c, i) {
                        var it = extractedItems[i];
                        return Card(child: ListTile(
                          title: Text(it['name'] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Qty: ${it['qty']} | Rate: ₹${it['rate']}"),
                          trailing: Text("₹${it['total']}", style: TextStyle(fontWeight: FontWeight.bold, color: themeColor)),
                        ));
                      },
                    )
                ],
              ),
            ),
          ),

          // 4. PROCEED BUTTON
          Container(
            padding: const EdgeInsets.all(20), decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)]),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: themeColor, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 55)),
              onPressed: _proceedToBilling,
              child: const Text("CONFIRM & SEND TO ERP", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }
}
