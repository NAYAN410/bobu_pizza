import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/splash_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/checkout_screen.dart';
import 'screens/error_screen.dart';
import 'screens/address_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/help_faq_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'services/theme_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );

  final themeService = ThemeService();
  await themeService.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService(),
      builder: (context, child) {
        final themeService = ThemeService();
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Bobu Pizza',
          themeMode: themeService.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFC72B1C)),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFFFF8F0),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFC72B1C),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFF121212),
          ),
          initialRoute: '/',
          routes: {
            '/': (context) => const SplashScreen(),
            '/onboarding': (context) => const OnboardingScreen(),
            '/login': (context) => const LoginScreen(),
            '/home': (context) => const MainScreen(),
            '/checkout': (context) => const CheckoutScreen(),
            '/error': (context) => const ErrorScreen(),
            '/addresses': (context) => const AddressScreen(),
            '/edit-profile': (context) => const EditProfileScreen(),
            '/help-faq': (context) => const HelpFaqScreen(),
            '/privacy-policy': (context) => const PrivacyPolicyScreen(),
          },
        );
      },
    );
  }
}
