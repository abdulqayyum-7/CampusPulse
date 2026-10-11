import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'core/config.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';

void main() => runApp(const CuiApp());

class CuiApp extends StatelessWidget {
  const CuiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Builder(builder: (context) {
        final st = context.read<AppState>();
        return MaterialApp(
          title: 'CampusPulse',
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: st.messengerKey,
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(seedColor: kBlue),
            textTheme: GoogleFonts.interTextTheme(),
            scaffoldBackgroundColor: const Color(0xFFF4F6FA),
          ),
          home: Consumer<AppState>(builder: (_, s, __) => s.user == null ? const LoginScreen() : const HomeScreen()),
        );
      }),
    );
  }
}
