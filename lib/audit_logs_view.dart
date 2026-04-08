import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';

class AuditLogsView extends StatelessWidget {
  const AuditLogsView({super.key});

  @override Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final logs = ph.logs.reversed.toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Audit Logs (History)")),
      body: logs.isEmpty 
        ? const Center(child: Text("No actions recorded yet."))
        : ListView.builder(
            itemCount: logs.length,
            itemBuilder: (c, i) {
              final log = logs[i];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                child: ListTile(
                  leading: Icon(
                    log.action == "DELETE" ? Icons.delete_forever : 
                    log.action == "CANCEL" ? Icons.block : Icons.add_circle,
                    color: log.action == "DELETE" ? Colors.red : Colors.blue,
                  ),
                  title: Text(log.action, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${log.details}\n${DateFormat('dd/MM HH:mm').format(log.time)}"),
                  isThreeLine: true,
                ),
              );
            },
          ),
    );
  }
}
