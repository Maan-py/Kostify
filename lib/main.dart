// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'controllers/auth_controller.dart';
import 'controllers/tenant_controller.dart';
import 'services/connectivity_service.dart';
import 'views/auth/login_screen.dart';
import 'views/admin/admin_dashboard_screen.dart';
import 'views/admin/add_tenant_screen.dart';
import 'views/admin/tenant_detail_screen.dart';
import 'views/tenant/tenant_dashboard_screen.dart';
import 'views/shared/saran_kesan_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await dotenv.load(fileName: ".env");
  await SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark));
  runApp(const KostifyApp());
}

class KostifyApp extends StatelessWidget {
  const KostifyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Kostify',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8095E4)),
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          titleTextStyle: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A2E)),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF8095E4).withOpacity(0.15),
          labelTextStyle: WidgetStateProperty.all(
              const TextStyle(fontSize: 11, fontFamily: 'Poppins')),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8095E4),
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(
                fontFamily: 'Poppins', fontWeight: FontWeight.w600),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12))),
        dialogTheme: DialogThemeData(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16))),
      ),
      initialBinding: AppBinding(),
      initialRoute: '/splash',
      getPages: AppRoutes.pages,
      defaultTransition: Transition.cupertino,
      transitionDuration: const Duration(milliseconds: 250),
    );
  }
}

class AppBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AuthController(), permanent: true);
    Get.put(ConnectivityService(), permanent: true);
    Get.lazyPut(() => TenantController());
  }
}

class AppRoutes {
  static final pages = [
    GetPage(name: '/splash', page: () => const SplashScreen()),
    GetPage(name: '/login', page: () => const LoginScreen()),
    GetPage(name: '/admin/dashboard', page: () => const AdminDashboardScreen()),
    GetPage(name: '/admin/add-tenant', page: () => const AddTenantScreen()),
    GetPage(
        name: '/admin/tenant-detail', page: () => const TenantDetailScreen()),
    GetPage(name: '/admin/saran-kesan', page: () => const SaranKesanScreen()),
    GetPage(
        name: '/tenant/dashboard', page: () => const TenantDashboardScreen()),
    GetPage(name: '/tenant/saran-kesan', page: () => const SaranKesanScreen()),
  ];
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale, _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _scale = Tween<double>(begin: 0.6, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      final auth = AuthController.to;
      Get.offAllNamed(auth.isLoggedIn
          ? (auth.isAdmin ? '/admin/dashboard' : '/tenant/dashboard')
          : '/login');
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF8095E4),
      body: Center(
        child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
                scale: _scale,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: const [
                            BoxShadow(
                                color: Colors.black12,
                                blurRadius: 24,
                                offset: Offset(0, 10))
                          ]),
                      child: const Icon(Icons.home_work_rounded,
                          color: Color(0xFF8095E4), size: 56),
                    ),
                    const SizedBox(height: 24),
                    const Text('Kostify',
                        style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5)),
                    const SizedBox(height: 6),
                    const Text('Smart Boarding Management System',
                        style: TextStyle(fontSize: 12, color: Colors.white70)),
                    const SizedBox(height: 64),
                    const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white54)),
                  ],
                ))),
      ),
    );
  }
}
