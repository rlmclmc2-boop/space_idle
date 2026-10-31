# Planet branch save configuration independence evidence

Source: feat/planet-single-side-ui@c883a36b1e1e42a5f6d746c264deeafa2a75b7b1
Owner method source: feat/amount-safe-previews@c38f1c2b06478d1d8b6e98b8571240e693e296fc
Probe: space-battleship/foundation/tests/_save_config_independence_probe.gd at source commit.
Godot: 4.7.2 stable; native: /tmp/planet-native-472/planet.gdextension (execution environment path).
Configuration: res://generated/config.json. Disposable save fixture: /tmp/planet-save-config-integration-718.
Run: SPACE_IDLE_NATIVE_EXTENSION=/tmp/planet-native-472/planet.gdextension SPACE_IDLE_SAVE_TEST_DIR=/tmp/planet-save-config-integration-718 SPACE_IDLE_GALAXY_PROBE_CONFIG=res://generated/config.json Godot --headless --path space-battleship --script res://foundation/tests/_save_config_independence_probe.gd
Result: 27 checks, 0 failures. Separate --check-only --script res://src/main.gd exit 0.
No generated save fixture or personal user save was archived. Existing unrelated old probes still assert the retired configHash rule and were not run as acceptance evidence.
