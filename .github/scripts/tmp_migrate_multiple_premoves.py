from pathlib import Path

path = Path('lib/src/view/game/game_body.dart')
text = path.read_text()

init_old = '''    _controller = ChessboardController(
      game: buildGameData(
        fen: state.currentPosition.fen,
        variant: state.game.meta.variant,
        position: state.currentPosition,
        playerSide: _playerSide(state),
        lastMove: state.game.moveAt(state.stepCursor),
        castlingMethod: boardPrefs.castlingMethod,
        boardHighlights: boardPrefs.boardHighlights,
      ),
    );
  }

  @override
  void dispose() {'''

init_new = '''    _controller = ChessboardController(
      game: buildGameData(
        fen: state.currentPosition.fen,
        variant: state.game.meta.variant,
        position: state.currentPosition,
        playerSide: _playerSide(state),
        lastMove: state.game.moveAt(state.stepCursor),
        castlingMethod: boardPrefs.castlingMethod,
        boardHighlights: boardPrefs.boardHighlights,
      ),
    );
    _applyPremoveMode(boardPrefs.premoveMode);
  }

  void _applyPremoveMode(PremoveMode mode) {
    if (!mode.enabled && _controller.premove != null) {
      _controller.clearPremoves();
    }
    _controller.maxPremoveCount = mode.maxCount;
  }

  @override
  void dispose() {'''

if init_old not in text:
    raise SystemExit('initState anchor not found')
text = text.replace(init_old, init_new, 1)

build_old = '''    final boardPrefs = ref.watch(boardPreferencesProvider);
    final blindfoldMode = ref.watch('''

build_new = '''    ref.listen(
      boardPreferencesProvider.select((prefs) => prefs.premoveMode),
      (previous, next) => _applyPremoveMode(next),
    );

    final boardPrefs = ref.watch(boardPreferencesProvider);
    final blindfoldMode = ref.watch('''

if build_old not in text:
    raise SystemExit('build anchor not found')
text = text.replace(build_old, build_new, 1)
path.write_text(text)
