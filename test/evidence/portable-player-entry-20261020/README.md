# Windows player entry verification — 2026-10-20

Candidate branch: `fix/main-startup`. Base GitHub `main`: `d2293ce92733766b51bd1aa4f54bec6ea265fd0f`. This evidence describes a candidate; it does not claim the player's checkout has received it.

## Root cause in the player's checkout

The actual player checkout was at the accepted `main` commit but had a local `project.godot` editor rewrite. Its existing Python launcher stopped at `Unreviewed local runtime changes: M space-battleship/project.godot`. The installed native DLL also differed from the accepted bundled DLL. Both conditions were observed without changing the checkout or its save. The former blocked launch immediately; the latter would block later validation. A fresh checkout also lacked Godot, installed DLL and Python, while the old entry assumed a local Python executable.

## Candidate behavior

`玩游戏.cmd` bootstraps a pinned Python 3.12.10 embeddable ZIP, then the Python entry obtains a pinned Godot 4.7.2 Windows ZIP and installs the bundled native DLL. All archives and executables are SHA-256 checked. An accepted `main` checkout with uncommitted runtime edits uses a managed clean mirror under ignored `.runtime/player-main/checkout`, routes the player's save to the original checkout, and leaves the original edits unchanged. Updating accepted `main` reuses that mirror, with a guard against non-generated mirror edits.

Supported boundary: Windows 10/11 x64, Git available for pulling, built-in PowerShell, OpenGL 3.3 GPU, internet for the first download. Later launches use verified caches.

## Checks

- `python test/test_player_entry.py -q`: 17 tests passed, including native inventory, branch/origin checks, mirror update, preservation of an uncommitted runtime edit, and one retry of the observed first-import access violation.
- Clean simulated-main clone with no engine, installed DLL, or Python cache: actual `玩游戏.cmd` fetched official verified runtimes, installed the DLL, imported the project, and ran the game window for 120 frames; exit 0. A second launch and a simulated accepted-main update also exited 0.
- Simulated-main clone with a dirty `project.godot`: managed mirror launch exited 0 and the original config SHA-256 stayed `0668c298a3342fcb2be6bc88a0542fec30453b260e502b606fae2a7671046ad7`. An earlier per-commit mirror also ran successfully after a simulated main update.
- With the reusable mirror, the first resource import after updating the simulated main reached the end of Godot's import but its process exited with Windows access violation `3221225477`. Repeating the same one-click entry succeeded (exit 0, 120 frames) without changing the original config. The candidate now retries that specific import crash once and retains the first log; this path has unit coverage but has not been reproduced end to end after adding the retry.
- An independent clone at candidate `19655899`, with a fresh managed mirror and no Godot import cache, imported and ran the real `玩游戏.cmd` on the first attempt (exit 0, 120 frames). Its first-attempt retry log was absent. A simulated accepted-main documentation update then reused the mirror and also exited 0 after 120 frames; the original dirty `project.godot` SHA-256 remained `5d4fe30ef598405272f9e4ba49122a0162689fdc86e1a8c274ce82dd83103176` before and after. These simulated commits and clones are local verification artifacts, not GitHub `main`.
- Against the actual player checkout at `d2293ce9`, candidate logic selected a clean accepted-main mirror, used the verified local engine and bundled native DLL, and launched for 120 frames twice (exit 0) with a **copy** of the player's save. The original checkout, installed DLL, and save were unchanged. This integration did not execute the original `玩游戏.cmd`, which still contains the old code until this candidate is accepted and delivered.

### Import crash analysis and limit

The single observed access violation happened after a fresh managed mirror's 651 asset-index steps and editor-layout loading began. The process returned `0xC0000005` during import, before the game process started. The available import output showed no script failure at that point. Windows Application events during the same interval contained no Godot crash or WER record, and the original first-attempt import log had already been overwritten by the prior launcher. The exact native faulting module therefore cannot be established from this run. Both a repeat on the same cache and a separate cache-free first import completed successfully; the latter also survived an accepted-main update. The explicit one-retry path is unit tested, preserves the first log, and stops if the second import fails. The real Godot crash has not recurred under the updated launcher, so its automatic recovery path remains unverified end to end. Godot reported `Failed to read the root certificate store` in the successful verification runs; this did not stop asset import or game startup.

No game data or balance files changed in the candidate branch. Its diff from `d2293ce9` is limited to `.gitignore`, launcher/bootstrap, documentation, and entry tests.
