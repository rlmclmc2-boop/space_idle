// Encounter execution prototype. All mutable simulation fields below have one owner.
// Dictionaries are admission descriptors and persistent presentation rows only;
// no Object/Game callback occurs in advance, impact, death or chain execution.
#include <godot_cpp/classes/random_number_generator.hpp>
#include <limits>
#include <map>
#include <queue>
#include <type_traits>
#include "amount_value.hpp"

class SpaceCombatKernel : public RefCounted {
    GDCLASS(SpaceCombatKernel, RefCounted)
    using Amount = foundation::Amount;
    static Amount read_amount(const Variant &v) {
        if (v.get_type() == Variant::STRING) return Amount::decimal(String(v).utf8().get_data());
        if (v.get_type() == Variant::INT) return Amount::decimal(std::to_string(int64_t(v)));
        if (v.get_type() == Variant::FLOAT) return Amount::normalized(double(v));
        throw std::domain_error("AmountEncoding");
    }
    static String wire(const Amount &v) { return String(v.decimal_text().c_str()); }
    static bool finite(const Amount &) { return true; }
    static bool finite(double v) { return std::isfinite(v); }
    static Amount ceil_number(const Amount &v) { return v.ceil_value(); }
    static double ceil_number(double v) { return std::ceil(v); }
    template<class A, class B> static auto minimum(A a, B b) {
        if constexpr (std::is_same_v<A, Amount> || std::is_same_v<B, Amount>) return Amount(a) < Amount(b) ? Amount(a) : Amount(b);
        else return std::min(a,b);
    }
    template<class A, class B> static auto maximum(A a, B b) {
        if constexpr (std::is_same_v<A, Amount> || std::is_same_v<B, Amount>) return Amount(a) > Amount(b) ? Amount(a) : Amount(b);
        else return std::max(a,b);
    }

    // Presentation reads the existing active order and generation; it never owns combat.
    friend class SpaceCombatPresentation;
    struct Handle {
        uint32_t index = UINT32_MAX, generation = 0;
    };
    struct DropRule {
        double chance = 0;
        Amount amount = 0;
        Amount base = 0;
        int resource = 0;
    };
    struct Actor {
        uint32_t generation = 1;
        int64_t uid = 0, guidance_layers = 0;
        uint64_t guidance_firsts = 0, guidance_reuses = 0, guidance_growth = 0, missile_hits = 0, derived_missile_hits = 0;
        double first_guidance_factor = 0, last_guidance_factor = 0, min_guidance_factor = 0, max_guidance_factor = 0;
        bool live = true;
        Amount hp = 0;
        Amount max_hp = 0;
        Amount shield = 0;
        Amount max_shield = 0;
        double delay = 0;
        double recovery = 0;
        double shield_at = 0;
        double hit_at = 0;
        int armour_type = 0, shield_type = 0, slot = 0;
        Vector2 logical, point, screen_point;
        PackedVector2Array collision_hull;
        uint64_t geometry_revision = 0;
        bool stationary_geometry = false;
        Dictionary view;
        std::vector<DropRule> drops;
        int jewel_rolls = 0;
        double interference = 0, explosion = 0;
        bool reactive_reduction = false;
        int reactive_stacks = 0;
        double reactive_volley_at = -1e100;
    };
    struct BirthConfig {
        Dictionary weapon, entry;
        Array effects;
        int slot = 0, kind = 0, type = 0, salvo = 1, chain_count = 0;
        double speed = 0, interval = 0, charge = 0, ramp = 1, maximum = 1;
        double repeat_delay = 0, repeat_multiplier = 1;
    };
    struct Weapon {
        int kind = 0, type = 0, slot = 0;
        bool hostile = false, endless = false, vacant = false;
        Handle source;
        double interval = 1;
        double remaining = 1;
        Amount base = 1;
        double factor = 1;
        double speed = 30;
        double charge = 0;
        double ramp = 1;
        double maximum = 1;
        int salvo = 1;
        double crit_rate = 0, crit_multiplier = 2, repeat_probability = 0, repeat_multiplier = 1,
               secondary_probability = 0;
        int chain_count = 0;
        Vector2 muzzle, screen_muzzle;
        PackedVector2Array presentation_muzzles; // Display inputs only; never used by combat.
        Dictionary entry, row;
        Array branch_factors, external_factors;
        int64_t beam = -1;
        std::shared_ptr<const BirthConfig> birth;
    };
    static std::shared_ptr<const BirthConfig> birth_config(const Weapon &w, Dictionary v, double delay) {
        auto b = std::make_shared<BirthConfig>();
        b->weapon = w.row.duplicate(true); b->weapon.make_read_only();
        b->entry = w.entry.duplicate(true); b->entry.make_read_only();
        b->effects = Array(v.get("transfer_effects", Array())).duplicate(true);
        for (int i = 0; i < b->effects.size(); ++i) { Dictionary e = b->effects[i]; e.make_read_only(); }
        b->effects.make_read_only(); b->slot = w.slot; b->kind = w.kind; b->type = w.type;
        b->salvo = w.salvo; b->chain_count = w.chain_count; b->speed = w.speed; b->interval = w.interval;
        b->charge = w.charge; b->ramp = w.ramp; b->maximum = w.maximum;
        b->repeat_delay = delay; b->repeat_multiplier = w.repeat_multiplier; return b;
    }
    Weapon committed_weapon(int wi, const std::shared_ptr<const BirthConfig> &b) const {
        Weapon w = weapons[wi];
        w.kind = b->kind; w.type = b->type; w.salvo = b->salvo; w.chain_count = b->chain_count;
        w.speed = b->speed; w.interval = b->interval; w.charge = b->charge;
        w.ramp = b->ramp; w.maximum = b->maximum; w.row = b->weapon; return w;
    }
    struct MissileContext {
        uint64_t id = 0, root = 0;
        String source;
        bool derived = false, chain = false, wild = false, wild_used = false;
        double blast = 0;
        std::map<int64_t, double> factors;
    };
    struct Attack {
        uint64_t id = 0;
        Amount damage = 0;
        bool critical = false, secondary = false, repeats = false;
        std::shared_ptr<MissileContext> context;
        std::shared_ptr<const BirthConfig> birth;
    };
    struct Instance {
        uint64_t id = 0;
        std::shared_ptr<const Attack> attack;
        bool chain_used = false, beam = false, ended = false, derived = false;
        int count = 0;
        Handle primary;
        std::vector<Handle> links;
        Dictionary view;
    };
    struct Flight {
        uint32_t generation = 1;
        bool live = false, hostile = false, beam = false, repeated = false, chain = false, prism = false;
        size_t active_index = 0, beam_index = 0, compatibility_index = SIZE_MAX;
        bool compact_laser = false, target_view_cleared = false;
        bool view_repeated = false, owns_primary_aim = false;
        int view_trigger_depth = 0;
        // The row at actual carrier birth can differ from Attack.birth after
        // an upgrade while a repeat is queued. Retain that immutable descriptor.
        std::shared_ptr<const BirthConfig> view_birth;
        uint64_t born_step = 0, serial = 0;
        int weapon = -1, type = 0, source_slot = 0;
        Handle source, target;
        std::shared_ptr<Instance> instance;
        std::shared_ptr<MissileContext> context;
        Amount multiplier = 1;
        Amount damage = 0;
        double cruise_speed = 0;
        double age = 0;
        double next_hit = 0;
        double charge = 0;
        double interval = 0;
        double ramp = 1;
        double maximum = 1;
        int ticks = 0;
        Vector2 aim, logical_aim;
        bool await_target = false;
        bool fixed_ray = false;
        Vector2 ray_origin, ray_step, launch_point;
        bool presentation_ray = false;
        Vector2 presentation_origin, presentation_step; // Frozen at actual birth, before first display.
        uint64_t contact_revision = 0;
        double contact_distance = -1;
        Ref<SpaceMotionLease> lease;
        Dictionary view;
    };
    struct Timed {
        double at = 0;
        uint64_t serial = 0;
        int kind = 0, weapon = 0, ordinal = 0;
        Handle target;
        std::shared_ptr<const Attack> attack;
        Amount multiplier = 1;
        std::shared_ptr<Instance> instance;
        size_t owner_flight = SIZE_MAX;
        uint32_t owner_generation = 0;
        bool damage_derived = false; // Carrier provenance is separate from shared chain allowance.
        std::shared_ptr<MissileContext> context;
    };
    struct Later {
        bool operator()(const Timed &a, const Timed &b) const {
            return a.at == b.at ? a.serial > b.serial : a.at > b.at;
        }
    };
    struct RootQueue : std::priority_queue<Timed, std::vector<Timed>, Later> {
        const std::vector<Timed> &entries() const { return this->c; }
    };
    struct Defence {
        Dictionary entry;
        Array branch_factors, external_factors;
        Amount maximum = 0;
        int layer = 0, type = 0;
        Amount base = 0;
        double factor = 1;
        Amount loss = 0;
        Amount buffer = 0;
        double delay = 0;
        double rate = 0;
        double last_hit = 0;
        double memory_heal = 0;
        double memory_cap = 0;
        double deferred_fraction = 0;
    };
    struct Effect {
        int kind = 0, type = 0;
        bool player = false, critical = false;
        int64_t uid = 0;
        Amount amount = 0;
        Amount absorbed = 0;
        double time = 0;
        int reactive_stacks = -1;
        double reactive_multiplier = 1;
        Vector2 point, direction, target_point;
        bool presentation_ray = false;
        Vector2 presentation_origin, presentation_step;
        int64_t target_uid = -1;
        Dictionary shot;
        // Value-owned feedback survives compact()/slot reuse. No flight lookup
        // after emission and no compatibility shot/lease allocation for lasers.
        bool compact_laser = false, laser_owns_aim = false, laser_drone = false;
        uint64_t laser_serial = 0;
        int laser_mount = -1;
        Vector2 laser_launch, laser_ray_origin, laser_ray_step;
        Dictionary laser_primary;
    };
    // Optional observation. Combat never reads this ledger.
    bool damage_stats_enabled = false;
    std::map<String, std::array<Amount, 2>> damage_stats;
    std::vector<Actor> actors;
    std::vector<Weapon> weapons;
    std::vector<Defence> defences;
    std::map<int64_t, std::array<Amount, 2>> debts;
    double defence_time = 0, memory_interval = 1, deferred_interval = 1, memory_elapsed = 0,
           deferred_elapsed = 0, deferred_duration = 1, clear_probability = 0, counter_growth = 0,
           defence_counter_growth = 0, counter_log_base = 10, counter_round_scale = 10;
    int64_t deferred_tick = 0;
    int64_t attack_counter = 0, incoming_counter = 0, counter_level = 0;
    String failure_reason;
    bool increment_history(int64_t &value) {
        if (value == std::numeric_limits<int64_t>::max()) { failure_reason = "CounterRangeExceeded"; stopped = true; return false; }
        ++value; return true;
    }
    // Encounter envelopes retain old birth configurations across numeric upgrades.
    // They only widen; no hot scan of carriers or queues is required.
    double retained_min_interval = std::numeric_limits<double>::infinity();
    int retained_salvo_bound = 1, retained_chain_bound = 0;
    double retained_drop_bound = 0;
    bool module_defence = false;

