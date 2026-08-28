import 'package:flutter/material.dart';
import 'features/admin/admin_dashboard.dart';
import 'features/patient_qr/patient_qr_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inpatient Companion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF166568),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF2D3748),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        // Handle web routing (e.g., /#/patient?token=XYZ)
        final uri = Uri.parse(settings.name ?? '/');

        // Check if the route is the patient dashboard
        if (uri.path == '/patient') {
          final token = uri.queryParameters['token'];
          if (token != null && token.isNotEmpty) {
            return MaterialPageRoute(
              builder: (context) => PatientQrPage(qrToken: token),
            );
          }
        }

        // Default route (Admin Dashboard)
        return MaterialPageRoute(
          builder: (context) => const AdminDashboard(),
        );
      },
    );
  }
}
