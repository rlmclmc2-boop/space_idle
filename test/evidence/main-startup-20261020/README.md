# Main player entry startup verification (2026-10-20)

This documents the earlier one-time acceptance-anchor change. Its limitations were found during review; the current candidate and its repeated-launch verification are in [robust-entry.md](robust-entry.md).

Source tested: `main` at `24f0751d5acd698eeb06d8ec7f0eb02e34a09e94`, with the `tools/play_main.py` change from `c4c0d7516b8271bddfec7cbab24a76a71dd717ae` applied in the isolated checkout before that change was committed on `fix/main-startup`. No other tracked runtime source changed for this test.

The unmodified entry first stopped before Godot started because its acceptance anchor was `fda7be2c217a208067f97266f85497b83cbdd840`, and the already committed runtime files between that anchor and `24f0751d` appeared in the rejection list. Advancing the anchor to the current main commit resolved this rejection while retaining the source and DLL checks.

Verification on Windows with Godot `4.7.2.stable.official.ed1daf0bf`:

```powershell
python tools/play_main.py --install-native
$env:SPACE_BATTLESHIP_VERIFY_WINDOW='1'
$env:SPACE_BATTLESHIP_VERIFY_QUIT_AFTER_FRAMES='120'
python tools/play_main.py
```

The matching bundled DLL installed successfully (SHA-256 `137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78`). The import completed, the game process ran for 120 frames, and the launcher exited with code **0**. The runtime receipt recorded game data SHA-256 `6e824478461d81f4e5679899d18aed892b5b2bf91e332c6b4522a902caa7bd0f` and accepted runtime `24f0751d`.

The local import log SHA-256 was `4b9b28e0c683bebdc575977a7e6b1119c33d8df8d1155c521e3b31fb9026e0a5`; the attached [game log](player-game-log.txt) SHA-256 was `4075b7e878d2d7113cc2e60697daf1dd0ef84c8b82327ecb50a6c9d8d7a66892`. Both logs contained the same nonfatal Windows root certificate store error. The game log reported OpenGL 3.3 compatibility rendering on an NVIDIA GeForce RTX 2060. No script error appeared in either log.

This is an entry startup check, not a gameplay acceptance test. The fix remains on its branch for review before any main merge.
