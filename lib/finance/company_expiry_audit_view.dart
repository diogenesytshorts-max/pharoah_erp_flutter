import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../expiry_master.dart';

class CompanyExpiryAuditView extends StatefulWidget {
  const CompanyExpiryAuditView({super.key});
  @override State<CompanyExpiryAuditView> createState() => _CompanyExpiryAuditViewState();
}

class _CompanyExpiryAuditViewState extends State<CompanyExpiryAuditView> {
  Company? selectedCompany;
  String viewMode = "STOCK"; // STOCK or PARTY
  int monthsHorizon = 3; // Default 3 months
  String companySearch = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<Map<String, dynamic>> auditData = [];

    if (selectedCompany != null) {
      auditData = _calculateExpiryData(ph);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFFF5F5), // Light Red tint for Expiry
      appBar: AppBar(
        title: Text(selectedCompany == null ? "Expiry Audit" : "${selectedCompany!.name}"),
        backgroundColor: Colors.red.shade900,
        actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () {})],
      ),
      body: Column(children: [
        _buildTopSelectionHeader(ph),
        if (selectedCompany != null) _buildModeToggle(),
        Expanded(
          child: selectedCompany == null 
            ? _buildCompanyPicker(ph) 
            : _buildAuditList(auditData, ph),
        ),
      ]),
    );
  }

  // ===========================================================================
  // 🧠 CORE LOGIC: EXPIRY & TRACEABILITY ENGINE
  // ===========================================================================
  List<Map<String, dynamic>> _calculateExpiryData(PharoahManager ph) {
    List<Map<String, dynamic>> results = [];
    DateTime threshold = DateTime.now().add(Duration(days: monthsHorizon * 30));

    // 1. Filter medicines by company
    final companyMeds = ph.medicines.where((m) => m.companyId == selectedCompany!.id).toList();

    for (var med in companyMeds) {
      final batches = ph.batchHistory[med.identityKey] ?? [];
      for (var b in batches) {
        if (b.qty <= 0) continue; // Khali batch skip karein

        // Expiry date check
        DateTime? expDate;
        try { expDate = DateFormat('MM/yy').parse(b.exp); } catch (e) { continue; }

        if (expDate.isBefore(threshold)) {
          Map<String, dynamic> entry = {
            'med': med,
            'batch': b,
            'status': expDate.isBefore(DateTime.now()) ? "EXPIRED" : "NEAR",
            'val': b.qty * med.purRate,
          };

          // 🔍 TRACEABILITY LOGIC: Find last supplier
          if (viewMode == "PARTY") {
            try {
              final lastPur = ph.purchases.lastWhere((p) => 
                p.items.any((it) => it.medicineID == med.id && it.batch == b.batch)
              );
              entry['supplier'] = lastPur.distributorName;
              entry['purDate'] = lastPur.date;
              entry['billNo'] = lastPur.billNo;
            } catch (e) {
              entry['supplier'] = "Unknown Source";
            }
          }
          results.add(entry);
        }
      }
    }
    return results;
  }

  // ===========================================================================
  // 🛠️ UI COMPONENTS
  // ===========================================================================

  Widget _buildTopSelectionHeader(PharoahManager ph) => Container(
    padding: const EdgeInsets.all(15), color: Colors.red.shade900,
    child: Column(children: [
      Row(children: [
        Expanded(child: _dropdownLabel("EXPIRY HORIZON")),
        const SizedBox(width: 15),
        Expanded(child: _dropdownLabel("MODE")),
      ]),
      Row(children: [
        Expanded(child: _simpleDropdown([3, 6, 12], (v) => setState(() => monthsHorizon = v!), "${monthsHorizon} Months")),
        const SizedBox(width: 15),
        Expanded(child: _simpleDropdown(["STOCK", "PARTY"], (v) => setState(() => viewMode = v!), viewMode)),
      ]),
    ]),
  );

  Widget _buildCompanyPicker(PharoahManager ph) {
    final list = ph.companies.where((c) => c.name.toLowerCase().contains(companySearch.toLowerCase())).toList();
    return Column(children: [
      Padding(padding: const EdgeInsets.all(15), child: TextField(decoration: const InputDecoration(hintText: "Select Company to start Audit...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder()), onChanged: (v) => setState(() => companySearch = v))),
      Expanded(child: ListView.builder(itemCount: list.length, itemBuilder: (c, i) => ListTile(leading: const Icon(Icons.business), title: Text(list[i].name), onTap: () => setState(() => selectedCompany = list[i]))))
    ]);
  }

  Widget _buildAuditList(List<Map<String, dynamic>> data, PharoahManager ph) {
    if (data.isEmpty) return const Center(child: Text("Great! No expiring stock found."));

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: data.length,
      itemBuilder: (c, i) {
        final row = data[i];
        bool isExp = row['status'] == "EXPIRED";
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: isExp ? Colors.red : Colors.orange, width: 1)),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(row['med'].name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                _badge(row['status'], isExp ? Colors.red : Colors.orange),
              ]),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _info("BATCH", row['batch'].batch),
                _info("EXPIRY", row['batch'].exp),
                _info("STOCK", row['batch'].qty.toStringAsFixed(2)),
                _info("LOSS VAL", "₹${row['val'].toStringAsFixed(0)}", isBold: true),
              ]),
              if (viewMode == "PARTY") ...[
                const Divider(),
                Row(children: [
                  const Icon(Icons.Local_shipping_outlined, size: 14, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Text("FROM: ${row['supplier']}", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const Spacer(),
                  Text("Bill #${row['billNo']}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ])
              ]
            ]),
          ),
        );
      },
    );
  }

  Widget _buildModeToggle() => ListTile(tileColor: Colors.white, title: Text("Selected: ${selectedCompany!.name}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), trailing: TextButton(onPressed: () => setState(() => selectedCompany = null), child: const Text("CHANGE COMPANY")));

  Widget _badge(String t, Color c) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(5)), child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)));
  Widget _info(String l, String v, {bool isBold = false}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 8, color: Colors.grey)), Text(v, style: TextStyle(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.normal))]);
  Widget _dropdownLabel(String t) => Text(t, style: const TextStyle(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold));
  Widget _simpleDropdown(List<dynamic> items, Function(dynamic) onChange, String value) => Container(height: 40, padding: const EdgeInsets.symmetric(horizontal: 10), decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(5)), child: DropdownButtonHideUnderline(child: DropdownButton<dynamic>(dropdownColor: Colors.red.shade900, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), isExpanded: true, value: items.contains(value) ? value : items.first, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(), onChanged: onChange)));
}
