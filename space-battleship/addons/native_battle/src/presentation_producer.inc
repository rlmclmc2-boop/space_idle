// Complete presentation experiment. Existing logical geometry remains synchronous.
// Included in space_native.cpp so exact engine vector helpers are shared.
class SpacePresentationProducer : public RefCounted {
    GDCLASS(SpacePresentationProducer, RefCounted)
    struct MountBinding {
        uint64_t node, body, strokes;
        bool physical = false;
        Vector2 normalized, port;
        double module = 0, base = 0, limit = 0, aim = 0;
    };
    struct ContactBinding {
        Ref<RefCounted> owner;
        Dictionary entity, pose;
        uint64_t root, hull, deck, protection, health, shield;
        std::array<uint64_t, 4> deck_parts;
        std::vector<MountBinding> mounts;
        int revision = -1;
    };
    struct ParticleFrame {
        Dictionary source;
        unsigned flags = 0;
        Vector2 position, velocity, direction, extent, end;
        Rect2 region;
        Ref<Texture2D> texture;
        double life = 0, size = 0, duration = 0, spin = 0;
        Color color;
    };
    std::vector<ParticleFrame> particle_frame;
    bool particles_prepared = false;
    void prepare_particles(Object *host) {
        Array particles = host->get("particles");
        particle_frame.clear();
        particle_frame.reserve(particles.size());
        const char *keys[] = {"rail_contact", "fragment", "flash", "destroy",
                              "spark",        "smoke",    "ring",  "beam_end"};
        for (int i = 0; i < particles.size(); ++i) {
            Dictionary p = particles[i];
            ParticleFrame f;
            f.source = p;
            for (int k = 0; k < 8; ++k)
                if (p.has(keys[k]))
                    f.flags |= 1u << k;
            f.position = p["pos"];
            f.velocity = p.get("vel", Vector2());
            f.direction = p.get("direction", Vector2());
            f.life = p.get("life", 0.);
            f.size = p.get("size", 0.);
            f.duration = p.get("duration", 0.);
            f.spin = p.get("spin", 0.);
            f.color = p.get("color", Color());
            f.extent = p.get("extent", Vector2());
            f.region = p.get("region", Rect2());
            f.texture = p.get("texture", Variant());
            f.end = p.get("beam_end", Vector2());
            particle_frame.push_back(std::move(f));
        }
        particles_prepared = true;
    }
    std::unordered_map<uint64_t, ContactBinding> contact_bindings;
    std::vector<uint64_t> live_uids;
    uint64_t frame_calls = 0, contact_frames = 0, contact_updates = 0, part_draws = 0, particle_draws = 0,
             beam_draws = 0, event_draws = 0, refresh_calls = 0, pose_calls = 0, fallbacks = 0, bindings = 0;
    bool allowed = false;
    uint64_t host_id, game_id;
    Array capability_signature;
    static Array capabilities(Object *game) {
        Array result;
        result.push_back(game->get_signal_connection_list("event"));
        Array observers = game->get("_native_readonly_observers");
        result.push_back(observers.duplicate());
        for (const char *name : {"target_provider", "launch_provider", "drone_launch_provider",
                                 "rail_geometry_provider", "rail_target_point_provider"})
            result.push_back(game->get(name));
        return result;
    }
    static Object *obj(Variant value) {
        return value.get_type() == Variant::OBJECT ? static_cast<Object *>(value) : nullptr;
    }
    template <class T> static T *node(uint64_t id) { return Object::cast_to<T>(ObjectDB::get_instance(id)); }
    static uint64_t id(Variant value) {
        Object *p = obj(value);
        return p ? p->get_instance_id() : 0;
    }
    static double scalar(Dictionary d, const char *key, double other = 0) {
        return double(d.get(StringName(key), other));
    }
    static Vector2 point(Dictionary d, const char *key) { return Vector2(d[StringName(key)]); }
    static Color tint(const char *s, double alpha = 1) {
        Color c = Color::html(s);
        c.a = alpha;
        return c;
    }
    static Color alpha(Color c, double a) {
        c.a = a;
        return c;
    }
    static double clamp(double n, double lo, double hi) { return std::clamp(n, lo, hi); }
    static double lerp(double a, double b, double t) { return a + (b - a) * t; }
    static PackedVector2Array packed(std::initializer_list<Vector2> points) {
        PackedVector2Array r;
        r.resize(points.size());
        std::copy(points.begin(), points.end(), r.ptrw());
        return r;
    }
    static Array array(std::initializer_list<Variant> values) {
        Array a;
        for (const auto &v : values)
            a.push_back(v);
        return a;
    }
    bool ready(Object *host) {
        Object *g = obj(host->get("game"));
        if (!allowed || host->get_instance_id() != host_id || !g || g->get_instance_id() != game_id ||
            bool(g->get("_native_forced_compatibility"))) {
            ++fallbacks;
            return false;
        }
        // Verify the actual capability set at every entry. Full script audit is
        // repeated immediately after any subscription/provider/opt-in change.
        Array signature = capabilities(g);
        if (signature != capability_signature) {
            allowed = bool(g->call("native_lifecycle_allowed"));
            capability_signature = signature;
            if (!allowed) {
                ++fallbacks;
                return false;
            }
        }
        return true;
    }
    static CanvasItem *canvas(Object *host) {
        return Object::cast_to<CanvasItem>(obj(host->get("draw_surface")));
    }
    static double fields(Object *o, const char *key) { return double(o->get(StringName(key))); }
    static void stroke_width(Node2D *n, double width) {
        Dictionary data = n->get("data");
        if (double(data["width"]) == width)
            return;
        data["width"] = width;
        n->queue_redraw();
    }
    void bind(ContactBinding &b, Object *record) {
        b.owner = Ref<RefCounted>(Object::cast_to<RefCounted>(record));
        b.entity = record->get("entity");
        b.pose = record->get("pose");
        b.revision = int64_t(record->get("shape_revision"));
        b.root = id(record->get("root"));
        b.hull = id(record->get("hull"));
        b.deck = id(record->get("deck"));
        b.protection = id(record->get("protection"));
        b.health = id(record->get("health"));
        b.shield = id(record->get("shield"));
        Dictionary parts = obj(record->get("deck"))->get("pieces");
        const char *names[] = {"deck_physical_body", "deck_physical_strokes", "deck_energy_body",
                               "deck_energy_strokes"};
        for (int i = 0; i < 4; ++i)
            b.deck_parts[i] = id(parts[names[i]]);
        Array mounts = record->get("mounts");
        b.mounts.clear();
        b.mounts.reserve(mounts.size());
        for (int i = 0; i < mounts.size(); ++i) {
            Object *m = obj(mounts[i]);
            MountBinding item;
            item.node = id(m->get("node"));
            Dictionary pieces = obj(m->get("node"))->get("pieces");
            item.body = id(pieces["body"]);
            item.strokes = id(pieces["strokes"]);
            item.physical = m->get("physical");
            item.normalized = m->get("normalized");
            item.port = m->get("port_factor");
            item.module = fields(m, "module_factor");
            item.base = fields(m, "base_rotation");
            item.limit = fields(m, "aim_limit");
            item.aim = fields(m, "aim_factor");
            b.mounts.push_back(item);
        }
        ++bindings;
    }
    static void meter(Node2D *n, Vector2 position, Vector2 size, double ratio, Color color) {
        n->set_position(position);
        Dictionary data = n->get("data");
        Rect2 rect = data["rect"];
        if (rect.size == size && double(data["ratio"]) == ratio && Color(data["color"]) == color)
            return;
        data["rect"] = Rect2(Vector2(), size);
        data["ratio"] = ratio;
        data["color"] = color;
        n->queue_redraw();
    }
    void update_contact(Object *host, Object *record, ContactBinding &b, Dictionary spatial, Vector2 offset);
    void protection(CanvasItem *surface, Dictionary enemy, double width, Dictionary packet, Dictionary status,
                    double clock);
    void deck_body(CanvasItem *surface, double width, bool physical);
    void deck_strokes(CanvasItem *surface, double width, bool physical);
    void weapon_body(CanvasItem *surface, double width, bool physical);
    void weapon_strokes(CanvasItem *surface, double width);
    bool known_enemy(Object *host, CanvasItem *surface, Dictionary enemy, Vector2 offset, bool boss);
    void rail_contact(CanvasItem *surface, Vector2 pos, double age, Vector2 direction, double strength);
    void particles(Object *host, CanvasItem *surface, Vector2 offset, bool core);
    void beams(Object *host, CanvasItem *surface, Array shots, Vector2 offset);
    void legacy_beam(Object *host, CanvasItem *surface, Dictionary shot, Vector2 offset);
    void charge(CanvasItem *surface, Vector2 muzzle, Vector2 target, double amount, double clock);
    void beam(CanvasItem *surface, Vector2 muzzle, Vector2 target, double clock, double width, double power,
              double pulse);
    static Color ramp(double power) {
        return power >= .999999 ? tint("f04aff")
               : power < .5     ? tint("8deaff").lerp(tint("2688ff"), power * 2)
                                : tint("2688ff").lerp(tint("925bff"), (power - .5) * 2);
    }

  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("begin_frame", "host"), &SpacePresentationProducer::begin_frame);
        ClassDB::bind_method(D_METHOD("advance_visuals", "host", "dt"),
                             &SpacePresentationProducer::advance_visuals);
        ClassDB::bind_method(D_METHOD("advance_transients", "host", "dt", "animate"),
                             &SpacePresentationProducer::advance_transients);
        ClassDB::bind_method(D_METHOD("prune_feedback", "host"), &SpacePresentationProducer::prune_feedback);
        ClassDB::bind_method(D_METHOD("refresh_layers", "host", "dt"),
                             &SpacePresentationProducer::refresh_layers);
        ClassDB::bind_method(D_METHOD("sync_contacts", "owner", "offset", "boss"),
                             &SpacePresentationProducer::sync_contacts);
        ClassDB::bind_method(D_METHOD("paint_part", "owner", "surface", "kind", "data"),
                             &SpacePresentationProducer::paint_part);
        ClassDB::bind_method(D_METHOD("draw_particles", "host", "offset", "core"),
                             &SpacePresentationProducer::draw_particles);
        ClassDB::bind_method(D_METHOD("draw_beams", "host", "shots", "offset"),
                             &SpacePresentationProducer::draw_beams);
        ClassDB::bind_method(D_METHOD("draw_feedback", "host"), &SpacePresentationProducer::draw_feedback);
        ClassDB::bind_method(D_METHOD("pose_ship", "view", "center", "height", "angle", "target", "time",
                                      "shield", "close", "delta", "check"),
                             &SpacePresentationProducer::pose_ship);
        ClassDB::bind_method(D_METHOD("slot_angles", "view", "angles"),
                             &SpacePresentationProducer::slot_angles);
        ClassDB::bind_method(D_METHOD("draw_environment", "host"),
                             &SpacePresentationProducer::draw_environment);
        ClassDB::bind_method(D_METHOD("stats"), &SpacePresentationProducer::stats);
    }

  public:
    bool begin_frame(Object *host) {
        Object *g = obj(host->get("game"));
        if (g && game_id != g->get_instance_id()) {
            contact_bindings.clear();
            particle_frame.clear();
        }
        host_id = host->get_instance_id();
        game_id = g ? g->get_instance_id() : uint64_t(0);
        allowed = g && bool(g->call("native_lifecycle_allowed"));
        if (g)
            capability_signature = capabilities(g);
        particles_prepared = false;
        if (allowed) {
            Object *view = obj(host->get("ship_view"));
            if (view)
                view->set("native_presentation", this);
        }
        ++frame_calls;
        if (!allowed) {
            contact_bindings.clear();
            particle_frame.clear();
            ++fallbacks;
        }
        return allowed;
    }
    bool advance_visuals(Object *host, double dt) {
        if (!ready(host))
            return false;
        Object *game = obj(host->get("game"));
        SpaceNativePipeline *pipeline =
            Object::cast_to<SpaceNativePipeline>(obj(game->get("native_pipeline")));
        if (!pipeline) {
            ++fallbacks;
            return false;
        }
        pipeline->advance_visuals(host, dt, true);
        return true;
    }
    bool advance_transients(Object *host, double dt, bool animate) {
        if (!ready(host))
            return false;
        // Original Dictionaries retain their identities for observers; only the
        // numeric traversal and stable compaction move into one native pass.
        for (const char *key : {"particles", "floats", "pickup_effects"}) {
            Array source = host->get(key), kept;
            kept.set_typed(source.get_typed_builtin(), source.get_typed_class_name(),
                           source.get_typed_script());
            const bool is_particle = StringName(key) == StringName("particles");
            if (is_particle && !animate)
                continue;
            for (int i = 0; i < source.size(); ++i) {
                Dictionary row = source[i];
                row["life"] = scalar(row, "life") - dt;
                if (is_particle) {
                    row["pos"] = point(row, "pos") + point(row, "vel") * dt;
                    row["vel"] = point(row, "vel") * .97;
                } else if (StringName(key) == StringName("floats") && bool(row.get("damage", false)) &&
                           !bool(row.get("incoming_lane", false))) {
                    Vector2 p = row["pos"];
                    p.y -= dt * 12;
                    row["pos"] = p;
                }
                if (scalar(row, "life") > 0)
                    kept.push_back(row);
            }
            host->set(key, kept);
        }
        prepare_particles(host);
        return true;
    }
    bool prune_feedback(Object *host) {
        if (!ready(host))
            return false;
        double time = fields(host, "fx_time");
        for (const char *key : {"destruction_events", "missile_events", "rail_events"}) {
            Array source = host->get(key), kept;
            kept.set_typed(source.get_typed_builtin(), source.get_typed_class_name(),
                           source.get_typed_script());
            if (StringName(key) != StringName("destruction_events") &&
                bool(host->get("accelerated_visual_mode"))) {
                host->set(key, kept);
                continue;
            }
            Object *rail = obj(host->get("rail_vfx"));
            double period =
                StringName(key) == StringName("rail_events") ? double(rail->call("afterglow_seconds")) : .65;
            for (int i = 0; i < source.size(); ++i) {
                Dictionary row = source[i];
                double duration =
                    StringName(key) == StringName("missile_events") ? scalar(row, "duration", .25) : period;
                if (time - scalar(row, "born") < duration)
                    kept.push_back(row);
            }
            host->set(key, kept);
        }
        // Beam validity is authoritative Game state, never inferred from age.
        Object *game = obj(host->get("game"));
        Array shots = game->get("projectiles");
        Dictionary valid, started = host->get("beam_full_started");
        for (int i = 0; i < shots.size(); ++i) {
            Dictionary shot = shots[i];
            if (!bool(shot.get("beam", false)) || bool(shot["hostile"]) ||
                !bool(game->call("long_laser_valid", shot)))
                continue;
            int64_t serial = shot["serial"];
            valid[serial] = true;
            if (int64_t(shot["ticks"]) > 0 && !started.has(serial)) {
                Dictionary style = host->call("beam_style", shot);
                if (double(style["power"]) >= .999999) {
                    started[serial] = time;
                    host->set("beam_full_cue_count", int64_t(host->get("beam_full_cue_count")) + 1);
                }
            }
        }
        Array serials = started.keys();
        for (int i = 0; i < serials.size(); ++i)
            if (!valid.has(serials[i]))
                started.erase(serials[i]);
        return true;
    }
    bool refresh_layers(Object *host, double dt);
    bool sync_contacts(Object *owner, Vector2 offset, bool boss);
    bool paint_part(Object *owner, CanvasItem *surface, String kind, Dictionary data);
    bool draw_particles(Object *host, Vector2 offset, bool core) {
        if (!ready(host))
            return false;
        particles(host, canvas(host), offset, core);
        ++particle_draws;
        return true;
    }
    bool draw_beams(Object *host, Array shots, Vector2 offset) {
        if (!ready(host))
            return false;
        beams(host, canvas(host), shots, offset);
        ++beam_draws;
        return true;
    }
    bool draw_feedback(Object *host);
    bool pose_ship(Object *view, Vector2 center, double height, double angle, Vector2 target, double time,
                   bool shield, bool close, double delta, bool check);
    bool slot_angles(Object *view, Array angles) {
        Object *host = ObjectDB::get_instance(host_id);
        if (!host || !ready(host))
            return false;
        Array modules = view->get("modules");
        for (int i = 0; i < modules.size(); ++i) {
            Dictionary m = modules[i];
            int slot = m["slot"];
            if (slot >= angles.size())
                continue;
            Node3D *pivot = Object::cast_to<Node3D>(obj(m["pivot"])),
                   *mount = Object::cast_to<Node3D>(obj(m["mount"]));
            Vector3 rotation = pivot->get_rotation();
            rotation.y = -double(angles[slot]) - mount->get_global_rotation().y;
            pivot->set_rotation(rotation);
        }
        return true;
    }
    bool draw_environment(Object *host) {
        if (!ready(host))
            return false;
        CanvasItem *s = canvas(host);
        Object *encounter = obj(host->get("encounter_presentation"));
        double fall = fields(encounter, "leader_fall");
        if (fall >= 1.4)
            return true;
        double progress = fall / 1.4;
        Vector2 focus = encounter->get("focus");
        Color color = encounter->get("accent");
        for (int side : {-1, 1}) {
            Vector2 point = focus + Vector2(side * (32 + progress * 85), progress * 65);
            s->draw_line(point - Vector2(0, 26), point + Vector2(0, 26), alpha(color, (1 - progress) * .8), 3,
                         true);
        }
        return true;
    }
    Dictionary stats() const {
        Dictionary d;
        d["frames"] = frame_calls;
        d["contact_frames"] = contact_frames;
        d["contact_updates"] = contact_updates;
        d["part_draws"] = part_draws;
        d["particle_draws"] = particle_draws;
        d["beam_draws"] = beam_draws;
        d["feedback_draws"] = event_draws;
        d["refresh_calls"] = refresh_calls;
        d["pose_calls"] = pose_calls;
        d["fallbacks"] = fallbacks;
        d["bindings"] = bindings;
        d["live_contact_bindings"] = int64_t(contact_bindings.size());
        return d;
    }
};

