import 'package:flutter/material.dart';
import 'models.dart';

class ImportResolver {
  // --- NAYI PARTY BANANE KA DIALOG ---
  static Future<Party?> showPartyFixer(BuildContext context, String name, String gstin) async {
    final nameC = TextEditingController(text: name);
    final gstC = TextEditingController(text: gstin);
    final cityC = TextEditingController();

    return showDialog<Party>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("New Party Detected", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Yeh party aapke system mein nahi hai. Details check karke save karein.", style: TextStyle(fontSize: 12)),
            const SizedBox(height: 15),
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Party Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            TextField(controller: cityC, decoration: const InputDecoration(labelText: "City", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c, Party(
                id: DateTime.now().toString(),
                name: nameC.text.toUpperCase(),
                gst: gstC.text.isEmpty ? "N/A" : gstC.text.toUpperCase(),
                city: cityC.text.toUpperCase(),
              ));
            },
            child: const Text("SAVE & LINK"),
          )
        ],
      ),
    );
  }

  // --- NAYA PRODUCT BANANE KA DIALOG ---
  static Future<Medicine?> showItemFixer(BuildContext context, String name, double rate, double gst) async {
    final nameC = TextEditingController(text: name);
    final rateC = TextEditingController(text: rate.toString());
    final hsnC = TextEditingController();

    return showDialog<Medicine>(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        title: const Text("New Product Detected", style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Medicine Name", border: OutlineInputBorder())),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: TextField(controller: rateC, decoration: const InputDecoration(labelText: "Rate", border: OutlineInputBorder()))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: hsnC, decoration: const InputDecoration(labelText: "HSN", border: OutlineInputBorder()))),
            ]),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(c, Medicine(
                id: DateTime.now().toString(),
                name: nameC.text.toUpperCase(),
                packing: "N/A",
                mrp: rate * 1.2,
                rateA: rate, rateB: rate, rateC: rate,
                purRate: rate,
                gst: gst,
                hsnCode: hsnC.text.isEmpty ? "N/A" : hsnC.text,
              ));
            },
            child: const Text("CREATE PRODUCT"),
          )
        ],
      ),
    );
  }
}
