from pathlib import Path

project = Path(__file__).resolve().parent / "space-battleship"
injection = 'preload("res://counter_probe.gd")'
for filename, names in {
    "game.gd": ["jewel_attack", "hit_enemy"],
    "presented_battle_game.gd": ["tick_projectiles"],
}.items():
    path = project / "scripts" / filename
    result = []
    for line in path.read_text(encoding="utf-8").splitlines(keepends=True):
        result.append(line)
        for name in names:
            if line.startswith(f"func {name}("):
                result.append(f'\t{injection}.legacy_call("{name}")\n')
    path.write_text("".join(result), encoding="utf-8")
