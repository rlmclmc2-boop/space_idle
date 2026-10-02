# Enhancement overview gate review

Candidate `ui/enhancement-overview-gates`, `8a3771e3c1cadd35a9ca930193a33d8ea4f578ab`, based on `31cd75eb99b688d065d57e0cc891393781e3d143`. Source diff contains only enhancement_panel.gd and test_enhancement_summary.gd. Not merged to main.

The six overview paths now use the existing enhancement_effect_runtime query. History bonuses use its eligible growth and history; deferred damage uses its eligible fraction. Repeat, critical and memory values use that same query without raw parameter fallbacks. No combat/runtime rule, progression, configuration or weapon presentation changes.

- `candidate.log`: original Godot output, 85 checks, 0 failures; no script errors.
- `candidate-texts.json`: 78 actual RichTextLabel parsed overview texts with independently computed expected texts. Remaining seven assertions check configured deferral probability/width and its branch boundaries.
- `base-reproduction.log` and `base-texts.json`: the exact same final test against the original candidate panel, 85 checks, 18 failures. Reproduces unlocked Lv1 third-position proficiency +30%, second-position adaptation +30%, and inactive deferred damage 50% under default configuration; candidate outputs zero.
- `weapon-workbook-audit.json`: SHA256 and byte equality for equipment.xlsx and weapon_motion.xlsx versus the base candidate.

Coverage includes locked high level, unlocked Lv0/1, ordered effects immediately below/at their main thresholds, reorder to an active position, the specific adaptation second-position case, a distinct valid threshold/growth configuration, and deferred/guaranteed-critical branch boundaries. This is a narrow headless text-rendering regression using synthetic in-memory state. No player save or source workbook is mutated; no broad combat suites were rerun.

An early fixture parse error was corrected by typing the game reference before the final runs. Only final candidate output and the deliberate failing base reproduction are retained here.
