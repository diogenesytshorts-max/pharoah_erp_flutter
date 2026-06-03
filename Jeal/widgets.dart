import 'package:flutter/material.dart';
import 'models.dart'; // <--- YE LINE SABSE ZAROORI HAI

// --- 1. STAT WIDGET ---
class StatWidget extends StatelessWidget {
  final String title, value, period;
  final String icon; 
  final Color color;
  const StatWidget({super.key, required this.title, required this.value, required this.period, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    IconData getIconData(String name) {
      switch (name) {
        case "trending_up": return Icons.trending_up_rounded;
        case "shopping_cart": return Icons.shopping_cart_rounded;
        case "payments": return Icons.payments_rounded;
        case "inventory_2": return Icons.inventory_2_rounded;
        default: return Icons.analytics_rounded;
      }
    }
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 8))], border: Border.all(color: color.withOpacity(0.05), width: 1)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(getIconData(icon), color: color, size: 20)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: color.withOpacity(0.05), borderRadius: BorderRadius.circular(8)), child: Text(period.toUpperCase(), style: TextStyle(color: color, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
          ]),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A237E)))),
      ]),
    );
  }
}

// --- 2. ACTION ICON BUTTON ---
class ActionIconBtn extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const ActionIconBtn({super.key, required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(18), child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.grey.shade100, width: 1.5), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(height: 52, width: 52, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: color, size: 28)),
            const SizedBox(height: 10),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey.shade800)),
    ])));
  }
}

// --- 3. SMART GRID (REPLACEMENT CODE) ---
class PharoahSmartGrid extends StatelessWidget {
  final List<ModuleAction> actions;
  final Function(ModuleAction) onActionTap;

  const PharoahSmartGrid({
    super.key,
    required this.actions,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return ActionIconBtn(
          title: action.title,
          icon: action.icon,
          color: action.color,
          onTap: () => onActionTap(action),
        );
      },
    );
  }
}