bool SpacePresentationProducer::refresh_layers(Object *host, double dt) {
    if (!ready(host))
        return false;
    Node2D *battle = Object::cast_to<Node2D>(obj(host->get("battle_layer")));
    if (!battle)
        return true;
    host->call("sync_battle_visibility");
    Object *game = obj(host->get("game"));
    Array enemies = game->get("enemies");
    Dictionary poses = host->get("enemy_poses");
    Array slots = poses.keys();
    // Preserve the exact synchronous pose owner routine; it serves geometry
    // readers before gameplay callbacks and can consume the original RNG.
    for (int i = 0; i < slots.size(); ++i) {
        Dictionary pose = poses[slots[i]], entity = pose["entity"];
        if (!enemies.has(entity) || double(entity.get("hp", 0)) <= 0)
            poses.erase(slots[i]);
    }
    for (int i = 0; i < enemies.size(); ++i) {
        Dictionary enemy = enemies[i];
        if (double(enemy.get("hp", 0)) > 0)
            host->call("enemy_pose", enemy);
    }
    Array drops = game->get("drops");
    Dictionary drop_positions = host->get("death_drop_positions");
    Array sources = drop_positions.keys();
    std::vector<int64_t> present;
    present.reserve(drops.size());
    for (int i = 0; i < drops.size(); ++i) {
        Dictionary drop = drops[i];
        present.push_back(int64_t(drop.get("source_uid", -1)));
    }
    for (int i = 0; i < sources.size(); ++i)
        if (std::find(present.begin(), present.end(), int64_t(sources[i])) == present.end())
            drop_positions.erase(sources[i]);
    host->call("recover_death_drop_positions");
    auto changed = [host](Object *layer, Array values) {
        return bool(host->call("ui_state_changed", layer, values));
    };
    Node2D *stars = Object::cast_to<Node2D>(obj(host->get("stars_layer")));
    if (changed(stars, array({host->get("star_travel"), host->get("star_streak"), game->get("speed"),
                              host->get("fx_time")})))
        stars->queue_redraw();
    Dictionary profile = game->get("profile");
    bool paused = game->get("paused");
    Array unlocks = game->get("pending_unlocks");
    if (battle->is_visible()) {
        bool diff =
            changed(battle, array({game->get("state"), paused, game->get("stage"), game->get("player"),
                                   profile["selectedShip"], profile["loadout"], game->call("stat", "armour"),
                                   game->call("max_shield"), profile["unlocked"], unlocks}));
        if (diff || (dt > 0 && (!paused || fields(host, "shake") > 0 || !drops.is_empty())))
            battle->queue_redraw();
    }
    Node2D *drop = Object::cast_to<Node2D>(obj(host->get("drop_layer")));
    if (drop->is_visible() != battle->is_visible())
        drop->set_visible(battle->is_visible());
    if (drop->is_visible()) {
        bool diff = changed(drop, array({drops, drop_positions}));
        if (diff || (dt > 0 && !paused && !drops.is_empty()))
            drop->queue_redraw();
    }
    Dictionary player = game->get("player");
    Node2D *hud = Object::cast_to<Node2D>(obj(host->get("battle_hud_layer")));
    if (changed(hud, array({game->get("stage"), game->get("state"), game->get("distance"),
                            game->get("group_index"), player["armour"], player["shield"],
                            game->call("stat", "armour"), game->call("max_shield"), profile["unlocked"],
                            paused, unlocks.is_empty(), game->call("is_boss_encounter"),
                            host->call("enhancement_defense_hud_state")})))
        hud->queue_redraw();
    Node2D *resource = Object::cast_to<Node2D>(obj(host->get("resource_layer")));
    if (changed(resource, array({host->call("resource_display", "1"), host->call("resource_display", "2")})))
        resource->queue_redraw();
    Variant hover = host->call("resource_hover_notices");
    host->set("resource_hover_feedback", hover);
    Node2D *overlay = Object::cast_to<Node2D>(obj(host->get("overlay_layer")));
    if (changed(overlay, array({host->get("help_open"), unlocks, host->call("battle_notices"),
                                host->get("pickup_effects"), hover})))
        overlay->queue_redraw();
    ++refresh_calls;
    return true;
}

