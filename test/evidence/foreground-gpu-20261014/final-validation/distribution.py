from pathlib import Path
import json,gzip,collections,statistics
P=Path(__file__).resolve().parent
source=P.parent
raw=json.load(gzip.open(source/"snapshot-locate.json.gz","rt",encoding="utf-8"))
ledger=json.loads((source/"snapshot-ledger.json").read_text())
N=len(raw["frames_us"])
groups={
"logic":["simulation_geometry_authority.before_tick","simulation_geometry_authority.after_tick","native_execution_session.prepare_geometry","game.tick","game.advance_shared_clock_and_economy","native_execution_session.advance","native.kernel_advance","battle_slice_runtime.advance","main.advance_game_time"],
"feedback_and_snapshot":["battlefield.on_event","battle_slice_runtime.on_event","native_execution_session.consume_feedback","battle_slice_runtime.snapshot","simulation_geometry_authority.finish_display_boundary","simulation_geometry_authority.display_frame"],
"presentation_prepare_upload_and_mixed_battle_draw":["battle_slice_runtime.spawn_visual","battle_slice_runtime.consume","main.sync_beam_visuals","main.advance_projectile_visuals","main.flush_damage_numbers","main.refresh_draw_layers","battle_slice_runtime.apply_nodes","flat_ship_compositor.sync","retained_enemy_contacts.sync","main.draw_battle","battlefield._process","battlefield._process_battlefield"],
"known_script_draw_command_construction":["main.draw_stars","battlefield._draw_muzzle_cues","retained_enemy_contacts.paint"],
"ui":["main.refresh_visible_cards","main.refresh_navigation","hightech_workshop._process","hightech_workshop.refresh","equipment_tab.refresh_slots"],
"other_frame_work":["main._process","main.unwrapped","gap.postdraw_to_signal","gap.signal_to_main","gap.after_main_before_render"],
"render_submission_and_wait_unsplit":["render_submission_gpu_wait_unsplit"]}
for k in ledger["exclusive_us"]:
 if k.startswith("snapshot."):groups["feedback_and_snapshot"].append(k)
owner={}
for category,names in groups.items():
 for name in names:
  assert name not in owner,name
  owner[name]=category
assert set(owner)==set(ledger["exclusive_us"]),(set(ledger["exclusive_us"])-set(owner),set(owner)-set(ledger["exclusive_us"]))
parts={category:{name:ledger["exclusive_us"][name]/N/1000 for name in names} for category,names in groups.items()}
totals={k:sum(v.values()) for k,v in parts.items()}
assert sum(ledger["exclusive_us"].values())==sum(raw["frames_us"])
out={"source":"59ca290d","raw":"../snapshot-locate.json.gz","frames":N,"steps":raw["steps"],"instrumented_frame_ms":statistics.mean(raw["frames_us"])/1000,"exclusive_category_ms":totals,"exclusive_parts_ms":parts,"closure_us":ledger["closure_us"],"limits":["Recomputed existing instrumented snapshot-locate run. No new diagnostic or performance run. Do not mix its16.054ms instrumented total with clean paired acceptance means.","Every interval is assigned once to its deepest timed span. Categories sum to the whole frame; parent inclusive totals must not be added to child values.","Presentation category intentionally contains main.draw_battle mixed work: retained GPU beam sync/uniform uploads and remaining draw commands were not independently instrumented. This1.013ms cannot be called pure upload or pure drawing.","Known script draw category measures CPU command construction, not completed GPU execution. Native/renderer submission, GPU execution and CPU/OS waiting remain combined in render_submission_and_wait_unsplit.","Feedback category includes required damage/history/effect dispatch work. Snapshot children are exclusive, while separately reported display_frame inclusive timing contains its nested geometry function.","Other frame work includes unwrapped callbacks, scheduling and probe bookkeeping. No gap or waiting category is assumed fully removable."]}
(P/"distribution.json").write_text(json.dumps(out,indent=2),encoding="utf-8")
print(json.dumps({k:v for k,v in out.items() if k not in ["exclusive_parts_ms","limits"]},indent=2))
