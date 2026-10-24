#include "combat_amount.h"
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
    static int64_t checked_increment(int64_t &value) {
        if(value==INT64_MAX) throw std::overflow_error("IntegerRangeExceeded"); return ++value;
    }
    static uint64_t checked_id(uint64_t &value) {
        if(value>=uint64_t(INT64_MAX)) throw std::overflow_error("IntegerRangeExceeded"); return ++value;
    }
    struct Handle {
        uint32_t index = UINT32_MAX, generation = 0;
    };
    struct DropRule {
        double chance = 0; CombatAmount amount = 0, base = 0;
        int resource = 0;
    };
    struct Actor {
        uint32_t generation = 1;
        int64_t uid = 0, guidance_layers = 0;
        uint64_t guidance_firsts = 0, guidance_reuses = 0, guidance_growth = 0, missile_hits = 0, derived_missile_hits = 0;
        double first_guidance_factor = 0, last_guidance_factor = 0, min_guidance_factor = 0, max_guidance_factor = 0;
        bool live = true;
        CombatAmount hp = 0, max_hp = 0, shield = 0, max_shield = 0;
        double delay = 0, recovery = 0, shield_at = 0,
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
        bool hostile = false, endless = false;
        Handle source;
        CombatAmount base = 1, factor = 1;
        double interval = 1, remaining = 1, speed = 30, charge = 0, ramp = 1,
               maximum = 1;
        int salvo = 1;
        double crit_rate = 0, crit_multiplier = 2, repeat_probability = 0, repeat_multiplier = 1,
               secondary_probability = 0;
        int chain_count = 0;
        Vector2 muzzle, screen_muzzle;
        PackedVector2Array presentation_muzzles; // Display inputs only; never used by combat.
        Dictionary entry, row;
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
        CombatAmount damage = 0;
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
        int weapon = -1, type = 0;
        Handle source, target;
        std::shared_ptr<Instance> instance;
        std::shared_ptr<MissileContext> context;
        CombatAmount damage = 0;
        CombatAmount multiplier = 1;
        double cruise_speed = 0, age = 0, next_hit = 0, charge = 0, interval = 0,
               ramp = 1, maximum = 1;
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
        CombatAmount multiplier = 1;
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
        int layer = 0, type = 0;
        CombatAmount base = 0, factor = 1, maximum = 0, loss = 0, buffer = 0;
        double delay = 0, rate = 0, last_hit = 0,
               memory_heal = 0, memory_cap = 0, deferred_fraction = 0;
    };
    struct Effect {
        int kind = 0, type = 0;
        bool player = false, critical = false;
        int64_t uid = 0;
        CombatAmount amount = 0, absorbed = 0; double time = 0;
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
    std::map<String, std::array<CombatAmount, 2>> damage_stats;
    std::vector<Actor> actors;
    std::vector<Weapon> weapons;
    std::vector<Defence> defences;
    std::map<int64_t, std::array<CombatAmount, 2>> debts;
    double defence_time = 0, memory_interval = 1, deferred_interval = 1, memory_elapsed = 0,
           deferred_elapsed = 0, deferred_duration = 1, clear_probability = 0, counter_growth = 0,
           defence_counter_growth = 0, counter_log_base = 10, counter_round_scale = 10;
    int64_t counter_level = 0;
    int64_t deferred_tick = 0;
    int64_t attack_counter = 0, incoming_counter = 0;
    // Encounter envelopes retain old birth configurations across numeric upgrades.
    // They only widen; no hot scan of carriers or queues is required.
    CombatAmount retained_damage_bound = 0; double retained_repeat_bound = 1, retained_maximum_bound = 1;
    double retained_min_interval = std::numeric_limits<double>::infinity();
    CombatAmount retained_explosion_bound = 0, retained_debt_bound = 0; double retained_interference_bound = 1;
    int retained_salvo_bound = 1, retained_chain_bound = 0;
    CombatAmount retained_recovery_bound = 0, retained_shield_bound = 0; double retained_drop_bound = 0;
    double envelope_clock = 0, retained_shield_elapsed = 0;
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
    double target_slot_center = 4.5;
    Vector2 player_point;
    uint32_t encounter_generation = 1;
    uint64_t refit_epoch = 0;
    uint64_t step_serial = 0, event_serial = 0, attack_serial = 0, instance_serial = 0, flight_serial = 0;
    double clock = 0, resistance = 0.5;
    double last_incoming_at = -100;
    double jewel_probability = 0, jewel_ratio = 1;
    int64_t drop_uid = 0;
    bool drop_rules = false;
    bool admitted = false, stopped = false, scatter = false, executing = false;
    bool final_encounter = false, final_cleared = false;
    String native_error;
    Dictionary session_descriptor;
    int64_t encounter_id=0, actor_id=0;
    bool wave_running=false, death_reported=false;
    int chain_count = 0, prism_count = 0;
    double crit_rate = 0, crit_multiplier = 2, repeat_probability = 0, repeat_multiplier = 1,
           repeat_delay = 0, secondary_probability = 0, scatter_bonus = 0, prism_bonus = 0;
    double laser_charge_multiplier = 1;
    bool guidance_enabled = false, guidance_limited = false, wild_enabled = false;
    double guidance_multiplier = 1, wild_multiplier = 1, wild_blast = 0;
    int64_t guidance_limit = 0, wild_period = 0, missile_attacks = 0;
    int wild_damage_type = 0;
    uint64_t context_serial = 0, wild_replacements = 0, wild_detonations = 0, wild_recursion_blocks = 0;
    double retained_guidance_layers = 0, retained_guidance_factor = 1, retained_wild_blast = 1;
    std::shared_ptr<MissileContext> missile_context(const Weapon &w, uint64_t root, bool derived, bool chain = false) {
        auto c = std::make_shared<MissileContext>(); c->id = checked_id(context_serial); c->root = root;
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
    static Dictionary export_missile_context(const std::shared_ptr<MissileContext> &c) {
        if (!c) return Dictionary();
        Dictionary record, value, factors;
        for (const auto &item : c->factors) factors[String::num_int64(item.first)] = item.second;
        value["root_id"] = int64_t(c->root); value["batch_id"] = int64_t(c->root);
        value["source_id"] = c->source; value["weapon"] = "missile";
        value["trigger_depth"] = c->derived ? 1 : 0;
        value["trigger"] = c->wild ? "wild_missile" : c->chain ? "chain" : c->derived ? "repeat_or_secondary" : "";
        value["guidance_factors"] = factors;
        if (c->derived && !c->chain && !c->wild) value["chain_allowance"] = true;
        if (c->wild) { value["wild_missile"] = true; value["wild_used"] = c->wild_used; value["blast_fraction"] = c->blast; }
        record["id"] = int64_t(c->id); record["value"] = value; return record;
    }
    static bool missile_arithmetic(CombatAmount &raw, double layers, bool guidance, double multiplier, double factor, double blast) {
        if (layers >= 9007199254740991.0) return false;
        if (guidance) factor = combat_max(factor, std::pow(multiplier,layers));
        CombatAmount exploded = raw * combat_max(1.0,blast);
        if (!combat_finite(factor) || !combat_finite(exploded)) return false;
        raw = combat_max(raw,exploded) * combat_max(1.0,factor);
        return combat_finite(raw);
    }
    struct StrangePacket {
        uint64_t order = 0, root = 0;
        CombatAmount damage = 0;
        int type = 0;
        String source;
        String stats_source;
    };
    // Deadlines select due work; insertion order controls settlement and cold export.
    std::multimap<double, StrangePacket> strange_pending;
    uint64_t strange_serial = 0;
    bool strange_enabled = false;
    double strange_probability = 0, strange_delay = 0, strange_multiplier = 0, strange_boundary_end = 0;
    CombatAmount retained_strange_damage = 0;
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
            row["remaining"] = nonnegative(item.first - clock); row["damage"] = p.damage;
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
        if (strange_pending.empty()) retained_strange_damage = 0;
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
            return combat_finite(double(value));
        case Variant::VECTOR2: {
            Vector2 point = value;
            return combat_finite(point.x) && combat_finite(point.y);
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
            if (value.get_type() == Variant::DICTIONARY) {
                const std::string field(key);
                if (field!="armour" && field!="shield" && field!="hp" && field!="max_hp" && field!="max_shield" &&
                    field!="damage" && field!="base" && field!="maximum" && field!="loss" && field!="buffer" &&
                    field!="amount" && field!="factor") return false;
                try { CombatAmount checked(value); } catch(const std::exception &) { return false; }
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
            if (row.has(key)) {
                if (row[key].get_type()==Variant::DICTIONARY) {
                    try { CombatAmount checked(row[key]); } catch(const std::exception &) {return false;}
                } else if(double(row[key])<0) return false;
            }
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
            !schema_integers(d,{"attack_counter","incoming_counter","counter_level"},false) ||
            !schema_types(d, Variant::DICTIONARY, {"player","deferred"}) ||
            !schema_types(d, Variant::ARRAY, {"enemies","weapons","defences","unsupported_rules"}) ||
            !schema_types(d, Variant::BOOL, {"final_encounter","scatter","requires_strange_matter","requires_laser_charge","requires_endless_beam","drop_rules_compiled","requires_drop_rules","requires_module_defense"}) ||
            !schema_integers(d, {"chain_count","prism_count"}) ||
            !schema_integers(d, {"rng_state","projectile_serial","attack_serial","instance_serial","deferred_tick","drop_uid"}, false) ||
            !numeric_fields(d, {"target_slot_center","clock","since_hit","ejection_gap","launch_speed","turn_rate","ignition","seek","cruise_at","lifetime","orphan_lifetime","brake_range","brake_angle","min_speed","brake_factor","hit_radius","chain_speed","resistance","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","repeat_delay","secondary_probability","scatter_bonus","laser_charge_multiplier","prism_bonus","attack_counter","incoming_counter","counter_growth","defence_counter_growth","counter_level","counter_log_base","counter_round_scale","memory_interval","deferred_interval","deferred_duration","clear_probability","defence_time","memory_elapsed","deferred_elapsed","jewel_probability","jewel_ratio"})) return false;
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
                int(v.get("reactive_stacks",0)) < 0 || int(v.get("reactive_stacks",0)) > 3) return false;
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
                !schema_types(v, Variant::DICTIONARY, {"entry","row"}) || !schema_types(v, Variant::ARRAY, {"transfer_effects"}) ||
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

    static bool checked_counter_bonus(Dictionary d, int64_t count, bool incoming, CombatAmount &bonus) {
        try {
            space::ModuleInput input; input.charged_base=space::Amount(1);
            input.history_count=count; input.effective_level=int64_t(d.get("counter_level",int64_t(0)));
            input.growth=d.get(incoming ? "defence_counter_growth" : "counter_growth",0.0);
            input.log_base=d.get("counter_log_base",10.0); input.round_scale=d.get("counter_round_scale",10.0);
            bonus=space::evaluate_module(input).history_factor.sub_nonnegative(space::Amount(1));
            return true;
        } catch(const std::exception &) { return false; }
    }
    // Check the actual evaluation order: finite inputs alone do not imply finite intermediates.
    // Called only after schema validation, before clearing or assigning any live state.
    static bool configuration_arithmetic(Dictionary d, int64_t attacks, int64_t incoming, CombatAmount retained_raw = 0, CombatAmount retained_debt = 0, double retained_layers = 0, double retained_factor = 1, double retained_blast = 1) {
        if(attacks<0 || incoming<0 || attacks==INT64_MAX || incoming==INT64_MAX) return false;
        CombatAmount attack_bonus = 0, defence_bonus = 0;
        if (!checked_counter_bonus(d, attacks, false, attack_bonus) ||
            !checked_counter_bonus(d, incoming, true, defence_bonus)) return false;
        CombatAmount next_attack_bonus = 0, next_defence_bonus = 0;
        if (!checked_counter_bonus(d, attacks + 1, false, next_attack_bonus) ||
            !checked_counter_bonus(d, incoming + 1, true, next_defence_bonus)) return false;
        attack_bonus = combat_max(attack_bonus,next_attack_bonus);
        defence_bonus = combat_max(defence_bonus,next_defence_bonus);
        double clock_value = d.get("clock", 0.0), defence_clock = d.get("defence_time", 0.0);
        if (!combat_finite(clock_value - double(d.get("since_hit", 100.0))) ||
            !combat_finite(clock_value + double(d.get("repeat_delay", .1))) ||
            !combat_finite(clock_value + double(d.get("strange_delay", 0.0)))) return false;
        double portions = combat_ceil(double(d.get("deferred_duration",1.0)) / double(d.get("deferred_interval",1.0)));
        double first_at = defence_clock + double(d.get("deferred_interval",1.0)) - 1e-9;
        double first_tick = combat_ceil(first_at / double(d.get("deferred_interval",1.0)));
        int64_t tick = d.get("deferred_tick",0);
        if (!combat_finite(portions) || portions > std::numeric_limits<int>::max() ||
            !combat_finite(first_at) || !combat_finite(first_tick) || first_tick >= 9223372036854775808.0 ||
            tick == std::numeric_limits<int64_t>::max()) return false;
        int64_t first = combat_max(tick + 1, int64_t(first_tick));
        if (first > std::numeric_limits<int64_t>::max() - int64_t(combat_max(1.0,portions))) return false;
        Array weapons = d["weapons"], enemies = d["enemies"], defs = d.get("defences", Array());
        CombatAmount raw_bound = retained_raw;
        // A configuration change also affects eligible hits from retained attacks.
        if (bool(d.get("requires_strange_matter",false))) {
            CombatAmount derived = retained_raw * double(d.get("strange_damage_multiplier",0.0));
            if (!combat_finite(derived)) return false;
            raw_bound = combat_max(raw_bound, derived);
        }
        for (int i = 0; i < weapons.size(); ++i) {
            Dictionary v = weapons[i];
            CombatAmount raw = v.get("damage", 1.0);
            if (!bool(v.get("hostile", false))) {
                raw *= 1 + attack_bonus;
                if (!combat_finite(raw)) return false;
                raw = combat_ceil(raw);
            }
            raw *= CombatAmount(v.get("factor", 1.0));
            if (!combat_finite(raw)) return false;
            if (!bool(v.get("hostile", false)) && int(v["kind"]) == 0) {
                double legendary = (bool(d.get("scatter",false)) ? 1 + double(d.get("scatter_bonus", 0.0)) : 1) *
                    double(d.get("laser_charge_multiplier", 1.0));
                if (!combat_finite(legendary)) return false;
                raw *= legendary;
            }
            if (!combat_finite(raw)) return false;
            // Both branches must be representable, regardless of the next RNG draw.
            CombatAmount critical = raw * double(v.get("critical_multiplier", d.get("critical_multiplier", 2.0)));
            if (!combat_finite(critical)) return false;
            raw = combat_max(raw, critical);
            if (bool(d.get("wild_missile",false)) && !bool(v.get("hostile",false)) && int(v["kind"]) == 2) {
                CombatAmount wild_raw = raw * double(d.get("wild_multiplier",1.0));
                if (!combat_finite(wild_raw)) return false;
                raw = combat_max(raw,wild_raw);
            }
            if (bool(d.get("requires_strange_matter",false)) && !bool(v.get("hostile",false)) && int(v["kind"]) == 1) {
                CombatAmount derived = raw * double(d.get("strange_damage_multiplier",0.0));
                if (!combat_finite(derived)) return false;
                raw_bound = combat_max(raw_bound, derived);
            }
            CombatAmount repeated = raw * double(v.get("repeat_multiplier", d.get("repeat_multiplier", 1.0)));
            if (!combat_finite(repeated)) return false;
            raw = combat_max(raw, repeated);
            CombatAmount maximum = double(v.get("maximum",1.0)) + double(d.get("prism_bonus",0.0));
            if (!combat_finite(maximum) || !combat_finite(raw * combat_max(1.0,maximum))) return false;
            raw_bound = combat_max(raw_bound, combat_max(raw, raw * combat_max(1.0, maximum)));
            if (!combat_finite(clock_value + double(v.get("remaining",int(v["kind"]) == 3 ? 0.0 : double(v.get("interval",1.0)))))) return false;
        }
        for (int i = 0; i < enemies.size(); ++i) {
            Dictionary v = enemies[i];
            CombatAmount explosion = CombatAmount(v["max_hp"]) * double(v.get("jewelExplosion",0.0));
            if (!combat_finite(explosion)) return false;
            raw_bound = combat_max(raw_bound, explosion);
            CombatAmount recovery = CombatAmount(v.get("max_shield",0.0)) * double(v.get("shieldRecovery",0.0));
            double elapsed = clock_value - double(v.get("shield_updated_at",clock_value));
            if (!combat_finite(recovery) || !combat_finite(elapsed) || !combat_finite(recovery * combat_max(0.0,elapsed)) ||
                !combat_finite(CombatAmount(v.get("shield",0.0)) + recovery * combat_max(0.0,elapsed)) ||
                !combat_finite(double(v.get("shield_hit_at",clock_value)) + double(v.get("shieldDelay",0.0)))) return false;
        }
        double layers = retained_layers;
        for (int i = 0; i < enemies.size(); ++i) {
            Dictionary v = enemies[i];
            if (!schema_integers(v, {"guidance_layers"}, false) || !schema_nonnegative(v, {"guidance_layers"})) return false;
            layers = combat_max(layers, double(v.get("guidance_layers",0)));
        }
        if (!missile_arithmetic(raw_bound,layers,bool(d.get("precise_guidance",false)),double(d.get("guidance_multiplier",1.0)),retained_factor,
            combat_max(retained_blast,bool(d.get("wild_missile",false)) ? double(d.get("wild_blast",0.0)) : 1.0))) return false;
        // Explosions use the receiving actor's interference too.
        for (int i = 0; i < enemies.size(); ++i) {
            Dictionary v = enemies[i];
            if (!combat_finite(raw_bound * (1 + double(v.get("interference",0.0))))) return false;
        }
        CombatAmount totals[2] = {}, losses[2] = {}, buffers[2] = {};
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i]; int layer = v.get("layer",0);
            CombatAmount before_ceil = CombatAmount(v.get("base",0.0)) * (1 + defence_bonus);
            CombatAmount maximum = combat_ceil(before_ceil) * CombatAmount(v.get("factor",1.0));
            CombatAmount supplied = v.get("maximum",0.0);
            if (!combat_finite(before_ceil) || !combat_finite(maximum) ||
                !combat_finite(maximum * double(v.get("memory_cap",0.0))) ||
                !combat_finite(supplied * double(v.get("memory_cap",0.0))) ||
                !combat_finite(maximum * double(v.get("memory_heal",0.0))) ||
                !combat_finite(maximum * double(v.get("rate",0.0))) ||
                !combat_finite(maximum / (1 - double(v.get("deferred_fraction",0.0)))) ||
                !combat_finite(defence_clock - double(v.get("last_hit",0.0))) ||
                !combat_finite(double(v.get("last_hit",0.0)) + double(v.get("delay",0.0))) ||
                !combat_finite(raw_bound * maximum)) return false;
            totals[layer] += maximum; losses[layer] += CombatAmount(v.get("loss",0.0)); buffers[layer] += CombatAmount(v.get("buffer",0.0));
            if (!combat_finite(totals[layer]) || !combat_finite(losses[layer]) || !combat_finite(buffers[layer])) return false;
        }
        Dictionary debt = d.get("deferred",Dictionary()); Array keys = debt.keys();
        CombatAmount debt_totals[2] = {retained_debt,retained_debt};
        for (int i = 0; i < keys.size(); ++i) {
            Dictionary payment = debt[keys[i]];
            debt_totals[0] += CombatAmount(payment.get("shield",0.0)); debt_totals[1] += CombatAmount(payment.get("armour",0.0));
            if (!combat_finite(debt_totals[0]) || !combat_finite(debt_totals[1])) return false;
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
        return combat_max(0.0, a);
    }
    static CombatAmount nonnegative(const CombatAmount &a) { return a; }
    void shield(Actor &a, double at) {
        if (!a.live || a.max_shield <= 0)
            return;
        if (at <= a.shield_at) return; // Duplicate/boundary reads never rewind the ledger.
        double ready = a.hit_at + a.delay;
        double elapsed = nonnegative(at - ready) - nonnegative(a.shield_at - ready);
        if (elapsed > 0)
            a.shield = combat_min(a.max_shield, a.shield + a.max_shield * a.recovery * elapsed);
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
        i->id = checked_id(instance_serial);
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
                roots.push({clock, checked_id(event_serial), 0, f.weapon});
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
    size_t birth(int wi, Handle target, std::shared_ptr<Instance> inst, CombatAmount multiplier,
                 bool repeated = false, bool chain = false, Vector2 origin = Vector2(), std::shared_ptr<MissileContext> missile_ctx = {}) {
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
        if (!w.hostile && w.kind == 2) f.context = missile_ctx ? missile_ctx : (chain || repeated ? missile_context(w,inst->attack->id,true,chain) : inst->attack->context);
        f.multiplier = multiplier;
        f.damage = inst->attack->damage * multiplier;
        f.repeated = repeated || inst->derived;
        f.view_repeated = repeated; f.owns_primary_aim = !w.hostile && !repeated && !chain;
        f.view_trigger_depth = repeated || chain || (f.context && f.context->derived) ? 1 : 0;
        f.chain = chain;
        f.beam = w.kind == 3 && !chain;
        f.serial = checked_id(flight_serial);
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
        // Parallel presentation geometry. Numerical origins, collision rays and RNG
        // remain untouched. Only the immutable birth snapshot reaches rendering.
        if (!w.hostile && !chain && !w.entry.has("drone_id") && !w.presentation_muzzles.is_empty()) {
            f.presentation_ray = true;
            const int ordinal = w.kind == 2 ? int(event_serial % w.presentation_muzzles.size()) : 0;
            f.presentation_origin = w.presentation_muzzles[ordinal];
            const Vector2 screen_aim = t ? t->screen_point : w.screen_muzzle + m.direction * 100;
            f.presentation_step = (screen_aim - f.presentation_origin) / combat_max(0.001, distance(from, aim));
        }
        if (compact_laser_births && !w.hostile && w.kind == 0 && !chain && t && t->collision_hull.size() >= 3) {
            f.compact_laser = true; ++compact_laser_count; f.fixed_ray = true;
            f.view_birth = weapons[wi].birth;
            f.launch_point = from; f.ray_origin = w.screen_muzzle;
            f.ray_step = (t->screen_point - w.screen_muzzle) / combat_max(0.001, distance(from, aim));
            if (t->stationary_geometry) refresh_ray_contact(f, *t);
            retained_damage_bound = combat_max(retained_damage_bound, f.damage);
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
        f.view["damage"] = f.damage;
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
            f.view["fixed_screen_step"] = (t->screen_point - w.screen_muzzle) / combat_max(0.001, distance(from, aim));
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
        retained_damage_bound = combat_max(retained_damage_bound, f.damage * combat_max(1.0,f.maximum));
        f.compatibility_index = compatibility_flights.size();
        compatibility_flights.push_back(id);
        flight_rows.push_back(f.view);
        effect(chain ? 4 : 0, f, from, clock);
        return id;
    }
    void hit_enemy(Handle h, CombatAmount raw, int type, const std::shared_ptr<Instance> &inst, bool trigger,
                   double at, int wi, bool chain_trigger = false, const std::shared_ptr<MissileContext> &context = {},
                   const String &damage_source = String()) {
        Actor *a = resolve(h);
        if (!a) {
            ++stale_rejections;
            return;
        }
        shield(*a, at);
        a->hit_at = at;
        const CombatAmount base_raw = raw;
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
                a->min_guidance_factor = combat_min(a->min_guidance_factor,factor);
                a->max_guidance_factor = combat_max(a->max_guidance_factor,factor);
                retained_guidance_factor = combat_max(retained_guidance_factor,factor);
                if (!context->derived) {
                    int64_t previous_layers = a->guidance_layers;
                    a->guidance_layers = guidance_limited ? combat_min(a->guidance_layers+1,guidance_limit) : a->guidance_layers+1;
                    if (a->guidance_layers > previous_layers) a->guidance_growth += a->guidance_layers - previous_layers;
                    a->view["guidance_layers"] = a->guidance_layers;
                    retained_guidance_layers = combat_max(retained_guidance_layers,double(a->guidance_layers));
                }
            } else ++a->guidance_reuses;
            raw *= found->second;
        }
        int reactive_stacks = -1;
        double reactive_multiplier = 1;
        if (a->reactive_reduction) {
            if (at > a->reactive_volley_at + 0.16) {
                a->reactive_stacks = at <= a->reactive_volley_at + 2.2
                    ? combat_min(3, a->reactive_stacks + 1) : 0;
                a->reactive_volley_at = at;
            }
            reactive_stacks = a->reactive_stacks;
            reactive_multiplier = 1.0 - 0.2 * reactive_stacks;
            raw *= reactive_multiplier;
            a->view["reactive_stacks"] = reactive_stacks;
            a->view["reactive_multiplier"] = reactive_multiplier;
            a->view["reactive_volley_at"] = a->reactive_volley_at;
        }
        CombatAmount incoming = raw * (1 + a->interference), absorbed = 0, damage = 0;
        const CombatAmount hp_before = a->hp;
        const CombatAmount shield_before = a->shield;
        if (a->shield > 0) {
            double factor = type == a->shield_type ? 1 - resistance : 1;
            absorbed = combat_min(a->shield, combat_max(1.0, incoming * factor));
            a->shield -= absorbed;
            incoming = factor > 0 ? nonnegative(incoming - absorbed / factor) : 0;
        }
        if (incoming > 0) {
            damage = combat_max(1.0, combat_ceil(incoming * (type == a->armour_type ? 1 - resistance : 1)));
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
            const CombatAmount shield_loss = nonnegative(shield_before - a->shield);
            const CombatAmount hp_loss = nonnegative(hp_before - a->hp);
            if (shield_loss > 0 || hp_loss > 0) {
                auto &sum = damage_stats[source];
                sum[0] += shield_loss;
                sum[1] += hp_loss;
            }
        }
        a->view["hp"] = a->hp;
        a->view["shield"] = a->shield;
        a->view["shield_hit_at"] = at;
        ++hit_count;
        Effect e;
        e.kind = 2;
        e.uid = a->uid;
        e.type = type;
        e.amount = (hp_before - a->hp) + (shield_before - a->shield);
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
                retained_strange_damage = combat_max(retained_strange_damage, p.damage);
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
            ++a->generation;
            ++dead_count;
            e.kind = 3;
            e.amount = 0;
            feedback.push_back(e);
            if (drop_rules) {
                for (int roll = 0; roll < a->jewel_rolls; ++roll)
                    if (rng->randf() < jewel_probability) {
                        Dictionary drop;
                        drop["uid"] = checked_increment(drop_uid);
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
                        drop["uid"] = checked_increment(drop_uid);
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
                        hit_enemy(handle(index), a->max_hp * a->explosion, type, {}, false, at, wi, false, {}, source);
            for (size_t id : active) {
                Flight &f = flights[id];
                if (endless_eligible(f) && f.target.index == h.index && !f.await_target) {
                    // All beam ages were projected to the segment end. Roll back
                    // only its post-death tail; waiting never creates catch-up debt.
                    f.age = combat_max(0.0,f.age - combat_max(0.0,clock-at));
                    f.await_target = true; f.view["await_target"] = true; f.view["elapsed"] = f.age;
                    // Keep links until this hit finishes its inherited chain work.
                }
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
                        birth(wi, t, inst, (inst->attack->damage > 0 ? base_raw / inst->attack->damage : CombatAmount(0)), false, true, origin);
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
    CombatAmount counter_bonus(int64_t count, bool incoming = false) const {
        space::ModuleInput input;input.charged_base=space::Amount(1);input.history_count=count;
        input.effective_level=int64_t(counter_level);input.growth=incoming?defence_counter_growth:counter_growth;
        input.log_base=counter_log_base;input.round_scale=counter_round_scale;
        return space::evaluate_module(input).history_factor.sub_nonnegative(space::Amount(1));
    }
    space::ModuleEvaluation evaluate_charged(const CombatAmount &base,const CombatAmount &factor,int64_t count,bool incoming=false) const {
        space::ModuleInput input;input.charged_base=base;input.history_count=count;input.effective_level=counter_level;
        input.growth=incoming?defence_counter_growth:counter_growth;input.log_base=counter_log_base;input.round_scale=counter_round_scale;
        if(factor!=1) input.external_factors.push_back(factor);
        return space::evaluate_module(input);
    }
    CombatAmount capacity(int layer) const {
        CombatAmount total = 0;
        for (const Defence &d : defences)
            if (d.layer == layer)
                total += d.maximum;
        return total;
    }
    CombatAmount layer_remaining(int layer) const {
        CombatAmount total=0;
        for(const Defence &module:defences) if(module.layer==layer) total+=module.maximum-module.loss;
        return total;
    }
    void assign_layer_missing(int layer,CombatAmount wanted) {
        CombatAmount current=0,total=0;
        for(Defence &module:defences) if(module.layer==layer) {
            module.loss=combat_min(module.loss,module.maximum);current+=module.loss;total+=module.maximum;
        }
        wanted=combat_min(wanted,total);
        const bool increase=wanted>current;
        CombatAmount delta=increase?wanted-current:current-wanted;
        CombatAmount weight_total=increase?total-current:current;
        for(Defence &module:defences) if(module.layer==layer && delta>0 && weight_total>0) {
            CombatAmount weight=increase?module.maximum-module.loss:module.loss;
            CombatAmount part=weight==weight_total?delta:delta*(weight/weight_total);
            module.loss=increase?combat_min(module.maximum,module.loss+part):module.loss-part;
            delta-=part;weight_total-=weight;
        }
    }
    void reconcile_defence() {
        const CombatAmount previous[2]={layer_remaining(0),layer_remaining(1)};
        for(Defence &module:defences) {
            module.maximum=evaluate_charged(module.base,module.factor,incoming_counter,true).final;
            module.loss=combat_min(module.loss,module.maximum);
            module.buffer=combat_min(module.buffer,module.maximum*module.memory_cap);
        }
        // Attribute/history changes preserve the former module-derived absolute
        // remaining health. No cached/player-row total is an input here.
        for(int layer=0;layer<2;++layer) assign_layer_missing(layer,capacity(layer)-previous[layer]);
    }
    CombatAmount protection(CombatAmount amount, CombatAmount &absorbed) {
        CombatAmount rest = amount;
        for (Defence &d : defences) {
            if (rest <= 0)
                break;
            CombatAmount paid = combat_min(d.buffer, rest);
            d.buffer -= paid;
            rest -= paid;
            absorbed += paid;
            if (paid > 0)
                d.last_hit = defence_time;
        }
        return rest;
    }
    void publish_player() {
        player_row["armour"] = layer_remaining(1);
        player_row["shield"] = layer_remaining(0);
        for (size_t i = 0; i < defences.size(); ++i) {
            buffer_rows[int64_t(i)] = defences[i].buffer;
            loss_rows[int64_t(i)] = defences[i].loss;
            defence_time_rows[int64_t(i)] = defence_time - defences[i].last_hit;
        }
    }
    void incoming_effect(CombatAmount loss, CombatAmount absorbed, int type, double at, bool deferred = false) {
        Effect e;
        e.kind = 2;
        e.player = true;
        e.point = player_point;
        e.type = type;
        e.amount = loss;
        e.absorbed = absorbed;
        e.time = at;
        feedback.push_back(e);
        ++hit_count;
        publish_player();
        if (layer_remaining(1) <= 0)
            cancel();
    }
    void queue_debt(int layer, CombatAmount amount) {
        if (amount <= 0)
            return;
        retained_debt_bound += amount;
        int portions = combat_max(1, int(combat_ceil(deferred_duration / deferred_interval)));
        int64_t first =
            combat_max(deferred_tick + 1,
                     int64_t(combat_ceil((defence_time + deferred_interval - 1e-9) / deferred_interval)));
        CombatAmount unit = amount / portions, remaining = amount;
        for (int i = 0; i < portions; ++i) {
            CombatAmount part = i == portions - 1 ? remaining : combat_min(unit, remaining);
            remaining = nonnegative(remaining - part);
            debts[first + i][layer] += part;
        }
    }
    void pay_debt(CombatAmount amount, double at) {
        CombatAmount absorbed = 0, rest = protection(amount, absorbed), loss = 0;
        for (int layer = 0; layer < 2 && rest > 0; ++layer) {
            reconcile_defence();
            CombatAmount total = 0;
            for (const Defence &d : defences)
                if (d.layer == layer)
                    total += nonnegative(d.maximum - d.loss);
            CombatAmount taken = combat_min(total, rest), body = 0;
            for (Defence &d : defences)
                if (d.layer == layer && total > 0) {
                    CombatAmount part = taken * (nonnegative(d.maximum - d.loss) / total);
                    d.loss += part;
                    body += part;
                    if (part > 0)
                        d.last_hit = defence_time;
                }
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
            double piece = combat_min(
                rest, combat_min(memory_interval - memory_elapsed, deferred_interval - deferred_elapsed));
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
                CombatAmount recovered = combat_min(d.loss, d.maximum * d.rate * elapsed);
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
                CombatAmount total = capacity(d.layer);
                if (memory && d.memory_heal > 0) {
                    CombatAmount healing = d.maximum * d.memory_heal, recovered = combat_min(d.loss, healing);
                    d.loss = nonnegative(d.loss - recovered);
                    d.buffer =
                        combat_min(d.maximum * d.memory_cap, d.buffer + nonnegative(healing - recovered));
                }
            }
            publish_player();
        }
    }
    void player_hit(CombatAmount raw, int type, double at) {
        if (final_cleared) return;
        checked_increment(incoming_counter);
        last_incoming_at = at;
        reconcile_defence();
        const CombatAmount previous[2]={layer_remaining(0),layer_remaining(1)};
        // A hit restarts every shield delay, even when cover or armour pays it.
        for (Defence &d : defences)
            if (d.layer == 0)
                d.last_hit = defence_time;
        CombatAmount absorbed = 0, rest = protection(raw, absorbed);
        std::array<CombatAmount, 2> payments{};
        std::array<bool, 2> deferred{};
        int shield_passes = 0;
        for (const Defence &d : defences)
            if (d.layer == 0)
                ++shield_passes;
        for (int pass = 0; pass <= shield_passes && rest > 0; ++pass) {
            int layer = pass < shield_passes ? 0 : 1;
            CombatAmount total = 0;
            std::vector<CombatAmount> available(defences.size(), 0);
            for (size_t i = 0; i < defences.size(); ++i)
                if (defences[i].layer == layer) {
                    available[i] = nonnegative(defences[i].maximum - defences[i].loss);
                    total += available[i];
                }
            if (total <= 0)
                continue;
            CombatAmount incoming = rest, spent = 0;
            for (size_t i = 0; i < defences.size(); ++i) {
                Defence &d = defences[i];
                if (d.layer != layer || available[i] <= 0)
                    continue;
                double factor = type == d.type ? 1 - resistance : 1;
                CombatAmount weighted = incoming * (available[i] / total), part = weighted * factor,
                       payable = available[i] / (1 - d.deferred_fraction),
                       taken = layer == 1 ? part : combat_min(payable, part),
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
        CombatAmount loss = 0;
        for (int layer = 0; layer < 2; ++layer) {
            CombatAmount paid = combat_min(previous[layer], deferred[layer] ? payments[layer] : combat_ceil(payments[layer]));
            assign_layer_missing(layer,capacity(layer)-(previous[layer]-paid));
            loss += paid;
        }
        incoming_effect(loss, absorbed, type, at);
    }
    void launch(int wi, Handle target, std::shared_ptr<const Attack> a, CombatAmount multiplier,
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
            auto salvo_context = repeated ? missile_context(w,a->id,true) : a->context;
            for (int n = 0; n < w.salvo; ++n) {
                Timed pending{clock + n * ejection_gap, checked_id(event_serial), 1, wi, n,
                              distribute && !choices.empty() ? choices[n % choices.size()] : target, a,
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
        a->id = checked_id(attack_serial);
        a->birth = w.birth;
        ++root_attacks;
        if (!w.hostile)
            checked_increment(attack_counter);
        // Match weapon_multiplier grouping before multiplying the rounded base.
        double legendary = !w.hostile && w.kind == 0 ?
            (scatter && candidates.size() == 1 ? 1 + scatter_bonus : 1) * laser_charge_multiplier : 1;
        a->damage = (w.hostile ? w.base*w.factor : CombatAmount(evaluate_charged(w.base,w.factor,attack_counter).final)) * legendary;
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
                retained_wild_blast = combat_max(retained_wild_blast,wild_blast);
                auto birth = std::make_shared<BirthConfig>(*a->birth); birth->salvo = 1;
                birth->weapon = birth->weapon.duplicate(true); birth->weapon["para1"] = 1; birth->weapon.make_read_only();
                a->birth = birth;
            }
        }
        a->secondary = !w.hostile && !wild && rng->randf() < w.secondary_probability;
        a->repeats = !w.hostile && !wild && rng->randf() < w.repeat_probability;
        retained_damage_bound = combat_max(retained_damage_bound,a->damage * retained_repeat_bound * retained_maximum_bound);
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
                {clock + repeat_delay, checked_id(event_serial), 2, wi, 0, candidates.front(), a, w.repeat_multiplier});
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
               (CombatAmount(player_row.get("armour",0.0)) > 0 || CombatAmount(player_row.get("shield",0.0)) > 0);
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
            for (double due = f.next_hit; due <= f.age + 1e-9; due += f.interval)
                periods.push_back({clock - f.age + due, due, id});
            f.view["elapsed"] = f.age;
        }
        std::sort(periods.begin(), periods.end(), [&](const Period &a, const Period &b) {
            return a.at == b.at ? flights[a.id].serial < flights[b.id].serial : a.at < b.at;
        });
        for (const Period &p : periods) {
            if (stopped || final_cleared) break;
            recover(nonnegative(p.at - defence_at), defence_at);
            defence_at = combat_max(defence_at, p.at);
            if (stopped) break;
            Flight &f = flights[p.id];
            if (!f.live || f.await_target || (f.hostile ? !resolve(f.source) : !resolve(f.target))) {
                if (f.live && (f.hostile || !retain_endless_target(f,p.at,false))) retire(p.id);
                continue;
            }
            // Collection is speculative; only an executed hit consumes its period.
            f.next_hit = p.due + f.interval;
            ++f.ticks;
            f.view["ticks"] = f.ticks;
            double duration = f.charge >= 0 ? (f.ticks - 1) * f.interval : p.due;
            double ramp = f.ramp > 0 ? std::clamp(duration / f.ramp, 0.0, 1.0) : 1;
            CombatAmount raw = f.damage * (1 + (f.maximum - 1) * ramp);
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
                              checked_id(event_serial),
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
        checked_id(step_serial);
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
                checked_increment(attack_counter);
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
                  q.damage_derived, false, Vector2(), q.context);
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
                f.target_view_cleared = true;
                if (!f.view.is_empty()) f.view["target"] = Dictionary();
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
                        m.speed = combat_min(m.speed, combat_max(min_speed, range * turn_rate * brake_factor));
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
                            const double margin = combat_max(1.0, std::abs(f.contact_distance) * 1e-4);
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
            if (f.live && f.beam && (f.hostile ? !resolve(f.source) : !resolve(f.target))) {
                if (f.hostile || !retain_endless_target(f,clock,false)) retire(id);
            }
        }
        for (Actor &a : actors)
            shield(a, clock);
        compact();
        executing = false;
    }

  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("last_error"), &SpaceCombatKernel::last_error);
        ClassDB::bind_method(D_METHOD("start_wave", "wave"), &SpaceCombatKernel::start_wave);
        ClassDB::bind_method(D_METHOD("finish_wave", "final"), &SpaceCombatKernel::finish_wave);
        ClassDB::bind_method(D_METHOD("take_results"), &SpaceCombatKernel::take_results);
        ClassDB::bind_method(D_METHOD("read_history"), &SpaceCombatKernel::read_history);
        ClassDB::bind_method(D_METHOD("allocate_drop_id"), &SpaceCombatKernel::allocate_drop_id);
        ClassDB::bind_method(D_METHOD("begin_retreat"), &SpaceCombatKernel::begin_retreat);
        ClassDB::bind_method(D_METHOD("prepare_departure"), &SpaceCombatKernel::prepare_departure);
        ClassDB::bind_method(D_METHOD("finish_retreat"), &SpaceCombatKernel::finish_retreat);
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
        ClassDB::bind_method(D_METHOD("enemy_views"), &SpaceCombatKernel::enemy_views);
        ClassDB::bind_method(D_METHOD("buffer_view"), &SpaceCombatKernel::buffer_view);
        ClassDB::bind_method(D_METHOD("deferred_total"), &SpaceCombatKernel::deferred_total);
        ClassDB::bind_method(D_METHOD("rng_source"), &SpaceCombatKernel::rng_source);
        ClassDB::bind_method(D_METHOD("exit_state"), &SpaceCombatKernel::exit_state);
        ClassDB::bind_method(D_METHOD("set_compact_laser_births", "enabled"), &SpaceCombatKernel::set_compact_laser_births);
        ClassDB::bind_method(D_METHOD("export_handoff"), &SpaceCombatKernel::export_handoff);
        ClassDB::bind_method(D_METHOD("commit_handoff", "revision"), &SpaceCombatKernel::commit_handoff);
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
        ClassDB::bind_method(D_METHOD("hit_handle", "handle", "raw", "type"), &SpaceCombatKernel::hit_handle);
        ClassDB::bind_method(D_METHOD("receive_player_hit", "raw", "type"),
                             &SpaceCombatKernel::receive_player_hit);
        ClassDB::bind_method(D_METHOD("cancel"), &SpaceCombatKernel::cancel);
        ClassDB::bind_method(D_METHOD("metrics"), &SpaceCombatKernel::metrics);
        ClassDB::bind_method(D_METHOD("cooldown_remaining", "slot", "source_uid"),
                             &SpaceCombatKernel::cooldown_remaining, DEFVAL(int64_t(-1)));
    }

  public:
    String last_error() const { return native_error; }
#include "wave_lifecycle.h"
    void retain_configuration_bounds(bool reset = false) {
        if (reset) {
            retained_damage_bound = retained_debt_bound = retained_explosion_bound = 0;
            retained_repeat_bound = retained_maximum_bound = retained_interference_bound = 1;
            retained_min_interval = std::numeric_limits<double>::infinity();
            retained_salvo_bound = 1; retained_chain_bound = 0;
            retained_drop_bound = retained_shield_elapsed = 0; retained_recovery_bound = retained_shield_bound = 0;
            envelope_clock = clock;
            for (const auto &payment : debts)
                retained_debt_bound += payment.second[0] + payment.second[1];
        }
        for (const Weapon &w : weapons) {
            retained_salvo_bound = combat_max(retained_salvo_bound,w.salvo);
            retained_chain_bound = combat_max(retained_chain_bound,combat_max(w.chain_count,prism_count));
            retained_min_interval = combat_min(retained_min_interval,w.interval);
            retained_repeat_bound = combat_max(retained_repeat_bound,w.repeat_multiplier);
            retained_maximum_bound = combat_max(retained_maximum_bound,w.maximum + prism_bonus);
        }
        if (reset) for (const Actor &a : actors) {
            retained_interference_bound = combat_max(retained_interference_bound,1 + a.interference);
            retained_explosion_bound = combat_max(retained_explosion_bound,a.max_hp * a.explosion);
            retained_drop_bound += double(a.jewel_rolls) + double(a.drops.size());
            retained_recovery_bound = combat_max(retained_recovery_bound,a.max_shield * a.recovery);
            retained_shield_bound = combat_max(retained_shield_bound,combat_max(a.shield,a.max_shield));
            retained_shield_elapsed = combat_max(retained_shield_elapsed,combat_max(0.0,clock-a.shield_at));
        }
    }
    bool can_advance(double seconds) const {
        return admitted && !stopped && !executing && std::isfinite(seconds) && seconds > 0 &&
            std::isfinite(clock + seconds) && clock + seconds > clock &&
            attack_counter < INT64_MAX && incoming_counter < INT64_MAX &&
            attack_serial < uint64_t(INT64_MAX) && flight_serial < uint64_t(INT64_MAX) &&
            event_serial < uint64_t(INT64_MAX) && instance_serial < uint64_t(INT64_MAX);
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
    bool configure(Dictionary d) {
        try { return configure_impl(d); }
        catch(const std::exception &error) { stopped=true; native_error=String(error.what()); return false; }
    }
    bool configure_impl(Dictionary d) {
        native_error=String();
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
        target_slot_center = d.get("target_slot_center", 4.5);
        player_point = Vector2(player_row.get("x", 286.0), player_row.get("y", 520.0));
        rng.instantiate();
        rng->set_state(int64_t(d.get("rng_state", 1)));
        missile_attacks = d.get("missile_attacks",0); context_serial = 0;
        wild_replacements = wild_detonations = wild_recursion_blocks = 0;
        retained_guidance_layers = 0; retained_guidance_factor = 1; retained_wild_blast = 1;
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
            a.guidance_layers = v.get("guidance_layers",0);
            retained_guidance_layers = combat_max(retained_guidance_layers,double(a.guidance_layers));
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
                a.drops.push_back({double(row["chance"]), CombatAmount(row["amount"]), CombatAmount(row["base"]),
                                   int(row["resource"])});
            }
            if (!combat_finite(a.hp))
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
            if (w.interval <= 0 || double(v.get("speed", 720.0)) <= 0 || CombatAmount(v.get("damage", 1.0)) < 0 ||
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
            w.endless = v.get("endless", false);
            w.muzzle = v.get("muzzle", Vector2(286, 520));
            w.entry = Dictionary(v.get("entry", Dictionary())).duplicate(true);
            w.row = Dictionary(v.get("row", Dictionary())).duplicate(true);
            w.birth = birth_config(w, v, d.get("repeat_delay", 0.5));
            weapons.push_back(w);
            roots.push({clock + w.remaining, checked_id(event_serial), 0, i});
        }
        attack_counter = d.get("attack_counter", 0.0);
        incoming_counter = d.get("incoming_counter", 0.0);
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
            debts[int64_t(debt_keys[i])] = {CombatAmount(payment.get("shield", 0.0)), CombatAmount(payment.get("armour", 0.0))};
        }
        if(defences.empty()) {
            Defence armour;armour.layer=1;armour.type=player_row.get("armour_type",0);
            armour.base=CombatAmount(player_row["armour"]);armour.maximum=armour.base;defences.push_back(armour);
            if(CombatAmount(player_row["shield"])>0) {
                Defence shield_module;shield_module.layer=0;shield_module.type=player_row.get("shield_type",0);
                shield_module.base=CombatAmount(player_row["shield"]);shield_module.maximum=shield_module.base;defences.push_back(shield_module);
            }
        }
        module_defence = true;
        admitted = (!bool(d.get("requires_module_defense", false)) || module_defence) &&
                   (!bool(d.get("requires_drop_rules", false)) || drop_rules);
        retain_configuration_bounds(true);
        publish_player();
        root_attacks = hit_count = dead_count = stale_rejections = physics_visits = 0;
        ballistic_checks = ballistic_skips = ballistic_ray_queries = 0;
        session_descriptor=d.duplicate(true);wave_running=!actors.empty();death_reported=false;
        actor_id=0;for(const Actor &actor:actors) actor_id=combat_max(actor_id,actor.uid);
        return admitted;
    }
    bool can_update_configuration(Dictionary d) const {
        try { return can_update_configuration_impl(d); } catch(const std::exception &) { return false; }
    }
    bool can_update_configuration_impl(Dictionary d) const {
        if (!admitted || stopped || executing || !configuration_schema(d) ||
            !configuration_arithmetic(d, attack_counter, incoming_counter, combat_max(retained_damage_bound, retained_strange_damage), retained_debt_bound, retained_guidance_layers, retained_guidance_factor, retained_wild_blast)) return false;
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
            if (!numeric_fields(v, {"kind","type","slot","source","damage","factor","interval","speed","salvo","charge","ramp","maximum","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","chain_count","secondary_probability"}) || double(v.get("interval", 0)) <= 0 || double(v.get("speed", 0)) <= 0 || CombatAmount(v.get("damage", 0.0)) < 0 || CombatAmount(v.get("factor", 1.0)) < 0) return false;
            if (int(v.get("kind", -1)) != w.kind || int(v.get("type", -1)) != w.type || int(v.get("slot", -1)) != w.slot || bool(v.get("hostile", false)) != w.hostile || int(v.get("source", -2)) != (w.hostile ? int(w.source.index) : -1)) return false;
            Dictionary entry = v.get("entry", Dictionary());
            if (entry.get("key", "") != w.entry.get("key", "") || entry.get("name", "") != w.entry.get("name", "") || entry.get("drone_id", "") != w.entry.get("drone_id", "")) return false;
            if (Array(v.get("transfer_effects", Array())) != w.birth->effects || int(v.get("chain_count", 0)) != w.chain_count || double(v.get("repeat_probability", 0)) != w.repeat_probability || double(v.get("secondary_probability", 0)) != w.secondary_probability) return false;
        }
        for (int i = 0; i < defs.size(); ++i) {
            Dictionary v = defs[i]; const Defence &a = defences[i];
            if (!numeric_fields(v, {"layer","type","base","factor","maximum","loss","buffer","last_hit","delay","rate","memory_heal","memory_cap","deferred_fraction"}) || CombatAmount(v.get("base", 0.0)) < 0 || CombatAmount(v.get("factor", 0.0)) < 0) return false;
            if (int(v.get("layer", -1)) != a.layer || int(v.get("type", -1)) != a.type || double(v.get("memory_heal",0)) != a.memory_heal || double(v.get("memory_cap",0)) != a.memory_cap || double(v.get("deferred_fraction",0)) != a.deferred_fraction) return false;
        }
        if (double(d.get("counter_growth",0)) != counter_growth || double(d.get("defence_counter_growth",0)) != defence_counter_growth || int64_t(d.get("counter_level",int64_t(0))) != counter_level || double(d.get("repeat_delay",0)) != repeat_delay || bool(d.get("scatter",false)) != scatter || int(d.get("prism_count",0)) != prism_count) return false;
        for (const auto &field : std::initializer_list<std::pair<const char *,double>>{
            {"target_slot_center",target_slot_center},{"counter_log_base",counter_log_base},{"counter_round_scale",counter_round_scale},
            {"memory_interval",memory_interval},{"deferred_interval",deferred_interval},{"deferred_duration",deferred_duration},
            {"resistance",resistance},{"chain_speed",chain_speed},{"ejection_gap",ejection_gap},{"launch_speed",launch_speed},
            {"turn_rate",turn_rate},{"ignition",ignition},{"seek",seek},{"cruise_at",cruise_at},{"lifetime",lifetime},
            {"orphan_lifetime",orphan_lifetime},{"brake_range",brake_range},{"brake_angle",brake_angle},
            {"min_speed",min_speed},{"brake_factor",brake_factor},{"hit_radius",hit_radius}})
            if (double(d.get(field.first,field.second)) != field.second) return false;
        Dictionary player = d.get("player", Dictionary());
        return player.has("armour") && player.has("shield") && numeric_fields(player, {"armour","shield"}) && CombatAmount(player["armour"]) >= 0 && CombatAmount(player["shield"]) >= 0;
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
        try { return can_refit_configuration_impl(d); } catch(const std::exception &) { return false; }
    }
    bool can_refit_configuration_impl(Dictionary d) const {
        if (Variant(d.get("refit_token", Variant())).get_type() != Variant::DICTIONARY ||
            Dictionary(d["refit_token"]) != refit_token()) return false;
        if (!can_update_configuration(d) ||
            (CombatAmount(Dictionary(d["player"])["armour"]) <= 0 &&
             CombatAmount(Dictionary(d["player"])["shield"]) <= 0)) return false;
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
        CombatAmount former_remaining[2]={layer_remaining(0),layer_remaining(1)};
        CombatAmount former_capacity[2]={capacity(0),capacity(1)};
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
        laser_charge_multiplier = d.get("laser_charge_multiplier", 1.0);
        configure_strange(d);
        configure_missile_legends(d);
        prism_count = d.get("prism_count", prism_count);
        prism_bonus = d.get("prism_bonus", prism_bonus);
        if (refit) {
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
        if(refit) for(int layer=0;layer<2;++layer) {
            CombatAmount current=former_capacity[layer]>0?capacity(layer)*(former_remaining[layer]/former_capacity[layer]):CombatAmount(0);
            assign_layer_missing(layer,capacity(layer)-current);
        }
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
                if (!combat_finite(ports[j].x) || !combat_finite(ports[j].y)) return false;
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
                f.contact_distance = combat_max(0.0, along);
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
            if (along >= 0 && along <= 1 && side >= 0 && side <= 1) first = combat_min(first, along);
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
        try { return advance_impl(seconds); }
        catch(const std::exception &error) { stopped=true;executing=false;native_error=String(error.what());return false; }
    }
    bool advance_impl(double seconds) {
        if (!can_advance(seconds)) return false;
        double end = clock + seconds;
        // One logical boundary, before movement/ejection subdivisions. Newborn packets
        // cannot run until the next advance, including a zero configured delay.
        strange_boundary_end = end;
        executing = true;
        advance_strange(end);
        executing = false;
        while (clock + 1e-9 < end && (!stopped || final_cleared)) {
            double next = end;
            if (!ejections.empty() && ejections.top().at > clock + 1e-9)
                next = combat_min(next, ejections.top().at);
            segment(next - clock, next == end);
        }
        // The session consumes this whole logical step; terminal death freezes defence,
        // while consuming any tail after an ejection split without more battle events.
        if (stopped) clock = end;
        return true;
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
        v["hostile"] = false; v["key"] = "laser"; v["type"] = f.type; v["damage"] = f.damage; v["dead"] = !f.live;
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
    Dictionary export_handoff() const {
        Dictionary out;
        if (!admitted || (stopped && !final_cleared) || executing) return out;
        out["strange_pending"] = export_strange();
        out["missile_attacks"] = missile_attacks;
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
            row["native_context"] = export_missile_context(a->context);
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
            if (f.compact_laser && !valid_laser_view(f)) return Dictionary();
            Dictionary row; row["view"] = f.compact_laser ? laser_view(f) : f.view; row["weapon_index"] = f.weapon;
            row["snapshot"] = attack_view(f.instance->attack); row["instance"] = instance_view(f.instance);
            row["instance_derived"] = f.repeated; row["damage"] = f.damage;
            row["native_context"] = export_missile_context(f.context);
            row["multiplier"] = f.multiplier; row["age"] = f.age; row["next_hit"] = f.next_hit;
            row["ticks"] = f.ticks; row["charge"] = f.charge; row["interval"] = f.interval;
            row["ramp"] = f.ramp; row["maximum"] = f.maximum; row["cruise_speed"] = f.cruise_speed;
            row["native_index"] = int64_t(id); row["native_generation"] = int64_t(f.generation);
            row["endless"] = endless_eligible(f); row["await_target"] = f.await_target;
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
                row["native_context"] = export_missile_context(q.context);
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
        strange_pending.clear(); retained_strange_damage = 0;
        while (!roots.empty()) roots.pop(); while (!ejections.empty()) ejections.pop(); while (!repeats.empty()) repeats.pop();
        // Drop executor references only. Published rows/leases stay live for the
        // receiving Game and visual surface; no retire/dead/effect is emitted.
        flights.clear(); active.clear(); active_beams.clear(); free_flights.clear(); retired.clear();
        compact_laser_births = false; compact_laser_count = 0; compatibility_flights.clear();
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
        values["strange_pending"] = export_strange();
        values["missile_attacks"] = missile_attacks;
        values["deferred"] = due; values["defence_time"] = defence_time;
        values["memory_elapsed"] = memory_elapsed; values["deferred_elapsed"] = deferred_elapsed; values["deferred_tick"] = deferred_tick;
        values["projectile_serial"] = int64_t(flight_serial); values["attack_serial"] = int64_t(attack_serial);
        values["instance_serial"] = int64_t(instance_serial); values["drop_uid"] = drop_uid;
        cancel(); debts.clear(); return values;
    }
    Variant deferred_total() const {
        CombatAmount total = 0;
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
    Variant projectile_views() {
        if (set_compact_laser_births(false) < 0) return Variant();
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
        return player_row.duplicate(true);
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
            row["shield"] = item.second[0];
            row["health"] = item.second[1];
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
    bool hit_handle(PackedInt64Array value, double raw, int type) {
        if (value.size() != 2 || !admitted || stopped || !combat_finite(raw) || raw < 0)
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
        if (!admitted || stopped || !combat_finite(raw) || raw < 0)
            return false;
        ++refit_epoch;
        player_hit(raw, type, clock);
        return true;
    }
    void cancel() {
        stopped = true;
        strange_pending.clear(); strange_serial = 0; retained_strange_damage = 0;
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
