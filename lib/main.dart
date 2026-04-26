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
      home: const AppGateway(),
    );
  }
}

class AppGateway extends StatelessWidget {
  const AppGateway({super.key});

  @override
  Widget build(BuildContext context) {
    final ph = Provider.of<PharoahManager>(context);

    // STEP 1: Agar ek bhi company register nahi hai -> Naya Detailed Setup dikhao
    if (ph.companiesRegistry.isEmpty) {
      return const MultiSetupView(isFirstRun: true);
    }

    // STEP 2: Agar company select nahi hui -> Company Selection List dikhao
    if (ph.activeCompany == null) {
      return const CompanyListScreen();
    }

    // STEP 3: Company select ho gayi, ab Login zaroori hai (Pehle Login aayega)
    if (!ph.isAdminAuthenticated) {
      return const LoginView();
    }

    // STEP 4: Login ho gaya par saal (FY) select nahi hua -> Control Panel dikhao
    if (ph.currentFY.isEmpty) {
      return const CompanyControlPanelView();
    }

    // STEP 5: Sab kuch sahi hai -> Seedha Dashboard kholo
    return DashboardView(onLogout: () {
      ph.clearSession(); 
    });
  }
}
