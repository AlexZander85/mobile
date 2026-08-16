import 'dart:convert';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' show Request;
import 'package:lichess_mobile/src/model/common/chess.dart';
import 'package:lichess_mobile/src/network/http.dart';

final publicBoardApiRepositoryProvider = Provider<PublicBoardApiRepository>((ref) {
  return PublicBoardApiRepository(ref.watch(lichessClientProvider));
}, name: 'PublicBoardApiRepositoryProvider');

/// Minimal description of an ongoing game returned by `GET /api/account/playing`.
class PublicBoardApiGame {
  const PublicBoardApiGame({
    required this.id,
    required this.side,
    required this.opponentName,
    required this.opponentRating,
    required this.speed,
    required this.variantKey,
    required this.isMyTurn,
  });

  final String id;
  final Side side;
  final String opponentName;
  final int? opponentRating;
  final String speed;
  final String variantKey;
  final bool isMyTurn;

  factory PublicBoardApiGame.fromJson(Map<String, dynamic> json) {
    final opponent = json['opponent'] as Map<String, dynamic>? ?? const {};
    final variant = json['variant'] as Map<String, dynamic>? ?? const {};
    return PublicBoardApiGame(
      id: json['gameId'] as String,
      side: json['color'] == 'black' ? Side.black : Side.white,
      opponentName:
          opponent['username'] as String? ?? opponent['name'] as String? ?? 'Anonymous opponent',
      opponentRating: (opponent['rating'] as num?)?.toInt(),
      speed: json['speed'] as String? ?? 'unknown',
      variantKey: variant['key'] as String? ?? 'standard',
      isMyTurn: json['isMyTurn'] as bool? ?? false,
    );
  }
}

/// Authoritative position reconstructed from a Board API `gameFull`/`gameState` event.
class PublicBoardGameState {
  const PublicBoardGameState({
    required this.initialFen,
    required this.variantKey,
    required this.position,
    required this.lastMove,
    required this.status,
    required this.whiteTimeMs,
    required this.blackTimeMs,
  });

  final String initialFen;
  final String variantKey;
  final Position position;
  final Move? lastMove;
  final String status;
  final int? whiteTimeMs;
  final int? blackTimeMs;

  bool get isPlaying => status == 'started' || status == 'created';
}

class PublicBoardApiRepository {
  const PublicBoardApiRepository(this.client);

  final LichessClient client;

  Future<List<PublicBoardApiGame>> ongoingGames() {
    return client.readJson(
      Uri(path: '/api/account/playing', queryParameters: const {'nb': '20'}),
      mapper: (json) {
        final games = json['nowPlaying'] as List<dynamic>? ?? const [];
        return games
            .whereType<Map<String, dynamic>>()
            .map(PublicBoardApiGame.fromJson)
            .toList(growable: false);
      },
    );
  }

  /// Streams Board API events as decoded JSON objects.
  ///
  /// The low-level [LichessClient.send] method does not resolve relative URIs, so this request uses
  /// an absolute [lichessUri]. Authentication is still attached by [LichessClient].
  Stream<Map<String, dynamic>> streamGame(String gameId) async* {
    final request = Request('GET', lichessUri('/api/board/game/stream/$gameId'))
      ..headers['Accept'] = 'application/x-ndjson';
    final response = await client.send(request);
    if (response.statusCode != 200) {
      await response.stream.drain<void>();
      throw Exception('Board API stream failed with HTTP ${response.statusCode}.');
    }

    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>);
  }

  Future<void> playMove(String gameId, Move move) async {
    // Lichess Board API uses Chess960-compatible castling notation (king takes rook), even for
    // standard chess. The helper converts e1g1/e1c1 style moves when necessary.
    final uci = normalizeUci(move.uci);
    await client.postRead(Uri(path: '/api/board/game/$gameId/move/$uci'));
  }
}

/// Reconstructs the authoritative board from the initial position plus the Board API UCI mainline.
///
/// The production tester intentionally supports the standard/chess960/from-position family first;
/// these all use dartchess' [Chess] rule implementation and cover normal Lichess games used for
/// multiple-premove testing. Other variants remain available in the normal app and can be added to
/// this transport adapter independently.
PublicBoardGameState publicBoardGameStateFromEvent({
  required String initialFen,
  required String variantKey,
  required Map<String, dynamic> state,
}) {
  if (!const {'standard', 'chess960', 'fromPosition'}.contains(variantKey)) {
    throw UnsupportedError('Board API test mode does not support the $variantKey variant yet.');
  }

  Position position = initialFen == 'startpos'
      ? Chess.initial
      : Chess.fromSetup(Setup.parseFen(initialFen));

  Move? lastMove;
  final movesText = state['moves'] as String? ?? '';
  if (movesText.trim().isNotEmpty) {
    for (final uci in movesText.trim().split(RegExp(r'\s+'))) {
      final move = Move.parse(uci);
      if (move == null) throw FormatException('Invalid Board API UCI move: $uci');
      if (!position.isLegal(move)) {
        throw StateError('Board API move $uci is illegal in ${position.fen}.');
      }
      position = position.playUnchecked(move);
      lastMove = move;
    }
  }

  return PublicBoardGameState(
    initialFen: initialFen,
    variantKey: variantKey,
    position: position,
    lastMove: lastMove,
    status: state['status'] as String? ?? 'started',
    whiteTimeMs: (state['wtime'] as num?)?.toInt(),
    blackTimeMs: (state['btime'] as num?)?.toInt(),
  );
}
