import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/i18n/app_language.dart';
import 'core/i18n/app_localizations.dart';
import 'core/widgets/api_feedback.dart';
import 'features/auth/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    // The app also accepts API_URL and MAPS_API_KEY through --dart-define.
  }

  runApp(const ProviderScope(child: ParkFinderApp()));
}

class ParkFinderApp extends ConsumerWidget {
  const ParkFinderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLanguageProvider);
    return MaterialApp(
      navigatorKey: ApiFeedback.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      title: appNameFor(locale),
      home: const AuthGate(),
    );
  }
}
