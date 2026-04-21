import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class LedgerReportsView extends StatefulWidget {
  const LedgerReportsView({super.key});
  @override State<LedgerReportsView> createState() => _LedgerReportsViewState();
}

class _LedgerReportsViewState extends State<LedgerReportsView> {
  String searchQuery = "";
  String filterGroup = "ALL";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // 1. Calculate Balances for all parties
    List<Map<String, dynamic>> ledgerSummaries = [];
    double totalReceivable = 0;
    double totalPayable = 0;

    for (var party in ph.parties) {
      if (party.accountGroup == "Bank Accounts") continue; // Skip banks

      double balance = _calculateNetBalance(ph, party);
      
      // Filter: Sirf non-zero balance wali parties dikhayein
      if (balance.abs() > 0.01) {
        if (balance > 0) totalReceivable += balance; else totalPayable += balance.abs();

        ledgerSummaries.add({
          'party': party,
          'balance': balance,
          'type': balance > 0 ? "Dr" : "Cr"
        });
      }
    }

    // Filter by search and group
    var filteredList = ledgerSummaries.where((item) {
      Party p = item['party'];
      bool matchesSearch = p.name.toLowerCase().contains(searchQuery.toLowerCase());
      bool matchesGroup = filterGroup == "ALL" || p.accountGroup.toUpperCase().contains(filterGroup);
      return matchesSearch && matchesGroup;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Khaata (Ledger Reports)"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- TOP SUMMARY TILES ---
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.indigo.shade900,
            child: Row(
              children: [
                _summaryBox("RECEIVABLE (Dr)", totalReceivable, Colors.greenAccent),
                const SizedBox(width: 10),
                _summaryBox("PAYABLE (Cr)", totalPayable, Colors.orangeAccent),
              ],
            ),
          ),

          // --- FILTERS ---
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search Party Name...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: EdgeInsets.zero
                  ),
                  onChanged: (v) => setState(() => searchQuery = v),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _choiceChip("ALL"),
                      _choiceChip("DEBTORS"),
                      _choiceChip("CREDITORS"),
                      _choiceChip("EXPENSES"),
                    ],
                  ),
                )
              ],
            ),
          ),

          // --- MAIN LIST ---
          Expanded(
            child: filteredList.isEmpty
                ? const Center(child: Text("No active balances found."))
                : ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (c, i) {
                      final item = filteredList[i];
                      final Party p = item['party'];
                      final double bal = item['balance'];
                      final String type = item['type'];

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        child: ListTile(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => SingleLedgerDetailView(party: p))),
                          leading: CircleAvatar(
                            backgroundColor: type == "Dr" ? Colors.green.shade50 : Colors.red.shade50,
                            child: Icon(type == "Dr" ? Icons.arrow_downward : Icons.arrow_upward, color: type == "Dr" ? Colors.green : Colors.red, size: 20),
                          ),
                          title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(p.accountGroup, style: const TextStyle(fontSize: 11)),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text("₹${bal.abs().toStringAsFixed(2)}", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: type == "Dr" ? Colors.green.shade700 : Colors.red.shade700)),
                              Text(type == "Dr" ? "RECEIVE" : "PAY", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: type == "Dr" ? Colors.green : Colors.red)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          )
        ],
      ),
    );
  }

  double _calculateNetBalance(PharoahManager ph, Party p) {
    // Start with Opening Balance
    double total = p.balanceType == "Debit" ? p.openingBalance : -p.openingBalance;

    // Add Sales (Debit for Debtors)
    for (var s in ph.sales.where((s) => s.partyName == p.name && s.status == "Active")) {
      total += s.totalAmount;
    }

    // Add Purchases (Credit for Creditors)
    for (var pur in ph.purchases.where((pur) => pur.distributorName == p.name)) {
      total -= pur.totalAmount;
    }

    // Add Vouchers
    for (var v in ph.vouchers.where((v) => v.partyName == p.name)) {
      if (v.type == "Receipt") total -= v.amount;
      else if (v.type == "Payment") total += v.amount;
    }

    return total;
  }

  Widget _summaryBox(String label, double val, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text("₹${val.toStringAsFixed(0)}", style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _choiceChip(String label) {
    bool isSelected = filterGroup == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 11)),
        selected: isSelected,
        onSelected: (v) => setState(() => filterGroup = label),
        selectedColor: Colors.indigo,
      ),
    );
  }
}

