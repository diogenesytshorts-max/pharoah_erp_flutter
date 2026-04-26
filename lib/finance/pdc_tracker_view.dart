// FILE: lib/finance/pdc_tracker_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';

class PdcTrackerView extends StatefulWidget {
  const PdcTrackerView({super.key});

  @override
  State<PdcTrackerView> createState() => _PdcTrackerViewState();
}

class _PdcTrackerViewState extends State<PdcTrackerView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String searchQuery = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Cheque / PDC Tracker"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: "ACTIVE CHEQUES"),
            Tab(text: "BOUNCED / RETURN"),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- SEARCH BAR ---
          _buildSearchBar(),

          // --- TAB VIEWS ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildChequeList(ph, "Received"), // Active Cheques
                _buildChequeList(ph, "Bounced"),  // History of Bounces
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.indigo.shade900,
      child: TextField(
        style: const TextStyle(color: Colors.white),
        onChanged: (v) => setState(() => searchQuery = v),
        decoration: InputDecoration(
          hintText: "Search by Cheque No or Party...",
          hintStyle: const TextStyle(color: Colors.white60),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          filled: true, fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildChequeList(PharoahManager ph, String statusFilter) {
    final filteredList = ph.cheques.where((c) {
      bool matchesStatus = c.status == statusFilter;
      bool matchesSearch = c.partyName.toLowerCase().contains(searchQuery.toLowerCase()) || 
                           c.chequeNo.contains(searchQuery);
      return matchesStatus && matchesSearch;
    }).toList();

    if (filteredList.isEmpty) {
      return Center(child: Text("No $statusFilter records found.", style: const TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: filteredList.length,
      itemBuilder: (c, i) {
        final ch = filteredList[i];
        bool isOverdue = ch.chequeDate.isBefore(DateTime.now()) && statusFilter == "Received";

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isOverdue ? Colors.red.shade200 : Colors.transparent),
          ),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: statusFilter == "Bounced" ? Colors.red.shade100 : Colors.indigo.shade50,
              child: Icon(
                statusFilter == "Bounced" ? Icons.report_problem : Icons.account_balance_wallet, 
                color: statusFilter == "Bounced" ? Colors.red : Colors.indigo,
                size: 20,
              ),
            ),
            title: Text(ch.partyName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text("Cheque: ${ch.chequeNo} | Date: ${DateFormat('dd/MM/yyyy').format(ch.chequeDate)}", style: const TextStyle(fontSize: 11)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("₹${ch.amount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.indigo)),
                if (isOverdue) const Text("OVERDUE", style: TextStyle(color: Colors.red, fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            ),
            children: [
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(15),
                child: Column(
                  children: [
                    _infoRow("Customer Bank", ch.partyBank),
                    _infoRow("Linked Bill", ch.billNo),
                    _infoRow("Our Deposit Bank", ch.depositBank),
                    if (statusFilter == "Bounced") _infoRow("Bounce Reason", ch.remark, color: Colors.red),
                    const SizedBox(height: 15),
                    if (statusFilter == "Received")
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _handleBounce(ph, ch),
                              icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.red),
                              label: const Text("REPORT BOUNCE", style: TextStyle(color: Colors.red)),
                              style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(String l, String v, {Color? color}) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(l, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      Text(v, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    ]),
  );

  // --- LOGIC: BOUNCE DIALOG ---
  void _handleBounce(PharoahManager ph, ChequeEntry ch) {
    final reasonC = TextEditingController();
    final penaltyC = TextEditingController(text: "0");

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Report Cheque Bounce"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Please enter why this cheque was returned.", style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 15),
            TextField(controller: reasonC, decoration: const InputDecoration(labelText: "Reason (e.g. Sign Mismatch)", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            TextField(controller: penaltyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Add Penalty Charge (₹)", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // 1. Update Cheque Status
              ph.updateChequeStatus(ch.id, "Bounced", reasonC.text.toUpperCase());
              
              // 2. Log Action
              ph.addLog("FINANCE", "Cheque #${ch.chequeNo} Bounced for ${ch.partyName}");

              // 3. (Optional) Penalty logic: Penalty can be added as an Expense/Voucher later
              
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cheque marked as Bounced. Party balance remains active."), backgroundColor: Colors.red));
            },
            child: const Text("MARK BOUNCED", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
