import 'package:flutter/material.dart';
import 'screens/buyer/buyer_shell.dart';
import 'screens/splash/brand_splash_screen.dart';
import 'screens/driver/auth/driver_splash_screen.dart';
import 'screens/driver/driver_shell.dart';
import 'screens/logistics/logistics_shell.dart';
import 'screens/pickup_courier/courier_dashboard.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BuyTheWay',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF14B8A6),
        ),
      ),
      home: const BrandSplashScreen(),
      routes: {
        '/home': (context) => const BuyerShell(),

        '/courier_dashboard': (context) => const CourierDashboard(),
        '/driver': (context) => const DriverSplashScreen(),
        '/driver_dashboard': (context) => const DriverShell(),
        '/logistics_dashboard': (context) => const LogisticsShell(),
      },
    );
  }
}