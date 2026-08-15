import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/public_board_api/public_board_api.dart';

void main() {
  group('publicBoardGameStateFromEvent', () {
    test('reconstructs a standard position from Board API UCI moves', () {
      final state = publicBoardGameStateFromEvent(
        initialFen: 'startpos',
        variantKey: 'standard',
        state: const {
          'type': 'gameState',
          'moves': 'e2e4 e7e5 g1f3',
          'wtime': 59000,
          'btime': 58000,
          'status': 'started',
        },
      );

      expect(
        state.position.fen,
        startsWith('rnbqkbnr/pppp1ppp/8/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq'),
      );
      expect(state.lastMove, NormalMove.fromUci('g1f3'));
      expect(state.whiteTimeMs, 59000);
      expect(state.blackTimeMs, 58000);
      expect(state.isPlaying, isTrue);
    });

    test('accepts an explicit FEN as the authoritative initial position', () {
      final state = publicBoardGameStateFromEvent(
        initialFen: '8/8/8/8/8/8/4K3/7k w - - 0 1',
        variantKey: 'fromPosition',
        state: const {
          'moves': 'e2e3',
          'wtime': 1000,
          'btime': 1000,
          'status': 'started',
        },
      );

      expect(state.position.fen, startsWith('8/8/8/8/8/4K3/8/7k b - -'));
    });

    test('rejects malformed UCI instead of silently desynchronizing', () {
      expect(
        () => publicBoardGameStateFromEvent(
          initialFen: 'startpos',
          variantKey: 'standard',
          state: const {'moves': 'e2e4 definitely-not-uci', 'status': 'started'},
        ),
        throwsFormatException,
      );
    });

    test('keeps unsupported variants out of the production transport adapter', () {
      expect(
        () => publicBoardGameStateFromEvent(
          initialFen: 'startpos',
          variantKey: 'atomic',
          state: const {'moves': '', 'status': 'started'},
        ),
        throwsUnsupportedError,
      );
    });
  });

  test('ongoing-game JSON preserves side and opponent data', () {
    final game = PublicBoardApiGame.fromJson(const {
      'gameId': 'abcdefgh',
      'color': 'black',
      'speed': 'rapid',
      'variant': {'key': 'standard'},
      'isMyTurn': false,
      'opponent': {'username': 'Opponent', 'rating': 1900},
    });

    expect(game.id, 'abcdefgh');
    expect(game.side, Side.black);
    expect(game.opponentName, 'Opponent');
    expect(game.opponentRating, 1900);
    expect(game.variantKey, 'standard');
  });
}
