import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'pharoah_date_controller.dart'; // NAYA
import 'app_date_logic.dart'; // NAYA

class VoucherEntryView extends StatefulWidget {
  final String type; // Receipt, Payment, Contra, Expense
  const VoucherEntryView({super.key, required this.type});

  @override State<VoucherEntryView> createState() => _VoucherEntryViewState();
}

class _VoucherEntryViewState extends State<VoucherEntryView> {
  DateTime selectedDate = DateTime.now();
  Party? selectedParty;
  final amountC = TextEditingController();
  final narrationC = TextEditingController();
  String payMode = "Cash";
  String partySearchQuery = "";
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final ph = Provider.of<PharoahManager>(context, listen: false);
      // NAYA: Smart Initial Date according to FY
      setState(() {
        selectedDate = PharoahDateController.getInitialBillDate(ph.currentFY);
      });
      _isInit = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    List<Party> filteredParties = ph.parties.where((p) {
      bool matchesSearch = p.name.toLowerCase().contains(partySearchQuery.toLowerCase());
      if (widget.type == "Receipt") {
        return matchesSearch && (p.group == "Sundry Debtors" || p.name == "CASH");
      } else if (widget.type == "Payment") {
        return matchesSearch && (p.group == "Sundry Creditors");
      }
      return matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: Text("${widget.type} Entry"), 
        backgroundColor: _getThemeColor(), 
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
                // NAYA: Date Tile with FY Locked Picker
                Expanded(child: _infoTile("DATE", AppDateLogic.format(selectedDate), Icons.calendar_today, onTap: () => _pickDate(ph))),
                const SizedBox(width: 15),
                Expanded(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)), child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: payMode, items: ["Cash", "Bank", "UPI", "Cheque"].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(), onChanged: (v) => setState(() => payMode = v!))))),
            ]),
            const SizedBox(height: 25),
            const Text("SELECT ACCOUNT / PARTY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            if (selectedParty == null)
              TextField(decoration: InputDecoration(hintText: "Search Account...", prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)), onChanged: (v) => setState(() => partySearchQuery = v))
            else
              ListTile(tileColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: _getThemeColor())), leading: const Icon(Icons.person, color: Colors.blue), title: Text(selectedParty!.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(selectedParty!.group), trailing: IconButton(icon: const Icon(Icons.cancel, color: Colors.red), onPressed: () => setState(() { selectedParty = null; }))),

            if (selectedParty == null && partySearchQuery.isNotEmpty)
              Container(margin: const EdgeInsets.only(top: 5), constraints: const BoxConstraints(maxHeight: 200), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]), child: ListView.builder(shrinkWrap: true, itemCount: filteredParties.length, itemBuilder: (c, i) => ListTile(title: Text(filteredParties[i].name), subtitle: Text(filteredParties[i].group), onTap: () => setState(() { selectedParty = filteredParties[i]; partySearchQuery = ""; })))),

            const SizedBox(height: 25),
            const Text("TRANSACTION DETAILS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
            const SizedBox(height: 10),
            TextField(controller: amountC, keyboardType: const TextInputType.numberWithOptions(decimal: true), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), decoration: const InputDecoration(labelText: "AMOUNT (₹)", border: OutlineInputBorder(), filled: true, fillColor: Colors.white)),
            const SizedBox(height: 15),
            TextField(controller: narrationC, decoration: const InputDecoration(labelText: "REMARKS / NARRATION", border: OutlineInputBorder(), filled: true, fillColor: Colors.white, hintText: "e.g. Being cash received...")),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: _getThemeColor(), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => _handleSave(ph), child: Text("SAVE ${widget.type.toUpperCase()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
        ]),
      ),
    );
  }

  void _handleSave(PharoahManager ph) {
    if (selectedParty == null || amountC.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Party and enter Amount!")));
      return;
    }
    double amt = double.tryParse(amountC.text) ?? 0;
    if (amt <= 0) return;

    final v = Voucher(id: DateTime.now().toString(), type: widget.type, date: selectedDate, partyId: selectedParty!.id, partyName: selectedParty!.name, amount: amt, paymentMode: payMode, narration: narrationC.text);
    ph.addVoucher(v);
    ph.addLog("ACCOUNTS", "${widget.type} of ₹$amt for ${selectedParty!.name}");
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("✅ ${widget.type} Saved Successfully!"), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  // NAYA: FY Locked Picker Integration
  void _pickDate(PharoahManager ph) async {
    DateTime? p = await PharoahDateController.pickDate(context: context, currentFY: ph.currentFY, initialDate: selectedDate);
    if (p != null) setState(() => selectedDate = p);
  }

  Color _getThemeColor() {
    if (widget.type == "Receipt") return Colors.green.shade700;
    if (widget.type == "Payment") return Colors.red.shade700;
    if (widget.type == "Contra") return Colors.orange.shade800;
    return Colors.brown;
  }

  Widget _infoTile(String l, String v, IconData i, {VoidCallback? onTap}) {
    return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.black12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(l, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)), const SizedBox(height: 4), Row(children: [Icon(i, size: 14, color: Colors.blueGrey), const SizedBox(width: 5), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))])])));
  }
}
