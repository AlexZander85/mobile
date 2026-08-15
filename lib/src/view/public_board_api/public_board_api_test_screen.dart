import 'dart:async';
import 'dart:math' as math;

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lichess_mobile/src/model/auth/auth_controller.dart';
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/model/public_board_api/public_board_api.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/widgets/board.dart';
import 'package:material_ui/material_ui.dart';

/// A deliberately small production-compatible shell for testing multiple premoves on lichess.org.
///
/// It uses public OAuth PKCE + the documented Board API instead of the official mobile app's
/// private `web:mobile` transport. That keeps the test build useful without copying or bypassing
/// Lichess deployment secrets.
class PublicBoardApiTestScreen extends ConsumerStatefulWidget {
  const PublicBoardApiTestScreen({super.key});

  @override
  ConsumerState<PublicBoardApiTestScreen> createState() => _PublicBoardApiTestScreenState();
}

class _PublicBoardApiTestScreenState extends ConsumerState<PublicBoardApiTestScreen> {
  Future<List<PublicBoardApiGame>>? _gamesFuture;
  bool _signingIn = false;
  String? _signInError;

  Future<void> _signIn() async {
    setState(() {
      _signingIn = true;
      _signInError = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).signIn();
      if (!mounted) return;
      setState(() => _gamesFuture = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _signInError = e.toString());
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).signOut();
    if (!mounted) return;
    setState(() => _gamesFuture = null);
  }

  void _refreshGames() {
    setState(() {
      _gamesFuture = ref.read(publicBoardApiRepositoryProvider).ongoingGames();
    });
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Multiple premoves • production test'),
        actions: [
          if (authUser != null)
            IconButton(
              onPressed: _refreshGames,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
          if (authUser != null)
            IconButton(onPressed: _signOut, icon: const Icon(Icons.logout), tooltip: 'Sign out'),
        ],
      ),
      body: SafeArea(
        child: authUser == null
            ? _SignedOutBody(signingIn: _signingIn, error: _signInError, onSignIn: _signIn)
            : _buildSignedIn(context, authUser.user.name),
      ),
    );
  }

  Widget _buildSignedIn(BuildContext context, String username) {
    _gamesFuture ??= ref.read(publicBoardApiRepositoryProvider).ongoingGames();

    return FutureBuilder<List<PublicBoardApiGame>>(
      future: _gamesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _CenteredMessage(
            title: 'Не удалось получить активные партии',
            body: '${snapshot.error}',
            action: FilledButton(onPressed: _refreshGames, child: const Text('Повторить')),
          );
        }

        final games = snapshot.data ?? const <PublicBoardApiGame>[];
        if (games.isEmpty) {
          return _CenteredMessage(
            title: 'В аккаунте $username нет активной партии',
            body:
                'Открой lichess.org и начни партию, затем нажми «Обновить». Для публичного Board '
                'API удобнее всего Rapid, Classical или Correspondence. Прямой вызов сопернику '
                'также позволяет проверить Blitz.',
            action: FilledButton.icon(
              onPressed: _refreshGames,
              icon: const Icon(Icons.refresh),
              label: const Text('Обновить'),
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Вход выполнен: $username', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text(
              'Выбери активную стандартную партию. Ходы будут идти через официальный Board API; '
              'очередь premove остаётся только на телефоне.',
            ),
            const SizedBox(height: 16),
            for (final game in games)
              Card(
                child: ListTile(
                  title: Text(
                    '${game.opponentName}${game.opponentRating != null ? ' • ${game.opponentRating}' : ''}',
                  ),
                  subtitle: Text(
                    '${game.speed} • ${game.variantKey} • '
                    '${game.side == Side.white ? 'белые' : 'чёрные'}'
                    '${game.isMyTurn ? ' • ваш ход' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PublicBoardGameTestScreen(game: game),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SignedOutBody extends StatelessWidget {
  const _SignedOutBody({required this.signingIn, required this.error, required this.onSignIn});

  final bool signingIn;
  final String? error;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      title: 'Вход в настоящий lichess.org',
      body:
          'Эта тестовая сборка использует публичный OAuth PKCE и запрашивает только право '
          'board:play. Пароль вводится на странице lichess.org в системном браузере и приложению '
          'не передаётся.',
      extra: error == null
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
      action: FilledButton.icon(
        onPressed: signingIn ? null : onSignIn,
        icon: signingIn
            ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.open_in_browser),
        label: Text(signingIn ? 'Открываю lichess.org…' : 'Войти через lichess.org'),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.title,
    required this.body,
    required this.action,
    this.extra,
  });

  final String title;
  final String body;
  final Widget action;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(body, textAlign: TextAlign.center),
              if (extra != null) extra!,
              const SizedBox(height: 20),
              action,
            ],
          ),
        ),
      ),
    );
  }
}

class PublicBoardGameTestScreen extends ConsumerStatefulWidget {
  const PublicBoardGameTestScreen({required this.game, super.key});

  final PublicBoardApiGame game;

  @override
  ConsumerState<PublicBoardGameTestScreen> createState() => _PublicBoardGameTestScreenState();
}

class _PublicBoardGameTestScreenState extends ConsumerState<PublicBoardGameTestScreen> {
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;
  ChessboardController? _controller;
  PublicBoardGameState? _authoritative;
  String? _initialFen;
  String? _variantKey;
  String? _error;
  bool _sendingMove = false;

  @override
  void initState() {
    super.initState();
    _streamSubscription = ref
        .read(publicBoardApiRepositoryProvider)
        .streamGame(widget.game.id)
        .listen(_onBoardApiEvent, onError: _onStreamError, onDone: _onStreamDone);
  }

