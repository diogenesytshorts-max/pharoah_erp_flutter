import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'pharoah_manager.dart';
import 'models.dart';

class PartyMasterView extends StatefulWidget {
  const PartyMasterView({super.key});

  @override
  State<PartyMasterView> createState() => _PartyMasterViewState();
}

class _PartyMasterViewState extends State<PartyMasterView> {
  String search = "";

  final List<String> states = [
    "Andhra Pradesh", "Arunachal Pradesh", "Assam", "Bihar", "Chhattisgarh", 
    "Goa", "Gujarat", "Haryana", "Himachal Pradesh", "Jharkhand", "Karnataka", 
    "Kerala", "Madhya Pradesh", "Maharashtra", "Manipur", "Meghalaya", "Mizoram", 
    "Nagaland", "Odisha", "Punjab", "Rajasthan", "Sikkim", "Tamil Nadu", 
    "Telangana", "Tripura", "Uttar Pradesh", "Uttarakhand", "West Bengal"
  ];

  final List<String> accountGroups = [
    "Sundry Debtors",
    "Sundry Creditors",
    "Cash in Hand",
    "Bank Accounts",
    "Expenses"
  ];

  // --- LEDGER FORM (ADD / EDIT) ---
  void _showForm({Party? party}) {
    final ph = Provider.of<PharoahManager>(context, listen: false);

    final nameC = TextEditingController(text: party?.name ?? "");
    final phoneC = TextEditingController(text: party?.phone ?? "");
    final addrC = TextEditingController(text: party?.address ?? "");
    final cityC = TextEditingController(text: party?.city ?? "");
    final gstC = TextEditingController(text: party?.gst ?? "");
    final dlC = TextEditingController(text: party?.dl ?? "");
    final emailC = TextEditingController(text: party?.email ?? "");
    final hsnC = TextEditingController(text: party?.hsnCode ?? "");
    final opBalC = TextEditingController(text: party?.openingBalance.toString() ?? "0.0");
    final limitC = TextEditingController(text: party?.creditLimit.toString() ?? "0.0");

    String selectedState = party?.state ?? ph.companyState;
    String selectedGroup = party?.accountGroup ?? "Sundry Debtors";
    String balType = party?.balanceType ?? "Debit";
    String ctrlMode = party?.creditControlMode ?? "Soft";
    DateTime? dlExpiryDate = (party?.dlExpiry != null && party!.dlExpiry.isNotEmpty) 
        ? DateFormat('dd/MM/yyyy').parse(party.dlExpiry) : null;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(party == null ? "Create New Ledger" : "Update Ledger Details"),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.95,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // --- ACCOUNT GROUP & NAME ---
                  _sectionHeader("BASIC ACCOUNT INFO"),
                  DropdownButtonFormField<String>(
                    value: selectedGroup,
                    decoration: const InputDecoration(labelText: "Account Group", border: OutlineInputBorder()),
                    items: accountGroups.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setDialogState(() => selectedGroup = v!),
                  ),
                  const SizedBox(height: 12),
                  _inputField(nameC, "Ledger / Firm Name", Icons.business),

                  // --- FINANCIALS ---
                  _sectionHeader("FINANCIAL SETTINGS"),
                  Row(
                    children: [
                      Expanded(child: _inputField(opBalC, "Opening Balance", Icons.account_balance_wallet, isNum: true)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'Debit', label: Text('Dr')),
                            ButtonSegment(value: 'Credit', label: Text('Cr')),
                          ],
                          selected: {balType},
                          onSelectionChanged: (v) => setDialogState(() => balType = v.first),
                        ),
                      ),
                    ],
                  ),

                  if (selectedGroup == "Sundry Debtors") ...[
                    Row(
                      children: [
                        Expanded(child: _inputField(limitC, "Credit Limit", Icons.speed, isNum: true)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: ctrlMode,
                            decoration: const InputDecoration(labelText: "Control", border: OutlineInputBorder()),
                            items: const [
                              DropdownMenuItem(value: 'Soft', child: Text("Soft (Warn)")),
                              DropdownMenuItem(value: 'Hard', child: Text("Hard (Block)")),
                            ],
                            onChanged: (v) => setDialogState(() => ctrlMode = v!),
                          ),
                        ),
                      ],
                    ),
                  ],

                  // --- COMPLIANCE ---
                  _sectionHeader("REGULATORY & CONTACT"),
                  _inputField(gstC, "GSTIN Number", Icons.receipt_long),
                  if (selectedGroup == "Expenses") _inputField(hsnC, "HSN / SAC Code", Icons.grid_on),
                  
                  Row(
                    children: [
                      Expanded(child: _inputField(dlC, "Drug License", Icons.medical_services)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () async {
                            DateTime? picked = await showDatePicker(
                              context: context, initialDate: dlExpiryDate ?? DateTime.now(),
                              firstDate: DateTime(2020), lastDate: DateTime(2040),
                              helpText: "DL EXPIRY DATE"
                            );
                            if (picked != null) setDialogState(() => dlExpiryDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
                            child: Text(dlExpiryDate == null ? "DL Expiry" : DateFormat('dd/MM/yy').format(dlExpiryDate!), style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),

                  DropdownButtonFormField<String>(
                    value: selectedState,
                    decoration: const InputDecoration(labelText: "State", border: OutlineInputBorder()),
                    items: states.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
                    onChanged: (v) => setDialogState(() => selectedState = v!),
                  ),
                  const SizedBox(height: 10),
                  _inputField(addrC, "Full Address", Icons.location_on),
                  Row(
                    children: [
                      Expanded(child: _inputField(phoneC, "Mobile", Icons.phone, isNum: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _inputField(emailC, "Email", Icons.email)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
              onPressed: () {
                if (nameC.text.trim().isEmpty) return;

                final p = Party(
                  id: party?.id ?? DateTime.now().toString(),
                  name: nameC.text.trim().toUpperCase(),
                  accountGroup: selectedGroup,
                  openingBalance: double.tryParse(opBalC.text) ?? 0.0,
                  balanceType: balType,
                  creditLimit: double.tryParse(limitC.text) ?? 0.0,
                  creditControlMode: ctrlMode,
                  gst: gstC.text.trim().isEmpty ? "N/A" : gstC.text.trim().toUpperCase(),
                  dl: dlC.text.trim().isEmpty ? "N/A" : dlC.text.trim().toUpperCase(),
                  dlExpiry: dlExpiryDate != null ? DateFormat('dd/MM/yyyy').format(dlExpiryDate!) : "",
                  hsnCode: hsnC.text.trim().isEmpty ? "N/A" : hsnC.text.trim().toUpperCase(),
                  state: selectedState,
                  city: cityC.text.trim().toUpperCase(),
                  address: addrC.text.trim(),
                  phone: phoneC.text.trim(),
                  email: emailC.text.trim().toLowerCase(),
                );

                if (party == null) ph.parties.add(p);
                else {
                  int idx = ph.parties.indexWhere((x) => x.id == party.id);
                  if (idx != -1) ph.parties[idx] = p;
                }
                ph.save();
                Navigator.pop(c);
              },
              child: const Text("SAVE LEDGER"),
            ),
          ],
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    
    // FILTER: Show everything EXCEPT Bank Accounts
    final filteredList = ph.parties
        .where((p) => p.accountGroup != "Bank Accounts")
        .where((p) => p.name.toLowerCase().contains(search.toLowerCase()) || p.accountGroup.toLowerCase().contains(search.toLowerCase()))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Ledger / Account Master"),
        backgroundColor: Colors.teal.shade700,
        foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.person_add_alt_1), onPressed: () => _showForm())],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(15),
            color: Colors.teal.shade50,
            child: TextField(
              decoration: InputDecoration(
                hintText: "Search Debtors, Creditors, Expenses...",
                prefixIcon: const Icon(Icons.search, color: Colors.teal),
                filled: true, fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                contentPadding: EdgeInsets.zero
              ),
              onChanged: (v) => setState(() => search = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: filteredList.length,
              itemBuilder: (context, index) {
                final item = filteredList[index];
                Color groupColor = _getGroupColor(item.accountGroup);

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: groupColor.withOpacity(0.1), child: Icon(_getGroupIcon(item.accountGroup), color: groupColor)),
                    title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("${item.accountGroup} | Op: ${item.openingBalance} ${item.balanceType}"),
                        if (item.dlExpiry.isNotEmpty) Text("DL Exp: ${item.dlExpiry}", style: const TextStyle(fontSize: 10, color: Colors.red)),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(icon: const Icon(Icons.edit, color: Colors.blue, size: 20), onPressed: () => _showForm(party: item)),
                        IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _confirmDelete(context, ph, item)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- UI HELPERS ---
  Widget _sectionHeader(String title) => Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Align(alignment: Alignment.centerLeft, child: Text(title, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1))));

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isNum = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12), child: TextField(controller: ctrl, keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 16), border: const OutlineInputBorder(), contentPadding: const EdgeInsets.all(10))));
  }

  Color _getGroupColor(String group) {
    if (group == "Sundry Debtors") return Colors.green;
    if (group == "Sundry Creditors") return Colors.orange;
    if (group == "Expenses") return Colors.red;
    return Colors.blue;
  }

  IconData _getGroupIcon(String group) {
    if (group == "Sundry Debtors") return Icons.person;
    if (group == "Sundry Creditors") return Icons.local_shipping;
    if (group == "Expenses") return Icons.money_off;
    return Icons.account_balance_wallet;
  }

  void _confirmDelete(BuildContext context, PharoahManager ph, Party p) {
    if (p.name == "CASH") return;
    showDialog(context: context, builder: (c) => AlertDialog(title: const Text("Delete Ledger?"), content: Text("Are you sure you want to delete '${p.name}'?"), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")), ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red), onPressed: () { ph.deleteParty(p.id); Navigator.pop(c); }, child: const Text("YES, DELETE"))]));
  }
}