bool SpacePresentationProducer::sync_contacts(Object *owner, Vector2 offset, bool boss) {
    Object *host = obj(owner->get("paint_owner"));
    if (!ready(host))
        return false;
    Object *game = obj(host->get("game")), *model = obj(host->get("battle_read_model"));
    Array enemies = game->get("enemies");
    Dictionary records = owner->get("records"), live;
    bool order_changed = false;
    int order = 0;
    live_uids.clear();
    for (int i = 0; i < enemies.size(); ++i) {
        Dictionary enemy = enemies[i];
        int64_t uid = enemy["uid"];
        live[uid] = true;
        live_uids.push_back(uid);
        Object *record = records.has(uid) ? obj(records[uid]) : nullptr;
        if (record && !same(Dictionary(record->get("entity")), enemy)) {
            Node2D *root = Object::cast_to<Node2D>(obj(record->get("root")));
            root->hide();
            root->queue_free();
            records.erase(uid);
            contact_bindings.erase(uid);
            record = nullptr;
            order_changed = true;
        }
        if (!record) {
            if (double(enemy["hp"]) <= 0)
                continue;
            record = obj(owner->call("create_record", enemy));
            records[uid] = record;
            order_changed = true;
        }
        if (int64_t(record->get("order_index")) != order) {
            record->set("order_index", order);
            order_changed = true;
        }
        ++order;
        bool alive = double(enemy["hp"]) > 0;
        if (bool(record->get("alive")) != alive) {
            record->set("alive", alive);
            Object::cast_to<Node2D>(obj(record->get("root")))->set_visible(alive);
            order_changed = true;
        }
        if (!alive)
            continue;
        Dictionary spatial = model->call("entry", enemy);
        if (spatial.is_empty()) {
            ++fallbacks;
            owner->call("update_record", record, spatial, offset);
            continue;
        }
        bool rebuilt = false;
        if (int64_t(record->get("shape_revision")) != int64_t(spatial["shape_revision"]) ||
            bool(record->get("boss")) != boss) {
            owner->call("compile_record", record, spatial, boss);
            rebuilt = true;
        } else {
            Dictionary pose = host->call("enemy_pose", enemy);
            if (!same(Dictionary(record->get("pose")), pose)) {
                owner->call("bind_pose", record, pose);
                rebuilt = true;
            }
        }
        if (!bool(record->get("supported"))) {
            Node2D *root = Object::cast_to<Node2D>(obj(record->get("root")));
            root->set_position(Vector2());
            Dictionary data;
            data["enemy"] = enemy;
            data["offset"] = offset;
            data["boss"] = boss;
            obj(record->get("fallback"))
                ->call("update", data, array({host->get("fx_time"), enemy, offset, boss}));
            continue;
        }
        auto &b = contact_bindings[uid];
        if (rebuilt || b.owner.ptr() != record || b.revision != int64_t(record->get("shape_revision")))
            bind(b, record);
        update_contact(host, record, b, spatial, offset);
        ++contact_updates;
    }
    Array keys = records.keys();
    for (int i = 0; i < keys.size(); ++i)
        if (!live.has(keys[i])) {
            Object *record = obj(records[keys[i]]);
            Node2D *root = Object::cast_to<Node2D>(obj(record->get("root")));
            root->hide();
            root->queue_free();
            contact_bindings.erase(int64_t(keys[i]));
            records.erase(keys[i]);
            order_changed = true;
        }
    Node2D *group = Object::cast_to<Node2D>(owner);
    if (order_changed) {
        int index = 0;
        for (int i = 0; i < enemies.size(); ++i) {
            Dictionary enemy = enemies[i];
            int64_t uid = enemy["uid"];
            if (records.has(uid))
                group->move_child(Object::cast_to<Node>(obj(obj(records[uid])->get("root"))), index++);
        }
        group->move_child(Object::cast_to<Node>(obj(owner->get("foreground"))), group->get_child_count() - 1);
    }
    ++contact_frames;
    return true;
}

void SpacePresentationProducer::update_contact(Object *host, Object *record, ContactBinding &b,
                                               Dictionary spatial, Vector2 offset) {
    Dictionary enemy = b.entity;
    Vector2 point_value = spatial["position"], pos = point_value + offset;
    Object *model = obj(host->get("battle_read_model"));
    double width = model->call("width_at", enemy, point_value.y),
           angle = host->call("enemy_render_angle", enemy);
    double depth = clamp((point_value.y - 90) / std::max(1., double(spatial["frontline"]) - 90), 0, 1),
           light = int64_t(enemy["size"]) <= 2 ? lerp(1.18, 1.30, depth) : lerp(.76, 1., depth);
    node<Node2D>(b.root)->set_position(pos);
    Node2D *hull = node<Node2D>(b.hull);
    hull->set_rotation(Math::PI + angle);
    hull->set_scale(Vector2(1, 1) * width);
    hull->set_self_modulate(Color(light, light, light, 1));
    node<Node2D>(b.deck)->set_rotation(Math::PI + angle);
    for (int i : {0, 2}) {
        Node2D *body = node<Node2D>(b.deck_parts[i]);
        if (!body->is_visible())
            continue;
        body->set_scale(Vector2(1, 1) * width);
        stroke_width(node<Node2D>(b.deck_parts[i + 1]), width);
    }
    bool repair = scalar(enemy, "max_shield") > 0 && scalar(enemy, "shieldRecovery") > 0,
         large = int64_t(enemy["size"]) >= 4;
    double scale = fields(record, "screen_scale");
    int bucket = std::ceil(width * std::max(.1, scale) / 2);
    double gap = ProjectSettings::get_singleton()->get_setting("visuals/enemy_protection_gap_pixels", 2.),
           layer = ProjectSettings::get_singleton()->get_setting("visuals/enemy_protection_layer_gap_pixels",
                                                                 2.5);
    Dictionary packet = record->get("packet"), previous = packet;
    Object *recognition = obj(host->get("enemy_recognition"));
    if (int64_t(record->get("packet_bucket")) != bucket || bool(record->get("packet_repair")) != repair ||
        bool(record->get("packet_large")) != large || fields(record, "protection_gap") != gap ||
        fields(record, "layer_gap") != layer) {
        packet = recognition->call("geometry", record->get("texture"), width, record->get("descriptors"),
                                   repair, record->get("pose"), scale, large);
        record->set("packet_bucket", bucket);
        record->set("packet_repair", repair);
        record->set("packet_large", large);
        record->set("protection_gap", gap);
        record->set("layer_gap", layer);
    }
    Dictionary status = record->get("status");
    bool alive = status.get("alive", false), active = status.get("active", false),
         old_repair = status.get("repair", false), recovering = status.get("recovering", false),
         old_hull = status.get("show_hull", false);
    double fraction = status.get("fraction", -INFINITY);
    Object *game = obj(host->get("game"));
    double clock = fields(game, "enemy_shield_time");
    recognition->call("state", enemy, clock, game->get("paused"), record->get("pose"), status);
    int armour = scalar(enemy, "armourType"), shield = scalar(enemy, "shieldType"),
        size = scalar(enemy, "size");
    bool changed = !same(previous, packet) || alive != bool(status["alive"]) ||
                   active != bool(status["active"]) || old_repair != bool(status["repair"]) ||
                   fraction != double(status["fraction"]) || recovering != bool(status["recovering"]) ||
                   old_hull != bool(status["show_hull"]) || int64_t(record->get("armour")) != armour ||
                   int64_t(record->get("shield_type")) != shield || int64_t(record->get("size")) != size;
    if (bool(status["repair"]) && fields(record, "protection_width") != width)
        changed = true;
    if (bool(status["recovering"]) && fields(record, "protection_clock") != clock)
        changed = true;
    record->set("packet", packet);
    record->set("armour", armour);
    record->set("shield_type", shield);
    record->set("size", size);
    record->set("protection_width", width);
    record->set("protection_clock", clock);
    Node2D *protection_node = node<Node2D>(b.protection);
    protection_node->set_rotation(Math::PI + angle);
    if (changed) {
        Dictionary data = protection_node->get("data");
        data["width"] = width;
        data["packet"] = packet;
        data["clock"] = clock;
        protection_node->queue_redraw();
    }
    PackedVector2Array outline = packet["inner"];
    if (!bool(status["alive"]))
        outline = PackedVector2Array();
    else if (bool(status["active"]) && shield >= 0 && shield <= 2) {
        outline = bool(status["show_hull"]) && (armour == 1 || armour == 2)
                      ? PackedVector2Array(packet["outer"])
                      : PackedVector2Array(packet["inner"]);
        if (shield == 1 && size >= 4)
            outline = bool(status["show_hull"]) && (armour == 1 || armour == 2)
                          ? PackedVector2Array(packet["front"])
                          : PackedVector2Array(packet["single_front"]);
    } else if (!(bool(status["show_hull"]) && (armour == 1 || armour == 2)) && !bool(status["repair"]))
        outline = PackedVector2Array();
    double top = pos.y;
    PackedVector2Array corners = record->get("corners");
    for (int i = 0; i < corners.size(); ++i)
        top = std::min(
            top, double(pos.y + engine_rotated(corners[i] * Vector2(width, width * 2), Math::PI + angle).y));
    for (int i = 0; i < outline.size(); ++i)
        top = std::min(top, double(pos.y + engine_rotated(outline[i], Math::PI + angle).y));
    top -= 9;
    Rect2 used = record->get("used");
    double bar_width = clamp(width * used.size.x, 28, 100),
           left = clamp(pos.x - bar_width * .5, 6, 572 - bar_width - 6);
    if (bool(enemy.get("explicit_formation", false)) && std::abs(scalar(enemy, "x") - 286) > 150)
        left = clamp(pos.x >= 286 ? pos.x : pos.x - bar_width, 6, 572 - bar_width - 6);
    meter(node<Node2D>(b.health), Vector2(left, std::max(6., top)) - pos, Vector2(bar_width, 4),
          scalar(enemy, "hp") / std::max(1., scalar(enemy, "max_hp")), tint("d9a477"));
    Node2D *shield_node = node<Node2D>(b.shield);
    shield_node->set_visible(scalar(enemy, "max_shield") > 0);
    if (shield_node->is_visible())
        meter(shield_node, Vector2(left, std::max(6., top - 7)) - pos, Vector2(bar_width, 4),
              scalar(enemy, "shield") / scalar(enemy, "max_shield"),
              tint(shield == 2   ? "ffaf61"
                   : shield == 1 ? "64b5ff"
                                 : "c6ced2"));
    Vector2 player = host->call("player_render_position");
    double desired =
               Math::wrapf(engine_angle(player - point_value) - Math::PI / 2 - angle, -Math::PI, Math::PI),
           minimum = 15 / std::max(.1, scale);
    for (const auto &mount : b.mounts) {
        double module_width = width * mount.module, w = std::max(minimum, module_width),
               mount_angle =
                   Math::PI / 2 + angle + clamp(desired, -mount.limit, mount.limit) * mount.aim + mount.base;
        Vector2 origin = engine_rotated(mount.normalized * width, Math::PI + angle),
                shift = mount.port * module_width - Vector2((mount.physical ? .64 : .45) * w, 0);
        Node2D *n = node<Node2D>(mount.node);
        n->set_position(origin + engine_rotated(shift, mount_angle));
        n->set_rotation(mount_angle - Math::PI / 2);
        node<Node2D>(mount.body)->set_scale(Vector2(1, 1) * w);
        if (!mount.physical)
            stroke_width(node<Node2D>(mount.strokes), w);
    }
}

