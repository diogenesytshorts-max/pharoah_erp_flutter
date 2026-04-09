import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'models.dart';
import 'sale_entry_view.dart';
import 'pdf_service.dart';
import 'package:intl/intl.dart';

class SaleBillModifyView extends StatefulWidget {
  const SaleBillModifyView({super.key});
  @override State<SaleBillModifyView> createState() => _SaleBillModifyViewState();
}

class _SaleBillModifyViewState extends State<SaleBillModifyView> {
  String dur = "Today"; 
  String pF = "All"; 
  Party? sP;

  // --- FILTER LOGIC ---
  List<Sale> getFilteredSales(List<Sale> all) {
    DateTime n = DateTime.now();
    
    return all.where((s) {
      // 1. Date Filter
      bool dateMatch = false;
      if (dur == "Today") {
        dateMatch = s.date.day == n.day && s.date.month == n.month && s.date.year == n.year;
      } else if (dur == "Yesterday") {
        DateTime y = n.subtract(const Duration(days: 1));
        dateMatch = s.date.day == y.day && s.date.month == y.month && s.date.year == y.year;
      } else if (dur == "Month") {
        dateMatch = s.date.month == n.month && s.date.year == n.year;
      } else {
        dateMatch = true; // For "All" duration
      }
      
      // 2. Party Filter
      bool partyMatch = true;
      if (pF == "Single") {
        if (sP == null) {
          partyMatch = false; // Agar party select nahi ki toh kuch mat dikhao
        } else {
          // Robust comparison: dono sides ko trim aur uppercase karke match karein
          partyMatch = s.partyName.trim().toUpperCase() == sP!.name.trim().toUpperCase();
        }
      }

      return dateMatch && partyMatch;
    }).toList().reversed.toList(); // Newest first
  }

  // --- SEARCHABLE PARTY DIALOG ---
  void _showPartySearchDialog(List<Party> allParties) {
    showDialog(
      context: context,
      builder: (context) {
        String dialogSearch = "";
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredList = allParties
                .where((p) => p.name.toLowerCase().contains(dialogSearch.toLowerCase()))
                .toList();

            return AlertDialog(
              title: const Text("Select Party"),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "Type Party Name...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        setDialogState(() => dialogSearch = v);
                      },
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredList.length,
                        itemBuilder: (c, i) {
                          return ListTile(
                            title: Text(filteredList[i].name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(filteredList[i].city),
                            onTap: () {
                              // Main State ko update karein
                              setState(() {
                                sP = filteredList[i];
                              });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);
    final list = getFilteredSales(ph.sales);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Sale Bill Modify & Reports"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // --- TOP FILTERS ---
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.orange[50],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("DURATION", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: dur,
                        items: ["Today", "Yesterday", "Month", "All"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) => setState(() => dur = v!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("FILTER BY", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      DropdownButton<String>(
                        isExpanded: true,
                        value: pF,
                        items: ["All", "Single"]
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                        onChanged: (v) {
                          setState(() {
                            pF = v!;
                            if (pF == "All") sP = null;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- PARTY SELECTION BUTTON ---
          if (pF == "Single")
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: ListTile(
                tileColor: Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                leading: const Icon(Icons.person, color: Colors.orange),
                title: Text(
                  sP?.name ?? "TAP TO SELECT PARTY",
                  style: TextStyle(
                    color: sP == null ? Colors.red : Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                trailing: const Icon(Icons.search),
                onTap: () => _showPartySearchDialog(ph.parties),
              ),
            ),

          // --- SUMMARY INFO ---
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Found ${list.length} Bills",
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ),

          // --- SALES LIST ---
          Expanded(
            child: list.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.receipt_long, size: 60, color: Colors.grey),
                        const SizedBox(height: 10),
                        Text(
                          pF == "Single" && sP == null 
                          ? "Please select a party to see bills" 
                          : "No Bills Found",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (c, i) {
                      final s = list[i];
                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        color: s.status == "Cancelled" ? Colors.red[50] : Colors.white,
                        child: ListTile(
                          title: Text("${s.billNo} | ${s.partyName}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Date: ${DateFormat('dd/MM/yyyy').format(s.date)} | Total: ₹${s.totalAmount.toStringAsFixed(2)}"),
                              Text(
                                s.items.map((it) => "${it.name}(${it.qty.toInt()})").join(", "),
                                style: const TextStyle(fontSize: 10, color: Colors.blueGrey),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (v) async {
                              if (v == 'v') Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: s, isReadOnly: true)));
                              if (v == 'm') Navigator.push(context, MaterialPageRoute(builder: (c) => SaleEntryView(existingSale: s)));
                              if (v == 'p') PdfService.generateInvoice(s, ph.parties.firstWhere((p) => p.name == s.partyName, orElse: () => ph.parties[0]));
                              if (v == 'c') _confirmAction("Cancel", () => ph.cancelBill(s.id));
                              if (v == 'd') _confirmAction("Delete", () => ph.deleteBill(s.id));
                            },
                            itemBuilder: (c) => [
                              const PopupMenuItem(value: 'v', child: Text("👁️ View Bill")),
                              const PopupMenuItem(value: 'm', child: Text("✏️ Modify Bill")),
                              const PopupMenuItem(value: 'p', child: Text("🖨️ Print Bill")),
                              const PopupMenuItem(value: 'c', child: Text("🚫 Cancel Bill")),
                              const PopupMenuItem(value: 'd', child: Text("🗑️ Delete Bill")),
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

  void _confirmAction(String action, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("$action Bill?"),
        content: Text("Are you sure you want to $action this bill? Stock will be reversed."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("NO")),
          TextButton(
            onPressed: () {
              onConfirm();
              Navigator.pop(c);
            },
            child: const Text("YES"),
          )
        ],
      ),
    );
  }
}
