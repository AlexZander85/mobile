import 'package:flutter/foundation.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n_esperanto/l10n_esperanto.dart';
import 'package:lichess_mobile/l10n/l10n.dart';
import 'package:lichess_mobile/src/binding.dart';
import 'package:lichess_mobile/src/init.dart';
import 'package:lichess_mobile/src/intl.dart';
import 'package:lichess_mobile/src/model/common/preloaded_data.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/general_preferences.dart';
import 'package:lichess_mobile/src/theme.dart';
import 'package:lichess_mobile/src/view/public_board_api/public_board_api_test_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Isolated entrypoint used only by the production Board API multiple-premove test APK.
///
/// It deliberately does not start the normal mobile application's websocket, challenge,
/// notification, message, correspondence or other `web:mobile` services. The test shell needs only
/// preferences, OAuth storage, the public Board API and the real chessboard widgets.
Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  final lichessBinding = AppLichessBinding.ensureInitialized();

  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  await lichessBinding.preloadSharedPreferences();
  await preloadPieceImages();

  if (defaultTargetPlatform == TargetPlatform.android) {
    await androidDisplayInitialization(widgetsBinding);
  }

  await initializeApp();
  await setupIntl(widgetsBinding);

  runApp(const ProviderScope(child: _PublicBoardApiBootstrap()));
}

class _PublicBoardApiBootstrap extends ConsumerWidget {
  const _PublicBoardApiBootstrap();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen<AsyncValue<PreloadedData>>(preloadedDataProvider, (_, state) {
      if (state.hasValue || state.hasError) FlutterNativeSplash.remove();
    });

    return switch (ref.watch(preloadedDataProvider)) {
      AsyncData() => const _PublicBoardApiApp(),
      AsyncError(:final error, :final stackTrace) => _BootstrapError(
        error: error,
        stackTrace: stackTrace,
      ),
      _ => const SizedBox.shrink(),
    };
  }
}

class _PublicBoardApiApp extends ConsumerWidget {
  const _PublicBoardApiApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generalPrefs = ref.watch(generalPreferencesProvider);
    final boardPrefs = ref.watch(boardPreferencesProvider);
    final theme = makeAppTheme(context, generalPrefs, boardPrefs);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        ...GlobalMaterialLocalizations.delegates,
        MaterialLocalizationsEo.delegate,
        CupertinoLocalizationsEo.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      title: 'Lichess multiple premoves test',
      locale: generalPrefs.locale,
      theme: theme,
      home: const PublicBoardApiTestScreen(),
    );
  }
}

class _BootstrapError extends StatelessWidget {
  const _BootstrapError({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Widget build(BuildContext context) {
    FlutterNativeSplash.remove();
    debugPrint('Public Board API bootstrap failed: $error\n$stackTrace');
    return MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Не удалось запустить тестовую сборку:\n$error'),
            ),
          ),
        ),
      ),
    );
  }
}
