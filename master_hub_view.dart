// FILE: lib/master_hub_view.dart (Replace Full)

import 'package:flutter/material.dart';
import 'widgets.dart';
import 'party_master.dart';
import 'product_master.dart';
import 'route_master_view.dart';
import 'company_master_view.dart';
import 'salt_master_view.dart';
import 'drug_type_master_view.dart';
import 'batch_master_view.dart';
import 'administration/bank_master_view.dart'; // NAYA
import 'administration/staff_management_view.dart'; // NAYA (Salesman)

class MasterHubView extends StatelessWidget {
  const MasterHubView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("Master Data Hub"),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("PRIMARY BUSINESS MASTERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2)),
            const SizedBox(height: 15),

            // --- SECTION 1: CORE MASTERS ---
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.2,
              children: [
                ActionIconBtn(title: "Parties / Ledgers", icon: Icons.people_alt_rounded, color: Colors.indigo, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PartyMasterView()))),
                ActionIconBtn(title: "Item Master", icon: Icons.inventory_2_rounded, color: Colors.purple, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const ProductMasterView()))),
                ActionIconBtn(title: "Batch Master", icon: Icons.layers_outlined, color: Colors.indigo.shade900, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BatchMasterView()))),
                ActionIconBtn(title: "Route Master", icon: Icons.map_rounded, color: Colors.teal, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const RouteAreaMasterView()))),
              ],
            ),

            const SizedBox(height: 30),

            const Text("FINANCE & STAFF MASTERS", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2)),
            const SizedBox(height: 15),

            // --- SECTION 2: NEWLY ADDED MASTERS (From Model Update) ---
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.2,
              children: [
                ActionIconBtn(title: "Bank Master", icon: Icons.account_balance_rounded, color: Colors.blue.shade800, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const BankMasterView()))),
                ActionIconBtn(title: "Salesman Master", icon: Icons.badge_rounded, color: Colors.red.shade800, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const StaffManagementView()))),
              ],
            ),

            const SizedBox(height: 30),

            const Text("PHARMA LIBRARIES", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey, letterSpacing: 1.2)),
            const SizedBox(height: 15),

            // --- SECTION 3: PHARMA MASTERS ---
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.2,
              children: [
                ActionIconBtn(title: "Company Master", icon: Icons.business_rounded, color: Colors.brown, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const CompanyMasterView()))),
                ActionIconBtn(title: "Salt Master", icon: Icons.science_rounded, color: Colors.deepOrange, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaltMasterView()))),
                ActionIconBtn(title: "Drug Categories", icon: Icons.verified_user_rounded, color: Colors.cyan.shade700, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const DrugTypeMasterView()))),
              ],
            ),
            
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// NOTE: Aapke code mein RouteMasterView ka naam shayad alag ho sakta hai, maine yahan standard nomenclature use kiya hai.
class RouteAreaMasterView extends RouteMasterView { const RouteAreaMasterView({super.key}); }
