// FILE: web_portal/web_entry.dart
// COMPLETE PHAROAH ERP WEB SUITE (ZERO WARNINGS, ALL CONCEPTS INCLUDED)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pharoah_erp_flutter/models.dart';
import 'web_manager.dart';
import 'web_drive_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => WebManager(),
      child: const PharoahWebERPApp(),
    ),
  );
}

class PharoahWebERPApp extends StatelessWidget {
  const PharoahWebERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharoah ERP Web Suite',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      home: const WebDashboardScreen(),
    );
  }
}

class WebDashboardScreen extends StatefulWidget {
  const WebDashboardScreen({super.key});

  @override
  State<WebDashboardScreen> createState() => _WebDashboardScreenState();
}

class _WebDashboardScreenState extends State<WebDashboardScreen> {
  int _selectedNav = 0;

  @override
  Widget build(BuildContext context) {
    final web = Provider.of<WebManager>(context);

    if (web.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D47A1),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 15),
              Text("Syncing Pharoah ERP with Google Drive...", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.local_pharmacy_rounded, color: Colors.white, size: 28),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(web.shopName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                Text("FY: ${web.currentFY} | ${web.syncStatus}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: web.isOnline ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(20)),
              child: Text(web.isOnline ? "ONLINE (DRIVE SYNC)" : "OFFLINE MODE", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.sync_rounded, color: Colors.white),
              tooltip: "Force Push & Pull Drive",
              onPressed: () => web.syncWithDrive(),
            ),
            IconButton(
              icon: const Icon(Icons.cloud_outlined, color: Colors.white),
              tooltip: "Cloud Configuration",
              onPressed: () => _showCloudConfig(context, web),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF0D47A1),
      ),
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedNav,
            onDestinationSelected: (i) => setState(() => _selectedNav = i),
            labelType: NavigationRailLabelType.all,
            backgroundColor: Colors.white,
            selectedIconTheme: const IconThemeData(color: Color(0xFF0D47A1)),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.dashboard_rounded), label: Text("Dashboard")),
              NavigationRailDestination(icon: Icon(Icons.point_of_sale_rounded), label: Text("Billing")),
              NavigationRailDestination(icon: Icon(Icons.inventory_2_rounded), label: Text("Stock & Batches")),
              NavigationRailDestination(icon: Icon(Icons.account_balance_wallet_rounded), label: Text("Accounts")),
              NavigationRailDestination(icon: Icon(Icons.verified_rounded), label: Text("GST Returns")),
              NavigationRailDestination(icon: Icon(Icons.hub_rounded), label: Text("Master Hub")),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: _buildSelectedView(web),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedView(WebManager web) {
    switch (_selectedNav) {
      case 0: return _buildDashboardView(web);
      case 1: return _buildBillingView(web);
      case 2: return _buildStockBatchView(web);
      case 3: return _buildAccountsView(web);
      case 4: return _buildGstView(web);
      case 5: return _buildMasterHubView(web);
      default: return _buildDashboardView(web);
    }
  }

  // 1. DASHBOARD
  Widget _buildDashboardView(WebManager web) {
    double todaySales = web.sales.fold(0.0, (s, e) => s + e.totalAmount);
    double todayPur = web.purchases.fold(0.0, (s, e) => s + e.totalAmount);
    double stockVal = web.medicines.fold(0.0, (s, m) => s + (m.stock * m.purRate));

    return ListView(
      children: [
        Row(
          children: [
            _statCard("TOTAL SALES", "₹${todaySales.toStringAsFixed(2)}", Icons.trending_up, Colors.green),
            const SizedBox(width: 12),
            _statCard("PURCHASES", "₹${todayPur.toStringAsFixed(2)}", Icons.shopping_cart, Colors.orange),
            const SizedBox(width: 12),
            _statCard("STOCK VALUATION", "₹${stockVal.toStringAsFixed(0)}", Icons.inventory_2, Colors.purple),
            const SizedBox(width: 12),
            _statCard("SHORTAGES", "${web.shortages.length} Items", Icons.warning_amber, Colors.red),
          ],
        ),
        const SizedBox(height: 25),
        const Text("Quick Action Launchers", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
        const SizedBox(height: 12),
        Row(
          children: [
            _actionBtn("NEW SALE BILL", Icons.add_shopping_cart, Colors.blue.shade700, () => _showNewSaleDialog(context, web)),
            const SizedBox(width: 12),
            _actionBtn("ADD PURCHASE", Icons.downloading, Colors.orange.shade800, () => _showNewPurchaseDialog(context, web)),
            const SizedBox(width: 12),
            _actionBtn("RECEIPT VOUCHER", Icons.add_chart, Colors.green.shade700, () => _showVoucherDialog(context, web, "Receipt")),
            const SizedBox(width: 12),
            _actionBtn("PAYMENT VOUCHER", Icons.analytics, Colors.red.shade700, () => _showVoucherDialog(context, web, "Payment")),
          ],
        ),
        const SizedBox(height: 25),
        const Text("Recent Invoices", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey)),
        const SizedBox(height: 8),
        ...web.sales.reversed.take(5).map((s) => Card(
          child: ListTile(
            leading: const Icon(Icons.receipt_long, color: Colors.blue),
            title: Text("${s.partyName} (Bill #${s.billNo})", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(DateFormat('dd/MM/yyyy').format(s.date)),
            trailing: Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.green)),
          ),
        )),
      ],
    );
  }

  // 2. BILLING
  Widget _buildBillingView(WebManager web) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Sale & Invoice Register", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade900, foregroundColor: Colors.white),
              onPressed: () => _showNewSaleDialog(context, web),
              icon: const Icon(Icons.add),
              label: const Text("CREATE SALE BILL"),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Expanded(
          child: web.sales.isEmpty
              ? const Center(child: Text("No sales recorded yet."))
              : ListView.builder(
                  itemCount: web.sales.length,
                  itemBuilder: (c, i) {
                    final s = web.sales[web.sales.length - 1 - i];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(backgroundColor: Colors.blue.shade50, child: const Icon(Icons.receipt, color: Colors.blue)),
                        title: Text("${s.partyName} - Bill #${s.billNo}", style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Items: ${s.items.length} | Mode: ${s.paymentMode} | Date: ${DateFormat('dd/MM/yy').format(s.date)}"),
                        trailing: Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // 3. STOCK & BATCHES
  Widget _buildStockBatchView(WebManager web) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Medicines & Batch Inventory (${web.medicines.length} Products)", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              onPressed: () => _showNewProductDialog(context, web),
              icon: const Icon(Icons.add),
              label: const Text("ADD NEW PRODUCT"),
            ),
          ],
        ),
        const SizedBox(height: 15),
        Expanded(
          child: ListView.builder(
            itemCount: web.medicines.length,
            itemBuilder: (c, i) {
              final m = web.medicines[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: m.isNarcotic ? Colors.red.shade100 : Colors.purple.shade50,
                    child: Icon(Icons.medication, color: m.isNarcotic ? Colors.red : Colors.purple),
                  ),
                  title: Text("${m.name} - ${m.drugForm}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("Pack: ${m.packing} | MRP: ₹${m.mrp} | Pur: ₹${m.purRate} | Rate A: ₹${m.rateA}"),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: m.stock > 0 ? Colors.green.shade50 : Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Text("Stock: ${m.stock.toInt()} ${m.packing}", style: TextStyle(fontWeight: FontWeight.w900, color: m.stock > 0 ? Colors.green.shade800 : Colors.red.shade800)),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 4. ACCOUNTS
  Widget _buildAccountsView(WebManager web) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text("Accounts & Party Ledgers", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Row(
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, foregroundColor: Colors.white),
                  onPressed: () => _showVoucherDialog(context, web, "Receipt"),
                  icon: const Icon(Icons.add),
                  label: const Text("RECEIPT"),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
                  onPressed: () => _showVoucherDialog(context, web, "Payment"),
                  icon: const Icon(Icons.remove),
                  label: const Text("PAYMENT"),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 15),
        Expanded(
          child: ListView.builder(
            itemCount: web.parties.length,
            itemBuilder: (c, i) {
              final p = web.parties[i];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.indigo.shade50, child: const Icon(Icons.person, color: Colors.indigo)),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${p.group} | City: ${p.city} | GST: ${p.gst}"),
                  trailing: Text("Bal: ₹${p.opBal.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 5. GST
  Widget _buildGstView(WebManager web) {
    double totalTaxable = web.sales.fold(0.0, (s, e) => s + e.totalAmount * 0.88);
    double totalTax = web.sales.fold(0.0, (s, e) => s + e.totalAmount * 0.12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("GST Statutory Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Row(
          children: [
            _statCard("OUTWARD TAXABLE", "₹${totalTaxable.toStringAsFixed(2)}", Icons.assignment, Colors.green),
            const SizedBox(width: 12),
            _statCard("TOTAL GST COLLECTED", "₹${totalTax.toStringAsFixed(2)}", Icons.summarize, Colors.blue),
            const SizedBox(width: 12),
            _statCard("HIGH VALUE (>50K)", "${web.sales.where((s) => s.totalAmount >= 50000).length} Bills", Icons.local_shipping, Colors.indigo),
          ],
        ),
        const SizedBox(height: 25),
        const Text("GSTR-1 Inward/Outward Sales Data", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        Expanded(
          child: ListView.builder(
            itemCount: web.sales.length,
            itemBuilder: (c, i) {
              final s = web.sales[i];
              return Card(
                child: ListTile(
                  title: Text("Inv: ${s.billNo} - ${s.partyName} (GSTIN: ${s.partyGstin})"),
                  subtitle: Text("Taxable: ₹${(s.totalAmount * 0.88).toStringAsFixed(2)} | GST: ₹${(s.totalAmount * 0.12).toStringAsFixed(2)}"),
                  trailing: Text("₹${s.totalAmount.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 6. MASTER HUB
  Widget _buildMasterHubView(WebManager web) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Primary Business Masters", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 15),
        Expanded(
          child: GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 15,
            mainAxisSpacing: 15,
            childAspectRatio: 1.5,
            children: [
              _hubCard("Party / Ledger Master", "${web.parties.length} Parties", Icons.people, Colors.indigo, () => _showNewPartyDialog(context, web)),
              _hubCard("Product / Item Master", "${web.medicines.length} Products", Icons.inventory_2, Colors.purple, () => _showNewProductDialog(context, web)),
              _hubCard("Company Master", "${web.companies.length} Companies", Icons.business, Colors.brown, () {}),
              _hubCard("Salt Master", "${web.salts.length} Salts", Icons.science, Colors.deepOrange, () {}),
              _hubCard("Drug Categories", "${web.drugTypes.length} Types", Icons.category, Colors.teal, () {}),
              _hubCard("Route Master", "${web.routes.length} Routes", Icons.map, Colors.blueGrey, () {}),
            ],
          ),
        ),
      ],
    );
  }

  // DIALOGS
  void _showNewSaleDialog(BuildContext context, WebManager web) {
    if (web.medicines.isEmpty || web.parties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Add products & parties first!")));
      return;
    }
    Party selectedParty = web.parties.first;
    Medicine selectedMed = web.medicines.first;
    final qtyC = TextEditingController(text: "1");
    final billNoC = TextEditingController(text: "INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}");

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setDState) => AlertDialog(
          title: const Text("New Sale Invoice"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: billNoC, decoration: const InputDecoration(labelText: "Bill Number")),
              const SizedBox(height: 10),
              DropdownButtonFormField<Party>(
                value: selectedParty,
                decoration: const InputDecoration(labelText: "Select Party / Customer"),
                items: web.parties.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (v) => setDState(() => selectedParty = v!),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<Medicine>(
                value: selectedMed,
                decoration: const InputDecoration(labelText: "Select Medicine / Item"),
                items: web.medicines.map((m) => DropdownMenuItem(value: m, child: Text("${m.name} (Stock: ${m.stock.toInt()})"))).toList(),
                onChanged: (v) => setDState(() => selectedMed = v!),
              ),
              const SizedBox(height: 10),
              TextField(controller: qtyC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Quantity")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
            ElevatedButton(
              onPressed: () {
                double qty = double.tryParse(qtyC.text) ?? 1;
                double rate = selectedMed.rateA > 0 ? selectedMed.rateA : selectedMed.mrp;
                double total = qty * rate;

                final item = BillItem(
                  id: DateTime.now().toString(),
                  srNo: 1,
                  medicineID: selectedMed.id,
                  name: selectedMed.name,
                  packing: selectedMed.packing,
                  batch: "BATCH-1",
                  exp: "12/28",
                  hsn: selectedMed.hsnCode,
                  mrp: selectedMed.mrp,
                  qty: qty,
                  rate: rate,
                  gstRate: selectedMed.gst,
                  total: total,
                );

                final sale = Sale(
                  id: DateTime.now().toString(),
                  billNo: billNoC.text,
                  date: DateTime.now(),
                  partyName: selectedParty.name,
                  partyGstin: selectedParty.gst,
                  partyState: selectedParty.state,
                  items: [item],
                  totalAmount: total,
                  paymentMode: "CASH",
                );

                web.addSale(sale);
                Navigator.pop(c);
              },
              child: const Text("SAVE BILL"),
            )
          ],
        ),
      ),
    );
  }

  void _showNewPurchaseDialog(BuildContext context, WebManager web) {
    final billNoC = TextEditingController();
    final distC = TextEditingController(text: "DEMO DISTRIBUTORS");
    final amtC = TextEditingController(text: "5000");

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Quick Purchase Entry"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: billNoC, decoration: const InputDecoration(labelText: "Supplier Bill No")),
            TextField(controller: distC, decoration: const InputDecoration(labelText: "Distributor Name")),
            TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Total Amount ₹")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final pur = Purchase(
                id: DateTime.now().toString(),
                internalNo: "PUR-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}",
                billNo: billNoC.text.isEmpty ? "PUR-01" : billNoC.text,
                date: DateTime.now(),
                entryDate: DateTime.now(),
                distributorName: distC.text,
                items: [],
                totalAmount: double.tryParse(amtC.text) ?? 0,
                paymentMode: "CREDIT",
              );
              web.addPurchase(pur);
              Navigator.pop(c);
            },
            child: const Text("SAVE PURCHASE"),
          )
        ],
      ),
    );
  }

  void _showVoucherDialog(BuildContext context, WebManager web, String type) {
    final partyC = TextEditingController(text: web.parties.first.name);
    final amtC = TextEditingController(text: "1000");

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text("New $type Voucher"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: partyC, decoration: const InputDecoration(labelText: "Party / Account")),
            TextField(controller: amtC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount ₹")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              final v = Voucher(
                id: DateTime.now().toString(),
                type: type,
                date: DateTime.now(),
                partyId: "1",
                partyName: partyC.text,
                amount: double.tryParse(amtC.text) ?? 0,
                paymentMode: "Cash",
              );
              web.addVoucher(v);
              Navigator.pop(c);
            },
            child: const Text("SAVE VOUCHER"),
          )
        ],
      ),
    );
  }

  void _showNewPartyDialog(BuildContext context, WebManager web) {
    final nameC = TextEditingController();
    final cityC = TextEditingController(text: "JAIPUR");
    final gstC = TextEditingController(text: "08XXXXX1234Z1");

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Create New Party / Customer"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Party Name")),
            TextField(controller: cityC, decoration: const InputDecoration(labelText: "City")),
            TextField(controller: gstC, decoration: const InputDecoration(labelText: "GSTIN")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (nameC.text.isNotEmpty) {
                web.addParty(Party(id: DateTime.now().toString(), name: nameC.text.toUpperCase(), city: cityC.text, gst: gstC.text));
                Navigator.pop(c);
              }
            },
            child: const Text("SAVE PARTY"),
          )
        ],
      ),
    );
  }

  void _showNewProductDialog(BuildContext context, WebManager web) {
    final nameC = TextEditingController();
    final packC = TextEditingController(text: "10 TAB");
    final mrpC = TextEditingController(text: "100");
    final purC = TextEditingController(text: "70");

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Add New Medicine / Product"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameC, decoration: const InputDecoration(labelText: "Product Name")),
            TextField(controller: packC, decoration: const InputDecoration(labelText: "Packing")),
            TextField(controller: mrpC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "MRP ₹")),
            TextField(controller: purC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Purchase Rate ₹")),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () {
              if (nameC.text.isNotEmpty) {
                double mrp = double.tryParse(mrpC.text) ?? 100;
                double pur = double.tryParse(purC.text) ?? 70;
                web.addMedicine(Medicine(
                  id: DateTime.now().toString(),
                  name: nameC.text.toUpperCase(),
                  packing: packC.text.toUpperCase(),
                  mrp: mrp,
                  purRate: pur,
                  rateA: mrp * 0.9,
                  rateB: mrp * 0.85,
                  rateC: pur * 1.1,
                  stock: 50,
                ));
                Navigator.pop(c);
              }
            },
            child: const Text("SAVE PRODUCT"),
          )
        ],
      ),
    );
  }

  void _showCloudConfig(BuildContext context, WebManager web) async {
    final urlC = TextEditingController(text: await WebDriveBridge.getWebhookUrl());
    final emailC = TextEditingController(text: await WebDriveBridge.getUserEmail());

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Google Drive Cloud Configuration"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: urlC, decoration: const InputDecoration(labelText: "Google Script Web App URL", border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: emailC, decoration: const InputDecoration(labelText: "Registered Business Email", border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text("CANCEL")),
          ElevatedButton(
            onPressed: () async {
              await WebDriveBridge.saveCloudConfig(urlC.text, emailC.text);
              if (c.mounted) Navigator.pop(c);
              await web.syncWithDrive();
            },
            child: const Text("SAVE & SYNC"),
          )
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)]),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withAlpha(25), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)), Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900))]),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: const Offset(0, 3))]),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hubCard(String title, String count, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withAlpha(25), child: Icon(icon, color: color)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)), Text(count, style: const TextStyle(fontSize: 11, color: Colors.grey))])),
            const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
