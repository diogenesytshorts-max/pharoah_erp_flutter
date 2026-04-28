import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pharoah_manager.dart';
import 'dashboard_view.dart';
import 'login_view.dart';
import 'gateway/multi_setup_view.dart';
import 'gateway/company_list_screen.dart';
import 'gateway/company_control_panel.dart';
import 'main_control_shell.dart'; // NAYA

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

    if (ph.companiesRegistry.isEmpty) {
      return const MultiSetupView(isFirstRun: true);
    }
    if (ph.activeCompany == null) {
      return const CompanyListScreen();
    }
    if (ph.currentFY.isEmpty) {
      return const CompanyControlPanelView();
    }
    if (!ph.isAdminAuthenticated) {
      return const LoginView();
    }

    return const MainControlShell();
  }
}
