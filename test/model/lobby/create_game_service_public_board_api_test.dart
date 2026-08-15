import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lichess_mobile/src/constants.dart';
import 'package:lichess_mobile/src/model/lobby/create_game_service.dart';
import 'package:lichess_mobile/src/model/lobby/game_seek.dart';
import 'package:lichess_mobile/src/network/http.dart';

import '../../network/fake_http_client_factory.dart';
import '../../test_container.dart';
import '../auth/fake_auth_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'public Board API seek resolves the new account game without a lobby socket',
    () async {
      var playingReads = 0;
      final requests = <http.Request>[];
      final mockClient = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path == '/api/account/playing') {
          playingReads++;
          if (playingReads == 1) return http.Response('{"nowPlaying":[]}', 200);
          return http.Response(
            jsonEncode({
              'nowPlaying': [
                {
                  'gameId': 'abcd1234',
                  'fullId': 'abcd1234wxyz',
                  'color': 'white',
                  'fen': 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
                  'perf': 'rapid',
                  'speed': 'rapid',
                  'variant': 'standard',
                  'isMyTurn': true,
                },
              ],
            }),
            200,
          );
        }
        if (request.method == 'POST' && request.url.path == '/api/board/seek') {
          return http.Response('', 200);
        }
        return http.Response('', 404);
      });

      final container = await makeContainer(
        authUser: fakeAuthUser,
        overrides: {
          httpClientFactoryProvider: httpClientFactoryProvider.overrideWith((ref) {
            return FakeHttpClientFactory(() => mockClient);
          }),
        },
      );
      addTearDown(container.dispose);

      final response = await container
          .read(createGameServiceProvider)
          .newLobbyGame(const GameSeek(clock: (Duration(minutes: 10), Duration.zero), rated: false));

      expect(response, isA<GameSeekCreated>());
      expect((response as GameSeekCreated).fullId.value, 'abcd1234wxyz');
      expect(requests.any((r) => r.method == 'POST' && r.url.path == '/api/board/seek'), isTrue);
    },
    skip: !kPublicBoardApiTest,
  );
}
