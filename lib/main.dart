import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'screens/auth_gate.dart';
import 'package:google_fonts/google_fonts.dart';

const String supabaseUrl = 'https://qnhehugabdbdgdjfiaga.supabase.co';
const String supabaseAnonKey = 'sb_publishable_QLmUoW783yRk88VgNbSRcg_fdCEQxmR';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey, // renamed from anonKey
  );
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
  title: 'Notes',
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    colorSchemeSeed: const Color.fromARGB(255, 42, 19, 81),
    useMaterial3: true,
    textTheme: GoogleFonts.poppinsTextTheme(),
  ),
  home: const AuthGate(),
   );
  }
}
