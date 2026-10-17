# Tutorial and unlock notice correction

- Goal: concise factual unlock notices and short location-based opening guidance; correct misleading gated cards and research completion behavior.
- Base: verified remote `main@3a0f40283ae653d004f738277606b2a57bf7739c`; candidate `feat/unlock-notice-copy-20261017`.
- Scope: unlock and onboarding copy, AI factory prerequisite visibility, reactor module visibility, enemy intelligence time display, opening tutorial pause, single-level research stop, and completion badge. Keep balance values and unlock gates unchanged.
- Stop: targeted source, headless text rendering, gate and pause behavior checked; retain original output and commit for parent review. No main merge.
- Locate: `docs/UI_TEXT.md`, matching `data/ui_text.json`/contract keys, `config_excel/unlock.xlsx` exception rows, and unlock rendering entry.
- Risk: the opening screenshot includes situational strategy inside a notice. Remove it without erasing the unlock identity or adjacent system instructions.
- Next: parent review and GUI check in its assigned serial window.

## Coverage

| Entry | Source / render path | Result |
|---|---|---|
| Opening, equipment, defense, upgrade, resource wait, combat, clear, retreat, pickup, enhancement | `data/ui_text.json` `onboarding.*` → `beginner_guide.gd` | Short capabilities and location; opening phase holds simulation until Next or Dismiss. |
| Unlock popup and guide archive | `unlock.xlsx` → `game_data.json` → `main.gd`, `unlock_tutorial.gd` | All 46 descriptions state only unlocked content; title and gate unchanged. |
| Synthetic hyperspace archive entry | `tutorial.hyperspace.description` | Short unlock summary. |
| AI research choices | `ai_tech_tree.gd` eligibility → `ai_tech_view_model.gd` → art page | Unmet first-level choices hidden; earned levels remain visible even if next level is gated. |
| Reactor module bays | `reactor_available_modules()` → `reactor_panel.gd` | Locked bays absent in both synced lists; stage 15 reveals condensation. |
| Research completion | `ai_tech_tree.gd` → profile → system navigation | Stops after one level, marks persisted unread badge, clears on tech page entry. |
| Enemy shield timing | `enemy_intel_page.gd` `duration_text` | 1800 ms is shown as 1.8 seconds; authored timing is unchanged. |
| Stage-clear drops | `game.gd` clear → `collect` → `main.gd` resource feedback | All remaining ordinary/core drops settle once before an unlock pause; the existing top resource icons receive increments and flight effects. |

## Mechanic checks

- Upgrade cost is a resource dictionary. `host.cost_text` already includes resource units, so the onboarding `{cost}` sentence adds no fixed “iron” suffix.
- Active weapon and defense slot counts come from the selected hull; copy asserts no fixed slot count. `equip_slot` changes a slot without charging resources; upgrade cost remains on the card.
- Fragment technology checks `enhancement_unlocked()` through research eligibility. The reactor condensation bay uses its own `reactor_module_unlocked()` gate, a cleared-stage 15 condition. These are distinct gates.
- Completion writes only the finished technology's level and resets its own progress; remaining `dt` stops at that boundary. Stored progress and multipliers for other technologies remain intact.
- Intro and unlock pause requests share one baseline paused state. Auto-skip still applies only to unlock notices.

## Before / after samples

| Surface | Before | After |
|---|---|---|
| Reactor unlock | “去【反应炉】点【均分】先看加成，再拖能源偏向武器或防御……” | “反应炉已解锁。” |
| Beam unlock | “先把一门武器换成光束……若打不动……再试另一类伤害。” | “高能激光已解锁。” |
| Shield unlock | Defense-slot, recovery, and comparison instructions | “偏转护盾已解锁。” |
| AI prerequisite | “强化碎片已解锁” even when prerequisites were unmet | Hidden until eligible; condition label is “解锁条件：强化系统”. |
| Enemy shield delay | “1800 毫秒” | “1.8 秒” |

The complete source-string before/after table is in `unlock-notice-copy-before-after-20261017.md`.

## Verification (Godot 4.7.2, `D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe`)

- `python tools/ui_text_editor.py --check` → `UI catalog: 2387 rows, valid`.
- Workbook audit → `XLSX_CELL_AUDIT_OK 46 desc cells; all other values and styles identical`.
- `test/test_unlock_copy.gd` → `COPY_CHECK_OK` with actual rendered waiting, reactor, shield, and auto-skip strings; all 46 projected unlock descriptions concise; 1.8/0.25 second conversions.
- `test/test_unlock_gates.gd` → `GATE_CHECK_OK` for initial, enhancement, core, earned, and final choices; reactor condensation absent before cleared stage 15 and present after; both bay lists compact.
- `test/test_ai_tech_stop_badge.gd` → `TECH_STOP_BADGE_OK level=1 active=none balance=9520.0 saved_unread=true restored_clear=true`.
- `test/test_tutorial_pause.gd` → `TUTORIAL_PAUSE_OK repeated intro, overlapping unlock, preexisting pause, auto-skip separation, resources stable`.
- `test/test_clear_drop_settlement.gd` → `CLEAR_DROPS_OK receipts={ "1": 1, "2": 1 } top_icons=2 effects=2 repeat=no_change`.
- Headless main scene for two frames (`--headless --path . --quit-after 2`) → exit code 0, with no script errors.

Godot emitted local log and certificate-store warnings because this sandbox cannot write the global Godot settings directory. The tests above returned exit code 0 and their checks passed. GUI review remains for the parent's serial window.

## AI investment performance check

The existing rich whole-game fixture (heavy battleship, eight level-150 weapons, four level-150 defenses, three durable enemies, completed galaxy state) was copied into one isolated project with Godot 4.7.2. Both runs used seed 1701, 480 measured realtime frames per page, the same imported assets, and the same fixture. Mode `zero` invested 0/0; mode `both` invested 100 iron and 100 uranium per game second. Page 0 is the hidden-factory case; page 1 opens the factory with its selection drawer. The page provider counted snapshot calls, while row instance IDs counted list rebuilds; no per-frame logging was added. Raw measurements: `ai-tech-investment-perf-20261017.json`.

| Factory | Inputs | Resource events | Snapshots | List rebuilds | Node delta | Main p95 (µs) | Frame p95 (µs) |
|---|---:|---:|---:|---:|---:|---:|---:|
| Hidden | 0/0 | 0 | 0 | 0 | +3 | 4318 | 6930 |
| Hidden | 100/100 | 13 | 0 | 0 | +3 | 3949 | 6916 |
| Visible | 0/0 | 0 | 13 | 0 | 0 | 3445 | 6921 |
| Visible | 100/100 | 13 | 13 | 0 | 0 | 3158 | 6920 |

The resource event path is `AITech.advance` (250 ms limit) → `resources_changed` → existing UI refresh. The visible page's separate 250 ms provider refresh ran 13 times in either mode. `_sync_rows` kept its ID/tier fingerprint and rebuilt no rows. The headless high-load CPU sample showed no investment-related rise in snapshot count, node growth, or measured p95 cost. Headless rendering reported zero draw calls, so this does not establish graphical FPS; GUI review remains in the parent's serial window.
