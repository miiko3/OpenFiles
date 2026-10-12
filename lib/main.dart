import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/l10n.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/app_settings.dart';
import 'features/browser/browser_screen.dart';
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
    ),
  );
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  L10n.language = settings.language;
  L10n.notifier.value = settings.language;
  runApp(OpenFilesApp(settings: settings));
}
class OpenFilesApp extends StatelessWidget {
  const OpenFilesApp({super.key, required this.settings});
  final AppSettings settings;
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: settings,
      child: Consumer<AppSettings>(
        builder: (context, value, _) {
          return ValueListenableBuilder<AppLanguage>(
            valueListenable: L10n.notifier,
            builder: (context, _, __) {
              return MaterialApp(
                title: 'OpenFiles',
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                darkTheme: AppTheme.dark(),
                themeMode: value.flutterThemeMode,
                builder: (context, child) {
                  final media = MediaQuery.of(context);
                  return MediaQuery(
                    data: media.copyWith(
                      textScaler: TextScaler.linear(value.textScale),
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
                home: const BrowserScreen(),
              );
            },
          );
        },
      ),
    );
  }
}