void SpacePresentationProducer::deck_body(CanvasItem *s, double w, bool physical) {
    double y = w * .23;
    if (physical) {
        s->draw_rect(Rect2(-w * .18, y - w * .19, w * .36, w * .48), tint("17212a"));
        for (int sign : {-1, 1}) {
            double x = sign * w * .10;
            s->draw_rect(Rect2(x - w * .035, y - w * .14, w * .07, w * .33), tint("c2c9c9"));
            s->draw_rect(Rect2(x - w * .022, y + w * .12, w * .044, w * .055), tint("080d13"));
        }
    } else {
        s->draw_colored_polygon(packed({Vector2(0, y - w * .22), Vector2(w * .17, y), Vector2(0, y + w * .22),
                                        Vector2(-w * .17, y)}),
                                tint("17212a"));
        s->draw_colored_polygon(packed({Vector2(0, y - w * .15), Vector2(w * .12, y), Vector2(0, y + w * .15),
                                        Vector2(-w * .12, y)}),
                                tint("b8a2d8"));
    }
}
void SpacePresentationProducer::deck_strokes(CanvasItem *s, double w, bool physical) {
    double y = w * .23;
    if (physical) {
        for (int stripe = 0; stripe < 3; ++stripe)
            s->draw_line(Vector2(-w * .15, y + w * (.21 + stripe * .025)),
                         Vector2(w * .15, y + w * (.21 + stripe * .025)), tint("757f83"),
                         std::max(.8, w * .018), true);
    } else {
        for (int sign : {-1, 1}) {
            double x = sign * w * .19;
            s->draw_polyline(packed({Vector2(x * .65, y - w * .24), Vector2(x, y - w * .13),
                                     Vector2(x, y + w * .13), Vector2(x * .65, y + w * .24)}),
                             tint("c2c9c9"), std::max(1., w * .045), true);
        }
    }
}
void SpacePresentationProducer::weapon_body(CanvasItem *s, double w, bool physical) {
    s->draw_rect(Rect2(-w * .24, -w * .22, w * .48, w * .42), tint("36424b"));
    if (physical) {
        s->draw_rect(Rect2(-w * .16, -w * .15, w * .32, w * .84), tint("ac886a"));
        s->draw_rect(Rect2(-w * .23, w * .48, w * .46, w * .25), tint("6e594a"));
        s->draw_rect(Rect2(-w * .15, w * .57, w * .30, w * .14), tint("080d13"));
    } else {
        for (int side : {-1, 1})
            s->draw_colored_polygon(
                packed({Vector2(side * w * .17, -w * .18), Vector2(side * w * .60, -w * .08),
                        Vector2(side * w * .60, w * .45), Vector2(side * w * .41, w * .45),
                        Vector2(side * w * .41, w * .07), Vector2(side * w * .17, 0)}),
                tint("aabfc6"));
        s->draw_rect(Rect2(-w * .13, w * .02, w * .26, w * .16), tint("64b5ff"));
    }
}
void SpacePresentationProducer::weapon_strokes(CanvasItem *s, double w) {
    for (int side : {-1, 1})
        s->draw_line(Vector2(side * w * .49, w * .20), Vector2(side * w * .49, w * .44), tint("64b5ff"),
                     std::max(1., w * .10), true);
}
void SpacePresentationProducer::protection(CanvasItem *s, Dictionary enemy, double width, Dictionary packet,
                                           Dictionary status, double clock) {
    if (!bool(status["alive"]))
        return;
    int hull = int64_t(enemy.get("armourType", 0)), shield = int64_t(enemy.get("shieldType", 0));
    bool visible = bool(status["show_hull"]) && (hull == 1 || hull == 2), active = status["active"],
         repair = status["repair"];
    if (!visible && !repair && !(active && shield >= 0 && shield <= 2))
        return;
    PackedVector2Array outline = packet["inner"];
    double hull_stroke = packet["hull_stroke"], shield_stroke = packet["shield_stroke"],
           scale = packet["scale"];
    auto closed = [s](PackedVector2Array path, Color color, double stroke) {
        path.push_back(path[0]);
        s->draw_polyline(path, color, stroke, true);
    };
    if (visible)
        closed(outline, tint(hull == 2 ? "ffaf61" : "64b5ff", .8), hull_stroke);
    Color color = tint(shield == 2 ? "ffaf61" : shield == 1 ? "64b5ff" : "c6ced2");
    if (active && shield >= 0 && shield <= 2) {
        if (visible)
            outline = packet["outer"];
        if (repair) {
            closed(outline, alpha(color, .20), shield_stroke);
            for (int i = 0; i < 6; ++i) {
                Vector2 a = outline[(i + 2) % 6], b = outline[(i + 3) % 6];
                s->draw_line(a.lerp(b, .08), a.lerp(b, .92), alpha(color, .18), shield_stroke, true);
                double fill = clamp(double(status["fraction"]) * 6 - i, 0, 1);
                if (fill > 0)
                    s->draw_line(a.lerp(b, .08), a.lerp(b, .08 + .84 * fill), alpha(color, .9), shield_stroke,
                                 true);
            }
        } else
            closed(outline, alpha(color, .65), shield_stroke);
        if (shield == 1 && int64_t(enemy["size"]) >= 4) {
            PackedVector2Array front =
                visible ? PackedVector2Array(packet["front"]) : PackedVector2Array(packet["single_front"]);
            s->draw_polyline(packed({front[5], front[0], front[1]}), tint("64b5ff", .85), shield_stroke,
                             true);
            outline = front;
        }
    }
    if (repair)
        for (int i = 0; i < 3; ++i) {
            double a = -Math::PI / 2 + i * Math::TAU / 3;
            Vector2 center(std::cos(a) * width * .45, std::sin(a) * width * .55);
            s->draw_rect(Rect2(center - Vector2(1, 1) * width * .075, Vector2(1, 1) * width * .15),
                         tint("303c45"));
            s->draw_rect(Rect2(center - Vector2(1, 1) * width * .05, Vector2(1, 1) * width * .10),
                         alpha(color, active ? .85 : .22), false, std::max(1. / scale, width * .02));
            if (bool(status["recovering"])) {
                Vector2 toward = -engine_normalized(center);
                double pulse = Math::fposmod(clock * 1.4 + i * .33, 1.);
                Vector2 p = center + toward * width * (.12 + .17 * pulse),
                        cross = toward.orthogonal() * width * .035;
                s->draw_polyline(
                    packed({p - toward * width * .045 + cross, p, p - toward * width * .045 - cross}),
                    alpha(color, 1 - pulse * .55), std::max(1. / scale, width * .025), true);
            }
        }
}
bool SpacePresentationProducer::paint_part(Object *owner, CanvasItem *surface, String kind, Dictionary data) {
    Object *host = obj(owner->get("paint_owner"));
    if (!ready(host))
        return false;
    if (kind == "foreground")
        return false; // Original state-lifetime orchestration, native producers below it.
    if (kind == "fallback") {
        if (known_enemy(host, surface, data["enemy"], data["offset"], data["boss"])) {
            ++part_draws;
            return true;
        }
        ++fallbacks;
        return false;
    }
    ++part_draws;
    if (kind == "hull")
        surface->draw_texture_rect(Ref<Texture2D>(data["texture"]), Rect2(Vector2(-.5, -1), Vector2(1, 2)),
                                   false, Color(1, 1, 1));
    else if (kind == "deck_physical_body" || kind == "deck_energy_body")
        deck_body(surface, 1, bool(data["physical"]));
    else if (kind == "deck_physical_strokes" || kind == "deck_energy_strokes")
        deck_strokes(surface, double(data["width"]), bool(data["physical"]));
    else if (kind == "weapon_body")
        weapon_body(surface, 1, bool(data["physical"]));
    else if (kind == "weapon_strokes")
        weapon_strokes(surface, double(data["width"]));
    else if (kind == "protection")
        protection(surface, data["enemy"], data["width"], data["packet"], data["status"], data["clock"]);
    else if (kind == "meter") {
        Variant previous = host->get("draw_surface");
        host->set("draw_surface", surface);
        host->call("battle_meter", data["rect"], data["ratio"], data["color"]);
        host->set("draw_surface", previous);
    } else {
        ++fallbacks;
        return false;
    }
    return true;
}
void SpacePresentationProducer::particles(Object *host, CanvasItem *s, Vector2 offset, bool core) {
    if (!particles_prepared)
        prepare_particles(host);
    for (const ParticleFrame &f : particle_frame) {
        const Dictionary &p = f.source;
        bool foreground = (f.flags & 0x5f) != 0;
        if (foreground != core)
            continue;
        Vector2 pos = battle_point(f.position) + offset;
        double life = f.life, size = f.size;
        Color color = f.color;
        if ((f.flags & (1u << 0))) {
            Object *rail = obj(host->get("railgun_fx"));
            rail_contact(s, pos, f.duration - life, f.direction,
                         clamp(fields(rail, "impact_intensity"), 0, 1.5));
            continue;
        }
        if ((f.flags & (1u << 1))) {
            double fade = clamp(life / f.duration, 0, 1);
            if (fade > .86)
                continue;
            Vector2 extent = f.extent;
            s->draw_set_transform(pos, f.spin * (1 - fade), Vector2(-1, 1));
            s->draw_texture_rect_region(Ref<Texture2D>(f.texture), Rect2(-extent / 2, extent), f.region,
                                        Color(1, .8 + fade * .2, .65 + fade * .35, fade));
            s->draw_set_transform(Vector2());
        } else if ((f.flags & (1u << 2))) {
            double fade = clamp(life / f.duration, 0, 1);
            s->draw_circle(pos, size * .55, alpha(color, fade * .45));
            s->draw_circle(pos, size * fade * .4, Color(1, .98, .88, fade));
            for (int ray = 0; ray < 4; ++ray) {
                Vector2 direction = engine_from_angle(ray * Math::PI / 2 + .35);
                s->draw_line(pos, pos + direction * size * fade * 1.5, alpha(color, fade), 2 * fade, true);
            }
        } else if ((f.flags & (1u << 3))) {
            double progress = 1 - clamp(life / f.duration, 0, 1);
            if (p.has("texture") && progress < .23) {
                Vector2 extent = f.extent;
                s->draw_set_transform(pos, Math::PI / 2);
                s->draw_texture_rect(Ref<Texture2D>(f.texture), Rect2(-extent / 2, extent), false,
                                     Color(1, 1, .82, 1 - progress / .23));
                s->draw_set_transform(Vector2());
            }
            for (int burst = 0; burst < 2; ++burst) {
                double pulse = std::max(0., 1 - std::abs(progress - (.27 + burst * .14)) / .13);
                if (pulse > 0)
                    s->draw_circle(pos + Vector2(burst == 0 ? -11. : 10., burst == 0 ? -5. : 7.), 8 * pulse,
                                   Color(1, .72, .35, .48 * pulse));
            }
            double pulse = std::max(0., 1 - std::abs(progress - .58) / .21);
            s->draw_circle(pos, size * (.25 + progress * .65), tint("ffbc73", .24 * (1 - progress)));
            s->draw_arc(pos, size * (.4 + progress * 1.1), 0, Math::TAU, 20,
                        tint("ffbc73", .45 * (1 - progress)), 1.5, true);
            if (pulse > 0)
                s->draw_circle(pos, size * .7 * pulse, Color(1, 1, 1));
        } else if ((f.flags & (1u << 4)))
            s->draw_line(pos, battle_point(f.position) - engine_normalized(f.velocity) * size + offset,
                         alpha(color, clamp(life * 8, 0, 1)), 2.2, true);
        else if ((f.flags & (1u << 5))) {
            double fade = clamp(life / f.duration, 0, 1);
            s->draw_circle(pos, size * (1 + (1 - fade) * 1.6), alpha(color, fade * .22));
        } else if ((f.flags & (1u << 6))) {
            double fade = clamp(life / f.duration, 0, 1);
            s->draw_arc(pos, size * (1 - fade) + 2, 0, Math::TAU, 24, alpha(color, fade), 2, true);
        } else if ((f.flags & (1u << 7))) {
            double fade = clamp(life / f.duration, 0, 1);
            s->draw_line(pos, battle_point(f.position.lerp(f.end, fade)) + offset, alpha(color, fade * .65),
                         size * fade, true);
        } else
            s->draw_circle(pos, size, alpha(color, clamp(life * 2, 0, 1)));
    }
}
void SpacePresentationProducer::charge(CanvasItem *s, Vector2 muzzle, Vector2 target, double amount,
                                       double clock) {
    if (!muzzle.is_finite() || !target.is_finite() || !std::isfinite(amount) || !std::isfinite(clock))
        return;
    double p = clamp(amount, 0, 1);
    Vector2 axis = engine_normalized(target - muzzle);
    if (axis.length_squared() < .5)
        axis = Vector2(0, -1);
    Vector2 across = axis.orthogonal();
    double radius = lerp(14, 6, p);
    s->draw_circle(muzzle, 4 + p * 3, tint("8deaff", .12 + p * .16));
    s->draw_circle(muzzle, 1.3 + p * 1.3, tint("edfff9", .45 + p * .5));
    for (int side : {-1, 1}) {
        Vector2 start = muzzle + across * side * radius - axis * 4.,
                bend = muzzle + across * side * radius * .5 + axis * 2.;
        s->draw_polyline(packed({start, bend, muzzle}), tint("8deaff", .3 + p * .5), 1.3, true);
    }
    double angle = clock * 1.2;
    s->draw_arc(muzzle, radius, angle, angle + Math::PI * (.3 + p * .6), 16, tint("8deaff", .45), 1.2, true);
}
void SpacePresentationProducer::beam(CanvasItem *s, Vector2 muzzle, Vector2 target, double clock,
                                     double width, double power, double pulse) {
    if (!muzzle.is_finite() || !target.is_finite() || !std::isfinite(clock) || !std::isfinite(width) ||
        !std::isfinite(power) || !std::isfinite(pulse) || width <= 0)
        return;
    Vector2 delta = target - muzzle;
    double distance = delta.length();
    if (distance < .5)
        return;
    Vector2 direction = delta / distance, across = direction.orthogonal();
    double intensity = clamp(power, 0, 1), hit = clamp(pulse, 0, 1);
    Color energy = ramp(intensity), core = tint("edfff9");
    double body = std::max(.7, width) * lerp(.65, 1.8, intensity),
           hair = std::max(.35, body * (intensity >= .999999 ? .40 : .28));
    s->draw_line(muzzle, target, alpha(energy, .025 + intensity * .14), body * 2.1, true);
    s->draw_line(muzzle, target, alpha(energy, .15 + intensity * .60), body, true);
    s->draw_line(muzzle, target, alpha(core, .22 + intensity * .73 + hit * .05), hair, true);
    double length = std::min(14., distance * .07);
    for (int i = 0; i < 3; ++i) {
        double phase = Math::fposmod(clock * .85 + i / 3., 1.),
               along = phase * std::max(0., distance - length);
        Vector2 offset = across * std::sin(clock * 2 + i * 2.1) * body * .22,
                start = muzzle + direction * along + offset;
        s->draw_line(start, start + direction * length, alpha(core, .06 + intensity * .16),
                     std::max(.7, hair * .55), true);
    }
    s->draw_circle(muzzle, body * .63, alpha(energy, .27));
    s->draw_circle(muzzle, hair * .75, alpha(core, .25 + intensity * .65));
    double radius = 1.8 + body * .40 + intensity * 3 + hit * .35;
    s->draw_circle(target, radius * 1.25, alpha(energy, .11 + hit * .07));
    PackedVector2Array ring;
    ring.resize(25);
    for (int i = 0; i < 25; ++i) {
        double angle = Math::TAU * i / 24.;
        ring.set(i, target + across * std::cos(angle) * radius + direction * std::sin(angle) * radius * .42);
    }
    s->draw_polyline(ring, alpha(energy, .56 + hit * .18), 1.2, true);
    s->draw_circle(target, .7 + body * .12 + intensity * 1.2 + hit * .15, alpha(core, .25 + intensity * .70));
    for (int side : {-1, 1}) {
        double shift = std::sin(clock * 3 + side) * .8;
        Vector2 tip = target + across * side * radius * 1.3 - direction * (1.5 + shift);
        s->draw_line(target + across * side * radius * .65, tip, alpha(energy, .4 + hit * .25), 1, true);
    }
}
void SpacePresentationProducer::beams(Object *host, CanvasItem *s, Array shots, Vector2 offset) {
    Object *game = obj(host->get("game"));
    double clock = fields(host, "fx_time");
    Dictionary full = host->get("beam_full_started");
    for (int i = 0; i < shots.size(); ++i) {
        Dictionary shot = shots[i];
        if (!bool(shot.get("beam", false)) || !bool(game->call("long_laser_valid", shot)))
            continue;
        // Keep actual muzzle and target geometry callbacks synchronous.
        if (!bool(host->get("prototype_enabled")) || !bool(host->get("continuous_beam_enabled")) ||
            bool(shot["hostile"])) {
            legacy_beam(host, s, shot, offset);
            continue;
        }
        Vector2 muzzle = battle_point(host->call("visual_muzzle", shot)) + offset,
                target = host->call("entity_render_position", shot["target"]);
        target += offset;
        if (scalar(shot, "charge") > 0 && scalar(shot, "elapsed") < scalar(shot, "charge"))
            charge(s, muzzle, target, scalar(shot, "elapsed") / scalar(shot, "charge"), clock);
        else if (int64_t(shot["ticks"]) > 0) {
            Dictionary style = host->call("beam_style", shot);
            beam(s, muzzle, target, clock, style["width"], style["power"], style["pulse"]);
            int64_t serial = shot["serial"];
            if (full.has(serial)) {
                double age = clock - double(full[serial]);
                if (age >= 0 && age <= .18) {
                    double t = age / .18;
                    s->draw_arc(target, 8 + 10 * t, 0, Math::TAU, 32, tint("f5adff", (1 - t) * .65), 1.8,
                                true);
                }
            }
            Array links = game->call("beam_chain_targets", shot);
            for (int j = 0; j < links.size(); ++j) {
                Vector2 end = host->call("entity_render_position", links[j]);
                end += offset;
                s->draw_line(target, end, tint("a7fff0", .28), 4, true);
                s->draw_line(target, end, tint("a7fff0"), 1.4, true);
                s->draw_circle(target.lerp(end, Math::fposmod(clock * 2, 1.)), 2.3, tint("f2fffc"));
            }
        }
    }
}

