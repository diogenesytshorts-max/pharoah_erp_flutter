// FILE: lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'dashboard_view.dart';
import 'login_view.dart';
import 'gateway/multi_setup_view.dart';
import 'gateway/company_list_screen.dart';
import 'gateway/company_control_panel.dart';

void main() async {
  // Flutter engine ko initialize karna zaroori hai
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
      // UniqueKey force refresh mein madad karta hai jab hum company switch karte hain
      key: UniqueKey(), 
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
        appBarTheme: const AppBarTheme(
          centerTitle: false, 
          elevation: 0,
          backgroundColor: Color(0xFF0D47A1),
          foregroundColor: Colors.white,
        ),
      ),
      // Entry point ab AppGateway hai
      home: const AppGateway(),
    );
  }
}

class AppGateway extends StatelessWidget {
  const AppGateway({super.key});

  @override
  Widget build(BuildContext context) {
    // PharoahManager se app ki current state puchhna
    final ph = Provider.of<PharoahManager>(context);

    // STEP 1: Agar ek bhi company register nahi hai -> Naya Detailed Setup dikhao
    if (ph.companiesRegistry.isEmpty) {
      return const MultiSetupView(isFirstRun: true);
    }

    // STEP 2: Agar company select nahi hui -> Company Selection List dikhao
    if (ph.activeCompany == null) {
      return const CompanyListScreen();
    }

    // STEP 3: Dukan select ho gayi par saal (FY) select nahi hua -> Control Panel dikhao
    if (ph.currentFY.isEmpty) {
      return const CompanyControlPanelView();
    }

    // STEP 4: FY select ho gaya, ab Admin login zaroori hai (New Security Layer)
    if (!ph.isAdminAuthenticated) {
      return const LoginView();
    }

    // STEP 5: Sab kuch sahi hai -> Seedha Dashboard kholo
    return DashboardView(onLogout: () {
      // Logout karne par session clear hoga aur user Company List par chala jayega
      ph.clearSession(); 
    });
  }
}
