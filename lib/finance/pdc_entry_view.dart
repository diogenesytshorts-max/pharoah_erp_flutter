// FILE: lib/finance/pdc_entry_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../pharoah_manager.dart';
import '../models.dart';
import '../pharoah_date_controller.dart';

class PdcEntryView extends StatefulWidget {
  const PdcEntryView({super.key});

  @override
  State<PdcEntryView> createState() => _PdcEntryViewState();
}

class _PdcEntryViewState extends State<PdcEntryView> {
  // --- CONTROLLERS ---
  final amountC = TextEditingController();
  final chequeNoC = TextEditingController();
  final customerBankC = TextEditingController(); // Kahan ka cheque hai
  
  // --- SELECTIONS ---
  Party? selectedParty;
  Bank? depositBank; // Hamara kaunsa bank account
  DateTime chequeDate = DateTime.now();
  String searchQuery = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("New Cheque / PDC Entry"),
        backgroundColor: Colors.teal.shade800,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. SELECT PARTY ---
            _sectionTitle("PAYMENT RECEIVED FROM (CUSTOMER)"),
            if (selectedParty == null)
              _buildPartySearch(ph)
            else
              _buildSelectedPartyCard(),

            const SizedBox(height: 25),

            // --- 2. CHEQUE DETAILS ---
            _sectionTitle("CHEQUE INFORMATION"),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _input(amountC, "Amount (₹)", Icons.currency_rupee, isNum: true)),
                const SizedBox(width: 10),
                Expanded(child: _input(chequeNoC, "Cheque No.", Icons.numbers)),
              ],
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: _input(customerBankC, "Customer Bank (e.g. SBI)", Icons.account_balance)),
                const SizedBox(width: 10),
                Expanded(child: _dateTile(ph)),
              ],
            ),

            const SizedBox(height: 25),

            // --- 3. DEPOSIT BANK (OUR BANK) ---
            _sectionTitle("SELECT OUR BANK (WHERE TO DEPOSIT)"),
            const SizedBox(height: 10),
            _buildDepositBankDropdown(ph),

            const SizedBox(height: 40),

            // --- SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade800,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => _handleSave(ph),
                child: const Text("SAVE CHEQUE ENTRY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPartySearch(PharoahManager ph) {
    return Column(
      children: [
        TextField(
          decoration: const InputDecoration(hintText: "Search Customer Name...", prefixIcon: Icon(Icons.search), border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
          onChanged: (v) => setState(() => searchQuery = v),
        ),
        Container(
          height: 150,
          margin: const EdgeInsets.only(top: 5),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
          child: ListView(
            children: ph.parties.where((p) => p.group == "Sundry Debtors" && p.name.toLowerCase().contains(searchQuery.toLowerCase())).map((p) => ListTile(
              title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              subtitle: Text(p.city, style: const TextStyle(fontSize: 11)),
              onTap: () => setState(() => selectedParty = p),
            )).toList(),
          ),
        )
      ],
    );
  }

  Widget _buildSelectedPartyCard() {
    return ListTile(
      tileColor: Colors.teal.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.teal.shade200)),
      leading: const CircleAvatar(backgroundColor: Colors.teal, child: Icon(Icons.person, color: Colors.white)),
      title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(selectedParty!.city),
      trailing: IconButton(icon: const Icon(Icons.close, color: Colors.red), onPressed: () => setState(() => selectedParty = null)),
    );
  }

  Widget _buildDepositBankDropdown(PharoahManager ph) {
    return DropdownButtonFormField<Bank>(
      value: depositBank,
      decoration: const InputDecoration(border: OutlineInputBorder(), filled: true, fillColor: Colors.white, prefixIcon: Icon(Icons.account_balance_wallet)),
      hint: const Text("Select Our Bank Account"),
      items: ph.banks.map((b) => DropdownMenuItem(value: b, child: Text("${b.name} (${b.branch})"))).toList(),
      onChanged: (v) => setState(() => depositBank = v),
    );
  }

  Widget _dateTile(PharoahManager ph) {
    return InkWell(
      onTap: () async {
        DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: ph.currentFY, initialDate: chequeDate);
        if (p != null) setState(() => chequeDate = p);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5), color: Colors.white),
        child: Text(DateFormat('dd/MM/yyyy').format(chequeDate), style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _input(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) => TextField(
    controller: ctrl,
    keyboardType: isNum ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder(), filled: true, fillColor: Colors.white),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 4),
    child: Text(t, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1)),
  );

  void _handleSave(PharoahManager ph) {
    if (selectedParty == null || amountC.text.isEmpty || depositBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Missing Party, Amount or Deposit Bank!")));
      return;
    }

    final entry = ChequeEntry(
      id: DateTime.now().toString(),
      partyName: selectedParty!.name,
      amount: double.tryParse(amountC.text) ?? 0,
      chequeNo: chequeNoC.text,
      date: DateTime.now(),
      chequeDate: chequeDate,
      partyBank: customerBankC.text.toUpperCase(),
      depositBank: depositBank!.name,
      status: "Received",
    );

    ph.addCheque(entry);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Cheque Record Saved!"), backgroundColor: Colors.green));
  }
}
