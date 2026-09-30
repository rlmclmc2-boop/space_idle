# Cartoon equipment panel prototype

Branch: `codex/cartoon-equipment-panel`, based on hybrid hull prototype `d3dae74`. User authorized the equipment-panel redesign independently of onboarding. No main-branch merge authorized.

Checkpoint: runnable component; 19 focused headless interaction checks pass via `test/test_equipment_panel_cartoon.gd`, including all five hulls and affordability. UI catalog validation passes. Native-resolution and narrow captures inspected after consistent weapon silhouettes, quieter labels, and disabled-cost contrast fixes. Screenshots in `review/` are disposable in-memory QA profiles, not player saves. Treat as user-unreviewed prototype.

Scope: warm rounded module cards, weapon/defence sections, live hull capacity and dormant overflow labels, direct upgrades, free-equip entry, explicit preview/confirm refit, selected-slot action footer, optional bounded inspector. Business state remains in BattleGame. No main.gd or onboarding behavior changed.

Onboarding integration: `equipment_panel.get_action_anchor(action, slot_id)` supports `empty_module`, `upgrade_action`, `module_detail`, `swap_module`, `equip_confirm`, `gems`; slot IDs come from `game.slot_id`. `select_item(slot_id)` and `open_picker(slot_id)` are semantic navigation helpers. Equipment-tab button remains `host.system_nav_buttons[0]`.

Pending: root review before publication and user review. Signal-driven interaction checks pass; manual pointer walk-through has not been performed. Existing `test_module_ui.gd` encodes the superseded permanent right-inspector geometry; use the focused new test for this component until those layout expectations are migrated deliberately.