bool SpacePresentationProducer::draw_feedback(Object *host) {
    if (!ready(host))
        return false;
    if (!bool(host->get("effects_enabled")) || !bool(host->get("prototype_enabled")))
        return true;
    CanvasItem *s = Object::cast_to<CanvasItem>(obj(host->get("pulse_layer")));
    Object *view = obj(host->get("ship_view"));
    Camera3D *camera = Object::cast_to<Camera3D>(obj(view->get("camera")));
    Object *game = obj(host->get("game"));
    Object *rail = obj(host->get("rail_vfx"));
    double time = fields(host, "fx_time"), trail_width = fields(rail, "trail_width"),
           charge_radius = fields(rail, "charge_radius"), flash_time = fields(rail, "flash_seconds"),
           impact_time = fields(rail, "impact_seconds"), impact_radius = fields(rail, "impact_radius");
    Array modules = view->get("modules");
    Dictionary poses = host->get("turret_visuals");
    for (int i = 0; i < modules.size(); ++i) {
        Dictionary module = modules[i];
        String key = module["key"];
        int slot = module["slot"];
        if (bool(host->get("missile_vfx_enabled")) && key == "missile")
            continue;
        if (bool(host->get("rail_vfx_enabled")) && key == "cannon") {
            if (bool(host->get("accelerated_visual_mode")) || int64_t(game->get("state")) != 3 ||
                !bool(game->call("has_alive_enemy")))
                continue;
            double amount = host->call("player_railgun_charge", slot);
            if (amount <= 0)
                continue;
            Vector2 point_value = view->call("screen_muzzle_for_slot", slot);
            Node3D *muzzle = Object::cast_to<Node3D>(obj(module["muzzle"]));
            Vector2 ahead = camera->unproject_position(muzzle->to_global(Vector3(0, 0, -.5))),
                    direction = engine_normalized(ahead - point_value), side = direction.orthogonal();
            for (int index = 0; index < 3; ++index) {
                double lit = clamp(amount * 3 - index, 0, 1);
                Vector2 center = point_value - direction * charge_radius * (.9 - index * .28);
                s->draw_line(center - side * charge_radius * .17, center + side * charge_radius * .17,
                             tint("9e2438", lit * .9), std::max(1., trail_width * .055), true);
            }
            continue;
        }
        if (bool(host->get("pulse_vfx_enabled")) && key == "laser")
            continue;
        Dictionary pose = poses.get(slot, Dictionary());
        double age = time - scalar(pose, "fired_at", -100);
        if (age < 0 || age > .12)
            continue;
        double fade = 1 - age / .12;
        Vector2 p = view->call("screen_muzzle_for_slot", slot);
        Node3D *muzzle = Object::cast_to<Node3D>(obj(module["muzzle"]));
        Vector2 ahead = camera->unproject_position(muzzle->to_global(Vector3(0, 0, -.5))),
                direction = engine_normalized(ahead - p), across(-direction.y, direction.x);
        Color color = tint(key == "missile" || key == "cannon" ? "ffbf75" : "96f6ff", fade);
        s->draw_line(p, p + direction * (9 + 6 * fade), color, 2, true);
        s->draw_line(p + direction * 3. - across * 3. * fade, p + direction * 3. + across * 3. * fade,
                     Color(1, 1, 1, fade), 1.5, true);
    }
    Array destruction = host->get("destruction_events");
    for (int i = 0; i < destruction.size(); ++i) {
        Dictionary e = destruction[i];
        double age = time - scalar(e, "born"), progress = clamp(age / .65, 0, 1),
               radius = clamp(scalar(e, "width") * .45, 12, 40);
        Vector2 p = battle_point(point(e, "position"));
        for (int piece = 0; piece < 7; ++piece) {
            double angle = piece * Math::TAU / 7 + scalar(e, "seed") * .7;
            Vector2 center = p + engine_from_angle(angle) * radius * (.25 + progress * 1.8),
                    extent = Vector2(4, 7) * (1 - progress);
            s->draw_set_transform(center, angle + progress);
            s->draw_rect(Rect2(-extent, extent * 2),
                         tint(piece % 2 == 0 ? "bc8060" : "384c59", 1 - progress));
        }
        s->draw_set_transform(Vector2());
        s->draw_circle(p, radius * (.3 + progress), tint("d9a477", std::max(0., .28 - age * 1.5)));
        if (age < .22)
            s->draw_circle(p, radius * (.5 - age * 1.5), tint("f5e4bd", 1 - age / .22));
    }
    Object *pipeline = obj(game->get("native_pipeline"));
    pipeline->call("draw_contacts", s->get_canvas_item(), time, host->get("pulse_vfx_enabled"));
    Array events = host->get("rail_events");
    if (bool(host->get("rail_vfx_enabled"))) {
        double budget = clamp(1.5 / std::sqrt(std::max(1., double(events.size()))), .42, 1.),
               lifetime = std::max(flash_time, impact_time * 3.5),
               standard_width = std::max(12., trail_width);
        Vector2 bounds = Object::cast_to<Control>(obj(host->get("battle_clip")))->get_size();
        for (int i = 0; i < events.size(); ++i) {
            Dictionary e = events[i];
            double age = time - scalar(e, "born");
            Vector2 p = battle_point(point(e, "position")), direction = e["direction"];
            if (String(e["kind"]) == "fire") {
                double flash = std::min(flash_time, .045);
                if (age >= 0 && age < flash)
                    s->draw_line(p - direction * 4., p + direction * 14.,
                                 tint("d54b58", (1 - age / flash) * budget), std::max(1., trail_width * .065),
                                 true);
                if (age < 0 || age >= lifetime)
                    continue;
                Vector2 contact = battle_point(point(e, "aim"));
                direction = engine_normalized(contact - p);
                double full = scalar(e, "full_width", standard_width), reach = INFINITY;
                if (direction.x > .0001)
                    reach = std::min(reach, double((bounds.x - p.x) / direction.x));
                else if (direction.x < -.0001)
                    reach = std::min(reach, double(-p.x / direction.x));
                if (direction.y > .0001)
                    reach = std::min(reach, double((bounds.y - p.y) / direction.y));
                else if (direction.y < -.0001)
                    reach = std::min(reach, double(-p.y / direction.y));
                Vector2 end = std::isfinite(reach) ? p + direction * (std::max(0., reach) + full) : p;
                double decoration = trail_width * full / standard_width;
                Vector2 side = direction.orthogonal();
                double main_time = std::min(flash_time, .09);
                if (age < main_time) {
                    double fade = std::pow(1 - age / main_time, .65);
                    s->draw_line(p, end, tint("9e2438", fade * budget), full, true);
                    s->draw_line(p, end, tint("d54b58", fade * budget * .85), std::max(4., decoration * .32),
                                 true);
                }
                double kink = std::min(decoration * .25, engine_distance(p, end) * .015);
                PackedVector2Array points =
                    packed({p, p.lerp(end, .25) + side * kink * .35, p.lerp(end, .36) - side * kink,
                            p.lerp(end, .38) + side * kink * .55, p.lerp(end, .64) - side * kink * .25,
                            p.lerp(end, .67) + side * kink * .8, p.lerp(end, .69) - side * kink * .5, end});
                double fade = std::pow(1 - age / lifetime, 1.4);
                s->draw_line(p, end, tint("9e2438", fade * budget * .38), std::max(2., decoration * .22),
                             true);
                s->draw_polyline(points, tint("d54b58", fade * budget * .85), std::max(1.5, decoration * .09),
                                 true);
            } else {
                double period = std::min(impact_time, .05);
                if (age < 0 || age >= period)
                    continue;
                double fade = 1 - age / period;
                Vector2 side = direction.orthogonal();
                for (int sign : {-1, 1})
                    s->draw_line(p, p + direction * impact_radius * .2 + side * sign * impact_radius * .22,
                                 tint("9e2438", fade * budget), std::max(.8, trail_width * .035), true);
            }
        }
    }
    events = host->get("missile_events");
    if (bool(host->get("missile_vfx_enabled"))) {
        double budget = clamp(2 / std::sqrt(std::max(1., double(events.size()))), .45, 1.);
        for (int i = 0; i < events.size(); ++i) {
            Dictionary e = events[i];
            double age = time - scalar(e, "born");
            Vector2 p = battle_point(point(e, "position")), direction = e["direction"],
                    axis = direction.length_squared() > .0001 ? engine_normalized(direction) : Vector2(0, -1);
            String kind = e["kind"];
            if (kind == "retired") {
                double coast = std::min(age, scalar(e, "coast_time"));
                p = battle_point(point(e, "position") + direction * scalar(e, "speed") * coast);
                if (age < scalar(e, "coast_time")) {
                    Ref<Mesh> mesh = host->get("missile_body_mesh");
                    if (mesh.is_valid() &&
                        s->get_global_transform_with_canvas().get_scale().is_equal_approx(Vector2(1, 1)))
                        s->draw_mesh(mesh, Ref<Texture2D>(),
                                     Transform2D(engine_angle(axis) + Math::PI / 2, p));
                    else { // Full original unit polygon body on scaled canvases.
                        Vector2 side = axis.orthogonal();
                        for (int sign : {-1, 1}) {
                            s->draw_colored_polygon(packed({p - axis * 16. + side * sign * 2.8,
                                                            p - axis * 24. + side * sign * 6.2,
                                                            p - axis * 22. + side * sign * 2.8}),
                                                    tint("26313b"));
                            s->draw_line(p - axis * 19. + side * sign * 3.4,
                                         p - axis * 23. + side * sign * 5., tint("cc6354"), 1.5, true);
                        }
                        PackedVector2Array body =
                            packed({p + axis, p - axis * 7. - side * 3.1, p - axis * 23. - side * 3.1,
                                    p - axis * 25., p - axis * 23. + side * 3.1, p - axis * 7. + side * 3.1});
                        s->draw_colored_polygon(body, tint("f2eee3"));
                        PackedVector2Array edge = body;
                        edge.push_back(body[0]);
                        s->draw_polyline(edge, tint("26313b"), 1, true);
                        s->draw_colored_polygon(
                            packed({p + axis, p - axis * 7. - side * 3.1, p - axis * 7. + side * 3.1}),
                            tint("cc6354"));
                        s->draw_line(p - axis * 9. + side * 1.5, p - axis * 21. + side * 1.5, tint("87949e"),
                                     1.5, true);
                        s->draw_line(p - axis * 9. - side * 1.7, p - axis * 20. - side * 1.7, Color(1, 1, 1),
                                     .9, true);
                    }
                } else {
                    double t = clamp((age - scalar(e, "coast_time")) / .18, 0, 1);
                    for (int index = 0; index < 3; ++index) {
                        Vector2 a = engine_rotated(direction, (index - 1) * 1.4),
                                center = p + a * (2 + 7 * t);
                        s->draw_line(center - a * 1.5, center + a * 1.5, tint("87949e", (1 - t) * .8), 1.4,
                                     true);
                    }
                }
            } else if (kind == "fire") {
                if (age < 0 || age >= .10)
                    continue;
                double t = age / .10, fade = (1 - t) * lerp(.40, 1, clamp(budget, 0, 1)),
                       hot = clamp(1 - age / .045, 0, 1);
                s->draw_line(p - axis * 3., p + axis * 5., tint("fff0be", hot * fade), 2.5, true);
            } else {
                if (age < 0 || age >= .22)
                    continue;
                double t = age / .22, decoration = lerp(.45, 1, clamp(budget, 0, 1)),
                       fade = (1 - t) * (1 - t) * decoration, scale = bool(e["critical"]) ? 1.12 : 1.;
                for (int index = 0; index < 3; ++index) {
                    Vector2 radial = engine_rotated(axis, index * Math::TAU / 3 + .4),
                            center = p + radial * (2 + 6 * t);
                    double radius = 4 + 3 * t;
                    s->draw_circle(center, radius, tint("aaa4a1", fade * .32));
                    double fire = clamp(1 - age / .13, 0, 1);
                    s->draw_circle(center, radius * .8, tint("ffad4c", fire * decoration));
                }
                for (int index = 0; index < 3; ++index) {
                    Vector2 radial = engine_rotated(axis, index * Math::TAU / 3),
                            end = p + radial * (4 + 14 * t) * scale;
                    s->draw_line(end - radial * 3., end, tint("ffad4c", fade * .6), 1.3, true);
                }
                double hot = clamp(1 - age / .065, 0, 1);
                s->draw_circle(p, (4 + t) * scale, tint("fff0be", hot * decoration));
            }
        }
    }
    ++event_draws;
    return true;
}

