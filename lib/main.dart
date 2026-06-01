import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/auth_service.dart';
import 'login.dart';
import 'regit.dart';
import 'night_dump_page.dart';
import 'notes.dart';
import 'history.dart';
import 'insights.dart';
import 'tasks.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Night Dump',
      routes: {
        '/login':    (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),
        '/home':     (_) => const NightDumpPage(),
        '/notes':    (_) => const Notes(),
        '/history':  (_) => const History(),
        '/insights': (_) => const InsightsScreen(),
        '/tasks':    (_) => const TasksPage(),
      },
      home: const _SplashScreen(),
    );
  }
}

class _SplashScreen extends StatefulWidget {
  const _SplashScreen();

  @override
  State<_SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<_SplashScreen> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final loggedIn = await AuthService().isLoggedIn();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, loggedIn ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF050B2C),
      body: Center(
        child: CircularProgressIndicator(
          color: Color(0xFFD1B3FF),
          strokeWidth: 2,
        ),
      ),
    );
  }
}