    std::deque<Flight> flights;
    std::vector<size_t> active, active_beams, free_flights, retired;
    RootQueue roots;
    std::priority_queue<Timed, std::vector<Timed>, Later> ejections, repeats;
    std::vector<Effect> feedback;
    std::shared_ptr<MotionArena> motion_arena = std::make_shared<MotionArena>();
    Ref<RandomNumberGenerator> rng;
    Array actor_rows, flight_rows;
    std::vector<size_t> compatibility_flights;
    bool compact_laser_births = false;
    int64_t laser_view_revision = 0;
    size_t compact_laser_count = 0;
    Dictionary player_row;
    Dictionary buffer_rows, loss_rows, defence_time_rows;
    Vector2 player_point;
    PackedVector2Array player_collision_hull;
    double target_slot_center = 0, battle_width = 0;
    double missile_departure_angle = 0, missile_launch_edge_margin = 0, missile_launch_forward_y = 0;
    uint32_t encounter_generation = 1;
    uint64_t refit_epoch = 0;
    uint64_t step_serial = 0, event_serial = 0, attack_serial = 0, instance_serial = 0, flight_serial = 0;
    double clock = 0;
    Amount player_hp = 0;
    Amount player_initial_hp = 0, player_initial_shield = 0;
    Amount player_shield = 0;
    double resistance = 0.5;
    double reactive_volley_window = 0, reactive_stack_seconds = 0, reactive_per_stack = 0;
    int reactive_stack_limit = 0;
    double projectile_min_x = 0, projectile_max_x = 0, projectile_min_y = 0, projectile_max_y = 0;
    double last_incoming_at = -100;
    double jewel_probability = 0, jewel_ratio = 1;
    int64_t drop_uid = 0;
    bool drop_rules = false;
    bool admitted = false, stopped = false, scatter = false, executing = false;
    bool final_encounter = false, final_cleared = false;
    int chain_count = 0, prism_count = 0;
    double crit_rate = 0, crit_multiplier = 2, repeat_probability = 0, repeat_multiplier = 1,
           repeat_delay = 0, secondary_probability = 0, scatter_bonus = 0, prism_bonus = 0;
    double laser_charge_multiplier = 1;
    bool guidance_enabled = false, guidance_limited = false, wild_enabled = false;
    double guidance_multiplier = 1, wild_multiplier = 1, wild_blast = 0;
    int64_t guidance_limit = 0, wild_period = 0, missile_attacks = 0;
    int wild_damage_type = 0;
    uint64_t context_serial = 0, wild_replacements = 0, wild_detonations = 0, wild_recursion_blocks = 0;
    std::shared_ptr<MissileContext> missile_context(const Weapon &w, uint64_t root, bool derived, bool chain = false) {
        auto c = std::make_shared<MissileContext>(); c->id = ++context_serial; c->root = root;
        c->source = w.entry.has("drone_id") ? String("drone:") + String(w.entry["drone_id"]) : String("module:") + String::num_int64(w.slot);
        c->derived = derived; c->chain = chain; return c;
    }
    void configure_missile_legends(Dictionary d) {
        guidance_enabled = d.get("precise_guidance",false); guidance_multiplier = d.get("guidance_multiplier",1.0);
        guidance_limited = d.get("guidance_limited",false); guidance_limit = d.get("guidance_limit",0);
        wild_enabled = d.get("wild_missile",false); wild_multiplier = d.get("wild_multiplier",1.0);
        wild_period = d.get("wild_period",0); wild_blast = d.get("wild_blast",0.0);
        wild_damage_type = d.get("wild_damage_type",0);
    }
    struct StrangePacket {
        uint64_t order = 0, root = 0;
        Amount damage = 0;
        int type = 0;
        String source;
        String stats_source;
    };
    // Deadlines select due work; insertion order controls settlement and cold export.
    std::multimap<double, StrangePacket> strange_pending;
    uint64_t strange_serial = 0;
    bool strange_enabled = false;
    double strange_probability = 0, strange_delay = 0, strange_multiplier = 0, strange_boundary_end = 0;
    int strange_kill_spawns = 0, strange_type = 0;
    void configure_strange(Dictionary d) {
        strange_enabled = d.get("requires_strange_matter", false);
        strange_probability = d.get("strange_probability", 0.0);
        strange_delay = d.get("strange_delay", 0.0);
        strange_multiplier = d.get("strange_damage_multiplier", 0.0);
        strange_kill_spawns = d.get("strange_kill_spawns", 0);
        strange_type = d.get("strange_damage_type", 0);
    }
    Array export_strange() const {
        std::map<uint64_t, Dictionary> ordered;
        for (const auto &item : strange_pending) {
            const StrangePacket &p = item.second;
            Dictionary context, row;
            context["root_id"] = int64_t(p.root); context["batch_id"] = int64_t(p.root);
            context["source_id"] = p.source; context["weapon"] = "cannon";
            context["trigger_depth"] = 1; context["trigger"] = "strange_matter";
            context["guidance_factors"] = Dictionary();
            row["remaining"] = nonnegative(item.first - clock); row["damage"] = wire(p.damage);
            row["type"] = p.type; row["context"] = context;
            ordered.emplace(p.order, row);
        }
        Array rows;
        for (const auto &item : ordered) rows.append(item.second);
        return rows;
    }
    void advance_strange(double end) {
        std::map<uint64_t, StrangePacket> due;
        while (!strange_pending.empty() && strange_pending.begin()->first <= end + 1e-9) {
            const auto first = strange_pending.begin();
            due.emplace(first->second.order, first->second);
            strange_pending.erase(first);
        }
        for (const auto &item : due) {
            const StrangePacket &p = item.second;
            for (size_t i = 0; i < actors.size(); ++i)
                if (actors[i].live) hit_enemy(handle(i), p.damage, p.type, {}, false, clock, -1, false, {},
                                               p.stats_source.is_empty() ? p.source : p.stats_source);
        }
    }
    double ejection_gap = 0.12, launch_speed = 120, turn_rate = 4, ignition = 0.22, seek = 0.4,
           cruise_at = 0.65, lifetime = 4.5, orphan_lifetime = 30, brake_range = 120, brake_angle = 0.3,
           min_speed = 60, brake_factor = 0.7, hit_radius = 5, chain_speed = 720;
    uint64_t root_attacks = 0, hit_count = 0, dead_count = 0, stale_rejections = 0, physics_visits = 0;
    uint64_t ballistic_checks = 0, ballistic_skips = 0, ballistic_ray_queries = 0;
    Actor *resolve(Handle h) {
        return h.index < actors.size() && actors[h.index].generation == h.generation && actors[h.index].live
                   ? &actors[h.index]
                   : nullptr;
    }
    const Actor *resolve(Handle h) const {
        return h.index < actors.size() && actors[h.index].generation == h.generation && actors[h.index].live
                   ? &actors[h.index]
                   : nullptr;
    }
    Handle handle(size_t index) const {
        return {uint32_t(index), actors[index].generation};
    }
    static bool finite_descriptor(const Variant &value) {
        switch (value.get_type()) {
        case Variant::FLOAT:
            return finite(double(value));
        case Variant::VECTOR2: {
            Vector2 point = value;
            return finite(point.x) && finite(point.y);
        }
        case Variant::DICTIONARY: {
            Dictionary values = value;
            Array keys = values.keys();
            for (int i = 0; i < keys.size(); ++i)
                if (!finite_descriptor(values[keys[i]]))
                    return false;
            return true;
        }
        case Variant::ARRAY: {
            Array values = value;
            for (int i = 0; i < values.size(); ++i)
                if (!finite_descriptor(values[i]))
                    return false;
            return true;
        }
        case Variant::OBJECT:
        case Variant::CALLABLE:
            return false; // Configuration cannot retain a legacy executor.
        default:
            return true;
        }
    }
    static bool numeric_fields(Dictionary values, std::initializer_list<const char *> keys) {
        for (const char *key : keys) {
            if (!values.has(key))
                continue;
            Variant value = values[key];
            const std::string field(key);
            if (field == "hp" || field == "max_hp" || field == "armour" || field == "shield" || field == "max_shield" || field == "damage" || field == "amount" || field == "base" || field == "loss" || field == "buffer" || field == "maximum") {
                try { read_amount(value); } catch (const std::exception &) { return false; }
            } else if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) return false;
        }
        return true;
    }
    static bool schema_types(Dictionary row, Variant::Type type,
                             std::initializer_list<const char *> keys) {
        for (const char *key : keys)
            if (row.has(key) && Variant(row[key]).get_type() != type) return false;
        return true;
    }
    static bool schema_integers(Dictionary row, std::initializer_list<const char *> keys,
                                bool narrow = true) {
        if (!schema_types(row, Variant::INT, keys)) return false;
        for (const char *key : keys) {
            if (!row.has(key) || !narrow) continue;
            int64_t value = row[key];
            if (value < std::numeric_limits<int>::min() || value > std::numeric_limits<int>::max()) return false;
        }
        return true;
    }
    static bool schema_required(Dictionary row, std::initializer_list<const char *> keys) {
        for (const char *key : keys) if (!row.has(key)) return false;
        return true;
    }
    static bool schema_nonnegative(Dictionary row, std::initializer_list<const char *> keys) {
        for (const char *key : keys)
            if (row.has(key) && Variant(row[key]).get_type() != Variant::STRING && double(row[key]) < 0) return false;
        return true;
    }
    static bool schema_probabilities(Dictionary row, std::initializer_list<const char *> keys) {
        for (const char *key : keys)
            if (row.has(key) && (double(row[key]) < 0 || double(row[key]) > 1)) return false;
        return true;
    }
    // Pure descriptor admission. No casts of unchecked fields, RNG draws or owner mutation.
    // GrowthNumber dictionaries are valid legacy values, but never native scalar values.
    static bool configuration_schema(Dictionary d) {
        if (!finite_descriptor(d) || !schema_required(d, {"player","enemies","weapons","target_slot_center"}) ||
            !schema_types(d, Variant::DICTIONARY, {"player","deferred"}) ||
            !schema_types(d, Variant::ARRAY, {"enemies","weapons","defences","unsupported_rules"}) ||
            !schema_types(d, Variant::BOOL, {"final_encounter","scatter","requires_strange_matter","requires_laser_charge","requires_endless_beam","drop_rules_compiled","requires_drop_rules","requires_module_defense"}) ||
            !schema_integers(d, {"chain_count","prism_count"}) ||
            !schema_integers(d, {"rng_state","projectile_serial","attack_serial","instance_serial","deferred_tick","drop_uid","attack_counter","incoming_counter","counter_level","reactive_stack_limit"}, false) ||
            !numeric_fields(d, {"reactive_volley_window","reactive_stack_seconds","reactive_per_stack","projectile_min_x","projectile_max_x","projectile_min_y","projectile_max_y","target_slot_center","battle_width","missile_departure_angle","missile_launch_edge_margin","missile_launch_forward_y","clock","since_hit","ejection_gap","launch_speed","turn_rate","ignition","seek","cruise_at","lifetime","orphan_lifetime","brake_range","brake_angle","min_speed","brake_factor","hit_radius","chain_speed","resistance","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","repeat_delay","secondary_probability","scatter_bonus","laser_charge_multiplier","prism_bonus","counter_growth","defence_counter_growth","counter_log_base","counter_round_scale","memory_interval","deferred_interval","deferred_duration","clear_probability","defence_time","memory_elapsed","deferred_elapsed","jewel_probability","jewel_ratio"})) return false;
        if (!Array(d.get("unsupported_rules", Array())).is_empty() ||
            !schema_nonnegative(d, {"since_hit","launch_speed","turn_rate","ignition","seek","lifetime","orphan_lifetime","brake_range","brake_angle","min_speed","brake_factor","hit_radius","critical_multiplier","repeat_multiplier","repeat_delay","attack_counter","incoming_counter","counter_growth","defence_counter_growth","counter_level","scatter_bonus","prism_bonus","deferred_duration","defence_time","memory_elapsed","deferred_elapsed","jewel_ratio","chain_count","prism_count","projectile_serial","attack_serial","instance_serial","deferred_tick","drop_uid"}) ||
            !schema_probabilities(d, {"resistance","critical_rate","repeat_probability","secondary_probability","clear_probability","jewel_probability"})) return false;
        if ((bool(d.get("requires_laser_charge", false)) && !d.has("laser_charge_multiplier")) ||
            double(d.get("laser_charge_multiplier", 1.0)) < 1) return false;
        if (!numeric_fields(d, {"strange_probability","strange_delay","strange_damage_multiplier"}) ||
            !schema_integers(d, {"strange_kill_spawns","strange_damage_type"}) ||
            !schema_nonnegative(d, {"strange_delay","strange_damage_multiplier","strange_kill_spawns","strange_damage_type"}) ||
            !schema_probabilities(d, {"strange_probability"}) || int(d.get("strange_damage_type",0)) > 2 ||
            (bool(d.get("requires_strange_matter",false)) && !schema_required(d, {"strange_probability","strange_delay","strange_damage_multiplier","strange_kill_spawns","strange_damage_type"}))) return false;
        if (!schema_types(d, Variant::BOOL, {"requires_missile_legends","precise_guidance","guidance_limited","wild_missile"}) ||
            !numeric_fields(d, {"guidance_multiplier","wild_multiplier","wild_blast"}) ||
            !schema_integers(d, {"guidance_limit","wild_period","missile_attacks"}, false) || !schema_integers(d, {"wild_damage_type"}) ||
            !schema_nonnegative(d, {"guidance_multiplier","wild_multiplier","wild_blast","guidance_limit","wild_period","missile_attacks","wild_damage_type"}) || int(d.get("wild_damage_type",0)) > 2 ||
            double(d.get("guidance_limit",0)) >= 9007199254740991.0 || double(d.get("wild_period",0)) >= 9007199254740991.0 || double(d.get("missile_attacks",0)) >= 9007199254740991.0) return false;
        if ((bool(d.get("precise_guidance",false)) && !schema_required(d, {"guidance_multiplier","guidance_limited","guidance_limit"})) ||
            (bool(d.get("wild_missile",false)) && !schema_required(d, {"wild_multiplier","wild_period","wild_blast","wild_damage_type","missile_attacks"}))) return false;
        double mi = d.get("memory_interval", 1.0), di = d.get("deferred_interval", 1.0);
        double lb = d.get("counter_log_base", 10.0);
        if (double(d.get("chain_speed",720.0)) <= 0 || double(d.get("ejection_gap", .12)) <= 0 || double(d.get("cruise_at", .65)) <= double(d.get("ignition", .22)) ||
            mi <= 1e-9 || di <= 1e-9 || double(d.get("memory_elapsed", 0.0)) >= mi ||
            double(d.get("deferred_elapsed", 0.0)) >= di || lb <= 0 || lb == 1 ||
            double(d.get("counter_round_scale", 10.0)) <= 0) return false;
        Dictionary player = d["player"];
        if (!schema_required(player, {"armour","shield"}) ||
            !numeric_fields(player, {"armour","shield","x","y"}) ||
            !schema_integers(player, {"armour_type","shield_type"}) ||
            int(player.get("armour_type",0)) < 0 || int(player.get("armour_type",0)) > 2 ||
            int(player.get("shield_type",0)) < 0 || int(player.get("shield_type",0)) > 2 ||
            !schema_nonnegative(player, {"armour","shield"})) return false;
        Array enemies = d["enemies"], weapons = d["weapons"], defs = d.get("defences", Array());
        if ((bool(d.get("requires_module_defense", false)) && defs.is_empty()) ||
            (bool(d.get("requires_drop_rules", false)) && !bool(d.get("drop_rules_compiled", false)))) return false;
        for (int i = 0; i < enemies.size(); ++i) {
            if (Variant(enemies[i]).get_type() != Variant::DICTIONARY) return false;
            Dictionary v = enemies[i];
            if (!schema_required(v, {"uid","hp","max_hp","x","y"}) ||
                !schema_integers(v, {"uid"}, false) || !schema_integers(v, {"armourType","shieldType","slot","jewel_rolls","reactiveReduction","reactive_stacks"}) ||
                !schema_types(v, Variant::ARRAY, {"compiled_drops"}) ||
                !numeric_fields(v, {"hp","max_hp","shield","max_shield","x","y","shield_hit_at","shield_updated_at","shieldDelay","shieldRecovery","interference","jewelExplosion","reactive_volley_at"}) ||
                !schema_nonnegative(v, {"max_hp","shield","max_shield","shieldDelay","shieldRecovery","interference","jewelExplosion","jewel_rolls","slot"}) ||
                int(v.get("armourType",0)) < 0 || int(v.get("armourType",0)) > 2 ||
                int(v.get("shieldType",0)) < 0 || int(v.get("shieldType",0)) > 2 ||
                int(v.get("reactiveReduction",0)) < 0 || int(v.get("reactiveReduction",0)) > 1 ||
                int(v.get("reactive_stacks",0)) < 0 || int(v.get("reactive_stacks",0)) > int(d.get("reactive_stack_limit",0))) return false;
            Array drops = v.get("compiled_drops", Array());
            for (int j = 0; j < drops.size(); ++j) {
                if (Variant(drops[j]).get_type() != Variant::DICTIONARY) return false;
                Dictionary drop = drops[j];
                if (!schema_required(drop, {"chance","amount","base","resource"}) ||
                    !numeric_fields(drop, {"chance","amount","base"}) || !schema_integers(drop, {"resource"}) ||
                    !schema_nonnegative(drop, {"amount","base","resource"}) || !schema_probabilities(drop, {"chance"})) return false;
            }
        }
        int endless_sources = 0;
        for (int i = 0; i < weapons.size(); ++i) {
            if (Variant(weapons[i]).get_type() != Variant::DICTIONARY) return false;
            Dictionary v = weapons[i];
            if (!schema_required(v, {"kind"}) || !schema_integers(v, {"kind","type","slot","source","salvo","chain_count"}) ||
                !schema_types(v, Variant::BOOL, {"hostile","endless"}) || !schema_types(v, Variant::VECTOR2, {"muzzle"}) ||
                !schema_types(v, Variant::DICTIONARY, {"entry","row"}) || !schema_types(v, Variant::ARRAY, {"transfer_effects","branch_factors","external_factors"}) ||
                !numeric_fields(v, {"damage","factor","interval","remaining","speed","charge","ramp","maximum","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","secondary_probability"}) ||
                !schema_nonnegative(v, {"damage","factor","ramp","maximum","critical_multiplier","repeat_multiplier","chain_count","slot"}) ||
                !schema_probabilities(v, {"critical_rate","repeat_probability","secondary_probability"})) return false;
            int kind = v["kind"], source = v.get("source", -1);
            if (kind < 0 || kind > 3 || int(v.get("type",1)) < 0 || int(v.get("type",1)) > 2 || double(v.get("interval", 1.0)) <= 0 || double(v.get("speed", 720.0)) <= 0 ||
                int(v.get("salvo", 1)) < 1 || (bool(v.get("hostile", false)) && (source < 0 || source >= enemies.size()))) return false;
            if (bool(v.get("endless", false))) {
                Dictionary entry = v.get("entry", Dictionary());
                if (++endless_sources > 1 || !bool(d.get("requires_endless_beam",false)) || kind != 3 ||
                    bool(v.get("hostile",false)) || entry.has("drone_id")) return false;
            }
            Array effects = v.get("transfer_effects", Array());
            for (int j = 0; j < effects.size(); ++j)
                if (Variant(effects[j]).get_type() != Variant::DICTIONARY) return false;
        }
        for (int i = 0; i < defs.size(); ++i) {
            if (Variant(defs[i]).get_type() != Variant::DICTIONARY) return false;
            Dictionary v = defs[i];
            if (!schema_types(v, Variant::DICTIONARY, {"entry"}) || !schema_types(v, Variant::ARRAY, {"branch_factors","external_factors"}) || !schema_integers(v, {"layer","type"}) ||
                !numeric_fields(v, {"base","factor","maximum","loss","buffer","delay","rate","last_hit","memory_heal","memory_cap","deferred_fraction"}) ||
                !schema_nonnegative(v, {"base","factor","maximum","loss","buffer","delay","rate","memory_heal","memory_cap","deferred_fraction"}) ||
                int(v.get("layer", 0)) < 0 || int(v.get("layer", 0)) > 1 ||
                int(v.get("type",0)) < 0 || int(v.get("type",0)) > 2 || double(v.get("deferred_fraction", 0.0)) >= 1) return false;
        }
        Dictionary debts = d.get("deferred", Dictionary());
        Array keys = debts.keys();
        for (int i = 0; i < keys.size(); ++i) {
            if (Variant(keys[i]).get_type() != Variant::INT || int64_t(keys[i]) < 0 ||
                Variant(debts[keys[i]]).get_type() != Variant::DICTIONARY) return false;
            Dictionary payment = debts[keys[i]];
            if (!numeric_fields(payment, {"shield","armour"}) || !schema_nonnegative(payment, {"shield","armour"})) return false;
        }
        return true;
    }

    static Amount history_bonus(int64_t count, double growth, int64_t level, double log_base, double round_scale) {
        if (count < 0 || level < 0 || log_base <= 0 || log_base == 1 || round_scale <= 0) throw std::domain_error("InvalidHistoryParameters");
        if (count <= 1 || level == 0 || growth == 0) return {};
        Amount bonus = Amount(growth) * Amount::decimal(std::to_string(level));
        bonus *= Amount(double(std::log(static_cast<long double>(count)) / std::log(static_cast<long double>(log_base))));
        // The gameplay formula rounds the bonus; Amount owns all magnitude arithmetic.
        return (bonus * round_scale + 0.5).floor_value() / round_scale;
    }
    static Amount evaluate_module_value(const Amount &charged, int64_t count, double growth, int64_t level, double log_base, double round_scale, Array branches = {}, Array external = {}) {
        Amount value = (charged * (Amount(1) + history_bonus(count, growth, level, log_base, round_scale))).ceil_value();
        for (int i = 0; i < branches.size(); ++i) value *= read_amount(branches[i]);
        for (int i = 0; i < external.size(); ++i) value *= read_amount(external[i]);
        return value;
    }
    static bool configuration_arithmetic(Dictionary d, int64_t attacks, int64_t incoming) {
        try {
            double log_base = d.get("counter_log_base", 10.0), scale = d.get("counter_round_scale", 100.0);
            int64_t level = d.get("counter_level", int64_t(0));
            history_bonus(attacks, d.get("counter_growth", 0.0), level, log_base, scale);
            history_bonus(incoming, d.get("defence_counter_growth", 0.0), level, log_base, scale);
            Array weapons = d.get("weapons", Array()), defences = d.get("defences", Array());
            for (int i = 0; i < weapons.size(); ++i) {
                Dictionary row = weapons[i];
                Amount value = bool(row.get("hostile", false)) ? read_amount(row.get("damage", 1.0)) :
                    evaluate_module_value(read_amount(row.get("damage", 1.0)), attacks, d.get("counter_growth", 0.0), level,
                        log_base, scale, row.get("branch_factors", Array()), row.get("external_factors", Array()));
                value *= read_amount(row.get("factor", 1.0));
            }
            for (int i = 0; i < defences.size(); ++i) {
                Dictionary row = defences[i];
                Amount value = evaluate_module_value(read_amount(row.get("base", 0.0)), incoming,
                    d.get("defence_counter_growth", 0.0), level, log_base, scale,
                    row.get("branch_factors", Array()), row.get("external_factors", Array()));
                value *= read_amount(row.get("factor", 1.0));
            }
            return true;
        } catch (const std::exception &) { return false; }
    }
    static Vector2 axis(double angle) {
        return Vector2(std::cos(angle), std::sin(angle));
    }
    static double angle(Vector2 value) {
        return std::atan2(value.y, value.x);
    }
    static Vector2 unit(Vector2 value) {
        double n = std::hypot(double(value.x), double(value.y));
        return n > 0 ? Vector2(value.x / n, value.y / n) : Vector2(0, -1);
    }
    static double distance(Vector2 a, Vector2 b) {
        return std::hypot(double(a.x - b.x), double(a.y - b.y));
    }
    static Amount nonnegative(const Amount &a) { return a; }
    static double nonnegative(double a) {
        return maximum(0.0, a);
    }
    void shield(Actor &a, double at) {
        if (!a.live || a.max_shield <= 0)
            return;
        if (at <= a.shield_at) return; // Duplicate/boundary reads never rewind the ledger.
        double ready = a.hit_at + a.delay;
        double elapsed = nonnegative(at - ready) - nonnegative(a.shield_at - ready);
        if (elapsed > 0)
            a.shield = minimum(a.max_shield, a.shield + a.max_shield * a.recovery * elapsed);
        a.shield_at = at;
        a.view["shield"] = wire(a.shield);
        a.view["shield_updated_at"] = at;
    }
    std::vector<Handle> targets(int type, double at) {
        std::vector<Handle> result;
        for (size_t i = 0; i < actors.size(); ++i)
            if (actors[i].live) {
                shield(actors[i], at);
                result.push_back(handle(i));
            }
        std::sort(result.begin(), result.end(), [&](Handle x, Handle y) {
            const Actor &a = actors[x.index], &b = actors[y.index];
            int ar = a.shield > 0 ? a.shield_type : a.armour_type,
                br = b.shield > 0 ? b.shield_type : b.armour_type;
            if (type && ((ar == type) != (br == type)))
                return ar != type;
            if (a.logical.y != b.logical.y)
                return a.logical.y > b.logical.y;
            double ac = std::abs(a.slot - target_slot_center), bc = std::abs(b.slot - target_slot_center);
            return ac == bc ? a.slot < b.slot : ac < bc;
        });
        return result;
    }
    Dictionary target_view(Handle h) {
        Actor *a = resolve(h);
        return a ? a->view : Dictionary();
    }
    void effect(int kind, const Flight &f, Vector2 p, double at) {
        Effect e;
        e.kind = kind;
        e.type = f.type;
        e.critical = f.instance && f.instance->attack->critical;
        e.time = at;
        e.point = p;
        e.direction = f.lease.is_valid() ? f.lease->motion().direction : Vector2(0, -1);
        if (f.compact_laser) {
            e.compact_laser = true; e.laser_serial = f.serial;
            e.laser_mount = f.view_birth->slot;
            e.laser_drone = f.view_birth->entry.has("drone_id");
            e.laser_owns_aim = f.owns_primary_aim;
            e.laser_primary = f.instance->view.get("primary_target", target_view(f.target));
            e.laser_launch = f.launch_point; e.laser_ray_origin = f.ray_origin; e.laser_ray_step = f.ray_step;
        } else e.shot = f.view;
        e.presentation_ray = f.presentation_ray;
        e.presentation_origin = f.presentation_origin; e.presentation_step = f.presentation_step;
        e.target_point = f.aim;
        Actor *target = resolve(f.target);
        e.target_uid = target ? target->uid : -1;
        feedback.push_back(e);
    }
    std::shared_ptr<Instance> instance(std::shared_ptr<const Attack> a, bool beam = false) {
        auto i = std::make_shared<Instance>();
        i->id = ++instance_serial;
        i->attack = a;
        i->count = a->birth->chain_count;
        i->beam = beam;
        i->view["id"] = int64_t(i->id);
        Dictionary chain;
        chain["instance_id"] = int64_t(i->id);
        chain["used"] = false;
        chain["beam"] = beam;
        chain["ended"] = false;
        chain["links"] = Array();
        i->view["chain"] = chain;
        return i;
    }
    void retire(size_t id, int reason = 0) {
        Flight &f = flights[id];
        if (!f.live)
            return;
        f.live = false;
        if (f.compact_laser) --compact_laser_count;
        if (f.beam) {
            active_beams[f.beam_index] = active_beams.back();
            flights[active_beams.back()].beam_index = f.beam_index;
            active_beams.pop_back();
        }
        if (!f.view.is_empty()) f.view["dead"] = true;
        retired.push_back(id);
        if (f.beam && f.weapon >= 0 && weapons[f.weapon].beam == int64_t(id)) {
            weapons[f.weapon].beam = -1;
            if (!stopped)
                roots.push({clock, ++event_serial, 0, f.weapon});
        }
        if (f.instance && f.beam) {
            f.instance->ended = true;
            Dictionary c = f.instance->view["chain"];
            c["ended"] = true;
            c["links"] = Array();
        }
        if (reason)
            effect(5, f, f.lease->get_position(), clock);
    }
    void compact() {
        for (size_t id : retired) {
            Flight &f = flights[id];
            size_t at = f.active_index;
            if (at < active.size() && active[at] == id) {
                active[at] = active.back();
                flights[active[at]].active_index = at;
                active.pop_back();
            }
            // Compatibility membership is a subset, never indexed by active_index.
            if (f.compatibility_index != SIZE_MAX) {
                size_t row = f.compatibility_index, moved = compatibility_flights.back();
                flight_rows[row] = flight_rows[flight_rows.size() - 1];
                compatibility_flights[row] = moved;
                flights[moved].compatibility_index = row;
                flight_rows.remove_at(flight_rows.size() - 1);
                compatibility_flights.pop_back();
                f.compatibility_index = SIZE_MAX;
            }
            f.lease.unref();
            f.instance.reset();
            f.context.reset();
            f.view_birth.reset();
            f.view = Dictionary();
            free_flights.push_back(id);
        }
        retired.clear();
    }
    size_t birth(int wi, Handle target, std::shared_ptr<Instance> inst, Amount multiplier,
                 bool repeated = false, bool chain = false, Vector2 origin = Vector2(), std::shared_ptr<MissileContext> missile_ctx = {}, int launch_ordinal = -1) {
        Weapon w = committed_weapon(wi, inst->attack->birth);
        size_t id;
        if (free_flights.empty()) {
            id = flights.size();
            flights.emplace_back();
        } else {
            id = free_flights.back();
            free_flights.pop_back();
        }
        uint32_t generation = flights[id].generation + 1;
        flights[id] = Flight();
        Flight &f = flights[id];
        f.generation = generation;
        f.live = true;
        f.weapon = wi;
        f.cruise_speed = w.speed;
        f.type = w.type;
        f.hostile = w.hostile;
        f.target = target;
        f.source = w.source;
        f.source_slot = w.hostile && w.source.index < actors.size() ? actors[w.source.index].slot : w.slot;
        f.instance = inst;
        if (!w.hostile && w.kind == 2) f.context = missile_ctx ? missile_ctx : (chain || repeated ? missile_context(w,inst->attack->id,true,chain) : inst->attack->context);
        f.multiplier = multiplier;
        f.damage = inst->attack->damage * multiplier;
        f.repeated = repeated || inst->derived;
        f.view_repeated = repeated; f.owns_primary_aim = !w.hostile && !repeated && !chain;
        f.view_trigger_depth = repeated || chain || (f.context && f.context->derived) ? 1 : 0;
        f.chain = chain;
        f.beam = w.kind == 3 && !chain;
        f.serial = ++flight_serial;
        f.born_step = step_serial;
        f.active_index = active.size();
        active.push_back(id);
        Ref<SpaceMotionLease> lease;
        lease.instantiate();
        lease->arena = motion_arena;
        if (motion_arena->free_slots.empty()) {
            lease->slot = motion_arena->motions.size();
            motion_arena->motions.emplace_back();
        } else {
            lease->slot = motion_arena->free_slots.back();
            motion_arena->free_slots.pop_back();
        }
        lease->generation = ++motion_arena->next_generation;
        Motion &m = motion_arena->motions[lease->slot];
        m = Motion();
        m.generation = lease->generation;
        m.kind = chain ? 2 : w.kind == 2 ? 1 : 0;
        m.missile_fields = m.kind == 1;
        f.lease = lease;
        Vector2 from = chain ? origin : w.muzzle;
        Actor *t = resolve(target);
        Vector2 aim = w.hostile ? player_point
                      : t       ? t->point
                                : from + Vector2(0, -100);
        m.x = from.x;
        m.y = from.y;
        m.direction = unit(aim - from);
        m.speed = chain ? chain_speed : w.speed;
        f.aim = aim;
        f.logical_aim = w.hostile ? Vector2(player_row.get("x", 286.0), player_row.get("y", 520.0)) : t ? t->logical : aim;
        if (m.kind == 1) {
            m.speed = launch_speed;
            int ordinal = launch_ordinal >= 0 ? launch_ordinal : int(f.serial % 2);
            double departure = (ordinal % 2 ? 1 : -1) * missile_departure_angle * 3.14159265358979323846 / 180.0;
            Vector2 trial = axis(angle(m.direction) + departure);
            if ((!w.hostile && trial.y >= missile_launch_forward_y) || (w.hostile && trial.y <= -missile_launch_forward_y) ||
                (from.x < missile_launch_edge_margin && trial.x < 0) || (from.x > battle_width - missile_launch_edge_margin && trial.x > 0))
                departure = 0;
            m.direction = axis(angle(m.direction) + departure);
            m.last_aim = aim;
        }
        // Parallel presentation geometry. Numerical origins, collision rays and RNG
        // remain untouched. Only the immutable birth snapshot reaches rendering.
        if (!w.hostile && !chain && !w.entry.has("drone_id") && !w.presentation_muzzles.is_empty()) {
            f.presentation_ray = true;
            const int ordinal = w.kind == 2 ? int(event_serial % w.presentation_muzzles.size()) : 0;
            f.presentation_origin = w.presentation_muzzles[ordinal];
            const Vector2 screen_aim = t ? t->screen_point : w.screen_muzzle + m.direction * 100;
            f.presentation_step = (screen_aim - f.presentation_origin) / maximum(0.001, distance(from, aim));
        }
        if (compact_laser_births && !w.hostile && w.kind == 0 && !chain && t && t->collision_hull.size() >= 3) {
            f.compact_laser = true; ++compact_laser_count; f.fixed_ray = true;
            f.view_birth = weapons[wi].birth;
            f.launch_point = from; f.ray_origin = w.screen_muzzle;
            f.ray_step = (t->screen_point - w.screen_muzzle) / maximum(0.001, distance(from, aim));
            if (t->stationary_geometry) refresh_ray_contact(f, *t);
            effect(0, f, from, clock);
            return id;
        }
        if (f.presentation_ray) {
            f.view["presentation_origin"] = f.presentation_origin;
            f.view["presentation_step"] = f.presentation_step;
        }
        f.view["serial"] = int64_t(f.serial);
        f.view["x"] = from.x;
        f.view["y"] = from.y;
        f.view["launch_point"] = from;
        f.view["target"] = w.hostile ? player_row : target_view(target);
        f.view["source"] = w.hostile ? target_view(w.source) : player_row;
        f.view["hostile"] = w.hostile;
        f.view["key"] = chain         ? String("chain")
                        : w.kind == 0 ? String(w.hostile ? "laser_mon" : "laser")
                        : w.kind == 1 ? String(w.hostile ? "cannon-mon" : "cannon")
                        : w.kind == 2 ? String(w.hostile ? "missile-mon" : "missile")
                                      : String(w.hostile ? "longLaser-mon" : "longLaser");
        f.view["type"] = w.type;
        f.view["damage"] = wire(f.damage);
        f.view["dead"] = false;
        f.view["entry"] = w.entry;
        if (chain) f.view["chain_weapon"] = w.kind == 0 ? String("laser")
                                             : w.kind == 1 ? String("cannon")
                                             : w.kind == 2 ? String("missile") : String("longLaser");
        f.view["mount"] = w.slot;
        f.view["motion_lease"] = lease;
        f.view["direction"] = m.direction;
        f.view["speed"] = m.speed;
        f.view["chain_hop"] = chain;
        f.view["prototype_missile"] = m.kind == 1;
        f.view["critical"] = inst->attack->critical;
        f.view["attack_instance"] = inst->view;
        f.view["repeated"] = repeated;
        f.view["owns_primary_aim"] = !w.hostile && !repeated && !chain;
        f.view["primary_target"] = inst->view.get("primary_target", f.view["target"]);
        if (!w.hostile && m.kind == 0 && t && t->collision_hull.size() >= 3) {
            f.view["ballistic_target_origin"] = aim;
            f.view["fixed_screen_origin"] = w.screen_muzzle;
            f.view["fixed_screen_step"] = (t->screen_point - w.screen_muzzle) / maximum(0.001, distance(from, aim));
            f.fixed_ray = true; f.ray_origin = w.screen_muzzle;
            f.ray_step = f.view["fixed_screen_step"]; f.launch_point = from;
            if (!f.beam && t->stationary_geometry) refresh_ray_contact(f, *t);
        }
        Dictionary context;
        context["source_id"] = w.hostile ? String("enemy:") + String::num_int64(actors[w.source.index].uid)
                               : w.entry.has("drone_id") ? String("drone:") + String(w.entry["drone_id"])
                                                         : String("module:") + String::num_int64(w.slot);
        context["trigger_depth"] = repeated || chain || (f.context && f.context->derived) ? 1 : 0;
        f.view["combat_context"] = context;
        f.view["prism_tower"] = false;
        if (f.beam) {
            f.beam_index = active_beams.size(); active_beams.push_back(id);
            f.charge = w.charge;
            f.interval = w.interval;
            f.ramp = w.ramp;
            f.maximum = w.maximum;
            f.next_hit = f.charge >= 0 ? f.charge : f.interval;
            f.view["beam"] = true;
            f.view["endless"] = !f.hostile && !f.repeated && w.endless;
            f.view["await_target"] = false;
            f.view["locked_target"] = w.hostile ? player_row : target_view(target);
            f.view["elapsed"] = 0.0;
            f.view["charge"] = f.charge;
            f.view["ticks"] = 0;
            f.view["weapon"] = w.row;
            Dictionary snapshot;
            snapshot["weapon"] = w.row;
            f.view["attack_snapshot"] = snapshot;
            f.view["charged_multiplier"] = 1.0;
            inst->beam = true;
            inst->primary = target;
            inst->chain_used = true;
            inst->count = w.hostile ? 0 : w.chain_count;
            auto candidates = targets(w.type, clock);
            if (!w.hostile && !repeated && prism_count > 0) {
                bool available = true;
                for (size_t fid : active)
                    if (fid != id && flights[fid].live && flights[fid].prism)
                        available = false;
                if (available) {
                    f.prism = true;
                    f.maximum += prism_bonus;
                    inst->count = prism_count;
                    std::sort(candidates.begin(), candidates.end(), [&](Handle a, Handle b) {
                        return distance(actors[a.index].point, aim) < distance(actors[b.index].point, aim);
                    });
                }
            }
            Array links;
            for (Handle h : candidates)
                if (h.index != target.index && int(inst->links.size()) < inst->count) {
                    inst->links.push_back(h);
                    Dictionary link;
                    link["target"] = target_view(h);
                    link["broken"] = false;
                    links.push_back(link);
                }
            Dictionary c = inst->view["chain"];
            c["beam"] = true;
            c["used"] = true;
            c["links"] = links;
            c["count"] = inst->count; c["primary"] = f.view["target"];
            Dictionary beam_row = w.row.duplicate(true); beam_row["para2"] = f.maximum;
            f.view["weapon"] = beam_row; snapshot["weapon"] = beam_row;
            f.view["prism_tower"] = f.prism;
        }
        f.compatibility_index = compatibility_flights.size();
        compatibility_flights.push_back(id);
        flight_rows.push_back(f.view);
        effect(chain ? 4 : 0, f, from, clock);
        return id;
    }
    void hit_enemy(Handle h, Amount raw, int type, const std::shared_ptr<Instance> &inst, bool trigger,
                   double at, int wi, bool chain_trigger = false, const std::shared_ptr<MissileContext> &context = {},
                   const String &damage_source = String()) {
        Actor *a = resolve(h);
        if (!a) {
            ++stale_rejections;
            return;
        }
        shield(*a, at);
        a->hit_at = at;
        const Amount base_raw = raw;
        if (context) {
            ++a->missile_hits;
            if (context->derived) ++a->derived_missile_hits;
            if (context->wild && context->wild_used) ++wild_recursion_blocks;
        }
        if (guidance_enabled && context) {
            auto found = context->factors.find(a->uid);
            if (found == context->factors.end()) {
                double factor = std::pow(guidance_multiplier,double(a->guidance_layers));
                found = context->factors.emplace(a->uid,factor).first;
                if (a->guidance_firsts++ == 0) a->first_guidance_factor = a->min_guidance_factor = a->max_guidance_factor = factor;
                a->last_guidance_factor = factor;
                a->min_guidance_factor = minimum(a->min_guidance_factor,factor);
                a->max_guidance_factor = maximum(a->max_guidance_factor,factor);
                if (!context->derived) {
                    int64_t previous_layers = a->guidance_layers;
                    a->guidance_layers = guidance_limited ? minimum(a->guidance_layers+1,guidance_limit) : a->guidance_layers+1;
                    if (a->guidance_layers > previous_layers) a->guidance_growth += a->guidance_layers - previous_layers;
                    a->view["guidance_layers"] = a->guidance_layers;
                }
            } else ++a->guidance_reuses;
            raw *= found->second;
        }
        int reactive_stacks = -1;
        double reactive_multiplier = 1;
        if (a->reactive_reduction) {
            if (at > a->reactive_volley_at + reactive_volley_window) {
                a->reactive_stacks = at <= a->reactive_volley_at + reactive_stack_seconds
                    ? minimum(reactive_stack_limit, a->reactive_stacks + 1) : 0;
                a->reactive_volley_at = at;
            }
            reactive_stacks = a->reactive_stacks;
            reactive_multiplier = 1.0 - reactive_per_stack * reactive_stacks;
            raw *= reactive_multiplier;
            a->view["reactive_stacks"] = reactive_stacks;
            a->view["reactive_multiplier"] = reactive_multiplier;
            a->view["reactive_volley_at"] = a->reactive_volley_at;
        }
        Amount incoming = raw * (1 + a->interference);
        Amount absorbed = 0;
        Amount damage = 0;
        const Amount hp_before = damage_stats_enabled ? a->hp : 0;
        const Amount shield_before = damage_stats_enabled ? a->shield : 0;
        if (a->shield > 0) {
            double factor = type == a->shield_type ? 1 - resistance : 1;
            absorbed = minimum(a->shield, maximum(1.0, incoming * factor));
            a->shield -= absorbed;
            incoming = factor > 0 ? nonnegative(incoming - absorbed / factor) : 0;
        }
        if (absorbed <= 0 || incoming > 0) {
            damage = maximum(1.0, ceil_number(incoming * (type == a->armour_type ? 1 - resistance : 1)));
            a->hp = nonnegative(a->hp - damage);
        }
        String source;
        if (damage_stats_enabled) {
            source = damage_source;
            if (source.is_empty() && context) source = context->source;
            if (source.is_empty() && inst && inst->attack && inst->attack->birth) {
                const BirthConfig &birth = *inst->attack->birth;
                source = birth.entry.has("drone_id") ? String("drone:") + String(birth.entry["drone_id"])
                    : String("module:") + String::num_int64(birth.slot);
            }
            if (source.is_empty()) source = "other";
            const Amount shield_loss = nonnegative(shield_before - a->shield);
            const Amount hp_loss = nonnegative(hp_before - a->hp);
            if (shield_loss > 0 || hp_loss > 0) {
                auto &sum = damage_stats[source];
                sum[0] += shield_loss;
                sum[1] += hp_loss;
            }
        }
        a->view["hp"] = wire(a->hp);
        a->view["shield"] = wire(a->shield);
        a->view["shield_hit_at"] = at;
        ++hit_count;
        Effect e;
        e.kind = 2;
        e.uid = a->uid;
        e.type = type;
        e.amount = damage + absorbed;
        e.time = at;
        e.critical = inst && inst->attack->critical;
        e.reactive_stacks = reactive_stacks;
        e.reactive_multiplier = reactive_multiplier;
        e.point = a->point;
        feedback.push_back(e);
        if (strange_enabled && trigger && inst && wi >= 0 && !weapons[wi].hostile && weapons[wi].kind == 1) {
            const Weapon &w = weapons[wi];
            int count = a->hp <= 0 ? strange_kill_spawns : (rng->randf() < strange_probability ? 1 : 0);
            for (int i = 0; i < count; ++i) {
                StrangePacket p;
                p.order = ++strange_serial; p.root = inst->attack->id;
                p.damage = raw * strange_multiplier; p.type = strange_type;
                p.source = w.entry.has("drone_id") ? String("drone:") + String(w.entry["drone_id"]) : String("module:") + String::num_int64(w.slot);
                if (damage_stats_enabled) p.stats_source = source;
                strange_pending.emplace(strange_boundary_end + strange_delay, p);
            }
        }
        // Birth freezes base damage and blast fraction; impact uses the current missile damage type, as Game does.
        if (context && context->wild && !context->wild_used) {
            ++wild_detonations;
            context->wild_used = true; // Shared context is marked before recursive AoE.
            for (size_t i = 0; i < actors.size(); ++i)
                if (actors[i].live && actors[i].hp > 0)
                    hit_enemy(handle(i),base_raw*context->blast,wild_damage_type,{},false,at,wi,false,context,damage_source);
        }
        Vector2 origin = a->point;
        if (a->hp <= 0 && a->live) {
            a->guidance_layers = 0; a->view.erase("guidance_layers");
            a->live = false;
            a->view["dead"] = true;
            ++a->generation;
            ++dead_count;
            e.kind = 3;
            e.amount = 0;
            feedback.push_back(e);
            if (drop_rules) {
                for (int roll = 0; roll < a->jewel_rolls; ++roll)
                    if (rng->randf() < jewel_probability) {
                        Dictionary drop;
                        if (drop_uid == std::numeric_limits<int64_t>::max()) { failure_reason = "DropIdRangeExceeded"; stopped = true; return; }
                        drop["uid"] = ++drop_uid;
                        drop["x"] = a->logical.x;
                        drop["y"] = a->logical.y + 65;
                        drop["age"] = 0.0;
                        drop["jewel"] = true;
                        drop["jewelRatio"] = jewel_ratio;
                        drop["id"] = "jewel";
                        drop["amount"] = 1;
                        Effect birth;
                        birth.kind = 7;
                        birth.time = at;
                        birth.shot = drop;
                        feedback.push_back(birth);
                    }
                for (const DropRule &rule : a->drops)
                    if (rng->randf() < rule.chance) {
                        Dictionary drop;
                        if (drop_uid == std::numeric_limits<int64_t>::max()) { failure_reason = "DropIdRangeExceeded"; stopped = true; return; }
                        drop["uid"] = ++drop_uid;
                        drop["x"] = a->logical.x;
                        drop["y"] = a->logical.y + 40;
                        drop["source_uid"] = a->uid;
                        drop["age"] = 0.0;
                        drop["id"] = String::num_int64(rule.resource);
                        drop["amount"] = wire(rule.amount);
                        drop["production_base"] = wire(rule.base);
                        Effect birth;
                        birth.kind = 7;
                        birth.time = at;
                        birth.shot = drop;
                        feedback.push_back(birth);
                    }
            }
            if (trigger && a->explosion > 0)
                for (size_t index = 0; index < actors.size(); ++index)
                    if (actors[index].live && (std::abs(actors[index].slot - a->slot) == 1 ||
                                               std::abs(actors[index].slot - a->slot) == 2))
                        hit_enemy(handle(index), a->max_hp * a->explosion, type, {}, false, at, wi, false, {}, source);
            for (size_t id : active) {
                Flight &f = flights[id];
                if (endless_eligible(f) && f.target.index == h.index && f.target.generation == h.generation && !f.await_target) {
                    // All beam ages were projected to the segment end. Roll back
                    // only its post-death tail; waiting never creates catch-up debt.
                    f.age = maximum(0.0,f.age - maximum(0.0,clock-at));
                    f.await_target = true; f.view["await_target"] = true; f.view["elapsed"] = f.age;
                    // Keep links until this hit finishes its inherited chain work.
                }
                if (f.live && f.beam && f.hostile && f.source.index == h.index && f.source.generation == h.generation)
                    retire(id);
                if (f.instance && f.instance->beam) {
                    Dictionary c = f.instance->view["chain"];
                    Array links = c.get("links", Array());
                    for (int i = 0; i < links.size(); ++i) {
                        Dictionary l = links[i];
                        Dictionary t = l["target"];
                        if (int64_t(t.get("uid", -1)) == a->uid)
                            l["broken"] = true;
                    }
                }
            }
        }
        // Death/attack triggers stay gated by trigger; an independent chain allowance
        // does not grant those decisions to repeats, secondary copies or chain hops.
        if ((trigger || chain_trigger) && inst && !inst->ended) {
            if (inst->beam) {
                if (inst->primary.index == h.index && inst->primary.generation == h.generation)
                    for (Handle link : inst->links)
                        if (resolve(link))
                            hit_enemy(link, raw, type, inst, false, at, wi);
            } else if (!inst->chain_used) {
                inst->chain_used = true;
                Dictionary c = inst->view["chain"];
                c["used"] = true;
                int count = 0;
                for (Handle t : targets(type, at))
                    if (t.index != h.index && count++ < inst->count)
                        birth(wi, t, inst, base_raw / inst->attack->damage, false, true, origin);
            }
        }
        commit_final_wipe();
    }
    void commit_final_wipe() {
        if (!final_encounter || final_cleared || actors.empty()) return;
        for (const Actor &a : actors) if (a.live) return;
        final_cleared = true;
        strange_pending.clear();
        // Completion is committed before any later boundary carrier can hit.
        for (size_t id : active) retire(id, false);
        while (!roots.empty()) roots.pop();
        while (!ejections.empty()) ejections.pop();
        while (!repeats.empty()) repeats.pop();
    }
    Amount counter_bonus(int64_t count, bool incoming = false) const {
        return history_bonus(count, incoming ? defence_counter_growth : counter_growth, counter_level, counter_log_base, counter_round_scale);
    }
    Amount capacity(int layer) const {
        Amount total = 0;
        for (const Defence &d : defences)
            if (d.layer == layer)
                total += d.maximum;
        return total;
    }
    Amount layer_health(int layer) const {
        Amount value;
        for (const Defence &d : defences) if (d.layer == layer) value += d.maximum - d.loss;
        return value;
    }
    void set_layer_health(int layer, Amount target) {
        for (Defence &d : defences) if (d.layer == layer) d.loss = minimum(d.loss, d.maximum);
        const Amount current = layer_health(layer), cap = capacity(layer);
        target = minimum(target, cap);
        if (target == current) return;
        const bool damage = current > target;
        const Amount delta = damage ? current - target : target - current;
        const Amount denominator = damage ? current : cap - current;
        if (denominator == 0) return;
        size_t last = SIZE_MAX;
        for (size_t i = 0; i < defences.size(); ++i) {
            const Defence &d = defences[i];
            if (d.layer == layer && (damage ? d.maximum - d.loss : d.loss) > 0) last = i;
        }
        Amount remaining = delta;
        for (size_t i = 0; i < defences.size() && remaining > 0; ++i) {
            Defence &d = defences[i];
            if (d.layer != layer) continue;
            const Amount weight = damage ? d.maximum - d.loss : d.loss;
            if (weight == 0) continue;
            const Amount part = minimum(weight, i == last ? remaining : minimum(remaining, delta * weight / denominator));
            d.loss = damage ? d.loss + part : d.loss - part;
            remaining -= part;
        }
    }
    void reconcile_defence() {
        const Amount before[2] = {layer_health(0), layer_health(1)};
        for (Defence &d : defences) {
            d.maximum = evaluate_module_value(d.base, incoming_counter, defence_counter_growth, counter_level, counter_log_base, counter_round_scale, d.branch_factors, d.external_factors) * d.factor;
            d.loss = minimum(d.loss, d.maximum);
            d.buffer = minimum(d.buffer, d.maximum * d.memory_cap);
        }
        // Capacity changes preserve absolute health; the module losses own it.
        set_layer_health(0, before[0]); set_layer_health(1, before[1]);
    }
    Amount protection(Amount amount, Amount &absorbed) {
        Amount rest = amount;
        for (Defence &d : defences) {
            if (rest <= 0)
                break;
            Amount paid = minimum(d.buffer, rest);
            d.buffer -= paid;
            rest -= paid;
            absorbed += paid;
            if (paid > 0)
                d.last_hit = defence_time;
        }
        return rest;
    }
    void publish_player() {
        if (module_defence) { player_hp = layer_health(1); player_shield = layer_health(0); }
        player_row["max_armour"] = wire(module_defence ? capacity(1) : player_initial_hp);
        player_row["max_shield"] = wire(module_defence ? capacity(0) : player_initial_shield);
        player_row["armour"] = wire(player_hp);
        player_row["shield"] = wire(player_shield);
        for (size_t i = 0; i < defences.size(); ++i) {
            buffer_rows[int64_t(i)] = wire(defences[i].buffer);
            loss_rows[int64_t(i)] = wire(defences[i].loss);
            defence_time_rows[int64_t(i)] = defence_time - defences[i].last_hit;
        }
    }
    void incoming_effect(Amount loss, Amount absorbed, int type, double at, bool deferred = false) {
        Effect e;
        e.kind = 2;
        e.player = true;
        e.point = player_point;
        e.type = type;
        e.amount = deferred ? ceil_number(loss) : loss;
        e.absorbed = absorbed;
        e.time = at;
        feedback.push_back(e);
        ++hit_count;
        publish_player();
        if (player_hp <= 0)
            cancel();
    }
    void queue_debt(int layer, Amount amount) {
        if (amount <= 0)
            return;
        int portions = maximum(1, int(ceil_number(deferred_duration / deferred_interval)));
        int64_t first =
            maximum(deferred_tick + 1,
                     int64_t(ceil_number((defence_time + deferred_interval - 1e-9) / deferred_interval)));
        Amount unit = amount / portions, remaining = amount;
        for (int i = 0; i < portions; ++i) {
            Amount part = i == portions - 1 ? remaining : minimum(unit, remaining);
            remaining = nonnegative(remaining - part);
            debts[first + i][layer] += part;
        }
    }
    void pay_debt(Amount amount, double at) {
        Amount absorbed = 0;
        Amount rest = protection(amount, absorbed);
        Amount loss = 0;
        for (int layer = 0; layer < 2 && rest > 0; ++layer) {
            reconcile_defence();
            Amount total = 0;
            for (const Defence &d : defences)
                if (d.layer == layer)
                    total += nonnegative(d.maximum - d.loss);
            Amount taken = minimum(total, rest);
            std::vector<Amount> old_losses;
            old_losses.reserve(defences.size());
            for (const Defence &d : defences) old_losses.push_back(d.loss);
            set_layer_health(layer, total - taken);
            for (size_t i = 0; i < defences.size(); ++i)
                if (defences[i].layer == layer && defences[i].loss > old_losses[i]) defences[i].last_hit = defence_time;
            loss += total - layer_health(layer);
            rest = nonnegative(rest - taken);
        }
        if (loss > 0 || absorbed > 0)
            incoming_effect(loss, absorbed, 0, at, true);
    }
    void recover(double dt, double begin_at) {
        if (!module_defence)
            return;
        double seconds_left = dt;
        while (seconds_left > 1e-9 && !stopped) {
            double piece = minimum(
                seconds_left, minimum(memory_interval - memory_elapsed, deferred_interval - deferred_elapsed));
            double begin_defence = defence_time;
            defence_time += piece;
            memory_elapsed += piece;
            deferred_elapsed += piece;
            seconds_left = nonnegative(seconds_left - piece);
            // Integrate only the elapsed interval before paying its endpoint events.
            reconcile_defence();
            for (Defence &d : defences) {
                if (d.layer != 0) continue;
                double ready = d.last_hit + d.delay;
                double elapsed = nonnegative(defence_time - ready) - nonnegative(begin_defence - ready);
                Amount recovered = minimum(d.loss, d.maximum * d.rate * elapsed);
                d.loss = nonnegative(d.loss - recovered);
            }
            // Same-time priority: continuous recovery, debt, memory, then beam hit.
            if (deferred_elapsed + 1e-9 >= deferred_interval) {
                deferred_elapsed = nonnegative(deferred_elapsed - deferred_interval);
                ++deferred_tick;
                auto at = debts.find(deferred_tick);
                if (at != debts.end()) {
                    auto due = at->second;
                    debts.erase(at);
                    for (int layer = 0; layer < 2 && !stopped; ++layer)
                        if (due[layer] > 0)
                            pay_debt(due[layer], begin_at + dt - seconds_left);
                    if (!stopped && rng->randf() < clear_probability)
                        debts.clear();
                }
            }
            if (stopped)
                break;
            bool memory = memory_elapsed + 1e-9 >= memory_interval;
            if (memory)
                memory_elapsed = nonnegative(memory_elapsed - memory_interval);
            reconcile_defence();
            for (Defence &d : defences) {
                if (memory && d.memory_heal > 0) {
                    Amount healing = d.maximum * d.memory_heal;
                    Amount recovered = minimum(d.loss, healing);
                    d.loss = nonnegative(d.loss - recovered);
                    d.buffer =
                        minimum(d.maximum * d.memory_cap, d.buffer + nonnegative(healing - recovered));
                }
            }
            publish_player();
        }
    }
    void player_hit(Amount raw, int type, double at) {
        if (final_cleared) return;
        if (!increment_history(incoming_counter)) return;
        last_incoming_at = at;
        if (!module_defence) {
            double factor = type == int(player_row.get("shield_type", 0)) ? 1 - resistance : 1;
            Amount absorbed = minimum(player_shield, maximum(1.0, raw * factor));
            player_shield -= absorbed;
            Amount left = factor > 0 ? nonnegative(raw - absorbed / factor) : 0;
            Amount damage =
                left > 0
                    ? ceil_number(left * (type == int(player_row.get("armour_type", 0)) ? 1 - resistance : 1))
                    : 0;
            player_hp = nonnegative(player_hp - damage);
            incoming_effect(damage + absorbed, 0, type, at);
            return;
        }
        reconcile_defence();
        // A hit restarts every shield delay, even when cover or armour pays it.
        for (Defence &d : defences)
            if (d.layer == 0)
                d.last_hit = defence_time;
        Amount absorbed = 0;
        Amount rest = protection(raw, absorbed);
        const Amount before[2] = {layer_health(0), layer_health(1)};
        std::array<Amount, 2> payments{};
        std::array<bool, 2> deferred{};
        int shield_passes = 0;
        for (const Defence &d : defences)
            if (d.layer == 0)
                ++shield_passes;
        for (int pass = 0; pass <= shield_passes && rest > 0; ++pass) {
            int layer = pass < shield_passes ? 0 : 1;
            Amount total = 0;
            std::vector<Amount> available(defences.size(), 0);
            for (size_t i = 0; i < defences.size(); ++i)
                if (defences[i].layer == layer) {
                    available[i] = nonnegative(defences[i].maximum - defences[i].loss);
                    total += available[i];
                }
            if (total <= 0)
                continue;
            Amount incoming = rest;
            Amount spent = 0;
            for (size_t i = 0; i < defences.size(); ++i) {
                Defence &d = defences[i];
                if (d.layer != layer || available[i] <= 0)
                    continue;
                double factor = type == d.type ? 1 - resistance : 1;
                Amount weighted = incoming * available[i] / total;
                Amount part = weighted * factor;
                Amount payable = available[i] / (1 - d.deferred_fraction);
                Amount taken = layer == 1 ? part : minimum(payable, part);
                Amount delayed = taken * d.deferred_fraction;
                Amount immediate = nonnegative(taken - delayed);
                if (layer == 0 && taken >= payable) {
                    immediate = available[i];
                    delayed = nonnegative(taken - immediate);
                }
                deferred[layer] = deferred[layer] || delayed > 0;
                queue_debt(layer, delayed);
                d.loss = minimum(d.maximum, d.loss + immediate);
                payments[layer] += immediate;
                spent += factor <= 0 ? weighted : taken / factor;
                if (taken > 0)
                    d.last_hit = defence_time;
            }
            rest = nonnegative(incoming - spent);
        }
        Amount loss = 0;
        for (int layer = 0; layer < 2; ++layer) {
            Amount paid = minimum(before[layer], deferred[layer] ? payments[layer] : ceil_number(payments[layer]));
            set_layer_health(layer, before[layer] - paid);
            loss += before[layer] - layer_health(layer);
        }
        incoming_effect(loss, absorbed, type, at);
    }
    void launch(int wi, Handle target, std::shared_ptr<const Attack> a, Amount multiplier,
                bool repeated = false, bool distribute = true, double inherited_maximum = -1,
                std::shared_ptr<Instance> shared_instance = {}) {
        Weapon w = committed_weapon(wi, a->birth);
        if (repeated && w.kind == 3) {
            for (Handle choice : targets(w.type, clock)) {
                bool occupied = false;
                for (size_t id : active) if (flights[id].live && flights[id].beam && flights[id].weapon == wi && flights[id].target.index == choice.index) occupied = true;
                if (!occupied) { target = choice; break; }
            }
        }
        auto inst = shared_instance ? shared_instance : instance(a);
        if (!shared_instance) inst->derived = repeated;
        if (w.kind == 2) {
            auto choices = targets(w.type, clock);
            auto salvo_context = repeated ? missile_context(w,a->id,true) : a->context;
            for (int n = 0; n < w.salvo; ++n) {
                Timed pending{clock + n * ejection_gap, ++event_serial, 1, wi, n,
                              w.hostile ? Handle{} : distribute && !choices.empty() ? choices[n % choices.size()] : target, a,
                              multiplier, inst};
                pending.damage_derived = repeated;
                pending.context = salvo_context;
                ejections.push(pending);
            }
            return;
        }
        size_t id = birth(wi, target, inst, multiplier, repeated);
        Flight &f = flights[id];
        if (w.kind == 3) {
            if (inherited_maximum >= 0) {
                f.maximum = inherited_maximum;
                Dictionary row = Dictionary(f.view["weapon"]).duplicate(true); row["para2"] = inherited_maximum;
                f.view["weapon"] = row; Dictionary snapshot = f.view["attack_snapshot"]; snapshot["weapon"] = row;
            }
            if (!repeated)
                weapons[wi].beam = id;
        } else if (w.kind == 1 && !w.hostile) {
            effect(1, f, f.aim, clock);
            hit_enemy(target, f.damage, f.type, inst, !repeated, clock, wi, true);
            retire(id);
        }
    }
    void primary(int wi) {
        Weapon &w = weapons[wi];
        if (w.hostile && !resolve(w.source))
            return;
        if (w.kind == 3 && w.beam >= 0 && flights[w.beam].live)
            return;
        auto candidates = targets(w.type, clock);
        if (!w.hostile && candidates.empty())
            return;
        auto a = std::make_shared<Attack>();
        a->id = ++attack_serial;
        a->birth = w.birth;
        ++root_attacks;
        if (!w.hostile && !increment_history(attack_counter)) return;
        // Match weapon_multiplier grouping before multiplying the rounded base.
        double legendary = !w.hostile && w.kind == 0 ?
            (scatter && candidates.size() == 1 ? 1 + scatter_bonus : 1) * laser_charge_multiplier : 1;
        a->damage = (w.hostile ? w.base : evaluate_module_value(w.base, attack_counter, counter_growth, counter_level, counter_log_base, counter_round_scale, w.branch_factors, w.external_factors)) *
                    w.factor * legendary;
        a->critical = !w.hostile && rng->randf() < w.crit_rate;
        if (a->critical)
            a->damage *= w.crit_multiplier;
        bool wild = !w.hostile && w.kind == 2 && wild_enabled && missile_attacks % (wild_period+1) == wild_period;
        if (!w.hostile && w.kind == 2) {
            ++missile_attacks;
            a->context = missile_context(w,a->id,wild);
            if (wild) {
                ++wild_replacements;
                a->damage *= wild_multiplier;
                a->context->wild = true; a->context->blast = wild_blast;
                auto birth = std::make_shared<BirthConfig>(*a->birth); birth->salvo = 1;
                birth->weapon = birth->weapon.duplicate(true); birth->weapon["para1"] = 1; birth->weapon.make_read_only();
                a->birth = birth;
            }
        }
        a->secondary = !w.hostile && !wild && rng->randf() < w.secondary_probability;
        a->repeats = !w.hostile && !wild && rng->randf() < w.repeat_probability;
        if (w.hostile) {
            launch(wi, {}, a, 1);
            return;
        }
        auto primary_instance = instance(a);
        primary_instance->view["primary_target"] = target_view(candidates.front());
        if (scatter && w.kind == 0) {
            for (Handle h : candidates)
                birth(wi, h, primary_instance, 1);
        } else
            launch(wi, candidates.front(), a, 1, false, true, -1, primary_instance);
        if (final_cleared) return;
        if (w.kind != 3 && a->repeats)
            repeats.push(
                {clock + repeat_delay, ++event_serial, 2, wi, 0, candidates.front(), a, w.repeat_multiplier});
        if (w.kind != 3 && a->secondary && candidates.size() > 1) {
            Vector2 target_position = actors[candidates[1].index].point;
            int64_t target_uid = actors[candidates[1].index].uid;
            launch(wi, candidates[1], a, 1, true, false, -1, primary_instance);
            Effect secondary;
            secondary.kind = 8;
            secondary.time = clock;
            secondary.point = actors[candidates[0].index].point;
            secondary.target_point = target_position;
            secondary.target_uid = target_uid;
            secondary.type = w.type;
            feedback.push_back(secondary);
        }
    }
    bool endless_eligible(const Flight &f) const {
        return f.live && f.beam && !f.hostile && !f.repeated && weapons[f.weapon].endless &&
               !stopped && !final_cleared &&
               (read_amount(player_row.get("armour",0.0)) > 0 || read_amount(player_row.get("shield",0.0)) > 0);
    }
    // One owner keeps the existing attack, charge, tick clock and frozen link count.
    // Rebinding happens only at the next segment start, never halfway through hits.
    bool retain_endless_target(Flight &f, double at, bool rebind) {
        if (!endless_eligible(f)) return false;
        f.await_target = true; f.view["await_target"] = true; f.view["dead"] = false;
        auto inst = f.instance;
        inst->links.clear(); inst->ended = false;
        Dictionary chain = inst->view["chain"];
        chain["links"] = Array(); chain["ended"] = false;
        if (!rebind) return true;
        auto candidates = targets(f.type, at);
        if (candidates.empty()) return true;
        f.target = candidates.front(); inst->primary = f.target;
        f.view["target"] = target_view(f.target); f.view["locked_target"] = target_view(f.target);
        inst->view["primary_target"] = target_view(f.target); chain["primary"] = target_view(f.target);
        f.await_target = false; f.view["await_target"] = false;
        f.aim = actors[f.target.index].point;
        if (f.prism) std::sort(candidates.begin(), candidates.end(), [&](Handle a, Handle b) {
            return distance(actors[a.index].point,f.aim) < distance(actors[b.index].point,f.aim);
        });
        Array links;
        for (Handle h : candidates) if (h.index != f.target.index && int(inst->links.size()) < inst->count) {
            inst->links.push_back(h);
            Dictionary link; link["target"] = target_view(h); link["broken"] = false; links.push_back(link);
        }
        chain["links"] = links;
        return true;
    }
    bool weapon_before(int left, int right) const {
        const Weapon &a = weapons[left], &b = weapons[right];
        if (a.hostile != b.hostile) return !a.hostile;
        if (a.hostile) {
            int as = a.source.index < actors.size() ? actors[a.source.index].slot : int(a.source.index);
            int bs = b.source.index < actors.size() ? actors[b.source.index].slot : int(b.source.index);
            if (as != bs) return as < bs;
        }
        if (a.slot != b.slot) return a.slot < b.slot;
        return left < right;
    }
    void advance_beam_clocks(double dt) {
        const size_t begin_count = active.size();
        for (size_t n = 0; n < begin_count; ++n) {
            size_t id = active[n];
            Flight &f = flights[id];
            if (!f.live || !f.beam)
                continue;
            if (!f.hostile && !resolve(f.target)) {
                if (!retain_endless_target(f, clock - dt, true)) { retire(id); continue; }
                if (f.await_target) continue;
            }
            Vector2 muzzle = weapons[f.weapon].muzzle;
            Motion &motion = f.lease->motion();
            motion.x = muzzle.x;
            motion.y = muzzle.y;
            f.view["launch_point"] = muzzle;
            Actor *target = resolve(f.target);
            f.aim = f.hostile ? player_point : target ? target->point : f.aim;
            motion.direction = unit(f.aim - muzzle);
            if (f.born_step < step_serial)
                f.age += dt;
            f.view["elapsed"] = f.age;
        }
    }
    void settle_beam(size_t id, double due, double at) {
        Flight &f = flights[id];
        if (!f.live || f.await_target || (f.hostile ? !resolve(f.source) : !resolve(f.target))) {
            if (f.live && (f.hostile || !retain_endless_target(f,at,false))) retire(id);
            return;
        }
        // Collection is speculative; only an executed hit consumes its period.
        f.next_hit = due + f.interval;
        ++f.ticks;
        f.view["ticks"] = f.ticks;
        double duration = f.charge >= 0 ? (f.ticks - 1) * f.interval : due;
        double ramp = f.ramp > 0 ? std::clamp(duration / f.ramp, 0.0, 1.0) : 1;
        Amount raw = f.damage * (1 + (f.maximum - 1) * ramp);
        effect(6, f, f.aim, at);
        if (!f.hostile && f.instance->attack->critical) effect(9, f, f.aim, at);
        if (f.hostile)
            player_hit(raw, f.type, at);
        else
            hit_enemy(f.target, raw, f.type, f.instance, !f.repeated, at, f.weapon, true);
        if (!final_cleared && f.ticks == 1 && !f.hostile && !f.repeated && f.instance->attack->secondary) {
            auto candidates = targets(f.type, at);
            for (Handle h : candidates)
                if (h.index != f.target.index) {
                    Vector2 target_position = actors[h.index].point;
                    int64_t target_uid = actors[h.index].uid;
                    hit_enemy(h, raw, f.type, f.instance, false, at, f.weapon);
                    Effect secondary;
                    secondary.kind = 8;
                    secondary.time = at;
                    secondary.point = f.aim;
                    secondary.target_point = target_position;
                    secondary.target_uid = target_uid;
                    secondary.type = f.type;
                    feedback.push_back(secondary);
                    break;
                }
        }
        if (!final_cleared && f.ticks == 1 && !f.repeated && f.instance->attack->repeats) {
            Timed pending{at + repeat_delay,
                          ++event_serial,
                          2,
                          f.weapon,
                          0,
                          f.target,
                          f.instance->attack,
                          weapons[f.weapon].repeat_multiplier};
            pending.owner_flight = id;
            pending.owner_generation = f.generation;
            repeats.push(pending);
        }
    }
    void advance_flight(size_t id, double dt) {
        Flight &f = flights[id];
        if (!f.live || f.beam || f.born_step >= step_serial)
            return;
        ++physics_visits;
        Motion &m = f.lease->motion();
        Actor *t = resolve(f.target);
        Vector2 aim = f.hostile ? player_point : t ? t->point : m.last_aim;
        if (!f.hostile && !t) {
            f.target_view_cleared = true;
            if (!f.view.is_empty()) f.view["target"] = Dictionary();
        }
        bool impact = false;
        if (m.kind == 1) {
            m.age += dt;
            if ((f.hostile || t) && m.age > lifetime) {
                retire(id, 1);
                return;
            }
            double progress = std::clamp((m.age - ignition) / (cruise_at - ignition), 0.0, 1.0);
            progress = progress * progress * (3 - 2 * progress);
            m.speed = launch_speed + (f.cruise_speed - launch_speed) * progress;
            if (f.hostile || t) {
                m.orphan = 0;
                m.last_aim = aim;
                double old = angle(m.direction), wanted = angle(aim - position(m));
                double change = std::remainder(wanted - old, 6.28318530717958647692);
                double range = distance(position(m), aim);
                if (range < brake_range && std::abs(change) > brake_angle)
                    m.speed = minimum(m.speed, maximum(min_speed, range * turn_rate * brake_factor));
                if (m.age >= seek)
                    m.direction = axis(old + std::clamp(change, -turn_rate * dt, turn_rate * dt));
                Vector2 delta = m.direction * m.speed * dt, p = position(m);
                double length = delta.length_squared();
                double ratio =
                    length > 0 ? std::clamp(double((aim - p).dot(delta)) / length, 0.0, 1.0) : 0;
                impact = distance(p + delta * ratio, aim) <= hit_radius;
            } else {
                m.orphan += dt;
                if (m.orphan >= orphan_lifetime) {
                    retire(id, 1);
                    return;
                }
            }
        } else {
            if (t || f.hostile) {
                Vector2 delta = aim - position(m);
                if (f.chain) {
                    // Chain carriers use their own straight contact path.
                    m.direction = unit(delta);
                    impact = distance(position(m), aim) <= m.speed * dt;
                } else {
                    if (f.hostile && player_collision_hull.size() >= 3) {
                        const Vector2 start = position(m), movement = m.direction * m.speed * dt;
                        const double ratio = hull_contact(start, movement, player_collision_hull);
                        impact = ratio <= 1.0;
                        if (impact) aim = start + movement * ratio;
                    } else if (!f.hostile && t && f.fixed_ray) {
                        const double progress = (position(m) - f.launch_point).dot(m.direction);
                        if (t->stationary_geometry && f.contact_revision != t->geometry_revision)
                            refresh_ray_contact(f, *t);
                        // The birth ray is a conservative far-contact gate, not a future hit.
                        // Keep the exact segment predicate at contact, preserving float rounding,
                        // impact coordinates and born_step; contact dispatch owns damage order.
                        const double margin = maximum(1.0, std::abs(f.contact_distance) * 1e-4);
                        if (t->stationary_geometry && f.contact_distance >= 0 &&
                            progress + m.speed * dt < f.contact_distance - margin) {
                            ++ballistic_skips;
                        } else {
                            ++ballistic_checks;
                            Vector2 start = f.ray_origin + f.ray_step * progress;
                            double ratio = hull_contact(start, f.ray_step * m.speed * dt, t->collision_hull);
                            impact = ratio <= 1.0;
                            if (impact) aim = position(m) + m.direction * m.speed * dt * ratio;
                        }
                    } else {
                        double along = delta.dot(m.direction);
                        impact = along >= 0 && along <= m.speed * dt &&
                                 std::abs(double(delta.cross(m.direction))) <= 0.5;
                    }
                }
            }
        }
        if (impact) {
            m.x = aim.x;
            m.y = aim.y;
            effect(1, f, aim, clock);
            if (f.hostile)
                player_hit(f.damage, f.type, clock);
            else
                hit_enemy(f.target, f.damage, f.type, f.instance, !f.chain && !f.repeated && !(f.context && f.context->derived), clock, f.weapon, !f.chain && !(f.context && f.context->wild), f.context);
            retire(id);
            return;
        }
        Vector2 move = m.direction * m.speed * dt;
        m.x += move.x;
        m.y += move.y;
        if (m.x < projectile_min_x || m.x > projectile_max_x || m.y < projectile_min_y || m.y > projectile_max_y)
            retire(id);
    }
    void settle_contacts(double dt) {
        struct Contact { double at, due; size_t id; uint32_t generation; bool beam; };
        std::vector<Contact> contacts;
        for (size_t id : active) {
            const Flight &f = flights[id];
            if (!f.live) continue;
            if (f.beam && !f.await_target) {
                for (double due = f.next_hit; due <= f.age + 1e-9; due += f.interval) {
                    double at = clock - f.age + due;
                    if (std::abs(at - clock) <= 1e-9) at = clock;
                    contacts.push_back({at, due, id, f.generation, true});
                }
            } else if (!f.beam && f.born_step < step_serial) {
                contacts.push_back({clock, 0, id, f.generation, false});
            }
        }
        // Snapshot identities, never the mutable dense active order. Each hit and
        // its local derivatives finish before the next source gets to settle.
        std::sort(contacts.begin(), contacts.end(), [&](const Contact &a, const Contact &b) {
            if (a.at != b.at) return a.at < b.at;
            const Flight &af = flights[a.id], &bf = flights[b.id];
            if (af.hostile != bf.hostile) return !af.hostile;
            if (af.source_slot != bf.source_slot) return af.source_slot < bf.source_slot;
            int as = weapons[af.weapon].slot, bs = weapons[bf.weapon].slot;
            if (as != bs) return as < bs;
            if (af.serial != bf.serial) return af.serial < bf.serial;
            return a.due < b.due;
        });
        for (const Contact &contact : contacts) {
            if (stopped || final_cleared) break;
            const Flight &f = flights[contact.id];
            if (!f.live || f.generation != contact.generation) continue;
            if (contact.beam) settle_beam(contact.id, contact.due, contact.at);
            else advance_flight(contact.id, dt);
        }
    }
    void segment(double dt) {
        executing = true;
        clock += dt;
        ++step_serial;
        double defence_at = clock - dt;
        // Preserve committed completion while settling its already-owned defence tail.
        if (final_cleared && !stopped) recover(dt, defence_at);
        if (stopped || final_cleared) {
            compact();
            executing = false;
            return;
        }
        // Project existing beam ages without settling hits. At this exact boundary,
        // recovery/debt comes first, every due birth second, existing hits third.
        advance_beam_clocks(dt);
        recover(nonnegative(clock - defence_at), defence_at);
        defence_at = clock;
        if (stopped) { compact(); executing = false; return; }
        std::vector<Timed> births, reschedule;
        auto collect_due = [&](auto &queue) {
            while (!queue.empty() && queue.top().at <= clock + 1e-9) {
                births.push_back(queue.top()); queue.pop();
            }
        };
        collect_due(roots); collect_due(repeats); collect_due(ejections);
        while (!births.empty() && !stopped && !final_cleared) {
            auto first = std::min_element(births.begin(), births.end(), [&](const Timed &a, const Timed &b) {
                return a.weapon != b.weapon ? weapon_before(a.weapon, b.weapon) : a.serial < b.serial;
            });
            Timed q = *first; births.erase(first);
            if (q.kind == 0) {
                const uint64_t before = attack_serial;
                primary(q.weapon);
                const Weapon &weapon = weapons[q.weapon];
                const bool fired = attack_serial != before;
                q.at = fired ? clock + weapon.interval : clock;
                const bool occupied_beam = weapon.kind == 3 && weapon.beam >= 0 && flights[weapon.beam].live;
                if (!stopped && !final_cleared && !occupied_beam && (!weapon.hostile || resolve(weapon.source)))
                    reschedule.push_back(q);
            } else if (q.kind == 2) {
                if (q.owner_flight != SIZE_MAX &&
                    (q.owner_flight >= flights.size() || !flights[q.owner_flight].live ||
                     flights[q.owner_flight].generation != q.owner_generation)) continue;
                auto targets_now = targets(weapons[q.weapon].type, clock);
                if (!targets_now.empty()) {
                    ++root_attacks;
                    launch(q.weapon, targets_now.front(), q.attack, q.multiplier, true, true,
                           q.owner_flight == SIZE_MAX ? -1 : flights[q.owner_flight].maximum);
                }
            } else {
                if (weapons[q.weapon].hostile) {
                    if (!resolve(weapons[q.weapon].source)) continue;
                } else if (!resolve(q.target)) {
                    auto targets_now = targets(weapons[q.weapon].type, clock);
                    if (targets_now.empty()) continue;
                    q.target = targets_now.front();
                }
                birth(q.weapon, q.target, q.instance ? q.instance : instance(q.attack), q.multiplier,
                      q.damage_derived, false, Vector2(), q.context, q.ordinal);
            }
            // Salvos may create their first ejection at this same birth boundary.
            collect_due(ejections);
        }
        if (!stopped && !final_cleared) for (const Timed &q : reschedule) roots.push(q);
        settle_contacts(dt);
        if (stopped || final_cleared) { compact(); executing = false; return; }
        for (size_t id : active) {
            Flight &f = flights[id];
            if (f.live && f.beam && (f.hostile ? !resolve(f.source) : !resolve(f.target))) {
                if (f.hostile || !retain_endless_target(f,clock,false)) retire(id);
            }
        }
        for (Actor &a : actors)
            shield(a, clock);
        compact();
        executing = false;
    }

    bool wave_active = false, battle_started = false, retreating = false;
    void reclaim_finished_wave() {
        compact();
        // All sources in the previous wave are dead. Their queued births would
        // fail the same source-generation check when due; discard them now.
        auto prune = [&](auto &queue) {
            std::vector<Timed> kept;
            while (!queue.empty()) {
                Timed event = queue.top(); queue.pop();
                if (!weapons[event.weapon].hostile) kept.push_back(event);
            }
            for (const Timed &event : kept) queue.push(event);
        };
        prune(roots); prune(ejections); prune(repeats);
        std::vector<bool> retained(weapons.size(), false);
        for (size_t id : active) if (flights[id].live) retained[flights[id].weapon] = true;
        for (size_t i = 0; i < weapons.size(); ++i) {
            if (weapons[i].hostile && !retained[i]) {
                weapons[i] = Weapon{};
                weapons[i].hostile = true;
                weapons[i].vacant = true;
            }
        }
        // Global encounter generations invalidate every old target/source
        // handle while independent live enemy carriers keep their weapon slot.
        actors.clear(); actor_rows.clear();
    }
    bool install_actors(Array values) {
        for (int i = 0; i < values.size(); ++i) {
            Dictionary v = values[i];
            if (!numeric_fields(v, {"hp", "max_hp", "shield", "max_shield"}))
                return false;
            Actor a;
            a.generation = encounter_generation;
            a.uid = v["uid"];
            a.view = v.duplicate(true);
            a.hp = read_amount(v["hp"]);
            a.live = a.hp > 0;
            a.max_hp = read_amount(v["max_hp"]);
            a.shield = read_amount(v.get("shield", 0.0));
            a.max_shield = read_amount(v.get("max_shield", 0.0));
            a.guidance_layers = v.get("guidance_layers",0);
            a.armour_type = v.get("armourType", 0);
            a.shield_type = v.get("shieldType", 0);
            a.slot = v.get("slot", i);
            a.logical = Vector2(v["x"], v["y"]);
            a.point = a.logical;
            a.hit_at = v.get("shield_hit_at", clock);
            a.shield_at = v.get("shield_updated_at", clock);
            a.delay = v.get("shieldDelay", 0.0);
            a.recovery = v.get("shieldRecovery", 0.0);
            a.interference = v.get("interference", 0.0);
            a.explosion = v.get("jewelExplosion", 0.0);
            a.jewel_rolls = v.get("jewel_rolls", 0);
            a.reactive_reduction = int(v.get("reactiveReduction", 0)) == 1;
            a.reactive_stacks = v.get("reactive_stacks", 0);
            a.reactive_volley_at = v.get("reactive_volley_at", -1e100);
            Array drops = v.get("compiled_drops", Array());
            for (int index = 0; index < drops.size(); ++index) {
                Dictionary row = drops[index];
                a.drops.push_back({double(row["chance"]), read_amount(row["amount"]), read_amount(row["base"]),
                                   int(row["resource"])});
            }
            if (!finite(a.hp))
                return false;
            actors.push_back(a);
            actor_rows.push_back(a.view);
        }
        return true;
    }
    bool install_weapons(Array wvalues, int actor_offset, double delay) {
        for (int i = 0; i < wvalues.size(); ++i) {
            Dictionary v = wvalues[i];
            if (!numeric_fields(
                    v, {"damage", "factor", "interval", "remaining", "speed", "charge", "ramp", "maximum"}))
                return false;
            Weapon w;
            w.kind = v["kind"];
            if (w.kind < 0 || w.kind > 3)
                return false;
            w.type = v.get("type", 1);
            w.slot = v.get("slot", i);
            w.hostile = v.get("hostile", false);
            int source = v.get("source", -1);
            if (w.hostile) {
                if (source < 0 || source >= int(actors.size()) - actor_offset)
                    return false;
                w.source = handle(source + actor_offset);
            }
            w.interval = v.get("interval", 1.0);
            if (w.interval <= 0 || double(v.get("speed", 720.0)) <= 0 || read_amount(v.get("damage", 1.0)) < 0 ||
                int(v.get("salvo", 1)) < 1)
                return false;
            w.remaining = v.get("remaining", w.kind == 3 ? 0.0 : w.interval);
            w.base = read_amount(v.get("damage", 1.0));
            w.branch_factors = Array(v.get("branch_factors", Array())).duplicate(true);
            w.external_factors = Array(v.get("external_factors", Array())).duplicate(true);
            w.factor = v.get("factor", 1.0);
            w.speed = v.get("speed", 720.0);
            w.salvo = v.get("salvo", 1);
            w.crit_rate = v.get("critical_rate", crit_rate);
            w.crit_multiplier = v.get("critical_multiplier", crit_multiplier);
            w.repeat_probability = v.get("repeat_probability", repeat_probability);
            w.repeat_multiplier = v.get("repeat_multiplier", repeat_multiplier);
            w.secondary_probability = v.get("secondary_probability", secondary_probability);
            w.chain_count = v.get("chain_count", chain_count);
            w.charge = v.get("charge", 0.0);
            w.ramp = v.get("ramp", 1.0);
            w.maximum = v.get("maximum", 1.0);
            w.endless = v.get("endless", false);
            w.muzzle = v.get("muzzle", Vector2(286, 520));
            w.entry = Dictionary(v.get("entry", Dictionary())).duplicate(true);
            w.row = Dictionary(v.get("row", Dictionary())).duplicate(true);
            w.birth = birth_config(w, v, delay);
            int index = 0;
            while (index < int(weapons.size()) && !weapons[index].vacant) ++index;
            if (index == int(weapons.size())) weapons.push_back(w);
            else weapons[index] = w;
            roots.push({clock + w.remaining, ++event_serial, 0, index});
        }
        return true;
    }

  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("evaluate_module", "module", "count"), &SpaceCombatKernel::evaluate_module);
        ClassDB::bind_method(D_METHOD("take_results"), &SpaceCombatKernel::take_results);
        ClassDB::bind_method(D_METHOD("read_history"), &SpaceCombatKernel::read_history);
        ClassDB::bind_method(D_METHOD("clear_encounter", "reason"), &SpaceCombatKernel::clear_encounter);
        ClassDB::bind_method(D_METHOD("finish_retreat"), &SpaceCombatKernel::finish_retreat);
        ClassDB::bind_method(D_METHOD("begin_retreat"), &SpaceCombatKernel::begin_retreat);
        ClassDB::bind_method(D_METHOD("finish_wave", "final"), &SpaceCombatKernel::finish_wave);
        ClassDB::bind_method(D_METHOD("start_wave", "wave"), &SpaceCombatKernel::start_wave);
        ClassDB::bind_method(D_METHOD("initialize", "descriptor"), &SpaceCombatKernel::initialize);
        ClassDB::bind_method(D_METHOD("missile_legend_metrics"), &SpaceCombatKernel::missile_legend_metrics);
        ClassDB::bind_method(D_METHOD("supports_endless_beam"), &SpaceCombatKernel::supports_endless_beam);
        ClassDB::bind_method(D_METHOD("supports_missile_legends"), &SpaceCombatKernel::supports_missile_legends);
        ClassDB::bind_method(D_METHOD("supports_strange_matter"), &SpaceCombatKernel::supports_strange_matter);
        ClassDB::bind_method(D_METHOD("supports_laser_charge"), &SpaceCombatKernel::supports_laser_charge);
        ClassDB::bind_method(D_METHOD("configure", "descriptor"), &SpaceCombatKernel::configure);
        ClassDB::bind_method(D_METHOD("input_presentation_muzzles", "rows"), &SpaceCombatKernel::input_presentation_muzzles);
        ClassDB::bind_method(D_METHOD("input_geometry", "points", "muzzles"),
                             &SpaceCombatKernel::input_geometry);
        ClassDB::bind_method(D_METHOD("input_ballistic_geometry", "hulls", "points", "muzzles", "stationary"), &SpaceCombatKernel::input_ballistic_geometry, DEFVAL(PackedByteArray()));
        ClassDB::bind_method(D_METHOD("advance", "seconds"), &SpaceCombatKernel::advance);
        ClassDB::bind_method(D_METHOD("can_advance", "seconds"), &SpaceCombatKernel::can_advance);
        ClassDB::bind_method(D_METHOD("can_update_configuration", "descriptor"), &SpaceCombatKernel::can_update_configuration);
        ClassDB::bind_method(D_METHOD("update_configuration", "descriptor"), &SpaceCombatKernel::update_configuration);
        ClassDB::bind_method(D_METHOD("refit_token"), &SpaceCombatKernel::refit_token);
        ClassDB::bind_method(D_METHOD("can_refit_configuration", "descriptor"), &SpaceCombatKernel::can_refit_configuration);
        ClassDB::bind_method(D_METHOD("refit_configuration", "descriptor"), &SpaceCombatKernel::refit_configuration);
        ClassDB::bind_method(D_METHOD("target_views", "type"), &SpaceCombatKernel::target_views);
        ClassDB::bind_method(D_METHOD("input_player_point", "point"), &SpaceCombatKernel::input_player_point);
        ClassDB::bind_method(D_METHOD("input_player_hull", "hull"), &SpaceCombatKernel::input_player_hull);
        ClassDB::bind_method(D_METHOD("enemy_views"), &SpaceCombatKernel::enemy_views);
        ClassDB::bind_method(D_METHOD("buffer_view"), &SpaceCombatKernel::buffer_view);
        ClassDB::bind_method(D_METHOD("deferred_total"), &SpaceCombatKernel::deferred_total_text);
        ClassDB::bind_method(D_METHOD("rng_source"), &SpaceCombatKernel::rng_source);
        ClassDB::bind_method(D_METHOD("exit_state"), &SpaceCombatKernel::exit_state);
        ClassDB::bind_method(D_METHOD("set_compact_laser_births", "enabled"), &SpaceCombatKernel::set_compact_laser_births);
        ClassDB::bind_method(D_METHOD("loss_view"), &SpaceCombatKernel::loss_view);
        ClassDB::bind_method(D_METHOD("defence_time_view"), &SpaceCombatKernel::defence_time_view);
        ClassDB::bind_method(D_METHOD("projectile_views"), &SpaceCombatKernel::projectile_views);
        ClassDB::bind_method(D_METHOD("presentation_projectile_rows"), &SpaceCombatKernel::presentation_projectile_rows);
        ClassDB::bind_method(D_METHOD("presentation_membership"), &SpaceCombatKernel::presentation_membership);
        ClassDB::bind_method(D_METHOD("presentation_beams"), &SpaceCombatKernel::presentation_beams);
        ClassDB::bind_method(D_METHOD("player_view"), &SpaceCombatKernel::player_view);
        ClassDB::bind_method(D_METHOD("take_feedback"), &SpaceCombatKernel::take_feedback);
        ClassDB::bind_method(D_METHOD("set_damage_stats_enabled", "enabled"), &SpaceCombatKernel::set_damage_stats_enabled);
        ClassDB::bind_method(D_METHOD("take_damage_stats"), &SpaceCombatKernel::take_damage_stats);
        ClassDB::bind_method(D_METHOD("actor_handle", "uid"), &SpaceCombatKernel::actor_handle);
        ClassDB::bind_method(D_METHOD("cancel"), &SpaceCombatKernel::cancel);
        ClassDB::bind_method(D_METHOD("metrics"), &SpaceCombatKernel::metrics);
        ClassDB::bind_method(D_METHOD("cooldown_remaining", "slot", "source_uid"),
                             &SpaceCombatKernel::cooldown_remaining, DEFVAL(int64_t(-1)));
    }

  public:
    void retain_configuration_bounds(bool reset = false) {
        if (reset) {
            retained_min_interval = std::numeric_limits<double>::infinity();
            retained_salvo_bound = 1; retained_chain_bound = 0; retained_drop_bound = 0;
        }
        for (const Weapon &w : weapons) {
            if (w.vacant) continue;
            retained_min_interval = minimum(retained_min_interval, w.interval);
            retained_salvo_bound = maximum(retained_salvo_bound, w.salvo);
            retained_chain_bound = maximum(retained_chain_bound, maximum(w.chain_count, prism_count));
        }
        double drops = 0;
        for (const Actor &a : actors) drops += double(a.jewel_rolls) + double(a.drops.size());
        retained_drop_bound = maximum(retained_drop_bound, drops);
    }
    bool can_advance(double seconds) const {
        if (!admitted || (stopped && !retreating) || executing || !finite(seconds) || seconds <= 0 ||
            !finite(clock + seconds) || !finite(defence_time + seconds)) return false;
        const long double exact_limit = static_cast<long double>(std::numeric_limits<int64_t>::max());
        // Only live beams: missile/pulse populations add no preflight scan.
        // Birth/retire maintain this dense index in O(1).
        double beam_segments = 0;
        for (size_t id : active_beams) {
            const Flight &f = flights[id];
            double future_age = f.age + seconds;
            double ticks = maximum(0.0,std::floor((future_age-f.next_hit)/f.interval)+1);
            beam_segments += ticks;
            if (!finite(future_age) || future_age <= f.age || future_age >= exact_limit ||
                f.next_hit + f.interval <= f.next_hit || !finite(f.next_hit + f.interval) ||
                double(f.ticks) + ticks >= 2147483647.0) return false;
        }
        // Normal roots reschedule after processing. Owned beams can retire/restart once
        // per segment. Every extra segment needs an existing or newly ejected missile.
        double normal = double(roots.size()) * (1 + ceil_number(seconds / retained_min_interval));
        double segments = 2 + beam_segments + normal + double(ejections.size()) + (normal + double(repeats.size())) * retained_salvo_bound;
        double root_bound = normal + (double(roots.size()) + double(weapons.size())) * segments;
        double copies = 3.0 * retained_salvo_bound * (maximum(1.0,double(actors.size())) + retained_chain_bound);
        double carriers = double(active.size()) + double(ejections.size()) + (root_bound + double(repeats.size())) * copies;
        double periods = carriers * (segments + 1 + ceil_number(seconds / retained_min_interval));
        // Repeated beams cannot repeat again; secondary shares the primary instance.
        double births = carriers + periods * copies;
        double hits = births * maximum(1.0,double(actors.size())) + double(actors.size()) * double(actors.size());
        double strange_births = strange_enabled ? hits * maximum(1, strange_kill_spawns) : 0;
        hits += double(strange_pending.size()) * double(actors.size());
        if (!finite(clock + seconds + strange_delay) ||
            double(strange_serial) + strange_births >= exact_limit) return false;
        long double attack_end = static_cast<long double>(attack_counter) + root_bound + double(repeats.size()) + periods;
        // Every retained wild context can explode once; no recursive explosion.
        hits *= 1 + double(actors.size());
        long double incoming_end = static_cast<long double>(incoming_counter) + hits;
        double events = births + hits + root_bound + periods + retained_drop_bound + strange_births;
        if (!finite(events) || events >= exact_limit || attack_end >= exact_limit || incoming_end >= exact_limit ||
            double(event_serial) + events >= exact_limit || double(flight_serial) + births >= exact_limit ||
            double(instance_serial) + births >= exact_limit || double(attack_serial) + root_bound >= exact_limit ||
            double(step_serial) + segments >= exact_limit || double(context_serial) + births + root_bound >= exact_limit ||
            double(missile_attacks) + root_bound >= exact_limit) return false;
        return true;
    }
    // Read only on demand; no per-step Dictionary/Array allocation for diagnostics.
    Dictionary missile_legend_metrics() const {
        Dictionary out; Array targets;
        uint64_t firsts = 0, reuses = 0, growth = 0, hits = 0, derived = 0;
        for (const Actor &a : actors) {
            Dictionary row; row["uid"] = a.uid; row["layers"] = a.guidance_layers;
            row["cache_firsts"] = int64_t(a.guidance_firsts); row["cache_hits"] = int64_t(a.guidance_reuses);
            row["effective_layer_growth"] = int64_t(a.guidance_growth);
            row["first_factor"] = a.first_guidance_factor; row["last_factor"] = a.last_guidance_factor;
            row["min_factor"] = a.min_guidance_factor; row["max_factor"] = a.max_guidance_factor;
            row["missile_hits"] = int64_t(a.missile_hits); row["derived_hits"] = int64_t(a.derived_missile_hits);
            targets.push_back(row); firsts += a.guidance_firsts; reuses += a.guidance_reuses;
            growth += a.guidance_growth; hits += a.missile_hits; derived += a.derived_missile_hits;
        }
        out["targets"] = targets; out["cache_firsts"] = int64_t(firsts); out["cache_hits"] = int64_t(reuses);
        out["effective_layer_growth"] = int64_t(growth); out["missile_hits"] = int64_t(hits); out["derived_hits"] = int64_t(derived);
        out["missile_attacks"] = missile_attacks; out["wild_substitutions"] = int64_t(wild_replacements);
        out["wild_blasts"] = int64_t(wild_detonations); out["recursion_blocked_entries"] = int64_t(wild_recursion_blocks);
        return out;
    }
    bool supports_endless_beam() const { return true; }
    bool supports_missile_legends() const { return true; }
    bool supports_strange_matter() const { return true; }
    bool supports_laser_charge() const { return true; }
    // One kernel owns the session. New waves append generations; they never
    // configure a replacement owner or discard legal carriers from an earlier wave.
    Dictionary evaluate_module(Dictionary module, int64_t count) const {
        Dictionary result;
        try {
            Amount value = evaluate_module_value(read_amount(module["charged_base"]), count,
                module.get("history_growth", 0.0), module.get("effective_enhancement_level", int64_t(0)),
                module.get("counter_log_base", 10.0), module.get("counter_round_scale", 100.0),
                module.get("branch_factors", Array()), module.get("external_factors", Array()));
            result["ok"] = true; result["value"] = wire(value);
        } catch (const std::exception &e) { result["ok"] = false; result["error"] = String(e.what()); }
        return result;
    }
    bool initialize(Dictionary descriptor) {
        try { return configure(descriptor); }
        catch (const std::exception &e) { failure_reason = String(e.what()); stopped = true; return false; }
    }
    bool start_wave(Dictionary wave) {
        if (!admitted || executing || stopped || wave_active) return false;
        for (const Actor &a : actors) if (a.live) return false;
        Dictionary descriptor;
        descriptor["player"] = player_row;
        descriptor["target_slot_center"] = target_slot_center;
        descriptor["reactive_stack_limit"] = reactive_stack_limit;
        descriptor["enemies"] = wave.get("enemies", Array());
        descriptor["weapons"] = wave.get("weapons", Array());
        if (!configuration_schema(descriptor) || Array(descriptor["enemies"]).is_empty()) return false;
        reclaim_finished_wave();
        if (final_cleared) {
            compact();
            actors.clear(); actor_rows.clear();
            weapons.erase(std::remove_if(weapons.begin(), weapons.end(), [](const Weapon &w) { return w.hostile; }), weapons.end());
            for (int i = 0; i < int(weapons.size()); ++i) {
                weapons[i].beam = -1;
                roots.push({clock + (weapons[i].kind == 3 ? 0 : weapons[i].interval), ++event_serial, 0, i});
            }
        }
        if (!battle_started) {
            while (!roots.empty()) roots.pop();
            for (int i = 0; i < int(weapons.size()); ++i)
                roots.push({clock + (weapons[i].kind == 3 ? 0 : weapons[i].interval), ++event_serial, 0, i});
        }
        const int actor_offset = int(actors.size());
        ++encounter_generation;
        if (!install_actors(descriptor["enemies"]) || !install_weapons(descriptor["weapons"], actor_offset, repeat_delay)) return false;
        final_encounter = wave.get("final", false);
        final_cleared = false;
        wave_active = true; battle_started = true;
        jewel_probability = wave.get("jewel_probability", jewel_probability);
        jewel_ratio = wave.get("jewel_ratio", 1.0);
        retain_configuration_bounds();
        return true;
    }
    void finish_wave(bool final) {
        if (executing) return;
        for (const Actor &a : actors) if (a.live) return;
        wave_active = false;
        if (final) { final_encounter = true; commit_final_wipe(); }
    }
    void begin_retreat() {
        if (executing) return;
        cancel(); wave_active = false; retreating = true;
        for (Actor &a : actors) { a.live = false; a.view["dead"] = true; ++a.generation; }
        debts.clear();
    }
    void finish_retreat() {
        if (executing || !stopped || !admitted) return;
        actors.clear(); actor_rows.clear();
        weapons.erase(std::remove_if(weapons.begin(), weapons.end(), [](const Weapon &w) { return w.hostile; }), weapons.end());
        for (Defence &d : defences) { d.loss = 0; d.buffer = 0; }
        if (!module_defence) { player_hp = player_initial_hp; player_shield = player_initial_shield; }
        reconcile_defence(); publish_player();
        stopped = false; retreating = false; final_encounter = final_cleared = false;
        for (int i = 0; i < int(weapons.size()); ++i) {
            weapons[i].beam = -1;
            roots.push({clock, ++event_serial, 0, i});
        }
    }
    void clear_encounter(const String &) { begin_retreat(); battle_started = false; }
    Dictionary read_history() const {
        Dictionary out; out["attacks"] = int64_t(attack_counter); out["incoming"] = int64_t(incoming_counter); return out;
    }
    Dictionary take_results() {
        Dictionary out; Array events = take_feedback(), drops;
        for (int i = 0; i < events.size(); ++i) {
            Dictionary event = events[i];
            if (int(event.get("kind", 0)) == 7) {
                Dictionary drop = event.get("shot", Dictionary()); drop["created_at"] = event["clock"]; drops.push_back(drop);
            }
        }
        bool cleared = wave_active;
        for (const Actor &a : actors) if (a.live) { cleared = false; break; }
        out["events"] = events; out["drops"] = drops;
        out["wave_cleared"] = cleared; out["final_cleared"] = cleared && final_cleared;
        out["player_dead"] = player_hp <= 0; out["history"] = read_history(); out["error"] = failure_reason;
        if (cleared) wave_active = false;
        return out;
    }

    bool configure(Dictionary d) {
        if (!configuration_schema(d) || !configuration_arithmetic(d, int64_t(d.get("attack_counter",int64_t(0))), int64_t(d.get("incoming_counter",int64_t(0))))) return false;
        cancel();
        feedback.clear();
        actors.clear();
        weapons.clear();
        defences.clear();
        debts.clear();
        buffer_rows = Dictionary();
        loss_rows = Dictionary();
        defence_time_rows = Dictionary();
        actor_rows = Array();
        actor_rows.set_typed(Variant::DICTIONARY, StringName(), Variant());
        compact_laser_births = false; compact_laser_count = 0; laser_view_revision = 0; compatibility_flights.clear();
        flight_rows = Array();
        flight_rows.set_typed(Variant::DICTIONARY, StringName(), Variant());
        admitted = false;
        stopped = false; retreating = false;
        final_encounter = d.get("final_encounter", false); final_cleared = false;
        ++encounter_generation;
        if (!finite_descriptor(d) || !d.has("player") || !d.has("enemies") || !d.has("weapons") ||
            !Array(d.get("unsupported_rules", Array())).is_empty())
            return false;
        if (!numeric_fields(d["player"], {"armour", "shield"}))
            return false;

        target_slot_center = d["target_slot_center"];
        battle_width = d.get("battle_width", 0.0);
        reactive_volley_window = d.get("reactive_volley_window", 0.0);
        reactive_stack_seconds = d.get("reactive_stack_seconds", 0.0);
        reactive_per_stack = d.get("reactive_per_stack", 0.0);
        reactive_stack_limit = d.get("reactive_stack_limit", 0);
        projectile_min_x = d.get("projectile_min_x", 0.0); projectile_max_x = d.get("projectile_max_x", 0.0);
        projectile_min_y = d.get("projectile_min_y", 0.0); projectile_max_y = d.get("projectile_max_y", 0.0);
        missile_departure_angle = d.get("missile_departure_angle", 0.0);
        missile_launch_edge_margin = d.get("missile_launch_edge_margin", 0.0);
        missile_launch_forward_y = d.get("missile_launch_forward_y", 0.0);
        clock = d.get("clock", 0.0);
        last_incoming_at = clock - double(d.get("since_hit", 100.0));
        flight_serial = d.get("projectile_serial", 0); attack_serial = d.get("attack_serial", 0);
        instance_serial = d.get("instance_serial", 0);
        ejection_gap = d.get("ejection_gap", 0.12);
        launch_speed = d.get("launch_speed", 120.0);
        turn_rate = d.get("turn_rate", 4.0);
        ignition = d.get("ignition", 0.22);
        seek = d.get("seek", 0.4);
        cruise_at = d.get("cruise_at", 0.65);
        lifetime = d.get("lifetime", 4.5);
        orphan_lifetime = d.get("orphan_lifetime", 30.0);
        brake_range = d.get("brake_range", 120.0);
        brake_angle = d.get("brake_angle", 0.3);
        min_speed = d.get("min_speed", 60.0);
        brake_factor = d.get("brake_factor", 0.7);
        hit_radius = d.get("hit_radius", 5.0);
        chain_speed = d.get("chain_speed",720.0);
        if (ejection_gap <= 0 || cruise_at <= ignition)
            return false;
        resistance = d.get("resistance", 0.5);
        player_row = Dictionary(d["player"]).duplicate(true);
        player_point = Vector2(player_row.get("x", 286.0), player_row.get("y", 520.0));
        player_collision_hull.clear();
        player_hp = read_amount(player_row["armour"]);
        player_shield = read_amount(player_row["shield"]);
        player_initial_hp = player_hp; player_initial_shield = player_shield;
        if (!finite(player_hp) || !finite(player_shield))
            return false;
        rng.instantiate();
        rng->set_state(int64_t(d.get("rng_state", 1)));
        missile_attacks = d.get("missile_attacks",0); context_serial = 0;
        wild_replacements = wild_detonations = wild_recursion_blocks = 0;
        crit_rate = d.get("critical_rate", 0.0);
        crit_multiplier = d.get("critical_multiplier", 2.0);
        repeat_probability = d.get("repeat_probability", 0.0);
        repeat_multiplier = d.get("repeat_multiplier", 1.0);
        repeat_delay = d.get("repeat_delay", 0.1);
        secondary_probability = d.get("secondary_probability", 0.0);
        chain_count = d.get("chain_count", 0);
        scatter = d.get("scatter", false);
        scatter_bonus = d.get("scatter_bonus", 0.0);
        laser_charge_multiplier = d.get("laser_charge_multiplier", 1.0);
        configure_strange(d);
        configure_missile_legends(d);
        prism_count = d.get("prism_count", 0);
        prism_bonus = d.get("prism_bonus", 0.0);
        if (!install_actors(d["enemies"]) || !install_weapons(d["weapons"], 0, d.get("repeat_delay", 0.5))) return false;
        attack_counter = d.get("attack_counter", int64_t(0));
        incoming_counter = d.get("incoming_counter", int64_t(0));
        counter_growth = d.get("counter_growth", 0.0);
        defence_counter_growth = d.get("defence_counter_growth", counter_growth);
        counter_level = d.get("counter_level", int64_t(0));
        counter_log_base = d.get("counter_log_base", 10.0);
        counter_round_scale = d.get("counter_round_scale", 10.0);
        memory_interval = d.get("memory_interval", 1.0);
        deferred_interval = d.get("deferred_interval", 1.0);
        deferred_duration = d.get("deferred_duration", 1.0);
        clear_probability = d.get("clear_probability", 0.0);
        defence_time = d.get("defence_time", 0.0);
        memory_elapsed = d.get("memory_elapsed", 0.0);
        deferred_elapsed = d.get("deferred_elapsed", 0.0);
        deferred_tick = d.get("deferred_tick", 0);
        if (!numeric_fields(d, {"memory_interval", "deferred_interval", "defence_time", "memory_elapsed", "deferred_elapsed", "deferred_tick"}) ||
            memory_interval <= 1e-9 || deferred_interval <= 1e-9 || defence_time < 0 ||
            memory_elapsed < 0 || memory_elapsed >= memory_interval ||
            deferred_elapsed < 0 || deferred_elapsed >= deferred_interval || counter_log_base <= 0 ||
            counter_log_base == 1 || counter_round_scale <= 0)
            return false;
        Array defs = d.get("defences", Array());
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i];
            Defence a;
            a.entry = Dictionary(v.get("entry", Dictionary())).duplicate(true);
            a.layer = v.get("layer", 0);
            a.type = v.get("type", 0);
            a.base = read_amount(v.get("base", 0.0));
            a.branch_factors = Array(v.get("branch_factors", Array())).duplicate(true);
            a.external_factors = Array(v.get("external_factors", Array())).duplicate(true);
            a.factor = v.get("factor", 1.0);
            a.maximum = read_amount(v.get("maximum", 0.0));
            a.loss = read_amount(v.get("loss", 0.0));
            a.buffer = read_amount(v.get("buffer", 0.0));
            a.delay = v.get("delay", 0.0);
            a.rate = v.get("rate", 0.0);
            a.last_hit = v.get("last_hit", 0.0);
            a.memory_heal = v.get("memory_heal", 0.0);
            a.memory_cap = v.get("memory_cap", 0.0);
            a.deferred_fraction = v.get("deferred_fraction", 0.0);
            if (a.layer < 0 || a.layer > 1 || a.deferred_fraction < 0 || a.deferred_fraction >= 1)
                return false;
            defences.push_back(a);
        }
        drop_rules = d.get("drop_rules_compiled", false);
        drop_uid = d.get("drop_uid", 0);
        jewel_probability = d.get("jewel_probability", 0.0);
        jewel_ratio = d.get("jewel_ratio", 1.0);
        Dictionary pending_debts = d.get("deferred", Dictionary());
        Array debt_keys = pending_debts.keys();
        for (int i = 0; i < debt_keys.size(); ++i) {
            Dictionary payment = pending_debts[debt_keys[i]];
            debts[int64_t(debt_keys[i])] = {read_amount(payment.get("shield", 0.0)), read_amount(payment.get("armour", 0.0))};
        }
        module_defence = !defences.empty();
        failure_reason = "";
        wave_active = !actors.empty(); battle_started = wave_active;
        admitted = (!bool(d.get("requires_module_defense", false)) || module_defence) &&
                   (!bool(d.get("requires_drop_rules", false)) || drop_rules);
        if (module_defence) {
            for (Defence &defence : defences) {
                defence.maximum = evaluate_module_value(defence.base, incoming_counter, defence_counter_growth, counter_level, counter_log_base, counter_round_scale, defence.branch_factors, defence.external_factors) * defence.factor;
                defence.loss = 0;
            }
        }
        retain_configuration_bounds(true);
        publish_player();
        root_attacks = hit_count = dead_count = stale_rejections = physics_visits = 0;
        ballistic_checks = ballistic_skips = ballistic_ray_queries = 0;
        return admitted;
    }
    bool can_update_configuration(Dictionary d) const {
        if (!admitted || stopped || executing || !configuration_schema(d) ||
            !configuration_arithmetic(d, attack_counter, incoming_counter)) return false;
        Array enemies = d.get("enemies", Array());
        if (enemies.size() != int(actors.size())) return false;
        for (int i = 0; i < enemies.size(); ++i) {
            Dictionary a = enemies[i];
            if (int64_t(a.get("uid", -1)) != actors[i].uid || int(a.get("slot", -1)) != actors[i].slot) return false;
        }
        Array rows = d.get("weapons", Array()), defs = d.get("defences", Array());
        if (rows.size() != int(weapons.size()) || defs.size() != int(defences.size())) return false;
        for (int i = 0; i < rows.size(); ++i) {
            Dictionary v = rows[i]; const Weapon &w = weapons[i];
            if (!numeric_fields(v, {"kind","type","slot","source","damage","factor","interval","speed","salvo","charge","ramp","maximum","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","chain_count","secondary_probability"}) || double(v.get("interval", 0)) <= 0 || double(v.get("speed", 0)) <= 0 || !v.has("damage") || double(v.get("factor", 1.0)) < 0) return false;
            if (int(v.get("kind", -1)) != w.kind || int(v.get("type", -1)) != w.type || int(v.get("slot", -1)) != w.slot || bool(v.get("hostile", false)) != w.hostile || int(v.get("source", -2)) != (w.hostile ? int(w.source.index) : -1)) return false;
            Dictionary entry = v.get("entry", Dictionary());
            if (entry.get("key", "") != w.entry.get("key", "") || entry.get("name", "") != w.entry.get("name", "") || entry.get("drone_id", "") != w.entry.get("drone_id", "")) return false;
            if (Array(v.get("transfer_effects", Array())) != w.birth->effects || int(v.get("chain_count", 0)) != w.chain_count || double(v.get("repeat_probability", 0)) != w.repeat_probability || double(v.get("secondary_probability", 0)) != w.secondary_probability) return false;
        }
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i]; const Defence &a = defences[i];
            if (!numeric_fields(v, {"layer","type","base","factor","maximum","loss","buffer","last_hit","delay","rate","memory_heal","memory_cap","deferred_fraction"}) || !v.has("base") || double(v.get("factor", -1)) < 0) return false;
            if (int(v.get("layer", -1)) != a.layer || int(v.get("type", -1)) != a.type || double(v.get("memory_heal",0)) != a.memory_heal || double(v.get("memory_cap",0)) != a.memory_cap || double(v.get("deferred_fraction",0)) != a.deferred_fraction) return false;
        }
        if (double(d.get("counter_growth",0)) != counter_growth || double(d.get("defence_counter_growth",0)) != defence_counter_growth || int64_t(d.get("counter_level",int64_t(0))) != counter_level || double(d.get("repeat_delay",0)) != repeat_delay || bool(d.get("scatter",false)) != scatter || int(d.get("prism_count",0)) != prism_count) return false;
        for (const auto &field : std::initializer_list<std::pair<const char *,double>>{
            {"counter_log_base",counter_log_base},{"counter_round_scale",counter_round_scale},
            {"memory_interval",memory_interval},{"deferred_interval",deferred_interval},{"deferred_duration",deferred_duration},
            {"resistance",resistance},{"chain_speed",chain_speed},{"ejection_gap",ejection_gap},{"launch_speed",launch_speed},
            {"turn_rate",turn_rate},{"ignition",ignition},{"seek",seek},{"cruise_at",cruise_at},{"lifetime",lifetime},
            {"orphan_lifetime",orphan_lifetime},{"brake_range",brake_range},{"brake_angle",brake_angle},
            {"min_speed",min_speed},{"brake_factor",brake_factor},{"hit_radius",hit_radius}})
            if (double(d.get(field.first,field.second)) != field.second) return false;
        Dictionary player = d.get("player", Dictionary());
        return player.has("armour") && player.has("shield") && numeric_fields(player, {"armour","shield"}) && read_amount(player["armour"]) >= 0 && read_amount(player["shield"]) >= 0;
    }
    Dictionary refit_token() const {
        Dictionary token;
        token["epoch"] = int64_t(refit_epoch); token["step"] = int64_t(step_serial);
        token["rng"] = rng->get_state();
        token["armour"] = player_row.get("armour", 0.0);
        token["shield"] = player_row.get("shield", 0.0);
        return token;
    }
    bool can_refit_configuration(Dictionary d) const {
        if (Variant(d.get("refit_token", Variant())).get_type() != Variant::DICTIONARY ||
            Dictionary(d["refit_token"]) != refit_token()) return false;
        if (!can_update_configuration(d) ||
            (read_amount(Dictionary(d["player"])["armour"]) <= 0 &&
             read_amount(Dictionary(d["player"])["shield"]) <= 0)) return false;
        // Galaxy refits change numeric equipment/health and resource amounts only.
        Array rows = d["weapons"], defs = d["defences"], enemies = d["enemies"];
        for (int i = 0; i < rows.size(); ++i) {
            Dictionary v = rows[i]; const Weapon &w = weapons[i];
            if (double(v["interval"]) != w.interval ||
                double(v["speed"]) != w.speed || int(v["salvo"]) != w.salvo ||
                double(v["charge"]) != w.charge || double(v["ramp"]) != w.ramp ||
                double(v["maximum"]) != w.maximum || Dictionary(v["entry"]) != w.entry) return false;
            // Compiled rows may omit UI names, descriptions and purchase costs.
            // Compare combat fields, not incidental cold/compiled row metadata.
            Dictionary row = v["row"];
            for (const char *field : {"level","dmgtype","dmg","dmgMulti","cd","para1","para2","para3","para4","cri","criDmg"})
                if (row.get(field, Variant()) != w.row.get(field, Variant())) return false;
        }
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i]; const Defence &a = defences[i];
            if (Dictionary(v.get("entry", Dictionary())) != a.entry || double(v["delay"]) != a.delay || double(v["rate"]) != a.rate) return false;
        }
        if (double(d["jewel_probability"]) != jewel_probability || double(d["jewel_ratio"]) != jewel_ratio) return false;
        for (int i = 0; i < enemies.size(); ++i) {
            Dictionary v = enemies[i]; const Actor &a = actors[i];
            Array drops = v["compiled_drops"];
            if (int(v["jewel_rolls"]) != a.jewel_rolls || drops.size() != int(a.drops.size())) return false;
            for (int j = 0; j < drops.size(); ++j) {
                Dictionary drop = drops[j];
                if (int(drop["resource"]) != a.drops[j].resource || double(drop["chance"]) != a.drops[j].chance) return false;
            }
        }
        return true;
    }
    bool refit_configuration(Dictionary d) {
        try {
        if (!can_refit_configuration(d)) return false;
        apply_configuration(d, true);
        return true;
        } catch (const std::exception &e) { failure_reason = String(e.what()); stopped = true; return false; }
    }
    bool update_configuration(Dictionary d) {
        try {
        if (!can_update_configuration(d)) return false;
        apply_configuration(d, false);
        return true;
        } catch (const std::exception &e) { failure_reason = String(e.what()); stopped = true; return false; }
    }
    void apply_configuration(Dictionary d, bool refit) {
        Amount proportions[2];
        if (module_defence && refit) for (int layer = 0; layer < 2; ++layer)
            if (capacity(layer) > 0) proportions[layer] = layer_health(layer) / capacity(layer);
        ++refit_epoch;
        // Both entrypoints validate before touching fields or published rows.
        Array rows = d["weapons"], defs = d["defences"];
        for (int i = 0; i < rows.size(); ++i) {
            Dictionary v = rows[i];
            Weapon &w = weapons[i];
            w.kind = v["kind"];
            w.type = v["type"];
            w.base = read_amount(v["damage"]);
            w.branch_factors = Array(v.get("branch_factors", Array())).duplicate(true);
            w.external_factors = Array(v.get("external_factors", Array())).duplicate(true);
            w.factor = v.get("factor", 1.0);
            w.interval = v["interval"];
            w.speed = v["speed"];
            w.salvo = v.get("salvo", 1);
            w.charge = v.get("charge", -1.0);
            w.ramp = v.get("ramp", 1.0);
            w.maximum = v.get("maximum", 1.0);
            w.endless = v.get("endless", false);
            w.crit_rate = v.get("critical_rate", 0.0);
            w.crit_multiplier = v.get("critical_multiplier", 2.0);
            w.repeat_probability = v.get("repeat_probability", 0.0);
            w.repeat_multiplier = v.get("repeat_multiplier", 1.0);
            w.chain_count = v.get("chain_count", 0);
            w.secondary_probability = v.get("secondary_probability", 0.0);
            w.entry = Dictionary(v.get("entry", Dictionary())).duplicate(true);
            w.row = Dictionary(v.get("row", Dictionary())).duplicate(true);
            w.birth = birth_config(w, v, repeat_delay);
        }
        for (size_t id : active) {
            Flight &f = flights[id];
            if (f.live && f.beam) f.view["endless"] = endless_eligible(f);
        }
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i];
            Defence &a = defences[i];
            a.entry = Dictionary(v.get("entry", Dictionary())).duplicate(true);
            a.layer = v["layer"];
            a.base = read_amount(v["base"]);
            a.branch_factors = Array(v.get("branch_factors", Array())).duplicate(true);
            a.external_factors = Array(v.get("external_factors", Array())).duplicate(true);
            a.factor = v["factor"];
            a.type = v["type"];
            a.delay = v.get("delay", 0.0);
            a.rate = v.get("rate", 0.0);
            a.memory_heal = v.get("memory_heal", 0.0);
            a.memory_cap = v.get("memory_cap", 0.0);
            a.deferred_fraction = v.get("deferred_fraction", 0.0);
        }

        counter_growth = d.get("counter_growth", counter_growth);
        defence_counter_growth = d.get("defence_counter_growth", defence_counter_growth);
        clear_probability = d.get("clear_probability", clear_probability);
        counter_level = d.get("counter_level", counter_level);
        repeat_delay = d.get("repeat_delay", repeat_delay);
        scatter = d.get("scatter", scatter);
        scatter_bonus = d.get("scatter_bonus", scatter_bonus);
        laser_charge_multiplier = d.get("laser_charge_multiplier", 1.0);
        configure_strange(d);
        configure_missile_legends(d);
        prism_count = d.get("prism_count", prism_count);
        prism_bonus = d.get("prism_bonus", prism_bonus);
        Dictionary player = d["player"];
        if (!module_defence) {
            player_hp = read_amount(player["armour"]);
            player_shield = read_amount(player["shield"]);
        }
        if (refit) {
            Array enemies = d["enemies"];
            for (int i = 0; i < enemies.size(); ++i) {
                Dictionary v = enemies[i]; Array drops = v["compiled_drops"];
                for (int j = 0; j < drops.size(); ++j) {
                    Dictionary row = drops[j];
                    actors[i].drops[j].base = read_amount(row["base"]);
                    actors[i].drops[j].amount = read_amount(row["amount"]);
                }
                actors[i].view["compiled_drops"] = drops.duplicate(true);
            }
        }
        retain_configuration_bounds();
        reconcile_defence();
        if (module_defence && refit) for (int layer = 0; layer < 2; ++layer) set_layer_health(layer, capacity(layer) * proportions[layer]);
        publish_player();
        if (!refit) compact();
    }
    Array target_views(int type) {
        Array values;
        values.set_typed(Variant::DICTIONARY, StringName(), Variant());
        for (Handle h : targets(type, clock))
            values.push_back(actors[h.index].view);
        return values;
    }
    // Atomic, O(weapon slots), reusable across arbitrary art/configuration edits.
    // Empty rows select the existing numerical display fallback.
    bool input_presentation_muzzles(Array rows) {
        if (rows.size() != int(weapons.size())) return false;
        for (int i = 0; i < rows.size(); ++i) {
            if (rows[i].get_type() != Variant::PACKED_VECTOR2_ARRAY) return false;
            PackedVector2Array ports = rows[i];
            for (int j = 0; j < ports.size(); ++j)
                if (!finite(ports[j].x) || !finite(ports[j].y)) return false;
        }
        for (int i = 0; i < rows.size(); ++i) weapons[i].presentation_muzzles = rows[i];
        return true;
    }
    void input_ballistic_geometry(Array hulls, PackedVector2Array points, PackedVector2Array muzzles, PackedByteArray stationary = PackedByteArray()) {
        for (int i = 0; i < int(actors.size()) && i < hulls.size() && i < points.size(); ++i) {
            const PackedVector2Array hull = hulls[i];
            const bool fixed = i < stationary.size() && stationary[i] != 0;
            if (actors[i].collision_hull != hull || actors[i].stationary_geometry != fixed)
                ++actors[i].geometry_revision;
            actors[i].collision_hull = hull;
            actors[i].stationary_geometry = fixed;
            actors[i].screen_point = points[i];
        }
        int muzzle_index = 0;
        for (Weapon &weapon : weapons) {
            if (weapon.vacant || (weapon.hostile && !resolve(weapon.source))) continue;
            if (muzzle_index < muzzles.size()) weapon.screen_muzzle = muzzles[muzzle_index++];
        }
    }
    void refresh_ray_contact(Flight &f, const Actor &target) {
        ++ballistic_ray_queries;
        f.contact_revision = target.geometry_revision;
        f.contact_distance = -1;
        bool inside = false;
        const Vector2 p = f.ray_origin, ray = f.ray_step;
        const auto &hull = target.collision_hull;
        for (int i = 0, j = hull.size() - 1; i < hull.size(); j = i++) {
            const Vector2 a = hull[j], b = hull[i], edge = b - a;
            if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x) inside = !inside;
            const double cross = ray.cross(edge);
            if (cross == 0.0) continue;
            const double along = (a-p).cross(edge)/cross, side = (a-p).cross(ray)/cross;
            // Expand vertex acceptance only for this rejection gate. The original
            // polygon predicate below still decides the actual contact.
            if (along >= -1.0 && side >= -1e-4 && side <= 1.0001 && (f.contact_distance < 0 || along < f.contact_distance))
                f.contact_distance = maximum(0.0, along);
        }
        if (inside) f.contact_distance = 0;
        // A miss/degenerate ray conservatively keeps the original per-segment test.
    }
    // Return the first contact along the visible fixed ray. Geometry is authored
    // by the same presentation authority that draws the hull; no seeking here.
    static double hull_contact(Vector2 p, Vector2 movement, const PackedVector2Array &hull) {
        bool inside = false;
        double first = 2.0;
        for (int i = 0, j = hull.size() - 1; i < hull.size(); j = i++) {
            Vector2 a = hull[j], b = hull[i], edge = b - a;
            if ((a.y > p.y) != (b.y > p.y) && p.x < (b.x-a.x)*(p.y-a.y)/(b.y-a.y)+a.x) inside = !inside;
            double cross = movement.cross(edge);
            if (std::abs(cross) < 1e-9) continue;
            double along = (a-p).cross(edge)/cross, side = (a-p).cross(movement)/cross;
            if (along >= 0 && along <= 1 && side >= 0 && side <= 1) first = minimum(first, along);
        }
        return inside ? 0.0 : first;
    }
    void input_player_point(Vector2 point) {
        player_point = point;
    }
    bool input_player_hull(PackedVector2Array hull) {
        if (executing || hull.size() < 3) return false;
        for (int i = 0; i < hull.size(); ++i)
            if (!finite(hull[i].x) || !finite(hull[i].y)) return false;
        player_collision_hull = hull;
        return true;
    }
    void input_geometry(PackedVector2Array points, PackedVector2Array muzzles) {
        for (int i = 0; i < points.size() && i < int(actors.size()); ++i)
            actors[i].point = points[i];
        int muzzle_index = 0;
        for (Weapon &weapon : weapons) {
            if (weapon.vacant || (weapon.hostile && !resolve(weapon.source))) continue;
            if (muzzle_index < muzzles.size()) weapon.muzzle = muzzles[muzzle_index++];
        }
    }
    bool advance(double seconds) {
        try {
        if (!can_advance(seconds)) return false;
        if (retreating) { clock += seconds; return true; }
        double end = clock + seconds;
        // One logical boundary, before movement/ejection subdivisions. Newborn packets
        // cannot run until the next advance, including a zero configured delay.
        strange_boundary_end = end;
        executing = true;
        advance_strange(end);
        executing = false;
        // A newly installed beam/root can be due at the current clock.
        segment(0.0);
        while (clock + 1e-9 < end && (!stopped || final_cleared)) {
            double next = end;
            auto include_due = [&](const auto &queue) {
                if (!queue.empty() && queue.top().at > clock + 1e-9) next = minimum(next, queue.top().at);
            };
            // Failed roots stay parked at clock until a target exists; they
            // must not hide later roots behind the queue's first entry.
            for (const Timed &root : roots.entries())
                if (root.at > clock + 1e-9) next = minimum(next, root.at);
            include_due(repeats); include_due(ejections);
            for (size_t id : active_beams) {
                const Flight &f = flights[id];
                if (!f.live || f.await_target) continue;
                double due = clock + nonnegative(f.next_hit - f.age);
                if (due > clock + 1e-9) next = minimum(next, due);
            }
            segment(next - clock);
        }
        // The session consumes this whole logical step; terminal death freezes defence,
        // while consuming any tail after an ejection split without more battle events.
        if (stopped) clock = end;
        return true;
        } catch (const std::exception &e) {
            failure_reason = String(e.what()); stopped = true; executing = false; return false;
        }
    }
    bool valid_laser_view(const Flight &f) const {
        return f.live && f.fixed_ray && f.lease.is_valid() && f.instance && f.instance->attack && f.instance->attack->birth && f.view_birth &&
            f.lease->arena == motion_arena && f.lease->slot < motion_arena->motions.size() &&
            f.lease->motion().generation == f.lease->generation;
    }
    Dictionary laser_view(const Flight &f) const {
        const auto &birth = *f.view_birth;
        const Motion &m = f.lease->motion();
        Dictionary v;
        if (f.presentation_ray) { v["presentation_origin"] = f.presentation_origin; v["presentation_step"] = f.presentation_step; }
        v["serial"] = int64_t(f.serial); v["x"] = f.launch_point.x; v["y"] = f.launch_point.y;
        v["launch_point"] = f.launch_point;
        const bool target_live = !f.target_view_cleared && f.target.index < actors.size() && actors[f.target.index].generation == f.target.generation;
        v["target"] = target_live ? actors[f.target.index].view : Dictionary(); v["source"] = player_row;
        v["hostile"] = false; v["key"] = "laser"; v["type"] = f.type; v["damage"] = wire(f.damage); v["dead"] = !f.live;
        v["entry"] = birth.entry; v["mount"] = birth.slot; v["motion_lease"] = f.lease;
        v["direction"] = m.direction; v["speed"] = m.speed; v["chain_hop"] = false; v["prototype_missile"] = false;
        v["critical"] = f.instance->attack->critical; v["attack_instance"] = f.instance->view;
        v["repeated"] = f.view_repeated; v["owns_primary_aim"] = f.owns_primary_aim;
        v["primary_target"] = f.instance->view.get("primary_target", v["target"]);
        v["ballistic_target_origin"] = f.aim; v["fixed_screen_origin"] = f.ray_origin; v["fixed_screen_step"] = f.ray_step;
        Dictionary context;
        context["source_id"] = birth.entry.has("drone_id") ? String("drone:") + String(birth.entry["drone_id"]) : String("module:") + String::num_int64(birth.slot);
        context["trigger_depth"] = f.view_trigger_depth; v["combat_context"] = context; v["prism_tower"] = false;
        return v;
    }
    // Cold presentation transition: prepare all missing rows first. A failure
    // leaves mode, rows, handles and the sole combat owner untouched.
    int64_t set_compact_laser_births(bool enabled) {
        if (executing) return -1;
        // Terminal owners must not block Main's next delta/exit/reselection.
        // Cancel/handoff normally leave no flights; otherwise close the views
        // before allowing the existing lifecycle path to continue.
        if (!admitted || stopped) enabled = false;
        if (enabled) { compact_laser_births = true; return laser_view_revision; }
        if (compact_laser_count == 0) { compact_laser_births = false; return laser_view_revision; }
        std::vector<std::pair<size_t, Dictionary>> pending;
        for (size_t id : active) {
            const Flight &f = flights[id];
            if (!f.compact_laser) continue;
            if (!valid_laser_view(f)) return -1;
            pending.emplace_back(id, laser_view(f));
        }
        for (auto &entry : pending) {
            Flight &f = flights[entry.first]; f.view = entry.second; f.compact_laser = false;
        }
        if (!pending.empty()) {
            flight_rows.clear(); compatibility_flights.clear();
            for (size_t id : active) {
                Flight &f = flights[id]; f.compatibility_index = compatibility_flights.size();
                compatibility_flights.push_back(id); flight_rows.push_back(f.view);
            }
        }
        if (!pending.empty()) ++laser_view_revision;
        compact_laser_count = 0;
        compact_laser_births = false;
        return laser_view_revision;
    }
    Ref<RandomNumberGenerator> rng_source() const { return rng; }
    Dictionary exit_state() {
        Dictionary values, due;
        for (const auto &item : debts) {
            Dictionary payment; payment["shield"] = wire(item.second[0]); payment["armour"] = wire(item.second[1]);
            due[item.first] = payment;
        }
        values["strange_pending"] = export_strange();
        values["missile_attacks"] = missile_attacks;
        values["deferred"] = due; values["defence_time"] = defence_time;
        values["memory_elapsed"] = memory_elapsed; values["deferred_elapsed"] = deferred_elapsed; values["deferred_tick"] = deferred_tick;
        values["projectile_serial"] = int64_t(flight_serial); values["attack_serial"] = int64_t(attack_serial);
        values["instance_serial"] = int64_t(instance_serial); values["drop_uid"] = drop_uid;
        cancel(); debts.clear(); return values;
    }
    String deferred_total_text() const { return wire(deferred_total()); }
    Amount deferred_total() const {
        Amount total = 0;
        for (const auto &due : debts)
            total += due.second[0] + due.second[1];
        return total;
    }
    Dictionary buffer_view() const {
        return buffer_rows;
    }
    Dictionary loss_view() const {
        return loss_rows;
    }
    Dictionary defence_time_view() const {
        return defence_time_rows;
    }
    Array enemy_views() const {
        return actor_rows;
    }
    // Explicit full compatibility request. NIL is failure, never a partial
    // collection or an empty collection pretending that no flights exist.
    Variant projectile_views() const {
        // A complete compatibility inventory requires an explicit entry-side
        // mode choice. Reading presentation data never changes the owner.
        if (compact_laser_count != 0) return Variant();
        return flight_rows;
    }
    // Internal native presentation binding only. Compact laser bodies remain
    // in typed active membership; this array is not a projectile inventory.
    Array presentation_projectile_rows() const { return flight_rows; }
    Array presentation_beams() const {
        // Compaction swaps the full flight order independently of beam order.
        // Sort only these beam indices to preserve the existing alpha draw order.
        std::vector<size_t> ordered = active_beams;
        std::sort(ordered.begin(), ordered.end(), [this](size_t a, size_t b) {
            return flights[a].active_index < flights[b].active_index;
        });
        Array beams;
        for (size_t id : ordered) beams.push_back(flights[id].view);
        return beams;
    }
    Dictionary presentation_membership() const {
        // Read existing typed ownership, never another combat snapshot. All actor
        // rows (including dead actors) survive for this kernel's whole encounter.
        Array beams = presentation_beams();
        PackedInt64Array muzzle_serials, compact_laser_serials;
        for (size_t id : active_beams) {
            const Flight &f = flights[id];
            muzzle_serials.push_back(int64_t(f.serial));
        }
        // Only rail and beam feedback owns a retained muzzle in the scene.
        // Ordinary flight rows need no GDScript traversal at display publication.
        for (size_t id : active) {
            const Flight &f = flights[id];
            if (f.compact_laser) compact_laser_serials.push_back(int64_t(f.serial));
            if (!f.beam && f.weapon >= 0 && weapons[f.weapon].kind == 1)
                muzzle_serials.push_back(int64_t(f.serial));
        }
        Dictionary result;
        result["beams"] = beams;
        result["muzzle_serials"] = muzzle_serials;
        result["compact_laser_serials"] = compact_laser_serials;
        return result;
    }

    double cooldown_remaining(int slot, int64_t source_uid = -1) const {
        // Read the existing root deadline; no mirrored clock or exported world.
        if (!admitted || stopped) return std::numeric_limits<double>::infinity();
        for (const Timed &due : roots.entries()) {
            const Weapon &w = weapons[due.weapon];
            if (w.slot != slot || w.hostile != (source_uid >= 0)) continue;
            if (w.hostile && (w.source.index >= actors.size() ||
                actors[w.source.index].uid != source_uid || !actors[w.source.index].live ||
                actors[w.source.index].generation != w.source.generation)) continue;
            return nonnegative(due.at - clock);
        }
        return std::numeric_limits<double>::infinity();
    }
    Dictionary player_view() const {
        return player_row;
    }
    Array take_feedback() {
        Array values;
        for (const Effect &e : feedback) {
            Dictionary d;
            d["kind"] = e.kind;
            d["uid"] = e.uid;
            d["type"] = e.type;
            d["player"] = e.player;
            d["critical"] = e.critical;
            d["amount"] = wire(e.amount);
            d["absorbed"] = wire(e.absorbed);
            d["clock"] = e.time;
            d["position"] = e.point;
            d["direction"] = e.direction;
            d["target_position"] = e.target_point;
            d["target_uid"] = e.target_uid;
            if (e.reactive_stacks >= 0) {
                d["reactive_stacks"] = e.reactive_stacks;
                d["reactive_multiplier"] = e.reactive_multiplier;
            }
            if (e.presentation_ray) { d["presentation_origin"] = e.presentation_origin; d["presentation_step"] = e.presentation_step; }
            if (e.compact_laser) {
                Dictionary laser;
                laser["serial"] = int64_t(e.laser_serial); laser["mount"] = e.laser_mount;
                laser["drone"] = e.laser_drone; laser["owns_primary_aim"] = e.laser_owns_aim;
                laser["primary_target"] = e.laser_primary;
                laser["launch"] = e.laser_launch; laser["ray_origin"] = e.laser_ray_origin; laser["ray_step"] = e.laser_ray_step;
                d["native_laser"] = laser;
            } else if (!e.shot.is_empty()) d["shot"] = e.shot;
            values.push_back(d);
        }
        feedback.clear();
        return values;
    }
    void set_damage_stats_enabled(bool enabled) {
        damage_stats_enabled = enabled;
        damage_stats.clear();
    }
    Array take_damage_stats() {
        Array rows;
        if (!damage_stats_enabled) return rows;
        for (const auto &item : damage_stats) {
            Dictionary row;
            row["source"] = item.first;
            row["shield"] = wire(item.second[0]);
            row["health"] = wire(item.second[1]);
            rows.append(row);
        }
        damage_stats.clear();
        return rows;
    }
    PackedInt64Array actor_handle(int64_t uid) const {
        PackedInt64Array h;
        for (size_t i = 0; i < actors.size(); ++i)
            if (actors[i].uid == uid) {
                h.push_back(i);
                h.push_back(actors[i].generation);
                break;
            }
        return h;
    }
    void cancel() {
        stopped = true;
        strange_pending.clear(); strange_serial = 0;
        while (!roots.empty())
            roots.pop();
        while (!ejections.empty())
            ejections.pop();
        while (!repeats.empty())
            repeats.pop();
        for (size_t id : active)
            retire(id, 1);
        if (!executing)
            compact();
    }
    Dictionary metrics() const {
        Dictionary d;
        d["admitted"] = admitted;
        d["final_cleared"] = final_cleared;
        d["clock"] = clock;
        d["since_hit"] = nonnegative(clock - last_incoming_at);
        d["steps"] = int64_t(step_serial);
        d["active_flights"] = int64_t(active.size());
        d["strange_pending"] = int64_t(strange_pending.size());
        d["missile_attacks"] = missile_attacks;
        d["root_attacks"] = int64_t(root_attacks);
        d["attack_counter"] = attack_counter;
        d["incoming_counter"] = incoming_counter;
        d["module_defence"] = module_defence;
        d["hits"] = int64_t(hit_count);
        d["deaths"] = int64_t(dead_count);
        d["stale_handle_rejections"] = int64_t(stale_rejections);
        d["physics_visits"] = int64_t(physics_visits);
        d["ballistic_checks"] = int64_t(ballistic_checks);
        d["ballistic_skips"] = int64_t(ballistic_skips);
        d["ballistic_ray_queries"] = int64_t(ballistic_ray_queries);
        d["attack_counter"] = attack_counter;
        d["incoming_counter"] = incoming_counter;
        d["drop_uid"] = drop_uid;
        d["defence_time"] = defence_time;
        d["memory_elapsed"] = memory_elapsed;
        d["deferred_elapsed"] = deferred_elapsed;
        d["deferred_tick"] = deferred_tick;
        d["old_game_callbacks"] = 0;
        d["object_refreshes"] = 0;
        d["ejection_queue"] = int64_t(ejections.size());
        d["repeat_queue"] = int64_t(repeats.size());
        return d;
    }
};
