// FILE: lib/export_selector_view.dart

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_saver/file_saver.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'csv_engine.dart';

class ExportSelectorView extends StatefulWidget {
  final String exportType; 
  const ExportSelectorView({super.key, required this.exportType});

  @override State<ExportSelectorView> createState() => _ExportSelectorViewState();
}

class _ExportSelectorViewState extends State<ExportSelectorView> {
  String partySearch = "";
  List<String> selectedIds = [];
  Party? targetParty;

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<dynamic> source = widget.exportType == "SALE" ? ph.sales : ph.purchases;
    // Sirf Active bills hi export karein
    if (widget.exportType == "SALE") {
      source = source.where((s) => s.status == "Active").toList();
    }
    source = source.reversed.toList();

    List<dynamic> filtered = source.where((b) {
      String pName = widget.exportType == "SALE" ? (b as Sale).partyName : (b as Purchase).distributorName;
      return targetParty == null || pName == targetParty!.name;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("Select ${widget.exportType} Bills"), 
        backgroundColor: Colors.indigo.shade800, 
        foregroundColor: Colors.white
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(15), color: Colors.white,
          child: targetParty == null 
            ? TextField(
                decoration: const InputDecoration(
                  hintText: "Search Party/Supplier...", 
                  prefixIcon: Icon(Icons.person_search), 
                  border: OutlineInputBorder()
                ), 
                onChanged: (v) => setState(() => partySearch = v)
              )
            : ListTile(
                tileColor: Colors.indigo.shade50, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)), 
                leading: const Icon(Icons.person, color: Colors.indigo), 
                title: Text(targetParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)), 
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red), 
                  onPressed: () => setState(() { targetParty = null; selectedIds.clear(); })
                )
              ),
        ),
        if (targetParty == null && partySearch.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 150), 
            color: Colors.white, 
            child: ListView(
              shrinkWrap: true, 
              children: ph.parties.where((p) => p.name.toLowerCase().contains(partySearch.toLowerCase())).map((p) => ListTile(
                title: Text(p.name), 
                onTap: () => setState(() { targetParty = p; partySearch = ""; })
              )).toList()
            )
          ),

        if (filtered.isNotEmpty) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5), 
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text("${filtered.length} Bills Available", style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
            TextButton(
              onPressed: () => setState(() => selectedIds.length == filtered.length ? selectedIds.clear() : selectedIds = filtered.map((e) => e.id as String).toList()), 
              child: Text(selectedIds.length == filtered.length ? "UNSELECT ALL" : "SELECT ALL")
            ),
          ])
        ),

        Expanded(child: ListView.builder(
          itemCount: filtered.length, 
          itemBuilder: (c, i) {
            final b = filtered[i];
            final isSel = selectedIds.contains(b.id);
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), 
              child: CheckboxListTile(
                activeColor: Colors.indigo, 
                value: isSel, 
                title: Text(widget.exportType == "SALE" ? (b as Sale).partyName : (b as Purchase).distributorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)), 
                subtitle: Text("No: ${b.billNo} | Date: ${DateFormat('dd/MM/yy').format(b.date)}"), 
                secondary: Text("₹${b.totalAmount.toStringAsFixed(0)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
