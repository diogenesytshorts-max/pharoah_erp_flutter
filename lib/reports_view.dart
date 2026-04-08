import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'pdf_service.dart';
import 'package:intl/intl.dart';

class ReportsView extends StatelessWidget {
  const ReportsView({super.key});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("Sales Reports")),
      body: ph.sales.isEmpty 
        ? const Center(child: Text("No Sales Record Found"))
        : ListView.builder(
            itemCount: ph.sales.length,
            itemBuilder: (context, index) {
              final sale = ph.sales.reversed.toList()[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  title: Text(sale.billNo, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${sale.partyName}\n${DateFormat('dd/MM/yyyy').format(sale.date)}"),
                  isThreeLine: true,
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("₹${sale.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: () {
                          final party = ph.parties.firstWhere((p) => p.name == sale.partyName, orElse: () => ph.parties[0]);
                          PdfService.generateInvoice(sale, party);
                        },
                        child: const Icon(Icons.print, size: 20, color: Colors.blue),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }
}
