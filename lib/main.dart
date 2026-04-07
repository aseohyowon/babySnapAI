import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/di/service_locator.dart';
import 'core/locale/app_locale.dart';
import 'core/services/ad_service.dart';
import 'core/theme/app_theme.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppLocaleNotifier.instance.init();
  await ServiceLocator.initialize();
  await MobileAds.instance.initialize();
  AdService.instance.loadInterstitial();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _showOnboarding = false;
  bool _showSplash = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFirstLaunch();
  }

  Future<void> _checkFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isOnboardingComplete = prefs.getBool('onboarding_complete') ?? false;

    if (mounted) {
      setState(() {
        _showOnboarding = !isOnboardingComplete;
        _isLoading = false;
      });
    }
  }

  void _completeSplash() {
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocaleNotifier.instance,
      builder: (_, __) {
        final locale = AppLocaleNotifier.instance.locale;
        if (_isLoading) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getDarkTheme(),
            locale: locale,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ko'), Locale('en')],
            home: Scaffold(
              backgroundColor: AppTheme.backgroundColor,
              body: Center(
                child: CircularProgressIndicator(
                  valueColor:
                      AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.getDarkTheme(),
          title: 'BabySnap AI',
          locale: locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('ko'), Locale('en')],
          routes: {
            '/home': (context) => const HomeScreen(),
          },
          home: _showSplash
              ? SplashScreen(onComplete: _completeSplash)
              : _showOnboarding
                  ? OnboardingScreen(
                      onComplete: () {
                        setState(() => _showOnboarding = false);
                      },
                    )
                  : const HomeScreen(),
        );
      },
    );
  }
}
