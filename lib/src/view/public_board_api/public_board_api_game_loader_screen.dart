import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/public_board_api/public_board_api.dart';
import 'package:lichess_mobile/src/view/public_board_api/public_board_api_test_screen.dart';
import 'package:material_ui/material_ui.dart';

/// Resolves an active Lichess game id through the public account playing endpoint and opens the
/// production-compatible Board API game screen.
///
/// This adapter lets the normal Lichess UI keep using [GameScreen.buildRoute] while fork builds
/// transparently replace only the transport of active games. Finished games continue through the
/// regular read-only game screen.
class PublicBoardApiGameLoaderScreen extends ConsumerStatefulWidget {
  const PublicBoardApiGameLoaderScreen({required this.gameId, super.key});

  final String gameId;

  @override
  ConsumerState<PublicBoardApiGameLoaderScreen> createState() =>
      _PublicBoardApiGameLoaderScreenState();
}

class _PublicBoardApiGameLoaderScreenState extends ConsumerState<PublicBoardApiGameLoaderScreen> {
  late Future<PublicBoardApiGame> _gameFuture;

  @override
  void initState() {
    super.initState();
    _gameFuture = _loadGame();
  }

  Future<PublicBoardApiGame> _loadGame() async {
    final games = await ref.read(publicBoardApiRepositoryProvider).ongoingGames();
    for (final game in games) {
      if (game.id == widget.gameId) return game;
    }
    throw StateError(
      'Игра ${widget.gameId} не найдена среди активных партий. '
      'Обновите список партий и попробуйте снова.',
    );
  }

  void _retry() {
    setState(() {
      _gameFuture = _loadGame();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PublicBoardApiGame>(
      future: _gameFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData) {
          return PublicBoardGameTestScreen(game: snapshot.requireData, showDiagnostics: false);
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Lichess')),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sync_problem, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Не удалось открыть активную партию',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
