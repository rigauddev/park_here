import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/i18n/app_language.dart';
import 'features/auth/pages/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await dotenv.load(fileName: ".env");
    } catch (_) {
      // The app also accepts API_URL through --dart-define.
    }
  }

  runApp(const ProviderScope(child: ParkFinderApp()));
}

class ParkFinderApp extends ConsumerWidget {
  const ParkFinderApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLanguageProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: locale,
      supportedLocales: const [Locale('pt', 'BR'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      title: appNameFor(locale),
      home: const AuthGate(),
    );
  }
}