bool SpacePresentationProducer::pose_ship(Object *view, Vector2 center, double height, double angle,
                                          Vector2 target, double time, bool shield_enabled, bool close,
                                          double delta, bool check) {
    Object *host = ObjectDB::get_instance(host_id);
    if (!host || !ready(host))
        return false;
    Control *control = Object::cast_to<Control>(view);
    Vector2 size = control->get_size();
    double rendered_height = height * (close ? 2.8 : 1.),
           scale = rendered_height / fields(view, "model_span") * .05,
           elapsed = fields(view, "orbit_elapsed") + clamp(delta, 0, .10);
    Vector2 position = close ? size * Vector2(.5, .58) : center;
    Vector3 orbit((position.x - size.x * .5) * .05, 0, (position.y - size.y * .5) * .05);
    view->set("elapsed", time);
    view->set("rendered_height", rendered_height);
    view->set("rendered_position", position);
    view->set("orbit_center", orbit);
    view->set("orbit_elapsed", elapsed);
    Node3D *ship = Object::cast_to<Node3D>(obj(view->get("ship")));
    ship->set_scale(Vector3(1, 1, 1) * scale);
    ship->set_position(orbit + Vector3(0, 0, std::sin(elapsed * Math::TAU / 8) * 1.2 * .05));
    ship->set_rotation(Vector3(0, -angle + std::sin(elapsed * Math::TAU / 10) * Math::deg_to_rad(.65), 0));
    Dictionary config = view->get("hull_config"), manifest = view->get("manifest");
    Array low = config["godot_aabb_min"], high = config["godot_aabb_max"];
    double pixels = scale / .05;
    Vector2 half(std::max(std::abs(double(low[0])), std::abs(double(high[0]))),
                 std::max(std::abs(double(low[2])), std::abs(double(high[2]))));
    half *= pixels;
    Dictionary contract = manifest["weapon_contract"];
    double radius =
        std::max(1.6, double(contract["conservative_xz_rotation_radius"]) * 1.2) * .48 * pixels + 3;
    Vector2 extent(160, 178);
    extent.x = std::min(double(extent.x), std::min(double(position.x), double(size.x - position.x)) - 8);
    extent.y = std::min(double(extent.y), std::min(double(position.y), double(size.y - position.y)) - 8);
    Vector2 orbit_radius(std::min(double(half.x + radius * .55 + 8), double(extent.x - radius)),
                         std::min(double(half.y + radius * .55 + 8), double(extent.y - radius)));
    orbit_radius = orbit_radius.max(Vector2(8, 8)) * .05;
    Array carriers = view->get("carriers"), states = view->get("carrier_states");
    for (int i = 0; i < carriers.size(); ++i) {
        double phase = Math::TAU * i / std::max(carriers.size(), int64_t(1)),
               period = 18 * (1 + .055 * std::sin(i * 2.399963)),
               theta = Math::TAU * elapsed / period + phase,
               radial = .94 + .06 * std::sin(theta * 2 + i * 1.7);
        Node3D *carrier = Object::cast_to<Node3D>(obj(carriers[i]));
        carrier->set_scale(Vector3(1, 1, 1) * scale * .48);
        carrier->set_global_position(orbit + Vector3(std::sin(theta) * orbit_radius.x * radial, -1.6 * scale,
                                                     -std::cos(theta) * orbit_radius.y * radial));
        carrier->set_rotation(
            Vector3(0, std::atan2(-std::cos(theta) * orbit_radius.x, -std::sin(theta) * orbit_radius.y), 0));
        Dictionary state = states[i];
        state["ready"] = true;
        carrier->set_visible(true);
    }
    view->set("last_pose_scale", scale);
    view->set("pose_initialized", true);
    if (check) {
        SubViewport *viewport = Object::cast_to<SubViewport>(obj(view->get("viewport")));
        Camera3D *camera = Object::cast_to<Camera3D>(obj(view->get("camera")));
        obj(view->get("body_baker"))
            ->call("guard_resolution",
                   double(int(viewport->get_size().x * viewport->get_scaling_3d_scale())) /
                       camera->get_size());
    }
    Vector3 world_target((target.x - size.x * .5) * .05, 0, (target.y - size.y * .5) * .05);
    Array modules = view->get("modules");
    for (int i = 0; i < modules.size(); ++i) {
        Dictionary module = modules[i];
        Node3D *mount = Object::cast_to<Node3D>(obj(module["mount"])),
               *pivot = Object::cast_to<Node3D>(obj(module["pivot"]));
        Vector3 local = mount->to_local(world_target), rotation = pivot->get_rotation();
        rotation.y = std::atan2(-local.x, -local.z);
        pivot->set_rotation(rotation);
    }
    Object::cast_to<Node3D>(obj(view->get("shield")))->set_visible(shield_enabled);
    Object::cast_to<ShaderMaterial>(obj(view->get("shield_material")))
        ->set_shader_parameter("impact_strength", std::max(0., 1 - Math::fposmod(time, 3.8) / .6));
    Array exhaust = view->get("exhaust_nodes");
    for (int i = 0; i < exhaust.size(); ++i) {
        Node3D *n = Object::cast_to<Node3D>(obj(exhaust[i]));
        Vector3 scale = n->get_scale();
        scale.z = 1 + std::sin(time * 9 + i) * .06;
        n->set_scale(scale);
    }
    SubViewport *viewport = Object::cast_to<SubViewport>(obj(view->get("viewport")));
    if (viewport->get_update_mode() != SubViewport::UPDATE_ALWAYS)
        viewport->set_update_mode(SubViewport::UPDATE_ONCE);
    ++pose_calls;
    return true;
}

