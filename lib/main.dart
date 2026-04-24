import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'dashboard_view.dart';
import 'gateway/multi_setup_view.dart'; // Nayi file Step 3 mein banayenge
import 'gateway/company_list_screen.dart'; // Nayi file Step 4 mein banayenge
import 'gateway/company_control_panel.dart'; // Nayi file Step 5 mein banayenge

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => PharoahManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      key: UniqueKey(), // Aapka purana logic preserved
      title: 'Pharoah ERP',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        cardTheme: const CardTheme(
          elevation: 3,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(15))),
        ),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      ),
      // Hume ab traffic control karne ke liye AppGateway chahiye
      home: const AppGateway(),
    );
  }
}

class AppGateway extends StatelessWidget {
  const AppGateway({super.key});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // STEP 1: Agar ek bhi company nahi hai toh Setup dikhao
    if (ph.companiesRegistry.isEmpty) {
      return MultiSetupView(isFirstRun: true);
    }

    // STEP 2: Agar company select nahi hui hai toh Selection Screen dikhao
    if (ph.activeCompany == null) {
      return const CompanyListScreen();
    }

    // STEP 3: Agar company select ho gayi par saal (FY) select nahi hua toh Control Panel dikhao
    if (ph.currentFY.isEmpty) {
      return const CompanyControlPanelView();
    }

    // STEP 4: Sab kuch set hai toh seedha Dashboard kholo
    return DashboardView(onLogout: () {
      ph.clearSession(); // Logout karne par wapas company list par
    });
  }
}
