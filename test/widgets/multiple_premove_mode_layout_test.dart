import 'dart:convert';

import 'package:chessground/chessground.dart';
import 'package:dartchess/dartchess.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lichess_mobile/src/model/game/game_board_params.dart';
import 'package:lichess_mobile/src/model/settings/board_preferences.dart';
import 'package:lichess_mobile/src/model/settings/preferences_storage.dart';
import 'package:lichess_mobile/src/widgets/game_layout.dart';
import 'package:material_ui/material_ui.dart';

import '../test_provider_scope.dart';

GameData _game(String fen, Side sideToMove) =>
    GameData(
      fen: fen,
      playerSide: PlayerSide.white,
      sideToMove: sideToMove,
      validMoves: const <Square, Set<Square>>{},
    );

NormalMove _move(Square from, Square to) => NormalMove(from: from, to: to);

void main() {
  testWidgets('GameLayout applies premove mode changes to its controller', (tester) async {
    final controller = ChessboardController(
      game: _game('7k/8/8/8/8/8/6K1/8 b - - 0 1', Side.black),
    );
    addTearDown(controller.dispose);

    final app = await makeTestProviderScope(
      tester,
      defaultPreferences: {
        PrefCategory.board.storageKey: jsonEncode(
          BoardPrefs.defaults.copyWith(pieceAnimation: false, multiplePremoves: true).toJson(),
        ),
      },
      child: MaterialApp(
        home: GameLayout(
          orientation: Side.white,
          controllerParams: ControllerBoardParams(
            controller: controller,
            variant: Variant.standard,
            onMove: (move, {viaDragAndDrop}) {},
          ),
        ),
      ),
    );
    await tester.pumpWidget(app);

    expect(controller.maxPremoveCount, kMultiplePremoveLimit);

    final first = _move(Square.g2, Square.f2);
    controller
      ..premove = first
      ..premove = _move(Square.f2, Square.e2);
    expect(controller.premoveQueue, hasLength(2));

    final container = ProviderScope.containerOf(tester.element(find.byType(GameLayout)));
    await container.read(boardPreferencesProvider.notifier).setPremoveMode(PremoveMode.single);
    await tester.pump();

    expect(controller.maxPremoveCount, 1);
    expect(controller.premoveQueue, [first]);

    await container.read(boardPreferencesProvider.notifier).setPremoveMode(PremoveMode.disabled);
    await tester.pump();

    expect(controller.maxPremoveCount, 1);
    expect(controller.premoveQueue, isEmpty);
  });
}
