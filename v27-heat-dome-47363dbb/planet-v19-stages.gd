extends SceneTree

func _initialize() -> void:
    call_deferred("_capture")

func _capture() -> void:
    var viewport := SubViewport.new()
    viewport.size = Vector2i(1600, 900)
    viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    root.add_child(viewport)
    var visual: Control = load("res://scripts/planet_visual.gd").new()
    visual.size = Vector2(1600, 900)
    viewport.add_child(visual)
    var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/config.json"))
    var rows: Array = config["planet"]["planet"]
    for row in rows:
        if int(row["id"]) != 1: continue
        var kinds = ["auto_explore", "refinery", "equipment", "shipyard"]
        for count in [1, 2, 3, 4]:
            var entries := []
            for index in 4:
                entries.append({"type": kinds[index], "owned": index < count})
            visual.configure("1", {"visual": row.get("visual", {}), "visualFacilities": entries})
            for i in 90: await process_frame
            visual.advance(0.0, false)
            for i in 3: await process_frame
            viewport.get_texture().get_image().save_png("/tmp/planet-v19-stage-%d.png" % count)
        break
    quit()
