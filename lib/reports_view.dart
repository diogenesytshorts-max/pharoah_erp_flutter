import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'pdf_service.dart';
import 'package:intl/intl.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});
  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = ph.sales.reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text("Sales History")),
      body: list.isEmpty ? const Center(child: Text("No Bills Found")) : ListView.builder(
        itemCount: list.length,
        itemBuilder: (c, i) {
          final s = list[i];
          return Card(margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: ListTile(
            title: Text("Bill: ${s.billNo} | ${s.partyName}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("${DateFormat('dd/MM/yyyy').format(s.date)} | Amount: ₹${s.totalAmount.toStringAsFixed(2)}"),
            trailing: IconButton(icon: const Icon(Icons.print, color: Colors.blue), onPressed: () {
              final p = ph.parties.firstWhere((x)=>x.name == s.partyName, orElse: () => ph.parties[0]);
              PdfService.generateInvoice(s, p);
            }),
          ));
        },
      ),
    );
  }
}
