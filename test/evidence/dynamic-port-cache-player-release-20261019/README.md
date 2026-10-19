# Formal player release closure — Windows 4.7.2

PASS. Actual `tools/player_runtime/space_native.dll`, launcher expected SHA, explicit installation target and current native acceptance inventory agree:
`137bd043ce2833b6378551e878cb6e9c3221cc0d98590d72db8399c89e0b0c78`.

Source registration anchor: `fda7be2c217a208067f97266f85497b83cbdd840`.
Tested launcher commit: `24b88272b12a0cf0d4dfce3714fbd60885579a70`.
The parent must preserve the anchor ancestry when merging this branch into main. No real main merge was performed. Remote main remained `4037308802924ffaefcb2a362028d7c91a9d4eda`.

17 directly related entry tests passed (unit.log). Added coverage keeps the exact entry-managed installed DLL subject to SHA validation, rejects an additional unknown DLL, and checks the actual committed bundle against the inventory. Existing branch, runtime edit, source ancestry, descriptor, engine and PCK guards remain active.

In an isolated checkout on its own main branch, with a space in its directory name, the actual root CMD was invoked from outside the checkout. The previous formal 04e7be92…1590f DLL was seeded at the installation target. Explicit installation backed it up with its exact hash and installed 137bd043…0c78. The real entry imported assets and started main.tscn with Godot 4.7.2 for 120 frames, returning 0. Both engine logs contain no ERROR, SCRIPT ERROR or WARNING. Player files were isolated under test/work. After startup, Git runtime-tree stdout was empty; line-ending notices from stderr are separately retained. See release.json and raw logs.

This is release closure only. The reviewed cache correctness (5717 checks), 8 valid high-load runs and 2 count runs are reused from [the preceding delivery](../dynamic-port-cache-win472-20261019/README.md); no additional performance claim is made and no broad test campaign was repeated. Native C++ and game behavior/art are unchanged. Historical center-contact acceptance remains unchanged.

The temporary relocated checkout was removed after retaining these receipts and logs. The production entry continues to resolve only its own repository and relative engine; it never searches this test location or another checkout. No blockers remain for parent review and normal merge. Squashing the source anchor or changing the game tree requires a new reviewed acceptance anchor.
