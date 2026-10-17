extends SceneTree
const MAIN=preload("res://main.tscn")
func _initialize()->void:
 call_deferred("_run")
func _run()->void:
 var db:=ShipDatabase.new()
 var g:=BattleGame.new(db,false)
 assert(int(g.profile.highestLevel)==1 and g.profile.cleared.is_empty())
 var eligible=bool(g.hightech_unlocked("singularity"))
 var started=bool(g.select_tech("singularity"))
 var selected=str(g.tech_tree_snapshot().selected)
 var viewport:=SubViewport.new()
 viewport.size=Vector2i(1440,900)
 root.add_child(viewport)
 var host=MAIN.instantiate()
 viewport.add_child(host)
 for i in 8:await process_frame
 host.refresh_tab_visibility()
 var tab_visible=not host.equipment_tabs.is_tab_hidden(1)
 var main_fresh=int(host.game.profile.highestLevel)==1 and host.game.profile.cleared.is_empty()
 print("QA_AI_FACTORY_START ",JSON.stringify({"fresh_game":true,"main_fresh":main_fresh,"tab_visible":tab_visible,"eligible":eligible,"select_started":started,"selected":selected,"tech_rows":db.data.ai_tech_tree.size()}))
 assert(main_fresh and tab_visible and eligible and started and selected=="singularity")
 quit()