void SpacePresentationProducer::legacy_beam(Object *host, CanvasItem *s, Dictionary shot, Vector2 offset) {
    Vector2 pos = battle_point(host->call("visual_muzzle", shot)) + offset;
    Color color = tint(bool(shot["hostile"]) ? "ffbc73" : "71e5f4");
    double elapsed = scalar(shot, "elapsed"), charge_time = scalar(shot, "charge");
    if (charge_time > 0 && elapsed < charge_time) {
        double progress = clamp(elapsed / charge_time, 0, 1), radius = lerp(28, 8, progress);
        s->draw_circle(pos, 4 + progress * 8, alpha(color, .2 + progress * .4));
        s->draw_circle(pos, 2 + progress * 3, Color(1, 1, 1));
        s->draw_arc(pos, radius, -Math::PI / 2, -Math::PI / 2 + Math::TAU * progress, 32, color, 2, true);
        for (int ray = 0; ray < 6; ++ray) {
            Vector2 direction = engine_from_angle(ray * Math::TAU / 6 + elapsed * 3);
            s->draw_line(pos + direction * radius, pos + direction * (radius + 7),
                         alpha(color, .35 + progress * .5), 1.5, true);
        }
    } else if (int64_t(shot["ticks"]) > 0) {
        Dictionary style = host->call("beam_style", shot);
        double width = style["width"], power = style["power"], pulse = style["pulse"];
        Vector2 end = host->call("entity_render_position", shot["target"]);
        end += offset;
        Dictionary visual = host->get("battle_visual");
        s->draw_line(pos, end, alpha(color, .28 + power * .12 + pulse * .5),
                     width * double(visual["laser_glow_scale"]), true);
        s->draw_line(pos, end, Color(1, 1, 1, .5 + pulse * .4), width * .38, true);
        for (int stream = 0; stream < 4; ++stream) {
            double phase = Math::fposmod(elapsed * 2 + stream * .25, 1.);
            Vector2 flow = pos.lerp(end, phase);
            s->draw_line(flow, flow.lerp(end, .035), Color(1, 1, 1, .12 + pulse * .5), width * .55, true);
        }
        s->draw_circle(pos, width * 1.3, alpha(color, .45));
        s->draw_circle(end, 4 + pulse * 3, alpha(color, .3 + pulse * .3));
        s->draw_circle(end, 1.8 + pulse * 1.8, Color(1, 1, 1));
        double spark_size = double(visual["beam_hit_spark_scale"]) * (3 + pulse * 4);
        for (int spark = 0; spark < 2; ++spark) {
            Vector2 direction = engine_from_angle(elapsed * 13 + spark * Math::PI);
            s->draw_line(end + direction * 2., end + direction * spark_size, alpha(color, .3 + pulse * .55),
                         1, true);
        }
    }
}

