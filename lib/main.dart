import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../pages/login_page.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://qwwegimfmcvsctshnehb.supabase.co',
    publishableKey: 'sb_publishable_3j23mtdEkdsc3zOSLc4hpQ_oRPfgkXP',
  );
  await NotificationService.initialize();

  runApp(const ClassScheduleApp());
}

final supabase = Supabase.instance.client;

class ClassScheduleApp extends StatelessWidget {
  const ClassScheduleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Class Schedule',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}