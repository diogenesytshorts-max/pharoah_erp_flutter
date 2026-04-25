// FILE: lib/modifications/modify_hub_view.dart

import 'package:flutter/material.dart';

class ModifyHubView extends StatefulWidget {
  const ModifyHubView({super.key});

  @override
  State<ModifyHubView> createState() => _ModifyHubViewState();
}

class _ModifyHubViewState extends State<ModifyHubView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text("Universal Modification Center"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.orange,
          indicatorWeight: 4,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: "SALE BILLS", icon: Icon(Icons.receipt, size: 20)),
            Tab(text: "PURCHASE", icon: Icon(Icons.shopping_bag, size: 20)),
            Tab(text: "CHALLANS", icon: Icon(Icons.local_shipping, size: 20)),
            Tab(text: "RETURNS", icon: Icon(Icons.assignment_return, size: 20)),
          ],
        ),
      ),
      body: Column(
        children: [
          // --- UNIVERSAL SEARCH BAR ---
          _buildSearchBar(),

          // --- TAB VIEWS ---
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPlaceholderList("Sales History"),
                _buildPlaceholderList("Purchase History"),
                _buildPlaceholderList("Challan Records"),
                _buildPlaceholderList("Credit/Debit Notes"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(15),
      color: Colors.blue.shade900,
      child: TextField(
        controller: _searchC,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: "Search by Bill No, Party or Mobile...",
          hintStyle: const TextStyle(color: Colors.white60),
          prefixIcon: const Icon(Icons.search, color: Colors.white70),
          suffixIcon: IconButton(
            icon: const Icon(Icons.tune, color: Colors.white70),
            onPressed: () { /* Date Range Picker logic yahan aayega */ },
          ),
          filled: true,
          fillColor: Colors.white.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          contentPadding: EdgeInsets.zero,
        ),
      ),
    );
  }

  Widget _buildPlaceholderList(String title) {
    return ListView.builder(
      padding: const EdgeInsets.all(15),
      itemCount: 5,
      itemBuilder: (c, i) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: ListTile(
          contentPadding: const EdgeInsets.all(15),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("TXN-100$i", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const Text("₹1,500.00", style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Party: Sample Medical Agency", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              Text("Date: 25/04/2026 | $title", style: const TextStyle(fontSize: 11)),
            ],
          ),
          trailing: const Icon(Icons.more_vert),
          onTap: () => _showActionSheet(context),
        ),
      ),
    );
  }

  void _showActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Choose Action", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const Divider(height: 30),
            _actionTile(Icons.visibility, "View Detail", Colors.blue),
            _actionTile(Icons.edit, "Edit / Modify", Colors.orange),
            _actionTile(Icons.print, "Print / Share", Colors.teal),
            _actionTile(Icons.delete_forever, "Delete Transaction", Colors.red),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () => Navigator.pop(context),
    );
  }
}
