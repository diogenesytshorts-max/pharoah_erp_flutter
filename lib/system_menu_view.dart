import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'audit_logs_view.dart';
import 'file_management_view.dart';
import 'user_master_view.dart';
import 'pharoah_manager.dart';
import 'widgets.dart';

class SystemMenuView extends StatelessWidget {
  final VoidCallback onLogout;
  const SystemMenuView({super.key, required this.onLogout});

  // --- THE 7-STEP MASTER RESET VERIFICATION ---
  // This logic ensures no one accidentally wipes the database.
  void _startResetProcess(BuildContext context) {
    final List<Map<String, String>> steps = [
      {
        "t": "Verification - Step 1/7",
        "m": "Kya aap vastav me sara data delete karna chahte hain?",
        "b": "AGREE & CONTINUE"
      },
      {
        "t": "Verification - Step 2/7",
        "m": "Isse aapki saari Sales, Purchase aur Inventory zero ho jayegi. Kya aapko ye pata hai?",
        "b": "YES, I UNDERSTAND"
      },
      {
        "t": "Verification - Step 3/7",
        "m": "Caurion: Bina backup ke aapka data kabhi wapas nahi aayega! Kya aapne backup le liya hai?",
        "b": "I HAVE BACKUP / PROCEED"
      },
      {
        "t": "Verification - Step 4/7",
        "m": "Ye action permanent hai. System reset hone ke baad purana record nahi milega. Proceed?",
        "b": "YES, GO AHEAD"
      },
      {
        "t": "Verification - Step 5/7",
        "m": "Final Warning: Pharoah ERP ki saari settings aur Master data reset ho jayega.",
        "b": "I AM SURE, RESET"
      },
      {
        "t": "Verification - Step 6/7",
        "m": "Aapka poora business record saaf hone wala hai. Kya aap abhi bhi aage badhna chahte hain?",
        "b": "YES, DELETE EVERYTHING"
      },
      {
        "t": "FINAL CONFIRMATION - 7/7",
        "m": "Ok, ye aakhri mauka hai piche hatne ka. Tap 'WIPE NOW' to format database.",
        "b": "WIPE EVERYTHING NOW"
      },
    ];

    _showVerificationStep(context, steps, 0);
  }

  // Recursive function to show each dialog step
  void _showVerificationStep(BuildContext context, List<Map<String, String>> steps, int index) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(
          steps[index]['t']!,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Text(
          steps[index]['m']!,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        actions: [
          // Cancel Option
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Reset Cancelled. Your data is safe."))
              );
            },
            child: const Text("NO / CANCEL", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          // Proceed Option
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(c);
              if (index < steps.length - 1) {
                // Move to next verification step
                _showVerificationStep(context, steps, index + 1);
              } else {
                // Final Step Reached - Execute Wipe
                _performMasterReset(context);
              }
            },
            child: Text(
              steps[index]['b']!,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // Execute the Actual Data Wipe
  void _performMasterReset(BuildContext context) async {
    final ph = Provider.of<PharoahManager>(context, listen: false);
    await ph.masterReset();
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("SYSTEM MASTER RESET COMPLETED!"),
          backgroundColor: Colors.black,
        ),
      );
      // Exit back to Dashboard or Setup
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F9),
      appBar: AppBar(
        title: const Text("System Administration"),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 5, bottom: 15),
              child: Text(
                "MAINTENANCE TOOLS",
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey, letterSpacing: 1.2),
              ),
            ),
            
            // --- GRID OF THE 6 CORE TOOLS ---
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
              children: [
                // 1. Company Profile Settings
                ActionIconBtn(
                  title: "Company",
                  icon: Icons.business_rounded,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                ),
                // 2. Audit Logs (History)
                ActionIconBtn(
                  title: "Audit Logs",
                  icon: Icons.history_edu_rounded,
                  color: Colors.brown,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const AuditLogsView())),
                ),
                // 3. Data Backup & Share
                ActionIconBtn(
                  title: "Backup",
                  icon: Icons.cloud_done_rounded,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView())),
                ),
                // 4. Financial Year Switch
                ActionIconBtn(
                  title: "Change FY",
                  icon: Icons.calendar_month_rounded,
                  color: Colors.teal,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const FileManagementView())),
                ),
                // 5. Admin Password/User Settings
                ActionIconBtn(
                  title: "Admin User",
                  icon: Icons.admin_panel_settings_rounded,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => UserMasterView(onLogout: onLogout))),
                ),
                // 6. Master Reset (Red Icon with 7-Step Check)
                ActionIconBtn(
                  title: "Reset Data",
                  icon: Icons.delete_forever_rounded,
                  color: Colors.red,
                  onTap: () => _startResetProcess(context),
                ),
              ],
            ),

            const SizedBox(height: 40),
            
            // Helpful Info Card
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.security_rounded, color: Colors.blue.shade900),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Text(
                      "All administrative actions are logged in Audit History. High-risk actions require multiple verifications.",
                      style: TextStyle(fontSize: 11, color: Colors.blueGrey, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
