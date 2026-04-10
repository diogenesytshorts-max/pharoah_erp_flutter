import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pharoah_manager.dart';
import 'dashboard_view.dart';
import 'setup_view.dart';
import 'login_view.dart';

void main() async {
  // Ensure Flutter engine is ready before starting the app
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => PharoahManager(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool isSetupDone = false;
  bool isLoggedIn = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialState();
  }

  // --- APP FLOW LOGIC ---
  // Yeh function check karega ki Company Setup ho chuka hai ya nahi
  Future<void> _checkInitialState() async {
    final prefs = await SharedPreferences.getInstance();
    
    setState(() {
      // Agar 'isSetupDone' true hai, matlab user setup kar chuka hai
      isSetupDone = prefs.getBool('isSetupDone') ?? false;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Jab tak check ho raha hai, Loading spinner dikhao
    if (isLoading) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp(
      key: UniqueKey(),
      title: 'Pharoah ERP',
      debugShowCheckedModeBanner: false,
      
      // Professional Blue Theme for ERP
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D47A1)),
        cardTheme: CardTheme(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
        ),
      ),

      // --- HOME NAVIGATION LOGIC ---
      // 1. Agar Setup nahi hua -> SetupView
      // 2. Agar Setup ho gaya par Login nahi hai -> LoginView
      // 3. Sab sahi hai toh -> DashboardView
      home: !isSetupDone 
          ? SetupView(onComplete: () => setState(() => isSetupDone = true))
          : (!isLoggedIn 
              ? LoginView(onLogin: () => setState(() => isLoggedIn = true)) 
              : DashboardView(onLogout: () => setState(() => isLoggedIn = false))),
    );
  }
}
