import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class VoucherEntryView extends StatefulWidget {
  final String type; // 'Receipt' or 'Payment'
  const VoucherEntryView({super.key, required this.type});

  @override State<VoucherEntryView> createState() => _VoucherEntryViewState();
}

class _VoucherEntryViewState extends State<VoucherEntryView> {
  DateTime selectedDate = DateTime.now();
  Party? selectedParty;
  dynamic selectedBill; // Can be Sale or Purchase
  final amountC = TextEditingController();
  final narrationC = TextEditingController();
  String payMode = "Cash";
  bool isAgainstBill = false;
  String partySearchQuery = "";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // Filter Ledgers based on Voucher Type
    List<Party> filteredParties = ph.parties.where((p) {
      bool matchesSearch = p.name.toLowerCase().contains(partySearchQuery.toLowerCase());
      if (widget.type == "Receipt") {
        return matchesSearch && (p.accountGroup == "Sundry Debtors" || p.name == "CASH");
      } else {
        return matchesSearch && (p.accountGroup == "Sundry Creditors" || p.accountGroup == "Expenses");
      }
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text(widget.type == "Receipt" ? "Receipt (Cash In)" : "Payment (Cash Out)"),
        backgroundColor: widget.type == "Receipt" ? Colors.green.shade700 : Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- HEADER: DATE & MODE ---
            Row(
              children: [
                Expanded(child: _infoTile("DATE", DateFormat('dd/MM/yyyy').format(selectedDate), Icons.calendar_today, onTap: _pickDate)),
                const SizedBox(width: 15),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: payMode,
                        items: ["Cash", "Bank", "UPI", "Cheque"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                        onChanged: (v) => setState(() => payMode = v!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // --- LEDGER SELECTION ---
            const Text("SELECT ACCOUNT / PARTY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            if (selectedParty == null)
              TextField(
                decoration: InputDecoration(hintText: "Search Ledger...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                onChanged: (v) => setState(() => partySearchQuery = v),
              )
            else
              ListTile(
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.blue)),
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(selectedParty!.accountGroup),
                trailing: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() { selectedParty = null; selectedBill = null; isAgainstBill = false; })),
              ),

            if (selectedParty == null && partySearchQuery.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: ListView(
                  shrinkWrap: true,
                  children: filteredParties.map((p) => ListTile(
                    title: Text(p.name),
                    subtitle: Text(p.accountGroup),
                    onTap: () => setState(() { selectedParty = p; partySearchQuery = ""; }),
                  )).toList(),
                ),
              ),

            const SizedBox(height: 25),

            // --- AGAINST BILL LOGIC ---
            if (selectedParty != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("ADJUST AGAINST BILL?", style: TextStyle(fontWeight: FontWeight.bold)),
                  Switch(value: isAgainstBill, onChanged: (v) => setState(() { isAgainstBill = v; selectedBill = null; amountC.clear(); })),
                ],
              ),
              if (isAgainstBill) _buildPendingBillsList(ph),
            ],

            const SizedBox(height: 20),

            // --- AMOUNT & NARRATION ---
            TextField(
              controller: amountC,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(labelText: "AMOUNT (₹)", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: narrationC,
              decoration: const InputDecoration(labelText: "NARRATION / REMARKS", border: OutlineInputBorder(), filled: true, fillColor: Colors.white),
            ),
            
            const SizedBox(height: 30),
            
            // --- SAVE BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.type == "Receipt" ? Colors.green.shade700 : Colors.red.shade700,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
                onPressed: () => _handleSave(ph),
                child: Text("SAVE ${widget.type.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPendingBillsList(PharoahManager ph) {
    // Get pending invoices for this party
    List<dynamic> pending;
    if (widget.type == "Receipt") {
      pending = ph.sales.where((s) => s.partyName == selectedParty!.name && s.pendingAmount > 0 && s.status == "Active").toList();
    } else {
      pending = ph.purchases.where((p) => p.distributorName == selectedParty!.name && p.pendingAmount > 0).toList();
    }

    if (pending.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Text("No pending bills found for this party.", style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic, fontSize: 12)),
      );
    }

    return Column(
      children: pending.map((bill) {
        bool isSelected = selectedBill?.id == bill.id;
        return Card(
          color: isSelected ? Colors.blue.shade50 : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isSelected ? Colors.blue : Colors.black12)),
          child: ListTile(
            title: Text("Bill: ${bill.billNo} | Date: ${DateFormat('dd/MM/yy').format(bill.date)}"),
            subtitle: Text("Total: ₹${bill.totalAmount} | Pending: ₹${bill.pendingAmount}"),
            onTap: () {
              setState(() {
                selectedBill = bill;
                amountC.text = bill.pendingAmount.toString();
              });
            },
          ),
        );
      }).toList(),
    );
  }

  void _handleSave(PharoahManager ph) {
    if (selectedParty == null || amountC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Party and enter Amount!")));
      return;
    }

    double amt = double.tryParse(amountC.text) ?? 0;
    if (amt <= 0) return;

    // Safety check for Against Bill
    if (isAgainstBill && selectedBill == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a Bill to adjust!")));
      return;
    }

    final v = Voucher(
      id: DateTime.now().toString(),
      type: widget.type,
      date: selectedDate,
      partyId: selectedParty!.id,
      partyName: selectedParty!.name,
      amount: amt,
      paymentMode: payMode,
      narration: narrationC.text,
      isAgainstBill: isAgainstBill,
      refBillId: selectedBill?.id ?? "",
      refBillNo: selectedBill?.billNo ?? "",
    );

    ph.addVoucher(v);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ${widget.type} Saved Successfully!"), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  void _pickDate() async {
    DateTime? p = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (p != null) setState(() => selectedDate = p);
  }

  Widget _infoTile(String l, String v, IconData i, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Row(children: [Icon(i, size: 14, color: Colors.blueGrey), const SizedBox(width: 5), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]),
          ],
        ),
      ),
    );
  }
}