bool SpacePresentationProducer::known_enemy(Object *host, CanvasItem *s, Dictionary enemy, Vector2 offset,
                                            bool boss) {
    // Bosses and authored legacy bay/embedded mounts are ordinary publication
    // paths, not unknown-state fallback. Validate all component implementations
    // before submitting the first command.
    Array components = host->call("enemy_weapon_components", enemy);
    for (int i = 0; i < components.size(); ++i) {
        Object *c = obj(components[i]);
        Object *script = obj(c->get_script());
        if (!script || String(script->get("resource_path")) != "res://scripts/weapon_visual.gd")
            return false;
    }
    Variant previous = host->get("draw_surface");
    host->set("draw_surface", s);
    Vector2 pos = host->call("enemy_render_position", enemy);
    pos += offset;
    double width = host->call("enemy_render_width", enemy), angle = host->call("enemy_render_angle", enemy),
           light = host->call("enemy_hull_light", enemy);
    Object *encounter = obj(host->get("encounter_presentation"));
    bool leader = encounter->call("is_leader", enemy);
    double hull_width = width * (leader ? (String(encounter->get("tier")) == "ultimate" ? 1.65 : 1.35) : 1.);
    if (boss)
        light = leader ? 1.20 : std::max(.72, light * .84);
    if (leader) {
        encounter->set("focus", pos);
        double spread = hull_width * .48 + 12,
               arrival = 1 - Math::smoothstep(0., 1.1, fields(encounter, "age"));
        Color color = encounter->get("accent");
        for (int side : {-1, 1}) {
            double x = pos.x + side * (spread + arrival * 32);
            s->draw_polyline(packed({Vector2(x - side * 12, pos.y - 32), Vector2(x, pos.y - 32),
                                     Vector2(x, pos.y + 32), Vector2(x - side * 12, pos.y + 32)}),
                             alpha(color, .35 + arrival * .35), 2, true);
        }
    }
    auto mounts = [&](bool under) {
        for (int i = 0; i < components.size(); ++i) {
            Object *component = obj(components[i]);
            Dictionary hardpoint = component->get("hardpoint");
            if ((int64_t(hardpoint.get("z", 1)) <= 0) != under)
                continue;
            Dictionary pose = host->call("enemy_component_pose", enemy, component,
                                         Vector2(INFINITY, INFINITY), width),
                       profile = component->get("profile");
            String visual_class = profile.get("visual_class", "");
            int type = component->get("damage_type");
            double w = pose["width"], aim = pose["angle"];
            Vector2 origin = pose["origin"], port = pose["port"];
            if ((type == 2 && visual_class == "gun") || (type == 1 && visual_class == "energy")) {
                bool physical = type == 2;
                w = std::max(15. / std::max(.1, double(host->call("enemy_recognition_screen_scale"))), w);
                Vector2 shift = port - Vector2((physical ? .64 : .45) * w, 0);
                s->draw_set_transform(pos + origin + engine_rotated(shift, aim), aim - Math::PI / 2);
                if (physical)
                    weapon_body(s, w, true);
                else {
                    s->draw_rect(Rect2(-w * .24, -w * .22, w * .48, w * .42), tint("36424b"));
                    for (int side : {-1, 1}) {
                        s->draw_colored_polygon(
                            packed({Vector2(side * w * .17, -w * .18), Vector2(side * w * .60, -w * .08),
                                    Vector2(side * w * .60, w * .45), Vector2(side * w * .41, w * .45),
                                    Vector2(side * w * .41, w * .07), Vector2(side * w * .17, 0)}),
                            tint("aabfc6"));
                        s->draw_line(Vector2(side * w * .49, w * .20), Vector2(side * w * .49, w * .44),
                                     tint("64b5ff"), std::max(1., w * .10), true);
                    }
                    s->draw_rect(Rect2(-w * .13, w * .02, w * .26, w * .16), tint("64b5ff"));
                }
                s->draw_set_transform(Vector2());
                continue;
            }
            s->draw_set_transform(pos + origin, aim);
            String mode = component->call("mode");
            if (mode == "bay") {
                s->draw_rect(Rect2(-w * .26, -w * .21, w * .52, w * .42), tint("292f34"));
                s->draw_line(Vector2(-w * .13, -w * .12), port, tint("b29b86"), std::max(1., w * .10), true);
            } else {
                double thickness = w * (mode == "embedded" ? .18 : .29);
                s->draw_rect(Rect2(-w * .22, -thickness * .5, w * .40, thickness), tint("485159"));
                s->draw_line(Vector2(-w * .10, 0), port, tint("b29b86"), std::max(1., w * .12), true);
            }
            s->draw_circle(port, std::max(.65, w * .06), tint("e2a36b"));
            s->draw_set_transform(Vector2());
        }
    };
    mounts(true);
    s->draw_set_transform(pos, Math::PI + angle);
    Vector2 dimensions(hull_width, hull_width * 2);
    Ref<Texture2D> texture = host->call(
        "ship_hull_texture",
        String("enemy_") + String::num_int64(std::clamp(int64_t(enemy["size"]), int64_t(1), int64_t(6))));
    s->draw_texture_rect(texture, Rect2(-dimensions / 2, dimensions), false, Color(light, light, light, 1));
    Array types = host->call("enemy_attack_types", enemy);
    if (types.has(2)) {
        deck_body(s, width, true);
        deck_strokes(s, width, true);
    }
    if (types.has(1)) {
        deck_body(s, width, false);
        deck_strokes(s, width, false);
    }
    Dictionary packet = host->call("enemy_recognition_geometry", enemy, width);
    Object *game = obj(host->get("game")), *recognition = obj(host->get("enemy_recognition"));
    Dictionary pose = host->call("enemy_pose", enemy),
               status = recognition->call("state", enemy, game->get("enemy_shield_time"), game->get("paused"),
                                          pose);
    double scale = width > 0 ? hull_width / width : 1;
    s->draw_set_transform(pos, Math::PI + angle, Vector2(1, 1) * scale);
    protection(s, enemy, width, packet, status, fields(game, "enemy_shield_time"));
    PackedVector2Array outline = packet["inner"];
    int armour = scalar(enemy, "armourType"), shield = scalar(enemy, "shieldType");
    bool visible = bool(status["show_hull"]) && (armour == 1 || armour == 2);
    if (!bool(status["alive"]) ||
        (!visible && !bool(status["repair"]) && !(bool(status["active"]) && shield >= 0 && shield <= 2)))
        outline = PackedVector2Array();
    else if (bool(status["active"]) && shield >= 0 && shield <= 2) {
        outline = visible ? PackedVector2Array(packet["outer"]) : PackedVector2Array(packet["inner"]);
        if (shield == 1 && int64_t(enemy["size"]) >= 4)
            outline =
                visible ? PackedVector2Array(packet["front"]) : PackedVector2Array(packet["single_front"]);
    }
    if (leader)
        for (int i = 0; i < outline.size(); ++i)
            outline.set(i, outline[i] * scale);
    s->draw_set_transform(Vector2());
    mounts(false);
    Dictionary layout = host->call("enemy_status_layout", enemy, pos, hull_width, angle, outline);
    host->call("battle_meter", layout["health"], scalar(enemy, "hp") / std::max(1., scalar(enemy, "max_hp")),
               tint("d9a477"));
    if (scalar(enemy, "max_shield") > 0)
        host->call("battle_meter", layout["shield"], scalar(enemy, "shield") / scalar(enemy, "max_shield"),
                   tint(shield == 2   ? "ffaf61"
                        : shield == 1 ? "64b5ff"
                                      : "c6ced2"));
    if (boss && leader)
        host->call("text_at", layout["caption"], layout["caption_position"], 17, tint("eeeede"));
    host->set("draw_surface", previous);
    return true;
}

void SpacePresentationProducer::rail_contact(CanvasItem *s, Vector2 pos, double age, Vector2 direction,
                                             double strength) {
    if (age < .04) {
        double fade = 1 - age / .04;
        s->draw_line(pos - direction * 3., pos + direction * 5., tint("9eeaff", fade), 2.2 * strength, true);
        s->draw_circle(pos, 1.7 * strength, Color(1, 1, 1, fade));
    } else if (age < .18) {
        double t = (age - .04) / .14;
        for (int i = 0; i < 3; ++i) {
            Vector2 ray = engine_rotated(direction, (i - 1) * .6), end = pos + ray * (3 + t * 13) * strength;
            s->draw_line(end - ray * 3., end, tint(i != 1 ? "c7dce7" : "9eeaff", 1 - t), .9, true);
        }
        Vector2 a = pos + direction.orthogonal() * 4. * strength,
                b = pos - direction.orthogonal() * 4. * strength;
        s->draw_polyline(packed({a, pos + direction * (2 + std::sin(age * 180) * 2), b}),
                         tint("9eeaff", (1 - t) * .5), .7, true);
        for (int side = 0; side < 2; ++side)
            s->draw_arc(pos, (3 + t * 5) * strength, side * Math::PI + .3, side * Math::PI + 1.1, 6,
                        tint("9eeaff", (1 - t) * .28), .7, true);
    }
}
