// ... (Purane imports)
import 'purchase/purchase_modify_view.dart'; // Naya import add karein

// ... (Baaki code dashboard ka same rahega, grid buttons mein ye add karein)

GridView.count(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  crossAxisCount: 3,
  crossAxisSpacing: 12,
  mainAxisSpacing: 12,
  childAspectRatio: 0.85,
  children: [
    ActionIconBtn(
      title: "New Sale",
      icon: Icons.add_shopping_cart_rounded,
      color: Colors.green,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleEntryView())),
    ),
    ActionIconBtn(
      title: "Purchase",
      icon: Icons.file_download_outlined,
      color: Colors.orange,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseEntryView())),
    ),
    // --- NAYA BUTTON: PURCHASE REGISTER ---
    ActionIconBtn(
      title: "Pur. Reg",
      icon: Icons.history_toggle_off_rounded,
      color: Colors.deepOrange,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const PurchaseModifyView())),
    ),
    ActionIconBtn(
      title: "Sales Edit",
      icon: Icons.edit_note_rounded,
      color: Colors.blue,
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const SaleBillModifyView())),
    ),
    // ... baaki buttons same
  ],
),
