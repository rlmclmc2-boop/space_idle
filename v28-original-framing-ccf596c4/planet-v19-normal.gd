extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1440, 900)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var visual: Control = load("res://scripts/planet_visual.gd").new()
    visual.size = Vector2(1440, 900)
    viewport.add_child(visual)
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
    var rows: Array = config["planet"]["planet"]
    var entries := []
    for kind in ["auto_explore", "refinery", "equipment", "shipyard"]:
        entries.append({"type": kind, "owned": true})
    for row in rows:
        if int(row["id"]) != 1: continue
        visual.configure("1", {"visual": row.get("visual", {}), "visualFacilities": entries})
        for i in 120:
            await process_frame
            if visual.planet_id == "1" and not visual.preparing and visual.globe.visible:
                break
        for i in 12: await process_frame
        for frame in 90:
            visual.advance(1.0 / 15.0, false)
            for i in 2: await process_frame
            viewport.get_texture().get_image().save_png("/tmp/planet-v19-normal-%02d.png" % frame)
        break
    quit()