  void _onBoardApiEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['type'];
    try {
      if (type == 'gameFull') {
        final variant = event['variant'] as Map<String, dynamic>? ?? const {};
        _initialFen = event['initialFen'] as String? ?? 'startpos';
        _variantKey = variant['key'] as String? ?? widget.game.variantKey;
        final state = event['state'] as Map<String, dynamic>;
        _applyAuthoritativeState(state, firstEvent: true);
      } else if (type == 'gameState') {
        _applyAuthoritativeState(event);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _applyAuthoritativeState(Map<String, dynamic> state, {bool firstEvent = false}) {
    final initialFen = _initialFen;
    final variantKey = _variantKey;
    if (initialFen == null || variantKey == null) return;

    final authoritative = publicBoardGameStateFromEvent(
      initialFen: initialFen,
      variantKey: variantKey,
      state: state,
    );
    final prefs = ref.read(boardPreferencesProvider);
    final variant = Variant.nameMap[variantKey] ?? Variant.standard;
    final playerSide = !authoritative.isPlaying
        ? PlayerSide.none
        : widget.game.side == Side.white
        ? PlayerSide.white
        : PlayerSide.black;
    final gameData = buildGameData(
      fen: authoritative.position.fen,
      variant: variant,
      position: authoritative.position,
      playerSide: playerSide,
      castlingMethod: prefs.castlingMethod,
      boardHighlights: prefs.boardHighlights,
      lastMove: authoritative.lastMove,
    );

    _authoritative = authoritative;
    if (_controller == null) {
      _controller = ChessboardController(game: gameData);
    } else {
      _controller!.updatePosition(gameData, animate: !firstEvent);
    }

    setState(() {
      _error = null;
      _sendingMove = false;
    });

    // Execute exactly one queued premove only after a real server update has made it our turn.
    // Remaining moves stay local until the opponent responds again.
    if (authoritative.isPlaying && authoritative.position.turn == widget.game.side) {
      tryExecutePremove(_controller!, authoritative.position, _sendMove);
    }
  }

  Future<void> _sendMove(Move move) async {
    if (_sendingMove) return;
    setState(() => _sendingMove = true);
    try {
      await ref.read(publicBoardApiRepositoryProvider).playMove(widget.game.id, move);
      // The authoritative stream will update the board. Do not send the next queued premove here.
    } catch (e) {
      if (!mounted) return;
      _restoreAuthoritativeAfterSendFailure();
      setState(() {
        _sendingMove = false;
        _error = 'Ход не принят сервером: $e';
      });
    }
  }

  void _restoreAuthoritativeAfterSendFailure() {
    final authoritative = _authoritative;
    final controller = _controller;
    if (authoritative == null || controller == null) return;
    final prefs = ref.read(boardPreferencesProvider);
    final variant = Variant.nameMap[authoritative.variantKey] ?? Variant.standard;
    controller.updatePosition(
      buildGameData(
        fen: authoritative.position.fen,
        variant: variant,
        position: authoritative.position,
        playerSide: widget.game.side == Side.white ? PlayerSide.white : PlayerSide.black,
        castlingMethod: prefs.castlingMethod,
        boardHighlights: prefs.boardHighlights,
        lastMove: authoritative.lastMove,
      ),
      animate: false,
      resetPremove: true,
    );
  }

  void _onStreamError(Object error, StackTrace stackTrace) {
    if (!mounted) return;
    setState(() => _error = 'Board API stream: $error');
  }

  void _onStreamDone() {
    if (!mounted) return;
    setState(() {
      if (_authoritative?.isPlaying == true && _error == null) {
        _error = 'Поток партии закрыт сервером.';
      }
    });
  }

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final prefs = ref.watch(boardPreferencesProvider);
    final variantKey = _variantKey ?? widget.game.variantKey;
    final variant = Variant.nameMap[variantKey] ?? Variant.standard;

    return Scaffold(
      appBar: AppBar(title: Text('vs ${widget.game.opponentName}')),
      body: SafeArea(
        child: controller == null
            ? _CenteredMessage(
                title: 'Подключаюсь к партии…',
                body: _error ?? 'Ожидаю первый gameFull от Board API.',
                action: const SizedBox.shrink(),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PremoveModeSelector(mode: prefs.premoveMode),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final size = math.min(constraints.maxWidth, 700.0);
                      return Center(
                        child: BoardWidget(
                          size: size,
                          orientation: widget.game.side,
                          settings: prefs.toBoardSettings(variant),
                          controller: controller,
                          onMove: (move, {viaDragAndDrop}) => _sendMove(move),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  AnimatedBuilder(
                    animation: controller,
                    builder: (context, _) {
                      final queue = controller.premoveQueue;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Очередь premove: ${queue.length}',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                if (queue.isNotEmpty)
                                  Text(queue.map((move) => move.uci).join(' → ')),
                                const SizedBox(height: 6),
                                Text(
                                  _sendingMove
                                      ? 'Отправляю один ход серверу…'
                                      : 'Сервер видит только текущий ход; хвост очереди остаётся на устройстве.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

class _PremoveModeSelector extends ConsumerWidget {
  const _PremoveModeSelector({required this.mode});

  final PremoveMode mode;

  String _label(PremoveMode value) => switch (value) {
    PremoveMode.multiple => 'Несколько',
    PremoveMode.single => 'Один',
    PremoveMode.disabled => 'Отключено',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Premoves', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final value in PremoveMode.values)
              ChoiceChip(
                label: Text(_label(value)),
                selected: mode == value,
                onSelected: (_) =>
                    ref.read(boardPreferencesProvider.notifier).setPremoveMode(value),
              ),
          ],
        ),
      ],
    );
  }
}
