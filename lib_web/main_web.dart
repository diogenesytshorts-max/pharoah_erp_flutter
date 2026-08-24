// FILE: lib_web/main_web.dart
// PURE FLUTTER WEB APP RUNNER (Zero modification to lib/ codebase)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'pharoah_web_manager.dart';
import '../lib/models.dart';
import '../lib/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => PharoahWebManager(),
      child: const PharoahWebERPApp(),
    ),
  );
}

class PharoahWebERPApp extends StatelessWidget {
  const PharoahWebERPApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pharoah ERP - Web Cloud Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0D47A1),
          brightness: Brightness.dark,
        ),
      ),
      home: const WebControlShell(),
    );
  }
}

class WebControlShell extends StatefulWidget {
  const WebControlShell({super.key});

  @override
  State<WebControlShell> createState() => _WebControlShellState();
}

class _WebControlShellState extends State<WebControlShell> {
  String activeView = "DASHBOARD";

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahWebManager>(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D47A1),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ph.activeCompany?.name ?? "DWARIKA MEDICALS",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
            ),
            Row(
              children: [
                Text("ID: ${ph.activeCompany?.id ?? 'PH-C-101'}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(color: Colors.blue.shade400, borderRadius: BorderRadius.circular(4)),
                  child: Text(ph.activeCompany?.businessType ?? "WHOLESALE", style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text("FY: ${ph.currentFY}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.15),
              border: Border.all(color: Colors.green.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              children: [
                CircleAvatar(radius: 4, backgroundColor: Colors.green),
                SizedBox(width: 6),
                Text("2-Way Cloud Sync", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.greenAccent)),
              ],
            ),
          ),
          if (activeView != "DASHBOARD")
            IconButton(
              icon: const Icon(Icons.dashboard_rounded, color: Colors.white),
              onPressed: () => setState(() => activeView = "DASHBOARD"),
              tooltip: "Dashboard",
            ),
        ],
      ),
      body: _buildCurrentView(ph),
    );
  }

  Widget _buildCurrentView(PharoahWebManager ph) {
    switch (activeView) {
      case "BILLING_STEP1":
        return _buildSaleStep1(ph);
      case "STOCK":
        return _buildStockView(ph);
      case "MASTERS":
        return _buildMastersView(ph);
      case "DAYBOOK":
        return _buildDaybookView(ph);
      default:
        return _buildDashboard(ph);
    }
  }

  // 1. DASHBOARD VIEW (Matching Flutter App 100%)
  Widget _buildDashboard(PharoahWebManager ph) {
    final now = DateTime.now();
    double todaySales = ph.sales
        .where((s) => s.status == "Active" && s.date.day == now.day && s.date.month == now.month)
        .fold(0.0, (sum, s) => sum + s.totalAmount);
    double todayPur = ph.purchases
        .where((p) => p.date.day == now.day && p.date.month == now.month)
        .fold(0.0, (sum, p) => sum + p.totalAmount);
    double stockVal = ph.medicines
        .fold(0.0, (sum, m) => sum + (m.stock > 0 ? m.stock * m.purRate : 0.0));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: StatWidget(title: "TODAY SALE", value: "₹${todaySales.toStringAsFixed(0)}", period: "Live", icon: "trending_up", color: Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: StatWidget(title: "TODAY PURCHASE", value: "₹${todayPur.toStringAsFixed(0)}", period: "Inward", icon: "shopping_cart", color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          StatWidget(title: "ESTIMATED STOCK VALUE", value: "₹${stockVal.toStringAsFixed(0)}", period: "Taxable", icon: "inventory_2", color: Colors.indigo),
          
          const SizedBox(height: 25),
          const Text("QUICK ENTRIES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey, letterSpacing: 1)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _bigEntryBtn("NEW SALE", Icons.add_shopping_cart, const Color(0xFF1D4ED8), () {
                  setState(() => activeView = "BILLING_STEP1");
                }),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: _bigEntryBtn("PURCHASE", Icons.downloading_rounded, const Color(0xFFC2410C), () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Purchase Inward Loaded.")));
                }),
              ),
            ],
          ),

          const SizedBox(height: 25),
          InkWell(
            onTap: () => setState(() => activeView = "MASTERS"),
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF3730A3), Color(0xFF1E1B4B)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                children: [
                  Icon(Icons.stars_rounded, color: Colors.white, size: 36),
                  SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("MASTER HUB", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        Text("Manage Products, Parties, Companies & Salts", style: TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 25),
          const Text("MAIN BUSINESS MODULES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey, letterSpacing: 1)),
          const SizedBox(height: 12),

          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.9,
            children: [
              ActionIconBtn(title: "Billing", icon: Icons.receipt_long, color: Colors.blue, onTap: () => setState(() => activeView = "BILLING_STEP1")),
              ActionIconBtn(title: "Challans", icon: Icons.local_shipping, color: Colors.teal, onTap: () {}),
              ActionIconBtn(title: "Returns", icon: Icons.assignment_return, color: Colors.red, onTap: () {}),
              ActionIconBtn(title: "Stock", icon: Icons.inventory, color: Colors.purple, onTap: () => setState(() => activeView = "STOCK")),
              ActionIconBtn(title: "Accounts", icon: Icons.account_balance_wallet, color: Colors.indigo, onTap: () {}),
              ActionIconBtn(title: "Masters", icon: Icons.stars, color: Colors.orange, onTap: () => setState(() => activeView = "MASTERS")),
              ActionIconBtn(title: "Daybook", icon: Icons.event_note, color: Colors.blueGrey, onTap: () => setState(() => activeView = "DAYBOOK")),
              ActionIconBtn(title: "Ledgers", icon: Icons.people, color: Colors.green, onTap: () {}),
              ActionIconBtn(title: "Data Hub", icon: Icons.cloud_sync, color: Colors.cyan, onTap: () {}),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bigEntryBtn(String title, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 80,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  // 2. SALE STEP 1 VIEW
  Widget _buildSaleStep1(PharoahWebManager ph) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("SALE ENTRY (STEP 1: SETUP)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  OutlinedButton(onPressed: () => setState(() => activeView = "DASHBOARD"), child: const Text("CANCEL")),
                ],
              ),
              const Divider(height: 30),
              TextField(
                decoration: const InputDecoration(labelText: "Invoice No", border: OutlineInputBorder()),
                controller: TextEditingController(text: ph.getNextNumber('SALE')),
                readOnly: true,
              ),
              const SizedBox(height: 15),
              const Text("SELECT REGISTERED PARTY:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  itemCount: ph.parties.length,
                  itemBuilder: (c, i) {
                    final p = ph.parties[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("${p.city} | GST: ${p.gst} | Bal: ₹${p.opBal}"),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Party Selected: ${p.name}")));
                        },
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 3. STOCK VIEW
  Widget _buildStockView(PharoahWebManager ph) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("STOCK LEDGER & LIVE INVENTORY", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  OutlinedButton(onPressed: () => setState(() => activeView = "DASHBOARD"), child: const Text("BACK")),
                ],
              ),
              const Divider(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: ph.medicines.length,
                  itemBuilder: (c, i) {
                    final m = ph.medicines[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.medication)),
                        title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Pack: ${m.packing} | Pur. Rate: ₹${m.purRate} | MRP: ₹${m.mrp}"),
                        trailing: Text("${m.stock.toInt()} Units", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.greenAccent)),
                      ),
                    );
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  // 4. MASTERS VIEW
  Widget _buildMastersView(PharoahWebManager ph) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("MASTER HUB (PRODUCTS & PARTIES)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  OutlinedButton(onPressed: () => setState(() => activeView = "DASHBOARD"), child: const Text("BACK")),
                ],
              ),
              const Divider(height: 30),
              Text("Total Products: ${ph.medicines.length} | Total Parties: ${ph.parties.length}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.cyanAccent)),
            ],
          ),
        ),
      ),
    );
  }

  // 5. DAYBOOK VIEW
  Widget _buildDaybookView(PharoahWebManager ph) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("DAILY DAYBOOK AUDIT REGISTER", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  OutlinedButton(onPressed: () => setState(() => activeView = "DASHBOARD"), child: const Text("BACK")),
                ],
              ),
              const Divider(height: 30),
              const Text("No entries recorded for today yet.", style: TextStyle(color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}
