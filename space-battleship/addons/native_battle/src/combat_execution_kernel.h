// Encounter execution prototype. All mutable simulation fields below have one owner.
// Dictionaries are admission descriptors and persistent presentation rows only;
// no Object/Game callback occurs in advance, impact, death or chain execution.
#include <godot_cpp/classes/random_number_generator.hpp>
#include <limits>
#include <map>
#include <queue>

class SpaceCombatKernel : public RefCounted {
    GDCLASS(SpaceCombatKernel, RefCounted)
    // Presentation reads the existing active order and generation; it never owns combat.
    friend class SpaceCombatPresentation;
    struct Handle {
        uint32_t index = UINT32_MAX, generation = 0;
    };
    struct DropRule {
        double chance = 0, amount = 0, base = 0;
        int resource = 0;
    };
    struct Actor {
        uint32_t generation = 1;
        int64_t uid = 0;
        bool live = true;
        double hp = 0, max_hp = 0, shield = 0, max_shield = 0, delay = 0, recovery = 0, shield_at = 0,
               hit_at = 0;
        int armour_type = 0, shield_type = 0, slot = 0;
        Vector2 logical, point, screen_point;
        PackedVector2Array collision_hull;
        uint64_t geometry_revision = 0;
        bool stationary_geometry = false;
        Dictionary view;
        std::vector<DropRule> drops;
        int jewel_rolls = 0;
        double interference = 0, explosion = 0;
    };
    struct BirthConfig {
        Dictionary weapon;
        Array effects;
        int slot = 0, kind = 0, type = 0, salvo = 1, chain_count = 0;
        double speed = 0, interval = 0, charge = 0, ramp = 1, maximum = 1;
        double repeat_delay = 0, repeat_multiplier = 1;
    };
    struct Weapon {
        int kind = 0, type = 0, slot = 0;
        bool hostile = false;
        Handle source;
        double interval = 1, remaining = 1, base = 1, factor = 1, speed = 30, charge = 0, ramp = 1,
               maximum = 1;
        int salvo = 1;
        double crit_rate = 0, crit_multiplier = 2, repeat_probability = 0, repeat_multiplier = 1,
               secondary_probability = 0;
        int chain_count = 0;
        Vector2 muzzle, screen_muzzle;
        Dictionary entry, row;
        int64_t beam = -1;
        std::shared_ptr<const BirthConfig> birth;
    };
    static std::shared_ptr<const BirthConfig> birth_config(const Weapon &w, Dictionary v, double delay) {
        auto b = std::make_shared<BirthConfig>();
        b->weapon = w.row.duplicate(true); b->weapon.make_read_only();
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
    struct Attack {
        uint64_t id = 0;
        double damage = 0;
        bool critical = false, secondary = false, repeats = false;
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
        size_t active_index = 0;
        uint64_t born_step = 0, serial = 0;
        int weapon = -1, type = 0;
        Handle source, target;
        std::shared_ptr<Instance> instance;
        double multiplier = 1, damage = 0, cruise_speed = 0, age = 0, next_hit = 0, charge = 0, interval = 0,
               ramp = 1, maximum = 1;
        int ticks = 0;
        Vector2 aim, logical_aim;
        bool fixed_ray = false;
        Vector2 ray_origin, ray_step, launch_point;
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
        double multiplier = 1;
        std::shared_ptr<Instance> instance;
        size_t owner_flight = SIZE_MAX;
        uint32_t owner_generation = 0;
        bool damage_derived = false; // Carrier provenance is separate from shared chain allowance.
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
        int layer = 0, type = 0;
        double base = 0, factor = 1, maximum = 0, loss = 0, buffer = 0, delay = 0, rate = 0, last_hit = 0,
               memory_heal = 0, memory_cap = 0, deferred_fraction = 0;
    };
    struct Effect {
        int kind = 0, type = 0;
        bool player = false, critical = false;
        int64_t uid = 0;
        double amount = 0, absorbed = 0, time = 0;
        Vector2 point, direction, target_point;
        int64_t target_uid = -1;
        Dictionary shot;
    };
    std::vector<Actor> actors;
    std::vector<Weapon> weapons;
    std::vector<Defence> defences;
    std::map<int64_t, std::array<double, 2>> debts;
    double defence_time = 0, memory_interval = 1, deferred_interval = 1, memory_elapsed = 0,
           deferred_elapsed = 0, deferred_duration = 1, clear_probability = 0, counter_growth = 0,
           defence_counter_growth = 0, counter_level = 0, counter_log_base = 10, counter_round_scale = 10;
    int64_t deferred_tick = 0;
    double attack_counter = 0, incoming_counter = 0;
    // Encounter envelopes retain old birth configurations across numeric upgrades.
    // They only widen; no hot scan of carriers or queues is required.
    double retained_damage_bound = 0, retained_repeat_bound = 1, retained_maximum_bound = 1;
    double retained_min_interval = std::numeric_limits<double>::infinity();
    double retained_interference_bound = 1, retained_explosion_bound = 0, retained_debt_bound = 0;
    int retained_salvo_bound = 1, retained_chain_bound = 0;
    double retained_drop_bound = 0, retained_recovery_bound = 0, retained_shield_bound = 0;
    double envelope_clock = 0, retained_shield_elapsed = 0;
    bool module_defence = false;

    std::deque<Flight> flights;
    std::vector<size_t> active, free_flights, retired;
    RootQueue roots;
    std::priority_queue<Timed, std::vector<Timed>, Later> ejections, repeats;
    std::vector<Effect> feedback;
    std::shared_ptr<MotionArena> motion_arena = std::make_shared<MotionArena>();
    Ref<RandomNumberGenerator> rng;
    Array actor_rows, flight_rows;
    Dictionary player_row;
    Dictionary buffer_rows, loss_rows, defence_time_rows;
    Vector2 player_point;
    uint32_t encounter_generation = 1;
    uint64_t refit_epoch = 0;
    uint64_t step_serial = 0, event_serial = 0, attack_serial = 0, instance_serial = 0, flight_serial = 0;
    double clock = 0, player_hp = 0, player_shield = 0, resistance = 0.5;
    double last_incoming_at = -100;
    double jewel_probability = 0, jewel_ratio = 1;
    int64_t drop_uid = 0;
    bool drop_rules = false;
    bool admitted = false, stopped = false, scatter = false, executing = false;
    bool final_encounter = false, final_cleared = false;
    int chain_count = 0, prism_count = 0;
    double crit_rate = 0, crit_multiplier = 2, repeat_probability = 0, repeat_multiplier = 1,
           repeat_delay = 0, secondary_probability = 0, scatter_bonus = 0, prism_bonus = 0;
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
            return std::isfinite(double(value));
        case Variant::VECTOR2: {
            Vector2 point = value;
            return std::isfinite(point.x) && std::isfinite(point.y);
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
            if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT)
                return false;
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
            if (row.has(key) && double(row[key]) < 0) return false;
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
        if (!finite_descriptor(d) || !schema_required(d, {"player","enemies","weapons"}) ||
            !schema_types(d, Variant::DICTIONARY, {"player","deferred"}) ||
            !schema_types(d, Variant::ARRAY, {"enemies","weapons","defences","unsupported_rules"}) ||
            !schema_types(d, Variant::BOOL, {"final_encounter","scatter","drop_rules_compiled","requires_drop_rules","requires_module_defense"}) ||
            !schema_integers(d, {"chain_count","prism_count"}) ||
            !schema_integers(d, {"rng_state","projectile_serial","attack_serial","instance_serial","deferred_tick","drop_uid"}, false) ||
            !numeric_fields(d, {"clock","since_hit","ejection_gap","launch_speed","turn_rate","ignition","seek","cruise_at","lifetime","orphan_lifetime","brake_range","brake_angle","min_speed","brake_factor","hit_radius","chain_speed","resistance","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","repeat_delay","secondary_probability","scatter_bonus","prism_bonus","attack_counter","incoming_counter","counter_growth","defence_counter_growth","counter_level","counter_log_base","counter_round_scale","memory_interval","deferred_interval","deferred_duration","clear_probability","defence_time","memory_elapsed","deferred_elapsed","jewel_probability","jewel_ratio"})) return false;
        if (!Array(d.get("unsupported_rules", Array())).is_empty() ||
            !schema_nonnegative(d, {"since_hit","launch_speed","turn_rate","ignition","seek","lifetime","orphan_lifetime","brake_range","brake_angle","min_speed","brake_factor","hit_radius","critical_multiplier","repeat_multiplier","repeat_delay","attack_counter","incoming_counter","counter_growth","defence_counter_growth","counter_level","scatter_bonus","prism_bonus","deferred_duration","defence_time","memory_elapsed","deferred_elapsed","jewel_ratio","chain_count","prism_count","projectile_serial","attack_serial","instance_serial","deferred_tick","drop_uid"}) ||
            !schema_probabilities(d, {"resistance","critical_rate","repeat_probability","secondary_probability","clear_probability","jewel_probability"})) return false;
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
                !schema_integers(v, {"uid"}, false) || !schema_integers(v, {"armourType","shieldType","slot","jewel_rolls"}) ||
                !schema_types(v, Variant::ARRAY, {"compiled_drops"}) ||
                !numeric_fields(v, {"hp","max_hp","shield","max_shield","x","y","shield_hit_at","shield_updated_at","shieldDelay","shieldRecovery","interference","jewelExplosion"}) ||
                !schema_nonnegative(v, {"max_hp","shield","max_shield","shieldDelay","shieldRecovery","interference","jewelExplosion","jewel_rolls","slot"}) ||
                int(v.get("armourType",0)) < 0 || int(v.get("armourType",0)) > 2 ||
                int(v.get("shieldType",0)) < 0 || int(v.get("shieldType",0)) > 2) return false;
            Array drops = v.get("compiled_drops", Array());
            for (int j = 0; j < drops.size(); ++j) {
                if (Variant(drops[j]).get_type() != Variant::DICTIONARY) return false;
                Dictionary drop = drops[j];
                if (!schema_required(drop, {"chance","amount","base","resource"}) ||
                    !numeric_fields(drop, {"chance","amount","base"}) || !schema_integers(drop, {"resource"}) ||
                    !schema_nonnegative(drop, {"amount","base","resource"}) || !schema_probabilities(drop, {"chance"})) return false;
            }
        }
        for (int i = 0; i < weapons.size(); ++i) {
            if (Variant(weapons[i]).get_type() != Variant::DICTIONARY) return false;
            Dictionary v = weapons[i];
            if (!schema_required(v, {"kind"}) || !schema_integers(v, {"kind","type","slot","source","salvo","chain_count"}) ||
                !schema_types(v, Variant::BOOL, {"hostile"}) || !schema_types(v, Variant::VECTOR2, {"muzzle"}) ||
                !schema_types(v, Variant::DICTIONARY, {"entry","row"}) || !schema_types(v, Variant::ARRAY, {"transfer_effects"}) ||
                !numeric_fields(v, {"damage","factor","interval","remaining","speed","charge","ramp","maximum","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","secondary_probability"}) ||
                !schema_nonnegative(v, {"damage","factor","ramp","maximum","critical_multiplier","repeat_multiplier","chain_count","slot"}) ||
                !schema_probabilities(v, {"critical_rate","repeat_probability","secondary_probability"})) return false;
            int kind = v["kind"], source = v.get("source", -1);
            if (kind < 0 || kind > 3 || int(v.get("type",1)) < 0 || int(v.get("type",1)) > 2 || double(v.get("interval", 1.0)) <= 0 || double(v.get("speed", 720.0)) <= 0 ||
                int(v.get("salvo", 1)) < 1 || (bool(v.get("hostile", false)) && (source < 0 || source >= enemies.size()))) return false;
            Array effects = v.get("transfer_effects", Array());
            for (int j = 0; j < effects.size(); ++j)
                if (Variant(effects[j]).get_type() != Variant::DICTIONARY) return false;
        }
        for (int i = 0; i < defs.size(); ++i) {
            if (Variant(defs[i]).get_type() != Variant::DICTIONARY) return false;
            Dictionary v = defs[i];
            if (!schema_types(v, Variant::DICTIONARY, {"entry"}) || !schema_integers(v, {"layer","type"}) ||
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

    static bool checked_counter_bonus(Dictionary d, double count, bool incoming, double &bonus) {
        // Counter increments must still be exact in the native double representation.
        if (count < 0 || count >= 9007199254740992.0 || std::floor(count) != count) return false;
        double growth = incoming ? double(d.get("defence_counter_growth", d.get("counter_growth", 0.0)))
                                 : double(d.get("counter_growth", 0.0));
        double product = growth * double(d.get("counter_level", 0.0));
        if (!std::isfinite(product)) return false;
        if (product == 0) { bonus = 0; return true; }
        double value = product * std::log(std::max(1.0, count));
        if (!std::isfinite(value)) return false;
        value /= std::log(double(d.get("counter_log_base", 10.0)));
        if (!std::isfinite(value)) return false;
        value *= double(d.get("counter_round_scale", 10.0));
        if (!std::isfinite(value)) return false;
        bonus = std::round(value) / double(d.get("counter_round_scale", 10.0));
        return std::isfinite(bonus) && std::isfinite(1 + bonus) && 1 + bonus >= 0;
    }
    // Check the actual evaluation order: finite inputs alone do not imply finite intermediates.
    // Called only after schema validation, before clearing or assigning any live state.
    static bool configuration_arithmetic(Dictionary d, double attacks, double incoming, double retained_raw = 0, double retained_debt = 0) {
        double attack_bonus = 0, defence_bonus = 0;
        if (!checked_counter_bonus(d, attacks, false, attack_bonus) ||
            !checked_counter_bonus(d, incoming, true, defence_bonus)) return false;
        double next_attack_bonus = 0, next_defence_bonus = 0;
        if (!checked_counter_bonus(d, attacks + 1, false, next_attack_bonus) ||
            !checked_counter_bonus(d, incoming + 1, true, next_defence_bonus)) return false;
        attack_bonus = std::max(attack_bonus,next_attack_bonus);
        defence_bonus = std::max(defence_bonus,next_defence_bonus);
        double clock_value = d.get("clock", 0.0), defence_clock = d.get("defence_time", 0.0);
        if (!std::isfinite(clock_value - double(d.get("since_hit", 100.0))) ||
            !std::isfinite(clock_value + double(d.get("repeat_delay", .1)))) return false;
        double portions = std::ceil(double(d.get("deferred_duration",1.0)) / double(d.get("deferred_interval",1.0)));
        double first_at = defence_clock + double(d.get("deferred_interval",1.0)) - 1e-9;
        double first_tick = std::ceil(first_at / double(d.get("deferred_interval",1.0)));
        int64_t tick = d.get("deferred_tick",0);
        if (!std::isfinite(portions) || portions > std::numeric_limits<int>::max() ||
            !std::isfinite(first_at) || !std::isfinite(first_tick) || first_tick >= 9223372036854775808.0 ||
            tick == std::numeric_limits<int64_t>::max()) return false;
        int64_t first = std::max(tick + 1, int64_t(first_tick));
        if (first > std::numeric_limits<int64_t>::max() - int64_t(std::max(1.0,portions))) return false;
        Array weapons = d["weapons"], enemies = d["enemies"], defs = d.get("defences", Array());
        double raw_bound = retained_raw;
        for (int i = 0; i < weapons.size(); ++i) {
            Dictionary v = weapons[i];
            double raw = v.get("damage", 1.0);
            if (!bool(v.get("hostile", false))) {
                raw *= 1 + attack_bonus;
                if (!std::isfinite(raw)) return false;
                raw = std::ceil(raw);
            }
            raw *= double(v.get("factor", 1.0));
            if (!std::isfinite(raw)) return false;
            if (!bool(v.get("hostile", false)) && bool(d.get("scatter",false)) && int(v["kind"]) == 0)
                raw *= 1 + double(d.get("scatter_bonus", 0.0));
            if (!std::isfinite(raw)) return false;
            // Both branches must be representable, regardless of the next RNG draw.
            double critical = raw * double(v.get("critical_multiplier", d.get("critical_multiplier", 2.0)));
            if (!std::isfinite(critical)) return false;
            raw = std::max(raw, critical);
            double repeated = raw * double(v.get("repeat_multiplier", d.get("repeat_multiplier", 1.0)));
            if (!std::isfinite(repeated)) return false;
            raw = std::max(raw, repeated);
            double maximum = double(v.get("maximum",1.0)) + double(d.get("prism_bonus",0.0));
            if (!std::isfinite(maximum) || !std::isfinite(raw * std::max(1.0,maximum))) return false;
            raw_bound = std::max(raw_bound, std::max(raw, raw * std::max(1.0, maximum)));
            if (!std::isfinite(clock_value + double(v.get("remaining",int(v["kind"]) == 3 ? 0.0 : double(v.get("interval",1.0)))))) return false;
        }
        for (int i = 0; i < enemies.size(); ++i) {
            Dictionary v = enemies[i];
            double explosion = double(v["max_hp"]) * double(v.get("jewelExplosion",0.0));
            if (!std::isfinite(explosion)) return false;
            raw_bound = std::max(raw_bound, explosion);
            double recovery = double(v.get("max_shield",0.0)) * double(v.get("shieldRecovery",0.0));
            double elapsed = clock_value - double(v.get("shield_updated_at",clock_value));
            if (!std::isfinite(recovery) || !std::isfinite(elapsed) || !std::isfinite(recovery * std::max(0.0,elapsed)) ||
                !std::isfinite(double(v.get("shield",0.0)) + recovery * std::max(0.0,elapsed)) ||
                !std::isfinite(double(v.get("shield_hit_at",clock_value)) + double(v.get("shieldDelay",0.0)))) return false;
        }
        // Explosions use the receiving actor's interference too.
        for (int i = 0; i < enemies.size(); ++i) {
            Dictionary v = enemies[i];
            if (!std::isfinite(raw_bound * (1 + double(v.get("interference",0.0))))) return false;
        }
        double totals[2] = {}, losses[2] = {}, buffers[2] = {};
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i]; int layer = v.get("layer",0);
            double before_ceil = double(v.get("base",0.0)) * (1 + defence_bonus);
            double maximum = std::ceil(before_ceil) * double(v.get("factor",1.0));
            double supplied = v.get("maximum",0.0);
            if (!std::isfinite(before_ceil) || !std::isfinite(maximum) ||
                !std::isfinite(maximum * double(v.get("memory_cap",0.0))) ||
                !std::isfinite(supplied * double(v.get("memory_cap",0.0))) ||
                !std::isfinite(maximum * double(v.get("memory_heal",0.0))) ||
                !std::isfinite(maximum * double(v.get("rate",0.0))) ||
                !std::isfinite(maximum / (1 - double(v.get("deferred_fraction",0.0)))) ||
                !std::isfinite(defence_clock - double(v.get("last_hit",0.0))) ||
                !std::isfinite(double(v.get("last_hit",0.0)) + double(v.get("delay",0.0))) ||
                !std::isfinite(raw_bound * maximum)) return false;
            totals[layer] += maximum; losses[layer] += double(v.get("loss",0.0)); buffers[layer] += double(v.get("buffer",0.0));
            if (!std::isfinite(totals[layer]) || !std::isfinite(losses[layer]) || !std::isfinite(buffers[layer])) return false;
        }
        Dictionary debt = d.get("deferred",Dictionary()); Array keys = debt.keys();
        double debt_totals[2] = {retained_debt,retained_debt};
        for (int i = 0; i < keys.size(); ++i) {
            Dictionary payment = debt[keys[i]];
            debt_totals[0] += double(payment.get("shield",0.0)); debt_totals[1] += double(payment.get("armour",0.0));
            if (!std::isfinite(debt_totals[0]) || !std::isfinite(debt_totals[1])) return false;
        }
        return true;
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
    static double nonnegative(double a) {
        return std::max(0.0, a);
    }
    void shield(Actor &a, double at) {
        if (!a.live || a.max_shield <= 0)
            return;
        if (at <= a.shield_at) return; // Duplicate/boundary reads never rewind the ledger.
        double ready = a.hit_at + a.delay;
        double elapsed = nonnegative(at - ready) - nonnegative(a.shield_at - ready);
        if (elapsed > 0)
            a.shield = std::min(a.max_shield, a.shield + a.max_shield * a.recovery * elapsed);
        a.shield_at = at;
        a.view["shield"] = a.shield;
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
            double ac = std::abs(a.slot - 4.5), bc = std::abs(b.slot - 4.5);
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
        e.shot = f.view;
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
        f.view["dead"] = true;
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
                flight_rows[at] = flight_rows[flight_rows.size() - 1];
                flight_rows.remove_at(flight_rows.size() - 1);
            }
            f.lease.unref();
            f.instance.reset();
            f.view = Dictionary();
            free_flights.push_back(id);
        }
        retired.clear();
    }
    size_t birth(int wi, Handle target, std::shared_ptr<Instance> inst, double multiplier,
                 bool repeated = false, bool chain = false, Vector2 origin = Vector2()) {
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
        f.instance = inst;
        f.multiplier = multiplier;
        f.damage = inst->attack->damage * multiplier;
        f.repeated = repeated || inst->derived;
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
        m.kind = chain ? 2 : w.kind == 2 ? (w.hostile ? 3 : 1) : 0;
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
            int ordinal = int(event_serial % 2);
            double departure = (ordinal ? 1 : -1) * 12.0 * 3.14159265358979323846 / 180.0;
            Vector2 trial = axis(angle(m.direction) + departure);
            if (trial.y >= -0.12 || (from.x < 55 && trial.x < 0) || (from.x > 517 && trial.x > 0))
                departure = 0;
            m.direction = axis(angle(m.direction) + departure);
            m.last_aim = aim;
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
        f.view["damage"] = f.damage;
        f.view["dead"] = false;
        f.view["entry"] = w.entry;
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
            f.view["fixed_screen_step"] = (t->screen_point - w.screen_muzzle) / std::max(0.001, distance(from, aim));
            f.fixed_ray = true; f.ray_origin = w.screen_muzzle;
            f.ray_step = f.view["fixed_screen_step"]; f.launch_point = from;
            if (!f.beam && t->stationary_geometry) refresh_ray_contact(f, *t);
        }
        Dictionary context;
        context["source_id"] = w.hostile ? String("enemy:") + String::num_int64(actors[w.source.index].uid)
                               : w.entry.has("drone_id") ? String("drone:") + String(w.entry["drone_id"])
                                                         : String("module:") + String::num_int64(w.slot);
        context["trigger_depth"] = repeated || chain ? 1 : 0;
        f.view["combat_context"] = context;
        f.view["prism_tower"] = false;
        if (f.beam) {
            f.charge = w.charge;
            f.interval = w.interval;
            f.ramp = w.ramp;
            f.maximum = w.maximum;
            f.next_hit = f.charge >= 0 ? f.charge : f.interval;
            f.view["beam"] = true;
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
        retained_damage_bound = std::max(retained_damage_bound, f.damage * std::max(1.0,f.maximum));
        flight_rows.push_back(f.view);
        effect(chain ? 4 : 0, f, from, clock);
        return id;
    }
    void hit_enemy(Handle h, double raw, int type, const std::shared_ptr<Instance> &inst, bool trigger,
                   double at, int wi, bool chain_trigger = false) {
        Actor *a = resolve(h);
        if (!a) {
            ++stale_rejections;
            return;
        }
        shield(*a, at);
        a->hit_at = at;
        double incoming = raw * (1 + a->interference), absorbed = 0, damage = 0;
        if (a->shield > 0) {
            double factor = type == a->shield_type ? 1 - resistance : 1;
            absorbed = std::min(a->shield, std::max(1.0, incoming * factor));
            a->shield -= absorbed;
            incoming = factor > 0 ? nonnegative(incoming - absorbed / factor) : 0;
        }
        if (absorbed <= 0 || incoming > 0) {
            damage = std::max(1.0, std::ceil(incoming * (type == a->armour_type ? 1 - resistance : 1)));
            a->hp = nonnegative(a->hp - damage);
        }
        a->view["hp"] = a->hp;
        a->view["shield"] = a->shield;
        a->view["shield_hit_at"] = at;
        ++hit_count;
        Effect e;
        e.kind = 2;
        e.uid = a->uid;
        e.type = type;
        e.amount = damage + absorbed;
        e.time = at;
        e.critical = inst && inst->attack->critical;
        e.point = a->point;
        feedback.push_back(e);
        Vector2 origin = a->point;
        if (a->hp <= 0) {
            a->live = false;
            ++a->generation;
            ++dead_count;
            e.kind = 3;
            e.amount = 0;
            feedback.push_back(e);
            if (drop_rules) {
                for (int roll = 0; roll < a->jewel_rolls; ++roll)
                    if (rng->randf() < jewel_probability) {
                        Dictionary drop;
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
                        drop["uid"] = ++drop_uid;
                        drop["x"] = a->logical.x;
                        drop["y"] = a->logical.y + 40;
                        drop["source_uid"] = a->uid;
                        drop["age"] = 0.0;
                        drop["id"] = String::num_int64(rule.resource);
                        drop["amount"] = rule.amount;
                        drop["production_base"] = rule.base;
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
                        hit_enemy(handle(index), a->max_hp * a->explosion, type, {}, false, at, wi);
            for (size_t id : active) {
                Flight &f = flights[id];
                if (f.live && f.beam && f.hostile && f.source.index == h.index)
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
                if (inst->primary.index == h.index)
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
                        birth(wi, t, inst, raw / inst->attack->damage, false, true, origin);
            }
        }
        commit_final_wipe();
    }
    void commit_final_wipe() {
        if (!final_encounter || final_cleared || actors.empty()) return;
        for (const Actor &a : actors) if (a.live) return;
        final_cleared = true;
        // Completion is committed before any later boundary carrier can hit.
        for (size_t id : active) retire(id, false);
        while (!roots.empty()) roots.pop();
        while (!ejections.empty()) ejections.pop();
        while (!repeats.empty()) repeats.pop();
    }
    double counter_bonus(double count, bool incoming = false) const {
        double growth = incoming ? defence_counter_growth : counter_growth;
        return growth * counter_level == 0
                   ? 0
                   : std::round(growth * counter_level * std::log(std::max(1.0, count)) /
                                std::log(counter_log_base) * counter_round_scale) /
                         counter_round_scale;
    }
    double capacity(int layer) const {
        double total = 0;
        for (const Defence &d : defences)
            if (d.layer == layer)
                total += d.maximum;
        return total;
    }
    void reconcile_defence() {
        for (Defence &d : defences) {
            d.maximum = std::ceil(d.base * (1 + counter_bonus(incoming_counter, true))) * d.factor;
            d.loss = std::min(d.loss, d.maximum);
            d.buffer = std::min(d.buffer, d.maximum * d.memory_cap);
        }
        for (int layer = 0; layer < 2; ++layer) {
            double total = capacity(layer), missing = 0;
            for (const Defence &d : defences)
                if (d.layer == layer)
                    missing += d.loss;
            double health = layer == 0 ? player_shield : player_hp, expected = nonnegative(total - health),
                   delta = std::abs(expected - missing);
            bool increase = expected > missing;
            for (Defence &d : defences)
                if (d.layer == layer) {
                    double weight = increase ? (d.maximum - d.loss) / std::max(0.001, total - missing)
                                             : d.loss / std::max(0.001, missing);
                    d.loss = std::min(d.maximum, nonnegative(d.loss + (increase ? delta : -delta) * weight));
                }
        }
    }
    double protection(double amount, double &absorbed) {
        double rest = amount;
        for (Defence &d : defences) {
            if (rest <= 0)
                break;
            double paid = std::min(d.buffer, rest);
            d.buffer -= paid;
            rest -= paid;
            absorbed += paid;
            if (paid > 0)
                d.last_hit = defence_time;
        }
        return rest;
    }
    void publish_player() {
        player_row["armour"] = player_hp;
        player_row["shield"] = player_shield;
        for (size_t i = 0; i < defences.size(); ++i) {
            buffer_rows[int64_t(i)] = defences[i].buffer;
            loss_rows[int64_t(i)] = defences[i].loss;
            defence_time_rows[int64_t(i)] = defence_time - defences[i].last_hit;
        }
    }
    void incoming_effect(double loss, double absorbed, int type, double at, bool deferred = false) {
        Effect e;
        e.kind = 2;
        e.player = true;
        e.point = player_point;
        e.type = type;
        e.amount = deferred ? std::ceil(loss) : loss;
        e.absorbed = absorbed;
        e.time = at;
        feedback.push_back(e);
        ++hit_count;
        publish_player();
        if (player_hp <= 0)
            cancel();
    }
    void queue_debt(int layer, double amount) {
        if (amount <= 0)
            return;
        retained_debt_bound += amount;
        int portions = std::max(1, int(std::ceil(deferred_duration / deferred_interval)));
        int64_t first =
            std::max(deferred_tick + 1,
                     int64_t(std::ceil((defence_time + deferred_interval - 1e-9) / deferred_interval)));
        double unit = amount / portions, remaining = amount;
        for (int i = 0; i < portions; ++i) {
            double part = i == portions - 1 ? remaining : std::min(unit, remaining);
            remaining = nonnegative(remaining - part);
            debts[first + i][layer] += part;
        }
    }
    void pay_debt(double amount, double at) {
        double absorbed = 0, rest = protection(amount, absorbed), loss = 0;
        for (int layer = 0; layer < 2 && rest > 0; ++layer) {
            reconcile_defence();
            double total = 0;
            for (const Defence &d : defences)
                if (d.layer == layer)
                    total += nonnegative(d.maximum - d.loss);
            double taken = std::min(total, rest), body = 0;
            for (Defence &d : defences)
                if (d.layer == layer && total > 0) {
                    double part = taken * nonnegative(d.maximum - d.loss) / total;
                    d.loss += part;
                    body += part;
                    if (part > 0)
                        d.last_hit = defence_time;
                }
            double &hp = layer == 0 ? player_shield : player_hp;
            hp = taken >= total && total > 0 ? 0 : nonnegative(hp - body);
            loss += body;
            rest = nonnegative(rest - taken);
        }
        if (loss > 0 || absorbed > 0)
            incoming_effect(loss, absorbed, 0, at, true);
    }
    void recover(double dt, double begin_at) {
        if (!module_defence)
            return;
        double rest = dt;
        while (rest > 1e-9 && !stopped) {
            double piece = std::min(
                rest, std::min(memory_interval - memory_elapsed, deferred_interval - deferred_elapsed));
            double begin_defence = defence_time;
            defence_time += piece;
            memory_elapsed += piece;
            deferred_elapsed += piece;
            rest = nonnegative(rest - piece);
            // Integrate only the elapsed interval before paying its endpoint events.
            reconcile_defence();
            for (Defence &d : defences) {
                if (d.layer != 0) continue;
                double ready = d.last_hit + d.delay;
                double elapsed = nonnegative(defence_time - ready) - nonnegative(begin_defence - ready);
                double recovered = std::min(d.loss, d.maximum * d.rate * elapsed);
                d.loss = nonnegative(d.loss - recovered);
                player_shield = std::min(capacity(0), player_shield + recovered);
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
                            pay_debt(due[layer], begin_at + dt - rest);
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
                double &hp = d.layer == 0 ? player_shield : player_hp;
                double total = capacity(d.layer);
                if (memory && d.memory_heal > 0) {
                    double healing = d.maximum * d.memory_heal, recovered = std::min(d.loss, healing);
                    d.loss = nonnegative(d.loss - recovered);
                    hp = std::min(total, hp + recovered);
                    d.buffer =
                        std::min(d.maximum * d.memory_cap, d.buffer + nonnegative(healing - recovered));
                }
            }
            publish_player();
        }
    }
    void player_hit(double raw, int type, double at) {
        if (final_cleared) return;
        ++incoming_counter;
        last_incoming_at = at;
        if (!module_defence) {
            double factor = type == int(player_row.get("shield_type", 0)) ? 1 - resistance : 1;
            double absorbed = std::min(player_shield, std::max(1.0, raw * factor));
            player_shield -= absorbed;
            double left = factor > 0 ? nonnegative(raw - absorbed / factor) : 0;
            double damage =
                left > 0
                    ? std::ceil(left * (type == int(player_row.get("armour_type", 0)) ? 1 - resistance : 1))
                    : 0;
            player_hp = nonnegative(player_hp - damage);
            incoming_effect(damage + absorbed, 0, type, at);
            return;
        }
        reconcile_defence();
        double absorbed = 0, rest = protection(raw, absorbed);
        std::array<double, 2> payments{};
        std::array<bool, 2> deferred{};
        int shield_passes = 0;
        for (const Defence &d : defences)
            if (d.layer == 0)
                ++shield_passes;
        for (int pass = 0; pass <= shield_passes && rest > 0; ++pass) {
            int layer = pass < shield_passes ? 0 : 1;
            double total = 0;
            std::vector<double> available(defences.size(), 0);
            for (size_t i = 0; i < defences.size(); ++i)
                if (defences[i].layer == layer) {
                    available[i] = nonnegative(defences[i].maximum - defences[i].loss);
                    total += available[i];
                }
            if (total <= 0)
                continue;
            double incoming = rest, spent = 0;
            for (size_t i = 0; i < defences.size(); ++i) {
                Defence &d = defences[i];
                if (d.layer != layer || available[i] <= 0)
                    continue;
                double factor = type == d.type ? 1 - resistance : 1,
                       weighted = incoming * available[i] / total, part = weighted * factor,
                       payable = available[i] / (1 - d.deferred_fraction),
                       taken = layer == 1 ? part : std::min(payable, part),
                       delayed = taken * d.deferred_fraction, immediate = nonnegative(taken - delayed);
                if (layer == 0 && taken >= payable) {
                    immediate = available[i];
                    delayed = nonnegative(taken - immediate);
                }
                deferred[layer] = deferred[layer] || delayed > 0;
                queue_debt(layer, delayed);
                d.loss += immediate;
                payments[layer] += immediate;
                spent += factor <= 0 ? weighted : taken / factor;
                if (taken > 0)
                    d.last_hit = defence_time;
            }
            rest = nonnegative(incoming - spent);
        }
        double loss = 0;
        for (int layer = 0; layer < 2; ++layer) {
            double &hp = layer == 0 ? player_shield : player_hp;
            double paid = std::min(hp, deferred[layer] ? payments[layer] : std::ceil(payments[layer]));
            hp = nonnegative(hp - paid);
            loss += paid;
        }
        incoming_effect(loss, absorbed, type, at);
    }
    void launch(int wi, Handle target, std::shared_ptr<const Attack> a, double multiplier,
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
        if (w.kind == 2 && !w.hostile) {
            auto choices = targets(w.type, clock);
            for (int n = 0; n < w.salvo; ++n) {
                Timed pending{clock + n * ejection_gap, ++event_serial, 1, wi, n,
                              distribute && !choices.empty() ? choices[n % choices.size()] : target, a,
                              multiplier, inst};
                pending.damage_derived = repeated;
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
        if (!w.hostile)
            ++attack_counter;
        a->damage = (w.hostile ? w.base : std::ceil(w.base * (1 + counter_bonus(attack_counter)))) *
                    w.factor *
                    (!w.hostile && scatter && w.kind == 0 && candidates.size() == 1 ? 1 + scatter_bonus : 1);
        a->critical = !w.hostile && rng->randf() < w.crit_rate;
        if (a->critical)
            a->damage *= w.crit_multiplier;
        a->secondary = !w.hostile && rng->randf() < w.secondary_probability;
        a->repeats = !w.hostile && rng->randf() < w.repeat_probability;
        retained_damage_bound = std::max(retained_damage_bound,a->damage * retained_repeat_bound * retained_maximum_bound);
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
    void beam_periods(double dt, bool newborn, double &defence_at) {
        // Scheduled periods are ordered before boundary roots can query future shields.
        struct Period {
            double at, due;
            size_t id;
        };
        std::vector<Period> periods;
        const size_t begin_count = active.size();
        for (size_t n = 0; n < begin_count; ++n) {
            size_t id = active[n];
            Flight &f = flights[id];
            if (!f.live || !f.beam || ((f.born_step == step_serial) != newborn))
                continue;
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
            while (f.next_hit <= f.age + 1e-9) {
                periods.push_back({clock - f.age + f.next_hit, f.next_hit, id});
                f.next_hit += f.interval;
            }
            f.view["elapsed"] = f.age;
        }
        std::sort(periods.begin(), periods.end(), [&](const Period &a, const Period &b) {
            return a.at == b.at ? flights[a.id].serial < flights[b.id].serial : a.at < b.at;
        });
        for (const Period &p : periods) {
            if (stopped || final_cleared) break;
            recover(nonnegative(p.at - defence_at), defence_at);
            defence_at = std::max(defence_at, p.at);
            if (stopped) break;
            Flight &f = flights[p.id];
            if (!f.live || (f.hostile ? !resolve(f.source) : !resolve(f.target))) {
                if (f.live) retire(p.id);
                continue;
            }
            ++f.ticks;
            f.view["ticks"] = f.ticks;
            double duration = f.charge >= 0 ? (f.ticks - 1) * f.interval : p.due;
            double ramp = f.ramp > 0 ? std::clamp(duration / f.ramp, 0.0, 1.0) : 1;
            double raw = f.damage * (1 + (f.maximum - 1) * ramp);
            effect(6, f, f.aim, p.at);
            if (!f.hostile && f.instance->attack->critical) effect(9, f, f.aim, p.at);
            if (f.hostile)
                player_hit(raw, f.type, p.at);
            else
                hit_enemy(f.target, raw, f.type, f.instance, !f.repeated, p.at, f.weapon, true);
            if (!final_cleared && f.ticks == 1 && !f.hostile && !f.repeated && f.instance->attack->secondary) {
                auto candidates = targets(f.type, p.at);
                for (Handle h : candidates)
                    if (h.index != f.target.index) {
                        Vector2 target_position = actors[h.index].point;
                        int64_t target_uid = actors[h.index].uid;
                        hit_enemy(h, raw, f.type, f.instance, false, p.at, f.weapon);
                        Effect secondary;
                        secondary.kind = 8;
                        secondary.time = p.at;
                        secondary.point = f.aim;
                        secondary.target_point = target_position;
                        secondary.target_uid = target_uid;
                        secondary.type = f.type;
                        feedback.push_back(secondary);
                        break;
                    }
            }
            if (!final_cleared && f.ticks == 1 && !f.repeated && f.instance->attack->repeats) {
                Timed pending{p.at + repeat_delay,
                              ++event_serial,
                              2,
                              f.weapon,
                              0,
                              f.target,
                              f.instance->attack,
                              weapons[f.weapon].repeat_multiplier};
                pending.owner_flight = p.id;
                pending.owner_generation = f.generation;
                repeats.push(pending);
            }
        }
    }
    void segment(double dt, bool frame_boundary) {
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
        beam_periods(dt, false, defence_at);
        if (final_cleared && !stopped) recover(nonnegative(clock - defence_at), defence_at);
        if (stopped || final_cleared) { compact(); executing = false; return; }
        recover(nonnegative(clock - defence_at), defence_at);
        defence_at = clock;
        if (stopped) { compact(); executing = false; return; }
        while (frame_boundary && !repeats.empty() && repeats.top().at <= clock + 1e-9) {
            Timed q = repeats.top();
            repeats.pop();
            if (q.owner_flight != SIZE_MAX &&
                (q.owner_flight >= flights.size() || !flights[q.owner_flight].live ||
                 flights[q.owner_flight].generation != q.owner_generation))
                continue;
            auto t = targets(weapons[q.weapon].type, clock);
            if (!t.empty()) {
                ++root_attacks;
                ++attack_counter;
                launch(q.weapon, t.front(), q.attack, q.multiplier, true, true, q.owner_flight == SIZE_MAX ? -1 : flights[q.owner_flight].maximum);
            }
        }
        std::vector<Timed> reschedule;
        while (!roots.empty() && !final_cleared && roots.top().at <= clock + 1e-9) {
            Timed q = roots.top();
            roots.pop();
            primary(q.weapon);
            q.at = clock + weapons[q.weapon].interval;
            if (!final_cleared && weapons[q.weapon].kind != 3)
                reschedule.push_back(q);
        }
        if (!final_cleared) for (const Timed &q : reschedule)
            roots.push(q);
        while (!ejections.empty() && ejections.top().at <= clock + 1e-9) {
            Timed q = ejections.top();
            ejections.pop();
            if (!resolve(q.target)) {
                auto t = targets(weapons[q.weapon].type, clock);
                if (t.empty())
                    continue;
                q.target = t.front();
            }
            birth(q.weapon, q.target, q.instance ? q.instance : instance(q.attack), q.multiplier,
                  q.damage_derived);
        }
        beam_periods(0.0, true, defence_at);
        if (stopped || final_cleared) { compact(); executing = false; return; }
        const size_t motion_count = active.size();
        for (size_t n = 0; n < motion_count && !stopped; ++n) {
            size_t id = active[n];
            Flight &f = flights[id];
            if (!f.live || f.beam || f.born_step >= step_serial)
                continue;
            ++physics_visits;
            Motion &m = f.lease->motion();
            Actor *t = resolve(f.target);
            Vector2 aim = f.hostile ? player_point : t ? t->point : m.last_aim;
            if (!f.hostile && !t) {
                f.view["target"] = Dictionary();
            }
            bool impact = false;
            if (m.kind == 1) {
                m.age += dt;
                if (t && m.age > lifetime) {
                    retire(id, 1);
                    continue;
                }
                double progress = std::clamp((m.age - ignition) / (cruise_at - ignition), 0.0, 1.0);
                progress = progress * progress * (3 - 2 * progress);
                m.speed = launch_speed + (f.cruise_speed - launch_speed) * progress;
                if (t) {
                    m.orphan = 0;
                    m.last_aim = aim;
                    double old = angle(m.direction), wanted = angle(aim - position(m));
                    double change = std::remainder(wanted - old, 6.28318530717958647692);
                    double range = distance(position(m), aim);
                    if (range < brake_range && std::abs(change) > brake_angle)
                        m.speed = std::min(m.speed, std::max(min_speed, range * turn_rate * brake_factor));
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
                        continue;
                    }
                }
            } else {
                if (t || f.hostile) {
                    Vector2 delta = aim - position(m);
                    if (f.chain || m.kind == 3) {
                        // Enemy missiles retain their table speed and track the current player point.
                        m.direction = unit(delta);
                        impact = distance(position(m), aim) <= m.speed * dt;
                    } else {
                        if (!f.hostile && t && f.fixed_ray) {
                            const double progress = (position(m) - f.launch_point).dot(m.direction);
                            if (t->stationary_geometry && f.contact_revision != t->geometry_revision)
                                refresh_ray_contact(f, *t);
                            // The birth ray is a conservative far-contact gate, not a future hit.
                            // Keep the exact segment predicate at contact, preserving float rounding,
                            // impact coordinates, born_step and active-order damage settlement.
                            const double margin = std::max(1.0, std::abs(f.contact_distance) * 1e-4);
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
                    hit_enemy(f.target, f.damage, f.type, f.instance, !f.chain && !f.repeated, clock, f.weapon, !f.chain);
                retire(id);
                continue;
            }
            Vector2 move = m.direction * m.speed * dt;
            m.x += move.x;
            m.y += move.y;
            if (m.x < -32 || m.x > 604 || m.y < -32 || m.y > 776)
                retire(id);
        }
        for (size_t id : active) {
            Flight &f = flights[id];
            if (f.live && f.beam && (f.hostile ? !resolve(f.source) : !resolve(f.target)))
                retire(id);
        }
        for (Actor &a : actors)
            shield(a, clock);
        compact();
        executing = false;
    }

  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("configure", "descriptor"), &SpaceCombatKernel::configure);
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
        ClassDB::bind_method(D_METHOD("enemy_views"), &SpaceCombatKernel::enemy_views);
        ClassDB::bind_method(D_METHOD("buffer_view"), &SpaceCombatKernel::buffer_view);
        ClassDB::bind_method(D_METHOD("deferred_total"), &SpaceCombatKernel::deferred_total);
        ClassDB::bind_method(D_METHOD("rng_source"), &SpaceCombatKernel::rng_source);
        ClassDB::bind_method(D_METHOD("exit_state"), &SpaceCombatKernel::exit_state);
        ClassDB::bind_method(D_METHOD("export_handoff"), &SpaceCombatKernel::export_handoff);
        ClassDB::bind_method(D_METHOD("commit_handoff", "revision"), &SpaceCombatKernel::commit_handoff);
        ClassDB::bind_method(D_METHOD("loss_view"), &SpaceCombatKernel::loss_view);
        ClassDB::bind_method(D_METHOD("defence_time_view"), &SpaceCombatKernel::defence_time_view);
        ClassDB::bind_method(D_METHOD("projectile_views"), &SpaceCombatKernel::projectile_views);
        ClassDB::bind_method(D_METHOD("player_view"), &SpaceCombatKernel::player_view);
        ClassDB::bind_method(D_METHOD("take_feedback"), &SpaceCombatKernel::take_feedback);
        ClassDB::bind_method(D_METHOD("actor_handle", "uid"), &SpaceCombatKernel::actor_handle);
        ClassDB::bind_method(D_METHOD("hit_handle", "handle", "raw", "type"), &SpaceCombatKernel::hit_handle);
        ClassDB::bind_method(D_METHOD("receive_player_hit", "raw", "type"),
                             &SpaceCombatKernel::receive_player_hit);
        ClassDB::bind_method(D_METHOD("cancel"), &SpaceCombatKernel::cancel);
        ClassDB::bind_method(D_METHOD("metrics"), &SpaceCombatKernel::metrics);
        ClassDB::bind_method(D_METHOD("cooldown_remaining", "slot", "source_uid"),
                             &SpaceCombatKernel::cooldown_remaining, DEFVAL(int64_t(-1)));
    }

  public:
    void retain_configuration_bounds(bool reset = false) {
        if (reset) {
            retained_damage_bound = retained_debt_bound = retained_explosion_bound = 0;
            retained_repeat_bound = retained_maximum_bound = retained_interference_bound = 1;
            retained_min_interval = std::numeric_limits<double>::infinity();
            retained_salvo_bound = 1; retained_chain_bound = 0;
            retained_drop_bound = retained_recovery_bound = retained_shield_bound = retained_shield_elapsed = 0;
            envelope_clock = clock;
            for (const auto &payment : debts)
                retained_debt_bound += payment.second[0] + payment.second[1];
        }
        for (const Weapon &w : weapons) {
            retained_salvo_bound = std::max(retained_salvo_bound,w.salvo);
            retained_chain_bound = std::max(retained_chain_bound,std::max(w.chain_count,prism_count));
            retained_min_interval = std::min(retained_min_interval,w.interval);
            retained_repeat_bound = std::max(retained_repeat_bound,w.repeat_multiplier);
            retained_maximum_bound = std::max(retained_maximum_bound,w.maximum + prism_bonus);
        }
        if (reset) for (const Actor &a : actors) {
            retained_interference_bound = std::max(retained_interference_bound,1 + a.interference);
            retained_explosion_bound = std::max(retained_explosion_bound,a.max_hp * a.explosion);
            retained_drop_bound += double(a.jewel_rolls) + double(a.drops.size());
            retained_recovery_bound = std::max(retained_recovery_bound,a.max_shield * a.recovery);
            retained_shield_bound = std::max(retained_shield_bound,std::max(a.shield,a.max_shield));
            retained_shield_elapsed = std::max(retained_shield_elapsed,std::max(0.0,clock-a.shield_at));
        }
    }
    bool can_advance(double seconds) const {
        if (!admitted || stopped || executing || !std::isfinite(seconds) || seconds <= 0 ||
            !std::isfinite(clock + seconds) || !std::isfinite(defence_time + seconds)) return false;
        const double exact_limit = 9007199254740992.0;
        // Normal roots reschedule after processing. Owned beams can retire/restart once
        // per segment. Every extra segment needs an existing or newly ejected missile.
        double normal = double(roots.size()) * (1 + std::ceil(seconds / retained_min_interval));
        double segments = 1 + double(ejections.size()) + (normal + double(repeats.size())) * retained_salvo_bound;
        double root_bound = normal + (double(roots.size()) + double(weapons.size())) * segments;
        double copies = 3.0 * retained_salvo_bound * (std::max(1.0,double(actors.size())) + retained_chain_bound);
        double carriers = double(active.size()) + double(ejections.size()) + (root_bound + double(repeats.size())) * copies;
        double periods = carriers * (segments + 1 + std::ceil(seconds / retained_min_interval));
        // Repeated beams cannot repeat again; secondary shares the primary instance.
        double births = carriers + periods * copies;
        double hits = births * std::max(1.0,double(actors.size())) + double(actors.size()) * double(actors.size());
        double attack_end = attack_counter + root_bound + double(repeats.size()) + periods;
        double incoming_end = incoming_counter + hits;
        double events = births + hits + root_bound + periods + retained_drop_bound;
        if (!std::isfinite(events) || events >= exact_limit || attack_end >= exact_limit || incoming_end >= exact_limit ||
            double(event_serial) + events >= exact_limit || double(flight_serial) + births >= exact_limit ||
            double(instance_serial) + births >= exact_limit || double(attack_serial) + root_bound >= exact_limit ||
            double(step_serial) + segments >= exact_limit) return false;
        auto bonus = [&](double count, double growth, double &out) {
            double product = growth * counter_level;
            if (!std::isfinite(product)) return false;
            double value = product * std::log(std::max(1.0,count));
            if (!std::isfinite(value)) return false;
            value /= std::log(counter_log_base);
            if (!std::isfinite(value)) return false;
            value *= counter_round_scale;
            if (!std::isfinite(value)) return false;
            out = std::round(value) / counter_round_scale;
            return std::isfinite(out) && 1 + out >= 0;
        };
        double attack_bonus = 0, defence_bonus = 0, current_attack_bonus = 0, current_defence_bonus = 0;
        if (!bonus(attack_counter,counter_growth,current_attack_bonus) || !bonus(incoming_counter,defence_counter_growth,current_defence_bonus)) return false;
        if (!bonus(attack_end,counter_growth,attack_bonus) || !bonus(incoming_end,defence_counter_growth,defence_bonus)) return false;
        attack_bonus = std::max(attack_bonus,current_attack_bonus);
        defence_bonus = std::max(defence_bonus,current_defence_bonus);
        double recovery_elapsed = retained_shield_elapsed + clock - envelope_clock + seconds;
        if (!std::isfinite(recovery_elapsed) || !std::isfinite(retained_recovery_bound*recovery_elapsed) ||
            !std::isfinite(retained_shield_bound + retained_recovery_bound*recovery_elapsed)) return false;
        double raw = std::max(retained_damage_bound,retained_explosion_bound);
        for (const Weapon &w : weapons) {
            double base = w.hostile ? w.base : w.base * (1 + attack_bonus);
            if (!std::isfinite(base)) return false;
            double damage = (w.hostile ? base : std::ceil(base)) * w.factor;
            if (!std::isfinite(damage)) return false;
            damage *= std::max(1.0,1 + scatter_bonus);
            if (!std::isfinite(damage)) return false;
            damage *= std::max(1.0,w.crit_multiplier);
            if (!std::isfinite(damage)) return false;
            damage *= retained_repeat_bound;
            if (!std::isfinite(damage)) return false;
            damage *= retained_maximum_bound;
            if (!std::isfinite(damage)) return false;
            raw = std::max(raw,damage);
        }
        raw *= retained_interference_bound;
        double new_damage = raw * hits;
        double total_damage = retained_debt_bound + new_damage;
        if (!std::isfinite(raw) || !std::isfinite(total_damage) || !std::isfinite(retained_debt_bound + total_damage) ||
            (resistance < 1 && !std::isfinite(raw / (1 - resistance)))) return false;
        double totals[2] = {}, buffers[2] = {}, losses[2] = {};
        for (const Defence &d : defences) {
            double before_ceil = d.base * (1 + defence_bonus);
            double maximum = std::ceil(before_ceil) * d.factor;
            double cap = maximum * d.memory_cap, heal = maximum * d.memory_heal;
            double recovery = maximum * d.rate;
            if (!std::isfinite(before_ceil) || !std::isfinite(maximum) || !std::isfinite(cap) || !std::isfinite(heal) ||
                !std::isfinite(recovery) || !std::isfinite(recovery * seconds) || !std::isfinite(cap + heal) ||
                !std::isfinite(d.buffer + heal) || !std::isfinite(d.loss + total_damage) ||
                !std::isfinite(maximum / (1 - d.deferred_fraction)) || !std::isfinite(total_damage * maximum)) return false;
            totals[d.layer] += maximum; buffers[d.layer] += cap; losses[d.layer] += d.loss;
            if (!std::isfinite(totals[d.layer]) || !std::isfinite(buffers[d.layer]) || !std::isfinite(losses[d.layer])) return false;
        }
        double periods_due = std::ceil(seconds / deferred_interval) + 1;
        double portions = std::max(1.0,std::ceil(deferred_duration / deferred_interval));
        if (!std::isfinite(periods_due + portions) || double(deferred_tick) + periods_due + portions >= 9223372036854775808.0 ||
            !std::isfinite((defence_time + seconds + deferred_interval) / deferred_interval) ||
            std::ceil((defence_time + seconds + deferred_interval) / deferred_interval) + portions >= 9223372036854775808.0 ||
            double(drop_uid) + retained_drop_bound >= 9223372036854775808.0) return false;
        return true;
    }
    bool configure(Dictionary d) {
        if (!configuration_schema(d) || !configuration_arithmetic(d, double(d.get("attack_counter",0.0)), double(d.get("incoming_counter",0.0)))) return false;
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
        flight_rows = Array();
        flight_rows.set_typed(Variant::DICTIONARY, StringName(), Variant());
        admitted = false;
        stopped = false;
        final_encounter = d.get("final_encounter", false); final_cleared = false;
        ++encounter_generation;
        if (!finite_descriptor(d) || !d.has("player") || !d.has("enemies") || !d.has("weapons") ||
            !Array(d.get("unsupported_rules", Array())).is_empty())
            return false;
        if (!numeric_fields(d["player"], {"armour", "shield"}))
            return false;

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
        player_hp = player_row["armour"];
        player_shield = player_row["shield"];
        if (!std::isfinite(player_hp) || !std::isfinite(player_shield))
            return false;
        rng.instantiate();
        rng->set_state(int64_t(d.get("rng_state", 1)));
        crit_rate = d.get("critical_rate", 0.0);
        crit_multiplier = d.get("critical_multiplier", 2.0);
        repeat_probability = d.get("repeat_probability", 0.0);
        repeat_multiplier = d.get("repeat_multiplier", 1.0);
        repeat_delay = d.get("repeat_delay", 0.1);
        secondary_probability = d.get("secondary_probability", 0.0);
        chain_count = d.get("chain_count", 0);
        scatter = d.get("scatter", false);
        scatter_bonus = d.get("scatter_bonus", 0.0);
        prism_count = d.get("prism_count", 0);
        prism_bonus = d.get("prism_bonus", 0.0);
        Array values = d["enemies"];
        for (int i = 0; i < values.size(); ++i) {
            Dictionary v = values[i];
            if (!numeric_fields(v, {"hp", "max_hp", "shield", "max_shield"}))
                return false;
            Actor a;
            a.generation = encounter_generation;
            a.uid = v["uid"];
            a.view = v.duplicate(true);
            a.hp = v["hp"];
            a.live = a.hp > 0;
            a.max_hp = v["max_hp"];
            a.shield = v.get("shield", 0.0);
            a.max_shield = v.get("max_shield", 0.0);
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
            Array drops = v.get("compiled_drops", Array());
            for (int index = 0; index < drops.size(); ++index) {
                Dictionary row = drops[index];
                a.drops.push_back({double(row["chance"]), double(row["amount"]), double(row["base"]),
                                   int(row["resource"])});
            }
            if (!std::isfinite(a.hp))
                return false;
            actors.push_back(a);
            actor_rows.push_back(a.view);
        }
        Array wvalues = d["weapons"];
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
                if (source < 0 || source >= int(actors.size()))
                    return false;
                w.source = handle(source);
            }
            w.interval = v.get("interval", 1.0);
            if (w.interval <= 0 || double(v.get("speed", 720.0)) <= 0 || double(v.get("damage", 1.0)) < 0 ||
                int(v.get("salvo", 1)) < 1)
                return false;
            w.remaining = v.get("remaining", w.kind == 3 ? 0.0 : w.interval);
            w.base = v.get("damage", 1.0);
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
            w.muzzle = v.get("muzzle", Vector2(286, 520));
            w.entry = Dictionary(v.get("entry", Dictionary())).duplicate(true);
            w.row = Dictionary(v.get("row", Dictionary())).duplicate(true);
            w.birth = birth_config(w, v, d.get("repeat_delay", 0.5));
            weapons.push_back(w);
            roots.push({clock + w.remaining, ++event_serial, 0, i});
        }
        attack_counter = d.get("attack_counter", 0.0);
        incoming_counter = d.get("incoming_counter", 0.0);
        counter_growth = d.get("counter_growth", 0.0);
        defence_counter_growth = d.get("defence_counter_growth", counter_growth);
        counter_level = d.get("counter_level", 0.0);
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
            a.base = v.get("base", 0.0);
            a.factor = v.get("factor", 1.0);
            a.maximum = v.get("maximum", 0.0);
            a.loss = v.get("loss", 0.0);
            a.buffer = v.get("buffer", 0.0);
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
            debts[int64_t(debt_keys[i])] = {double(payment.get("shield", 0.0)), double(payment.get("armour", 0.0))};
        }
        module_defence = !defences.empty();
        admitted = (!bool(d.get("requires_module_defense", false)) || module_defence) &&
                   (!bool(d.get("requires_drop_rules", false)) || drop_rules);
        retain_configuration_bounds(true);
        publish_player();
        root_attacks = hit_count = dead_count = stale_rejections = physics_visits = 0;
        ballistic_checks = ballistic_skips = ballistic_ray_queries = 0;
        return admitted;
    }
    bool can_update_configuration(Dictionary d) const {
        if (!admitted || stopped || executing || !configuration_schema(d) ||
            !configuration_arithmetic(d, attack_counter, incoming_counter, retained_damage_bound, retained_debt_bound)) return false;
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
            if (!numeric_fields(v, {"kind","type","slot","source","damage","factor","interval","speed","salvo","charge","ramp","maximum","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","chain_count","secondary_probability"}) || double(v.get("interval", 0)) <= 0 || double(v.get("speed", 0)) <= 0 || double(v.get("damage", -1)) < 0 || double(v.get("factor", 1.0)) < 0) return false;
            if (int(v.get("kind", -1)) != w.kind || int(v.get("type", -1)) != w.type || int(v.get("slot", -1)) != w.slot || bool(v.get("hostile", false)) != w.hostile || int(v.get("source", -2)) != (w.hostile ? int(w.source.index) : -1)) return false;
            Dictionary entry = v.get("entry", Dictionary());
            if (entry.get("key", "") != w.entry.get("key", "") || entry.get("name", "") != w.entry.get("name", "") || entry.get("drone_id", "") != w.entry.get("drone_id", "")) return false;
            if (Array(v.get("transfer_effects", Array())) != w.birth->effects || int(v.get("chain_count", 0)) != w.chain_count || double(v.get("repeat_probability", 0)) != w.repeat_probability || double(v.get("secondary_probability", 0)) != w.secondary_probability) return false;
        }
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i]; const Defence &a = defences[i];
            if (!numeric_fields(v, {"layer","type","base","factor","maximum","loss","buffer","last_hit","delay","rate","memory_heal","memory_cap","deferred_fraction"}) || double(v.get("base", -1)) < 0 || double(v.get("factor", -1)) < 0) return false;
            if (int(v.get("layer", -1)) != a.layer || int(v.get("type", -1)) != a.type || double(v.get("memory_heal",0)) != a.memory_heal || double(v.get("memory_cap",0)) != a.memory_cap || double(v.get("deferred_fraction",0)) != a.deferred_fraction) return false;
        }
        if (double(d.get("counter_growth",0)) != counter_growth || double(d.get("defence_counter_growth",0)) != defence_counter_growth || double(d.get("counter_level",0)) != counter_level || double(d.get("repeat_delay",0)) != repeat_delay || bool(d.get("scatter",false)) != scatter || int(d.get("prism_count",0)) != prism_count) return false;
        for (const auto &field : std::initializer_list<std::pair<const char *,double>>{
            {"counter_log_base",counter_log_base},{"counter_round_scale",counter_round_scale},
            {"memory_interval",memory_interval},{"deferred_interval",deferred_interval},{"deferred_duration",deferred_duration},
            {"resistance",resistance},{"chain_speed",chain_speed},{"ejection_gap",ejection_gap},{"launch_speed",launch_speed},
            {"turn_rate",turn_rate},{"ignition",ignition},{"seek",seek},{"cruise_at",cruise_at},{"lifetime",lifetime},
            {"orphan_lifetime",orphan_lifetime},{"brake_range",brake_range},{"brake_angle",brake_angle},
            {"min_speed",min_speed},{"brake_factor",brake_factor},{"hit_radius",hit_radius}})
            if (double(d.get(field.first,field.second)) != field.second) return false;
        Dictionary player = d.get("player", Dictionary());
        return player.has("armour") && player.has("shield") && numeric_fields(player, {"armour","shield"}) && double(player["armour"]) >= 0 && double(player["shield"]) >= 0;
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
        if (!can_update_configuration(d) || double(Dictionary(d["player"])["armour"]) <= 0) return false;
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
        if (!can_refit_configuration(d)) return false;
        apply_configuration(d, true);
        return true;
    }
    bool update_configuration(Dictionary d) {
        if (!can_update_configuration(d)) return false;
        apply_configuration(d, false);
        return true;
    }
    void apply_configuration(Dictionary d, bool refit) {
        ++refit_epoch;
        // Both entrypoints validate before touching fields or published rows.
        Array rows = d["weapons"], defs = d["defences"];
        for (int i = 0; i < rows.size(); ++i) {
            Dictionary v = rows[i];
            Weapon &w = weapons[i];
            w.kind = v["kind"];
            w.type = v["type"];
            w.base = v["damage"];
            w.factor = v.get("factor", 1.0);
            w.interval = v["interval"];
            w.speed = v["speed"];
            w.salvo = v.get("salvo", 1);
            w.charge = v.get("charge", -1.0);
            w.ramp = v.get("ramp", 1.0);
            w.maximum = v.get("maximum", 1.0);
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
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i];
            Defence &a = defences[i];
            a.entry = Dictionary(v.get("entry", Dictionary())).duplicate(true);
            a.layer = v["layer"];
            a.base = v["base"];
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
        prism_count = d.get("prism_count", prism_count);
        prism_bonus = d.get("prism_bonus", prism_bonus);
        Dictionary player = d["player"];
        player_hp = player["armour"];
        player_shield = player["shield"];
        if (refit) {
            for (Defence &a : defences) a.loss = 0;
            Array enemies = d["enemies"];
            for (int i = 0; i < enemies.size(); ++i) {
                Dictionary v = enemies[i]; Array drops = v["compiled_drops"];
                for (int j = 0; j < drops.size(); ++j) {
                    Dictionary row = drops[j];
                    actors[i].drops[j].base = row["base"];
                    actors[i].drops[j].amount = row["amount"];
                }
                actors[i].view["compiled_drops"] = drops.duplicate(true);
            }
        }
        retain_configuration_bounds();
        reconcile_defence();
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
        for (int i = 0; i < int(weapons.size()) && i < muzzles.size(); ++i)
            weapons[i].screen_muzzle = muzzles[i];
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
                f.contact_distance = std::max(0.0, along);
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
            if (along >= 0 && along <= 1 && side >= 0 && side <= 1) first = std::min(first, along);
        }
        return inside ? 0.0 : first;
    }
    void input_player_point(Vector2 point) {
        player_point = point;
    }
    void input_geometry(PackedVector2Array points, PackedVector2Array muzzles) {
        for (int i = 0; i < points.size() && i < int(actors.size()); ++i)
            actors[i].point = points[i];
        for (int i = 0; i < muzzles.size() && i < int(weapons.size()); ++i)
            weapons[i].muzzle = muzzles[i];
    }
    bool advance(double seconds) {
        if (!can_advance(seconds)) return false;
        double end = clock + seconds;
        while (clock + 1e-9 < end && (!stopped || final_cleared)) {
            double next = end;
            if (!ejections.empty() && ejections.top().at > clock + 1e-9)
                next = std::min(next, ejections.top().at);
            segment(next - clock, next == end);
        }
        // The session consumes this whole logical step; terminal death freezes defence,
        // while consuming any tail after an ejection split without more battle events.
        if (stopped) clock = end;
        return true;
    }
    Dictionary export_handoff() const {
        Dictionary out;
        if (!admitted || (stopped && !final_cleared) || executing) return out;
        out["schema"] = 1; out["revision"] = int64_t(step_serial); out["clock"] = clock;
        out["player"] = player_row; out["enemies"] = actor_rows;
        out["buffers"] = buffer_rows; out["losses"] = loss_rows; out["defence_times"] = defence_time_rows;
        // Eligible beam deadlines can exceed the segment clock by rounding epsilon.
        out["since_hit"] = nonnegative(clock - last_incoming_at);
        out["defence_time"] = defence_time; out["memory_elapsed"] = memory_elapsed;
        out["deferred_elapsed"] = deferred_elapsed; out["deferred_tick"] = deferred_tick;
        out["attack_counter"] = attack_counter; out["incoming_counter"] = incoming_counter;
        out["projectile_serial"] = int64_t(flight_serial); out["attack_serial"] = int64_t(attack_serial);
        out["instance_serial"] = int64_t(instance_serial); out["drop_uid"] = drop_uid; out["rng"] = rng;
        Dictionary deferred;
        for (const auto &item : debts) { Dictionary due; due["shield"] = item.second[0]; due["armour"] = item.second[1]; deferred[item.first] = due; }
        out["deferred"] = deferred;
        std::map<uint64_t, Dictionary> attack_rows;
        auto attack_view = [&](const std::shared_ptr<const Attack> &a) {
            auto found = attack_rows.find(a->id); if (found != attack_rows.end()) return found->second;
            Dictionary row; row["id"] = int64_t(a->id); row["damage"] = a->damage;
            row["critical"] = a->critical; row["critical_bonus_applied"] = a->critical;
            row["secondary"] = a->secondary; row["secondary_used"] = true; row["repeats_queued"] = true;
            row["weapon"] = a->birth->weapon.duplicate(true); row["effects"] = a->birth->effects;
            row["repeat_plan"] = Array(); row["source_slot"] = a->birth->slot;
            attack_rows[a->id] = row; return row;
        };
        // Cold transfer copies typed mutable state without mutating live views.
        std::map<uint64_t, Dictionary> instance_rows;
        auto instance_view = [&](const std::shared_ptr<Instance> &inst) {
            if (!inst) return Dictionary();
            auto found = instance_rows.find(inst->id); if (found != instance_rows.end()) return found->second;
            Dictionary row = inst->view.duplicate();
            Dictionary chain = Dictionary(inst->view["chain"]).duplicate();
            chain["count"] = inst->count; chain["used"] = inst->chain_used;
            chain["beam"] = inst->beam; chain["ended"] = inst->ended;
            if (inst->beam) chain["primary"] = inst->primary.index < actors.size() ? actors[inst->primary.index].view : Dictionary();
            row["chain"] = chain; instance_rows[inst->id] = row; return row;
        };
        Array records;
        for (size_t id : active) {
            const Flight &f = flights[id]; if (!f.live) continue;
            Dictionary row; row["view"] = f.view; row["weapon_index"] = f.weapon;
            row["snapshot"] = attack_view(f.instance->attack); row["instance"] = instance_view(f.instance);
            row["instance_derived"] = f.repeated; row["damage"] = f.damage;
            row["multiplier"] = f.multiplier; row["age"] = f.age; row["next_hit"] = f.next_hit;
            row["ticks"] = f.ticks; row["charge"] = f.charge; row["interval"] = f.interval;
            row["ramp"] = f.ramp; row["maximum"] = f.maximum; row["cruise_speed"] = f.cruise_speed;
            row["native_index"] = int64_t(id); row["native_generation"] = int64_t(f.generation);
            row["beam"] = f.beam; row["chain"] = f.chain; row["repeated"] = f.repeated;
            row["hostile"] = f.hostile;
            const Motion &m = f.lease->motion(); row["position"] = position(m); row["direction"] = m.direction;
            row["speed"] = m.speed; row["motion_age"] = m.age; row["orphan_age"] = m.orphan; row["last_aim"] = m.last_aim;
            if (f.beam) {
                Dictionary snap = row["snapshot"], weapon = Dictionary(snap["weapon"]).duplicate(true);
                weapon["para2"] = f.maximum; snap["weapon"] = weapon;
                if (!f.repeated && f.ticks == 0) {
                    snap["secondary_used"] = false; snap["repeats_queued"] = false;
                    if (f.instance->attack->repeats) {
                        Dictionary plan; plan["depth"] = 1; plan["delay"] = f.instance->attack->birth->repeat_delay;
                        plan["factor"] = f.instance->attack->birth->repeat_multiplier; plan["parent"] = -1; plan["plan_index"] = 0;
                        Array plans; plans.push_back(plan); snap["repeat_plan"] = plans;
                    }
                }
            }
            records.push_back(row);
        }
        out["flights"] = records;
        Array due_roots; auto root_copy = roots;
        while (!root_copy.empty()) { auto q = root_copy.top(); root_copy.pop(); Dictionary row; row["weapon_index"] = q.weapon; row["remaining"] = nonnegative(q.at - clock); due_roots.push_back(row); }
        out["cooldowns"] = due_roots;
        auto export_queue = [&](auto queue) {
            Array rows;
            while (!queue.empty()) { auto q = queue.top(); queue.pop(); Dictionary row;
                row["weapon_index"] = q.weapon; row["due"] = q.at; row["remaining"] = nonnegative(q.at - clock);
                row["ordinal"] = q.ordinal; row["multiplier"] = q.multiplier;
                row["target"] = q.target.index < actors.size() ? actors[q.target.index].view : Dictionary();
                row["snapshot"] = attack_view(q.attack); row["instance"] = instance_view(q.instance); row["derived"] = q.damage_derived;
                row["owner_index"] = q.owner_flight == SIZE_MAX ? -1 : int64_t(q.owner_flight);
                row["owner_generation"] = int64_t(q.owner_generation); rows.push_back(row);
            }
            return rows;
        };
        out["ejections"] = export_queue(ejections); out["repeats"] = export_queue(repeats);
        return out;
    }
    bool commit_handoff(int64_t revision) {
        if (!admitted || (stopped && !final_cleared) || executing || revision != int64_t(step_serial)) return false;
        stopped = true; admitted = false;
        while (!roots.empty()) roots.pop(); while (!ejections.empty()) ejections.pop(); while (!repeats.empty()) repeats.pop();
        // Drop executor references only. Published rows/leases stay live for the
        // receiving Game and visual surface; no retire/dead/effect is emitted.
        flights.clear(); active.clear(); free_flights.clear(); retired.clear();
        flight_rows = Array(); actor_rows = Array(); actors.clear(); weapons.clear(); defences.clear(); debts.clear();
        return true;
    }
    Ref<RandomNumberGenerator> rng_source() const { return rng; }
    Dictionary exit_state() {
        Dictionary values, due;
        for (const auto &item : debts) {
            Dictionary payment; payment["shield"] = item.second[0]; payment["armour"] = item.second[1];
            due[item.first] = payment;
        }
        values["deferred"] = due; values["defence_time"] = defence_time;
        values["memory_elapsed"] = memory_elapsed; values["deferred_elapsed"] = deferred_elapsed; values["deferred_tick"] = deferred_tick;
        values["projectile_serial"] = int64_t(flight_serial); values["attack_serial"] = int64_t(attack_serial);
        values["instance_serial"] = int64_t(instance_serial); values["drop_uid"] = drop_uid;
        cancel(); debts.clear(); return values;
    }
    double deferred_total() const {
        double total = 0;
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
    Array projectile_views() const {
        return flight_rows;
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
            d["amount"] = e.amount;
            d["absorbed"] = e.absorbed;
            d["clock"] = e.time;
            d["position"] = e.point;
            d["direction"] = e.direction;
            d["target_position"] = e.target_point;
            d["target_uid"] = e.target_uid;
            if (!e.shot.is_empty())
                d["shot"] = e.shot;
            values.push_back(d);
        }
        feedback.clear();
        return values;
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
    bool hit_handle(PackedInt64Array value, double raw, int type) {
        if (value.size() != 2 || !admitted || stopped || !std::isfinite(raw) || raw < 0)
            return false;
        Handle h{uint32_t(value[0]), uint32_t(value[1])};
        if (!resolve(h)) {
            ++stale_rejections;
            return false;
        }
        ++refit_epoch;
        hit_enemy(h, raw, type, {}, false, clock, 0);
        compact();
        return true;
    }
    bool receive_player_hit(double raw, int type) {
        if (!admitted || stopped || !std::isfinite(raw) || raw < 0)
            return false;
        ++refit_epoch;
        player_hit(raw, type, clock);
        return true;
    }
    void cancel() {
        stopped = true;
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