// ==========================================
// SCREEN 2: SINGLE PARTY DETAIL VIEW
// ==========================================
class SingleLedgerDetailView extends StatelessWidget {
  final Party party;
  const SingleLedgerDetailView({super.key, required this.party});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    List<Map<String, dynamic>> history = [];

    // Add Opening Balance
    double runningBal = party.balanceType == "Debit" ? party.openingBalance : -party.openingBalance;
    history.add({'date': DateTime(2024), 'desc': "Opening Balance", 'type': "OP", 'dr': party.balanceType == "Debit" ? party.openingBalance : 0.0, 'cr': party.balanceType == "Credit" ? party.openingBalance : 0.0, 'bal': runningBal});

    // Collect all transactions
    for (var s in ph.sales.where((s) => s.partyName == party.name && s.status == "Active")) {
      history.add({'date': s.date, 'desc': "Sale Inv #${s.billNo}", 'type': "SALE", 'dr': s.totalAmount, 'cr': 0.0});
    }
    for (var pur in ph.purchases.where((pur) => pur.distributorName == party.name)) {
      history.add({'date': pur.date, 'desc': "Pur Bill #${pur.billNo}", 'type': "PUR", 'dr': 0.0, 'cr': pur.totalAmount});
    }
    for (var v in ph.vouchers.where((v) => v.partyName == party.name)) {
      history.add({'date': v.date, 'desc': "${v.type} (${v.paymentMode}) ${v.refBillNo.isNotEmpty ? 'Agst ${v.refBillNo}' : ''}", 'type': "VOUC", 'dr': v.type == "Payment" ? v.amount : 0.0, 'cr': v.type == "Receipt" ? v.amount : 0.0});
    }

    // Sort by Date
    history.sort((a, b) => a['date'].compareTo(b['date']));

    // Re-calculate Running Balance
    double currentRunning = 0;
    for (int i = 0; i < history.length; i++) {
      if (i == 0) {
        currentRunning = history[i]['bal'];
      } else {
        currentRunning += (history[i]['dr'] - history[i]['cr']);
        history[i]['bal'] = currentRunning;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(party.name),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () => _shareReminder(party, currentRunning)),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.indigo.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("CURRENT BALANCE:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                Text(
                  "₹${currentRunning.abs().toStringAsFixed(2)} ${currentRunning >= 0 ? 'Dr' : 'Cr'}",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: currentRunning >= 0 ? Colors.green : Colors.red),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: history.length,
              itemBuilder: (c, i) {
                final tr = history[i];
                return Container(
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.grey.shade200))),
                  child: ListTile(
                    dense: true,
                    title: Row(
                      children: [
                        Text(DateFormat('dd/MM/yy').format(tr['date']), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(tr['desc'], style: const TextStyle(fontWeight: FontWeight.w500))),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("In: ₹${tr['dr']}", style: TextStyle(color: Colors.green.shade700, fontSize: 11)),
                          Text("Out: ₹${tr['cr']}", style: TextStyle(color: Colors.red.shade700, fontSize: 11)),
                          Text("Bal: ₹${tr['bal'].abs().toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  void _shareReminder(Party p, double bal) {
    String msg = "Hello ${p.name}, this is a reminder regarding your outstanding balance of Rs. ${bal.abs().toStringAsFixed(2)} ${bal > 0 ? 'Debit' : 'Credit'} with PHAROAH ERP. Please arrange payment at the earliest.";
    Share.share(msg);
  }
}
