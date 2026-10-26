// Encounter execution prototype. All mutable simulation fields below have one owner.
// Dictionaries are admission descriptors and persistent presentation rows only;
// no Object/Game callback occurs in advance, impact, death or chain execution.
#include <godot_cpp/classes/random_number_generator.hpp>
#include <limits>
#include <map>
#include <queue>
#include <set>
#include <tuple>
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
        Dictionary entry;
        int slot = 0, kind = 0, type = 0, salvo = 1, chain_count = 0;
        double speed = 0, interval = 0, charge = 0, ramp = 1, maximum = 1;
        double repeat_delay = 0, repeat_multiplier = 1;
        bool proficiency_pierce = false;
        double pierce_resistance = 0;
    };
    struct Weapon {
        int kind = 0, type = 0, slot = 0;
        bool hostile = false, endless = false, vacant = false, enabled = true, configured = true;
        Handle source;
        double interval = 1, normal_interval = 1, base_interval = 1;
        int normal_chain_count = 0;
        double remaining = 1;
        Amount base = 1;
        double factor = 1;
        double speed = 30;
        double charge = 0;
        double ramp = 1;
        double maximum = 1, normal_maximum = 1;
        int salvo = 1;
        double crit_rate = 0, crit_multiplier = 2, repeat_probability = 0, repeat_multiplier = 1,
               secondary_probability = 0;
        int chain_count = 0;
        Vector2 muzzle, screen_muzzle;
        Dictionary entry;
        std::vector<Amount> branch_factors, external_factors;
        int64_t beam = -1, focus_uid = -1;
        double focus_since = 0, critical_until = 0;
        int critical_stacks = 0, critical_attacks = 0;
        std::shared_ptr<const BirthConfig> birth;
    };
    static std::shared_ptr<const BirthConfig> birth_config(const Weapon &w, Dictionary v, double delay) {
        auto b = std::make_shared<BirthConfig>();
        b->entry = w.entry.duplicate(true); b->entry.make_read_only();
        b->slot = w.slot; b->kind = w.kind; b->type = w.type;
        b->salvo = w.salvo; b->chain_count = w.chain_count; b->speed = w.speed; b->interval = w.interval;
        b->charge = w.charge; b->ramp = w.ramp; b->maximum = w.maximum;
        b->repeat_delay = delay; b->repeat_multiplier = w.repeat_multiplier; b->proficiency_pierce = v.get("proficiency_pierce", false); b->pierce_resistance = v.get("pierce_resistance", 0.0); return b;
    }
    Weapon committed_weapon(int wi, const std::shared_ptr<const BirthConfig> &b) const {
        Weapon w = weapons[wi];
        w.kind = b->kind; w.type = b->type; w.salvo = b->salvo; w.chain_count = b->chain_count;
        w.speed = b->speed; w.interval = b->interval; w.charge = b->charge;
        w.ramp = b->ramp; w.maximum = b->maximum; return w;
    }
    struct MissileContext {
        String source;
        bool derived = false, wild = false, wild_used = false;
        double blast = 0;
        bool guidance_enabled = false, guidance_limited = false;
        int64_t guidance_limit = 0;
        Amount guidance_multiplier = 1;
        std::map<int64_t, Amount> factors;
    };
    struct Attack {
        Amount damage = 0;
        bool critical = false, critical_bonus_applied = false, secondary = false, repeats = false, higgs = false;
        double higgs_width = 0;
        bool strange_enabled = false;
        double strange_probability = 0, strange_delay = 0, strange_multiplier = 0;
        int strange_kill_spawns = 0, strange_type = 0;
        std::shared_ptr<MissileContext> context;
        std::shared_ptr<const BirthConfig> birth;
    };
    struct Instance {
        std::shared_ptr<const Attack> attack;
        bool chain_used = false, beam = false, ended = false, derived = false;
        int count = 0;
        Handle primary;
        std::vector<Handle> links;
    };
    struct Flight {
        uint32_t generation = 1;
        bool live = false, hostile = false, beam = false, repeated = false, chain = false, prism = false;
        size_t active_index = 0, beam_index = 0;
        bool target_lost = false;
        uint64_t born_step = 0, serial = 0, contact_order = 0;
        int weapon = -1, type = 0, source_slot = 0;
        int64_t source_uid = 0;
        Handle source, target;
        std::shared_ptr<Instance> instance;
        std::shared_ptr<MissileContext> context;
        Amount damage = 0;
        double cruise_speed = 0;
        double age = 0;
        double next_hit = 0;
        double charge = 0;
        double interval = 0;
        double ramp = 1;
        double maximum = 1;
        int ticks = 0;
        Vector2 aim;
        bool await_target = false;
        bool fixed_ray = false;
        Vector2 ray_origin, ray_step, launch_point;
        uint64_t contact_revision = 0;
        double contact_distance = -1;
        Ref<SpaceMotionLease> lease;
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
        std::vector<Amount> branch_factors, external_factors;
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
        Amount cover;
        double cover_next = 0, cover_until = 0, protection_until = 0, protection_lockout = 0;
        int protection_type = 0;
        std::map<int64_t, int> source_stacks;
    };
    struct Effect {
        int kind = 0, type = 0;
        bool critical = false, critical_bonus_applied = false, hostile = false;
        double time = 0;
        Vector2 point, direction;
        Amount damage = 0;
        Dictionary drop;
    };
    // Optional observation. Combat never reads this ledger.
    bool damage_stats_enabled = false;
    int damage_receipts_emitted = 0;
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
    Dictionary enhancement_effects, enhancement_rules;
    Array equipped_drone_rows;
    std::vector<std::array<Amount, 2>> drone_global_values;
    std::array<Amount, 2> active_drone_globals{Amount(1), Amount(1)};
    Dictionary legendary_definitions, legendary_constants, selected_legends;
    std::set<String> disabled_drones;
    int rebuild_count = 0;
    uint64_t rebuild_epoch = 0;
    double rebuild_bonus = 0, dodge_ready_at = 0, black_next_at = 0, black_until = 0;
    Amount black_accumulated, black_release, iron_drop_factor = 1;
    uint64_t black_release_order = 0;
    double rail_trail_width = 0, higgs_minimum_width = 0;
    double memory_reduction_until = 0, deferred_reduction_until = 0;
    double deferred_unforced_probability = 0;
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

    std::deque<Flight> flights;
    std::vector<size_t> active, active_beams, free_flights, retired;
    RootQueue roots;
    std::priority_queue<Timed, std::vector<Timed>, Later> ejections, repeats;
    std::vector<Effect> feedback;
    std::shared_ptr<MotionArena> motion_arena = std::make_shared<MotionArena>();
    Ref<RandomNumberGenerator> rng;
    mutable Array actor_view_rows;
    mutable std::set<size_t> actor_view_changes;
    Dictionary player_row;
    Vector2 player_point;
    PackedVector2Array player_collision_hull;
    double target_slot_center = 0, battle_width = 0, battle_height = 0;
    double missile_departure_angle = 0, missile_launch_edge_margin = 0, missile_launch_forward_y = 0;
    uint32_t encounter_generation = 1;
    uint64_t step_serial = 0, event_serial = 0, flight_serial = 0;
    uint64_t contact_serial = 0;
    uint64_t next_contact_order() {
        if (contact_serial == std::numeric_limits<uint64_t>::max()) throw std::overflow_error("ContactOrderRangeExceeded");
        return ++contact_serial;
    }
    double clock = 0;
    Amount player_hp = 0;
    Amount player_shield = 0;
    double resistance = 0.5;
    double reactive_volley_window = 0, reactive_stack_seconds = 0, reactive_per_stack = 0;
    int reactive_stack_limit = 0;
    double projectile_min_x = 0, projectile_max_x = 0, projectile_min_y = 0, projectile_max_y = 0;
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
    std::shared_ptr<MissileContext> missile_context(const Weapon &w, bool derived,
                                                    const std::shared_ptr<MissileContext> &birth = {}) {
        auto c = std::make_shared<MissileContext>();
        c->source = birth ? birth->source : w.entry.has("drone_id") ? String("drone:") + String(w.entry["drone_id"]) : String("module:") + String::num_int64(w.slot);
        c->guidance_enabled = birth ? birth->guidance_enabled : guidance_enabled;
        c->guidance_limited = birth ? birth->guidance_limited : guidance_limited;
        c->guidance_limit = birth ? birth->guidance_limit : guidance_limit;
        c->guidance_multiplier = birth ? birth->guidance_multiplier : Amount(guidance_multiplier);
        c->derived = derived; return c;
    }
    struct StrangePacket {
        uint64_t order = 0;
        Amount damage = 0;
        int type = 0, source_slot = 0;
        String source;
    };
    // Same deadline/source/serial ordering as ordinary contacts; new packets
    // enter the timeline at the originating hit time plus the configured delay.
    std::map<std::tuple<double, int, uint64_t>, StrangePacket> strange_pending;
    bool strange_enabled = false;
    double strange_probability = 0, strange_delay = 0, strange_multiplier = 0;
    int strange_kill_spawns = 0, strange_type = 0;
    void settle_strange(const StrangePacket &packet, double at) {
        for (size_t i = 0; i < actors.size(); ++i) {
            if (stopped || final_cleared) break;
            if (!actors[i].live) continue;
            // Derived area damage never rolls another primary strange-matter trigger.
            hit_enemy(handle(i), packet.damage, packet.type, {}, false, at, -1, false, {}, packet.source);
        }
    }
    double ejection_gap = 0.12, launch_speed = 120, turn_rate = 4, ignition = 0.22, seek = 0.4,
           cruise_at = 0.65, lifetime = 4.5, orphan_lifetime = 30, brake_range = 120, brake_angle = 0.3,
           min_speed = 60, brake_factor = 0.7, hit_radius = 5, chain_speed = 720;
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
    static bool numeric_fields(Dictionary values, std::initializer_list<const char *> keys, bool decode_amounts = true) {
        for (const char *key : keys) {
            if (!values.has(key))
                continue;
            Variant value = values[key];
            const std::string field(key);
            if (field == "hp" || field == "max_hp" || field == "armour" || field == "shield" || field == "max_shield" || field == "damage" || field == "amount" || field == "base" || field == "loss" || field == "buffer" || field == "maximum") {
                if (decode_amounts) {
                    try { read_amount(value); } catch (const std::exception &) { return false; }
                } else if (value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT &&
                           value.get_type() != Variant::STRING && value.get_type() != Variant::DICTIONARY) return false;
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
    static bool configuration_schema(Dictionary d, bool decode_modules = true) {
        if (!finite_descriptor(d) || !schema_required(d, {"player","enemies","weapons","target_slot_center"}) ||
            !schema_types(d, Variant::DICTIONARY, {"player","deferred"}) ||
            !schema_types(d, Variant::ARRAY, {"enemies","weapons","defences","unsupported_rules"}) ||
            !schema_types(d, Variant::BOOL, {"final_encounter","drop_rules_compiled","requires_drop_rules"}) ||
            !schema_integers(d, {"chain_count"}) ||
            !schema_integers(d, {"rng_state","projectile_serial","deferred_tick","drop_uid","attack_counter","incoming_counter","counter_level","reactive_stack_limit"}, false) ||
            !numeric_fields(d, {"reactive_volley_window","reactive_stack_seconds","reactive_per_stack","projectile_min_x","projectile_max_x","projectile_min_y","projectile_max_y","target_slot_center","battle_width","missile_departure_angle","missile_launch_edge_margin","missile_launch_forward_y","clock","ejection_gap","launch_speed","turn_rate","ignition","seek","cruise_at","lifetime","orphan_lifetime","brake_range","brake_angle","min_speed","brake_factor","hit_radius","chain_speed","resistance","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","repeat_delay","secondary_probability","counter_growth","defence_counter_growth","counter_log_base","counter_round_scale","memory_interval","deferred_interval","deferred_duration","clear_probability","defence_time","memory_elapsed","deferred_elapsed","jewel_probability","jewel_ratio"})) return false;
        if (!Array(d.get("unsupported_rules", Array())).is_empty() ||
            !schema_nonnegative(d, {"launch_speed","turn_rate","ignition","seek","lifetime","orphan_lifetime","brake_range","brake_angle","min_speed","brake_factor","hit_radius","critical_multiplier","repeat_multiplier","repeat_delay","attack_counter","incoming_counter","counter_growth","defence_counter_growth","counter_level","deferred_duration","defence_time","memory_elapsed","deferred_elapsed","jewel_ratio","chain_count","projectile_serial","deferred_tick","drop_uid"}) ||
            !schema_probabilities(d, {"resistance","critical_rate","repeat_probability","secondary_probability","clear_probability","jewel_probability"})) return false;
        if (!schema_integers(d, {"strange_damage_type","wild_damage_type"}) ||
            !schema_nonnegative(d, {"strange_damage_type","wild_damage_type"}) ||
            int(d.get("strange_damage_type",0)) > 2 || int(d.get("wild_damage_type",0)) > 2 ||
            !schema_integers(d, {"missile_attacks"}, false) ||
            !schema_nonnegative(d, {"missile_attacks"}) || double(d.get("missile_attacks",0)) >= 9007199254740991.0) return false;
        double mi = d.get("memory_interval", 1.0), di = d.get("deferred_interval", 1.0);
        double lb = d.get("counter_log_base", 10.0);
        if (double(d.get("chain_speed",720.0)) <= 0 || double(d.get("ejection_gap", .12)) <= 0 || double(d.get("cruise_at", .65)) <= double(d.get("ignition", .22)) ||
            mi <= 1e-9 || di <= 1e-9 || double(d.get("memory_elapsed", 0.0)) >= mi ||
            double(d.get("deferred_elapsed", 0.0)) >= di || lb <= 0 || lb == 1 ||
            double(d.get("counter_round_scale", 10.0)) <= 0) return false;
        Dictionary player = d["player"];
        if (!numeric_fields(player, {"x","y"})) return false;
        Array enemies = d["enemies"], weapons = d["weapons"], defs = d.get("defences", Array());
        if (bool(d.get("requires_drop_rules", false)) && !bool(d.get("drop_rules_compiled", false))) return false;
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
        for (int i = 0; i < weapons.size(); ++i) {
            if (Variant(weapons[i]).get_type() != Variant::DICTIONARY) return false;
            Dictionary v = weapons[i];
            if (!schema_required(v, {"kind"}) || !schema_integers(v, {"kind","type","slot","source","salvo","chain_count"}) ||
                !schema_types(v, Variant::BOOL, {"hostile"}) || !schema_types(v, Variant::VECTOR2, {"muzzle"}) ||
                !schema_types(v, Variant::DICTIONARY, {"entry"}) || !schema_types(v, Variant::ARRAY, {"branch_factors","external_factors"}) ||
                !numeric_fields(v, {"damage","factor","interval","remaining","speed","charge","ramp","maximum","critical_rate","critical_multiplier","repeat_probability","repeat_multiplier","secondary_probability"}, decode_modules) ||
                !schema_nonnegative(v, {"damage","factor","ramp","maximum","critical_multiplier","repeat_multiplier","chain_count","slot"}) ||
                !schema_probabilities(v, {"critical_rate","repeat_probability","secondary_probability"})) return false;
            int kind = v["kind"], source = v.get("source", -1);
            if (kind < 0 || kind > 3 || int(v.get("type",1)) < 0 || int(v.get("type",1)) > 2 || double(v.get("interval", 1.0)) <= 0 || double(v.get("speed", 720.0)) <= 0 ||
                int(v.get("salvo", 1)) < 1 || (bool(v.get("hostile", false)) && (source < 0 || source >= enemies.size()))) return false;
        }
        for (int i = 0; i < defs.size(); ++i) {
            if (Variant(defs[i]).get_type() != Variant::DICTIONARY) return false;
            Dictionary v = defs[i];
            if (!schema_types(v, Variant::DICTIONARY, {"entry"}) || !schema_types(v, Variant::ARRAY, {"branch_factors","external_factors"}) || !schema_integers(v, {"layer","type"}) ||
                !numeric_fields(v, {"base","factor","maximum","loss","buffer","delay","rate","last_hit","memory_heal","memory_cap","deferred_fraction"}, decode_modules) ||
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
    static std::vector<Amount> read_factors(Array values) {
        std::vector<Amount> result; result.reserve(values.size());
        for (int i = 0; i < values.size(); ++i) result.push_back(read_amount(values[i]));
        return result;
    }
    static Amount evaluate_module_value(const Amount &charged, int64_t count, double growth, int64_t level, double log_base, double round_scale,
            const std::vector<Amount> &branches = {}, const std::vector<Amount> &external = {}) {
        Amount value = (charged * (Amount(1) + history_bonus(count, growth, level, log_base, round_scale))).ceil_value();
        for (const Amount &factor : branches) value *= factor;
        for (const Amount &factor : external) value *= factor;
        return value;
    }
    static bool configuration_arithmetic(Dictionary d, int64_t attacks, int64_t incoming,
            const std::vector<Weapon> &sources, const std::vector<Defence> &modules) {
        try {
            double log_base = d.get("counter_log_base", 10.0), scale = d.get("counter_round_scale", 100.0);
            int64_t level = d.get("counter_level", int64_t(0));
            history_bonus(attacks, d.get("counter_growth", 0.0), level, log_base, scale);
            history_bonus(incoming, d.get("defence_counter_growth", 0.0), level, log_base, scale);
            for (const Weapon &w : sources) {
                Amount value = w.hostile ? w.base : evaluate_module_value(w.base, attacks,
                    d.get("counter_growth", 0.0), level, log_base, scale, w.branch_factors, w.external_factors);
                value *= w.factor;
            }
            for (const Defence &module : modules) {
                Amount value = evaluate_module_value(module.base, incoming, d.get("defence_counter_growth", 0.0),
                    level, log_base, scale, module.branch_factors, module.external_factors);
                value *= module.factor;
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
    void effect(int kind, const Flight &f, Vector2 point, double at) {
        Effect e;
        e.kind = kind; e.type = f.type; e.hostile = f.hostile;
        e.critical = f.instance && f.instance->attack->critical;
        e.critical_bonus_applied = f.instance && f.instance->attack->critical_bonus_applied;
        e.time = at; e.point = point;
        e.direction = f.lease.is_valid() ? f.lease->motion().direction : Vector2(0, -1);
        feedback.push_back(e);
    }
    std::shared_ptr<Instance> instance(std::shared_ptr<const Attack> a, bool beam = false) {
        auto i = std::make_shared<Instance>();
        i->attack = a;
        i->count = a->birth->chain_count;
        i->beam = beam;
        return i;
    }
    void retire(size_t id) {
        Flight &f = flights[id];
        if (!f.live)
            return;
        f.live = false;
        if (f.beam) {
            active_beams[f.beam_index] = active_beams.back();
            flights[active_beams.back()].beam_index = f.beam_index;
            active_beams.pop_back();
        }
        retired.push_back(id);
        if (f.beam && f.weapon >= 0 && weapons[f.weapon].beam == int64_t(id)) {
            weapons[f.weapon].beam = -1;
            if (!stopped)
                roots.push({clock, ++event_serial, 0, f.weapon});
        }
        if (f.instance && f.beam) f.instance->ended = true;
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
            f.lease.unref();
            f.instance.reset();
            f.context.reset();
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
        f.source_uid = w.hostile && w.source.index < actors.size() ? actors[w.source.index].uid : 0;
        f.source_slot = w.hostile && w.source.index < actors.size() ? actors[w.source.index].slot : w.slot;
        f.instance = inst;
        if (!w.hostile && w.kind == 2) f.context = missile_ctx ? missile_ctx : (chain || repeated ? missile_context(w,true,inst->attack->context) : inst->attack->context);
        f.damage = inst->attack->damage * multiplier;
        f.repeated = repeated || inst->derived;
        f.chain = chain;
        f.beam = w.kind == 3 && !chain;
        f.serial = ++flight_serial;
        f.contact_order = next_contact_order();
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
        f.lease = lease;
        Vector2 from = chain ? origin : w.muzzle;
        Actor *t = resolve(target);
        f.target_lost = !w.hostile && !t;
        Vector2 aim = w.hostile ? player_point
                      : t       ? t->point
                                : from + Vector2(0, -100);
        m.x = from.x;
        m.y = from.y;
        m.direction = unit(aim - from);
        m.speed = chain ? chain_speed : w.speed;
        f.aim = aim;
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
        f.launch_point = from;
        if (!w.hostile && m.kind == 0 && t && t->collision_hull.size() >= 3) {
            f.fixed_ray = true; f.ray_origin = w.screen_muzzle;
            f.ray_step = (t->screen_point - w.screen_muzzle) / maximum(0.001, distance(from, aim));
            if (!f.beam && t->stationary_geometry) refresh_ray_contact(f, *t);
        }
        if (f.beam) {
            f.beam_index = active_beams.size(); active_beams.push_back(id);
            f.charge = w.charge;
            f.interval = w.interval;
            f.ramp = w.ramp;
            f.maximum = w.maximum;
            f.next_hit = f.charge >= 0 ? f.charge : f.interval;
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
            for (Handle h : candidates)
                if (h.index != target.index && int(inst->links.size()) < inst->count) inst->links.push_back(h);
        }
        if (!chain) effect(0, f, from, clock);
        return id;
    }
    void hit_enemy(Handle h, Amount raw, int type, const std::shared_ptr<Instance> &inst, bool trigger,
                   double at, int wi, bool chain_trigger = false, const std::shared_ptr<MissileContext> &context = {},
                   const String &damage_source = String(), bool bypass_absorption = false) {
        Actor *a = resolve(h);
        if (!a) {

            return;
        }
        shield(*a, at);
        const Amount base_raw = raw;
        if (context && context->guidance_enabled) {
            auto found = context->factors.find(a->uid);
            if (found == context->factors.end()) {
                Amount factor = context->guidance_multiplier.power_integer(uint64_t(a->guidance_layers));
                found = context->factors.emplace(a->uid,factor).first;
                if (!context->derived) {
                    a->guidance_layers = context->guidance_limited ? minimum(a->guidance_layers+1,context->guidance_limit) : a->guidance_layers+1;
                }
            }
            raw *= found->second;
        }
        String source = damage_source;
        if (source.is_empty() && context) source = context->source;
        if (source.is_empty() && inst && inst->attack && inst->attack->birth) {
            const BirthConfig &birth = *inst->attack->birth;
            source = birth.entry.has("drone_id") ? String("drone:") + String(birth.entry["drone_id"])
                : String("module:") + String::num_int64(birth.slot);
        }
        if (source.is_empty()) source = "other";
        if (!bypass_absorption && black_absorbing()) {
            black_accumulated += raw;

            return;
        }
        a->hit_at = at;
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
        }
        double effective_resistance = inst && inst->attack && inst->attack->birth && inst->attack->birth->proficiency_pierce ? inst->attack->birth->pierce_resistance : resistance;
        Amount incoming = raw * (1 + a->interference);
        Amount absorbed = 0;
        Amount damage = 0;
        const Amount hp_before = a->hp;
        const Amount shield_before = a->shield;
        if (a->shield > 0) {
            double factor = type > 0 && type == a->shield_type ? 1 - effective_resistance : 1;
            absorbed = minimum(a->shield, maximum(1.0, incoming * factor));
            a->shield -= absorbed;
            incoming = factor > 0 ? incoming - absorbed / factor : 0;
        }
        if (absorbed <= 0 || incoming > 0) {
            damage = maximum(1.0, ceil_number(incoming * (type > 0 && type == a->armour_type ? 1 - effective_resistance : 1)));
            a->hp -= damage;
        }
        if (damage_stats_enabled) {
            const Amount shield_loss = shield_before - a->shield;
            const Amount hp_loss = hp_before - a->hp;
            if (shield_loss > 0 || hp_loss > 0) {
                auto &sum = damage_stats[source];
                sum[0] += shield_loss;
                sum[1] += hp_loss;
                if (damage_receipts_emitted < 64) {
                    Effect receipt;
                    receipt.kind = 8; receipt.type = type; receipt.time = at;
                    receipt.point = a->point; receipt.damage = shield_loss + hp_loss;
                    receipt.critical = inst && inst->attack && inst->attack->critical;
                    receipt.critical_bonus_applied = inst && inst->attack && inst->attack->critical_bonus_applied;
                    feedback.push_back(receipt);
                    ++damage_receipts_emitted;
                }
            }
        }
        if (a->hp != hp_before) { a->view["hp"] = wire(a->hp); actor_view_changes.insert(h.index); }

        if (inst && inst->attack && inst->attack->strange_enabled && trigger) {
            const Attack &birth = *inst->attack;
            int count = a->hp <= 0 ? birth.strange_kill_spawns : (rng->randf() < birth.strange_probability ? 1 : 0);
            for (int i = 0; i < count; ++i) {
                StrangePacket p;
                p.order = next_contact_order();
                p.damage = raw * birth.strange_multiplier; p.type = birth.strange_type;
                p.source = source; p.source_slot = birth.birth->slot;
                strange_pending.emplace(std::make_tuple(at + birth.strange_delay, p.source_slot, p.order), p);
            }
        }
        // Birth freezes base damage and blast fraction; impact uses the current missile damage type, as Game does.
        if (context && context->wild && !context->wild_used) {

            context->wild_used = true; // Shared context is marked before recursive AoE.
            for (size_t i = 0; i < actors.size(); ++i)
                if (actors[i].live && actors[i].hp > 0)
                    hit_enemy(handle(i),base_raw*context->blast,wild_damage_type,{},false,at,wi,false,context,damage_source);
        }
        Vector2 origin = a->point;
        if (a->hp <= 0 && a->live) {
            a->guidance_layers = 0;
            a->live = false;
            a->view["dead"] = true;
            ++a->generation;

            for (Defence &defence : defences) defence.source_stacks.erase(a->uid);
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
                        birth.drop = drop;
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
                        drop["amount"] = wire(ceil_number(rule.amount * (rule.resource == 1 ? iron_drop_factor : Amount(1))));
                        drop["production_base"] = wire(ceil_number(rule.base * (rule.resource == 1 ? iron_drop_factor : Amount(1))));
                        Effect birth;
                        birth.kind = 7;
                        birth.time = at;
                        birth.drop = drop;
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
                    f.await_target = true;
                    // Keep links until this hit finishes its inherited chain work.
                }
                if (f.live && f.beam && f.hostile && f.source.index == h.index && f.source.generation == h.generation)
                    retire(id);

            }
        }
        // Death/attack triggers stay gated by trigger; an independent chain allowance
        // does not grant those decisions to repeats, secondary copies or chain hops.
        if ((trigger || chain_trigger) && inst && !inst->ended) {
            if (inst->beam) {
                if (inst->primary.index == h.index && inst->primary.generation == h.generation)
                    for (Handle link : inst->links)
                        hit_enemy(link, raw, type, inst, false, at, wi);
            } else if (!inst->chain_used) {
                inst->chain_used = true;
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
        strange_pending.clear(); black_accumulated = black_release = 0;
        // Completion is committed before any later boundary carrier can hit.
        for (size_t id : active) retire(id);
        while (!roots.empty()) roots.pop();
        while (!ejections.empty()) ejections.pop();
        while (!repeats.empty()) repeats.pop();
    }
    bool branch(const char *name, const char *node) const {
        Dictionary effect = enhancement_effects.get(name, Dictionary()); return effect.get("active", false) && bool(effect.get(node, false));
    }
    double enhancement_rule(const char *name) const { return enhancement_rules.get(name, 0.0); }
    void configure_enhancement(Dictionary descriptor, bool partial = false) {
        Dictionary state = descriptor.get("enhancement_state", Dictionary()), effects = state.get("effects", Dictionary());
        if (partial) { Array keys = effects.keys(); for (int i = 0; i < keys.size(); ++i) enhancement_effects[keys[i]] = Dictionary(effects[keys[i]]).duplicate(); }
        else { enhancement_effects = effects.duplicate(true); enhancement_rules = Dictionary(state.get("rules", Dictionary())).duplicate(true); }
        deferred_unforced_probability = descriptor.get("clear_probability", partial ? deferred_unforced_probability : 0.0);
        clear_probability = branch("deferred", "b3") ? enhancement_rule("deferred_b3_forced_probability") : branch("deferred", "b2") ? 0.0 : deferred_unforced_probability;
        if (!partial || effects.has("proficiency") || effects.has("critical")) for (Weapon &w : weapons) if (!w.hostile && w.configured && !w.vacant) {
            if ((!partial || effects.has("proficiency")) && !branch("proficiency", "b1")) w.focus_uid = -1;
            if (!partial || effects.has("critical")) {
                if (!branch("critical", "b1")) w.critical_attacks = 0;
                if (!branch("critical", "b2")) { w.critical_stacks = 0; w.critical_until = 0; }
            }
        }
        if (!partial || effects.has("adaptation") || effects.has("memory")) for (Defence &d : defences) {
            if (!partial || effects.has("adaptation")) {
                if (!branch("adaptation", "b1")) d.source_stacks.clear();
                if (!branch("adaptation", "b2")) { d.cover = 0; d.cover_next = d.cover_until = 0; }
                else if (d.cover_next <= 0) d.cover_next = defence_time + enhancement_rule("adaptation_b2_interval");
            }
            if ((!partial || effects.has("memory")) && !branch("memory", "b2")) { d.protection_type = 0; d.protection_until = d.protection_lockout = 0; }
        }
        if ((!partial || effects.has("memory")) && !branch("memory", "b1")) memory_reduction_until = 0;
        if ((!partial || effects.has("deferred")) && !branch("deferred", "b1")) deferred_reduction_until = 0;
    }
    void enhance_weapon(Weapon &w, Dictionary changes) const {
        if (changes.has("branch_factors")) w.branch_factors = read_factors(changes["branch_factors"]);
        if (changes.has("interval_multiplier")) { w.normal_interval = w.base_interval * double(changes["interval_multiplier"]); w.interval = w.normal_interval / (1.0 + drone_scalar("attack_speed_bonus")); }
        if (changes.has("chain_count")) {
            const int64_t count = changes["chain_count"]; const double combined = double(count) + drone_scalar("chain_count_bonus");
            if (count < 0 || combined > std::numeric_limits<int>::max() || combined != std::floor(combined)) throw std::domain_error("InvalidChainCount");
            w.normal_chain_count = int(count); w.chain_count = int(combined);
        }
        w.crit_rate = changes.get("critical_rate", w.crit_rate); w.crit_multiplier = changes.get("critical_multiplier", w.crit_multiplier);
        w.repeat_probability = changes.get("repeat_probability", w.repeat_probability); w.repeat_multiplier = changes.get("repeat_multiplier", w.repeat_multiplier);
        w.secondary_probability = changes.get("secondary_probability", w.secondary_probability);
        if (w.interval <= 0 || !finite(w.interval) || clock + w.interval <= clock) throw std::domain_error("InvalidWeaponInterval");
        if (changes.has("interval_multiplier") || changes.has("chain_count") || changes.has("repeat_multiplier") || changes.has("proficiency_pierce") || changes.has("pierce_resistance")) {
            auto birth = std::make_shared<BirthConfig>(*w.birth); birth->interval = w.interval; birth->chain_count = w.chain_count; birth->repeat_multiplier = w.repeat_multiplier;
            birth->proficiency_pierce = changes.get("proficiency_pierce", birth->proficiency_pierce); birth->pierce_resistance = changes.get("pierce_resistance", birth->pierce_resistance); w.birth = birth;
        }
    }
    bool legend_active(const char *key) const { return selected_legends.has(key); }
    double legend_constant(const char *key, const char *parameter) const {
        Dictionary constants = legendary_constants.get(key, Dictionary()); return constants.get(parameter, 0.0);
    }
    double legend_value(const char *key, const char *parameter) const {
        Dictionary source = selected_legends.get(key, Dictionary());
        Dictionary parameters = source.get("legendary_parameters", Dictionary()); return parameters.get(parameter, 0.0);
    }
    void select_endless_source() {
        int selected = -1;
        for (int i = 0; i < int(weapons.size()); ++i) {
            const Weapon &w = weapons[i];
            if (w.hostile || w.vacant || !w.enabled || w.kind != 3 || w.entry.has("drone_id")) continue;
            if (selected < 0 || int64_t(w.entry.get("paid_level", 1)) > int64_t(weapons[selected].entry.get("paid_level", 1)) ||
                (w.entry.get("paid_level", 1) == weapons[selected].entry.get("paid_level", 1) && w.slot < weapons[selected].slot)) selected = i;
        }
        for (int i = 0; i < int(weapons.size()); ++i) {
            Weapon &w = weapons[i];
            if (w.hostile || w.vacant || !w.enabled || w.kind != 3) continue;
            bool endless = legend_active("endless_beam") && i == selected;
            double maximum = w.normal_maximum + (endless ? legend_value("endless_beam", "maximum_multiplier_bonus") : 0.0);
            if (w.endless == endless && w.maximum == maximum) continue;
            w.endless = endless; w.maximum = maximum;
            if (w.birth) { auto updated = std::make_shared<BirthConfig>(*w.birth); updated->maximum = maximum; w.birth = updated; }
        }
    }
    void select_legends() {
        std::array<Amount, 2> sums{};
        for (int i = 0; i < equipped_drone_rows.size(); ++i) {
            Dictionary row = equipped_drone_rows[i];
            if (disabled_drones.count(String(row.get("id", "")))) continue;
            sums[0] += drone_global_values[i][0]; sums[1] += drone_global_values[i][1];
        }
        for (int layer = 0; layer < 2; ++layer)
            active_drone_globals[layer] = (Amount(1) + sums[layer]) * (1.0 + rebuild_bonus);
        Dictionary previous_black = selected_legends.get("black_hole", Dictionary());
        String previous_black_id = previous_black.get("id", "");
        const bool had_black_hole = legend_active("black_hole");
        selected_legends.clear();
        for (int i = 0; i < equipped_drone_rows.size(); ++i) {
            Dictionary row = equipped_drone_rows[i]; String id = row.get("id", "");
            if (disabled_drones.count(id)) continue;
            String key = row.get("legendary_effect", "");
            if (!legendary_definitions.has(key)) continue;
            Dictionary definition = legendary_definitions[key], parameters = row.get("legendary_parameters", Dictionary());
            String score_key = definition.get("score_parameter_note", "");
            Dictionary old = selected_legends.get(key, Dictionary()), old_parameters = old.get("legendary_parameters", Dictionary());
            double score = parameters.get(score_key, 0.0), old_score = old_parameters.get(score_key, 0.0);
            if (old.is_empty() || score > old_score || (score == old_score && id < String(old.get("id", "")))) selected_legends[key] = row;
        }
        Dictionary current_black = selected_legends.get("black_hole", Dictionary());
        if (legend_active("black_hole") && (!had_black_hole || previous_black_id != String(current_black.get("id", "")))) {
            black_next_at = clock + legend_constant("black_hole", "period"); black_until = 0; black_accumulated = black_release = 0;
        }
        if (!legend_active("black_hole")) { black_until = black_next_at = 0; black_accumulated = black_release = 0; }
        scatter = legend_active("scatter_pulse"); scatter_bonus = legend_value("scatter_pulse", "single_target_bonus");
        guidance_enabled = legend_active("precise_guidance"); guidance_multiplier = legend_constant("precise_guidance", "stack_multiplier");
        guidance_limited = legend_constant("precise_guidance", "stack_limit_enabled") != 0; guidance_limit = int64_t(legend_constant("precise_guidance", "stack_limit"));
        wild_enabled = legend_active("wild_missile"); wild_multiplier = legend_value("wild_missile", "damage_multiplier");
        wild_period = int64_t(legend_constant("wild_missile", "attack_period")); wild_blast = legend_constant("wild_missile", "blast_fraction");
        prism_count = legend_active("prism_tower") ? int(legend_constant("prism_tower", "nearby_targets")) : 0;
        prism_bonus = legend_value("prism_tower", "maximum_multiplier_bonus");
        strange_enabled = legend_active("strange_matter"); strange_probability = legend_constant("strange_matter", "spawn_probability");
        strange_delay = legend_constant("strange_matter", "delay"); strange_multiplier = legend_value("strange_matter", "damage_multiplier");
        strange_kill_spawns = int(legend_constant("strange_matter", "kill_spawns"));
        int laser_sources = 0;
        for (const Weapon &w : weapons) if (!w.hostile && !w.vacant && w.enabled && w.kind == 0) ++laser_sources;
        laser_charge_multiplier = legend_active("laser_charge") ? 1.0 + minimum(legend_value("laser_charge", "maximum_bonus"), laser_sources * legend_constant("laser_charge", "bonus_per_laser")) : 1.0;
        select_endless_source();
        for (Weapon &w : weapons) if (!w.hostile && w.enabled && w.birth) {
            auto updated = std::make_shared<BirthConfig>(*w.birth); updated->maximum = w.maximum;
            w.interval = w.normal_interval / (1.0 + drone_scalar("attack_speed_bonus"));
            w.chain_count = w.normal_chain_count + int(drone_scalar("chain_count_bonus"));
            updated->interval = w.interval; updated->chain_count = w.chain_count; w.birth = updated;
        }
    }
    void configure_legends(Dictionary descriptor, const std::vector<std::array<Amount, 2>> &globals) {
        drone_global_values = globals;
        equipped_drone_rows = Array(descriptor.get("equipped_drones", Array())).duplicate(true);
        legendary_definitions = Dictionary(descriptor.get("legendary_definitions", Dictionary())).duplicate(true);
        legendary_constants = Dictionary(descriptor.get("legendary_constants", Dictionary())).duplicate(true);
        rail_trail_width = descriptor.get("rail_trail_width", 0.0); higgs_minimum_width = descriptor.get("higgs_minimum_width", 0.0);
        iron_drop_factor = read_amount(descriptor.get("iron_drop_factor", String("1")));
        strange_type = descriptor.get("strange_damage_type", strange_type);
        wild_damage_type = descriptor.get("wild_damage_type", wild_damage_type);
        select_legends();
    }
    // Contributions are resolved per entity; rebuild removes that entity's whole contribution.
    // Existing Attacks retain their immutable birth values.
    double drone_scalar(const char *field) const {
        double total = 0;
        for (int i = 0; i < equipped_drone_rows.size(); ++i) {
            Dictionary row = equipped_drone_rows[i];
            if (!disabled_drones.count(String(row.get("id", "")))) total += double(row.get(field, 0.0));
        }
        return total;
    }
    Amount drone_weapon(int kind) const {
        const char *fields[] = {"laser_damage_bonus", "cannon_damage_bonus", "missile_damage_bonus", "long_laser_damage_bonus"};
        return drone_global(false) * (1.0 + drone_scalar(fields[kind]));
    }
    Amount drone_defence(int layer) const {
        return drone_global(true) * (1.0 + drone_scalar(layer == 0 ? "shield_capacity_bonus" : "armour_capacity_bonus"));
    }
    Amount drone_global(bool defence) const { return active_drone_globals[defence ? 1 : 0]; }
    double highest_drone_quality() const {
        double highest = 0;
        for (int i = 0; i < equipped_drone_rows.size(); ++i) {
            Dictionary row = equipped_drone_rows[i];
            if (disabled_drones.count(String(row.get("id", "")))) continue;
            String path = String("quality_ratios/") + String(row.get("quality", ""));
            highest = maximum(highest, legend_constant("drone_master", path.utf8().get_data()));
        }
        return highest;
    }
    void discard_disabled_tasks() {
        auto prune = [&](auto &queue) {
            std::vector<Timed> kept;
            while (!queue.empty()) {
                Timed event = queue.top(); queue.pop();
                if (weapons[event.weapon].enabled) kept.push_back(event);
            }
            for (const Timed &event : kept) queue.push(event);
        };
        prune(roots); prune(ejections); prune(repeats);
    }
    bool try_rebuild() {
        if (!legend_active("drone_rebuild") || rebuild_count >= int(legend_constant("drone_rebuild", "maximum_stacks"))) return false;
        Dictionary sacrifice; double lowest = std::numeric_limits<double>::infinity();
        for (int i = 0; i < equipped_drone_rows.size(); ++i) {
            Dictionary row = equipped_drone_rows[i]; String id = row.get("id", "");
            if (disabled_drones.count(id)) continue;
            String path = String("quality_ratios/") + String(row.get("quality", ""));
            double quality = legend_constant("drone_master", path.utf8().get_data());
            if (sacrifice.is_empty() || quality < lowest || (quality == lowest && id < String(sacrifice["id"]))) { sacrifice = row; lowest = quality; }
        }
        if (sacrifice.is_empty()) return false;
        String id = sacrifice["id"];
        rebuild_bonus += legend_value("drone_rebuild", "damage_and_defence_bonus");
        ++rebuild_count; ++rebuild_epoch; disabled_drones.insert(id);
        for (Weapon &w : weapons) if (String(w.entry.get("drone_id", "")) == id) w.enabled = false;
        for (size_t flight : active) if (flights[flight].live && flights[flight].beam && !weapons[flights[flight].weapon].enabled) retire(flight);
        discard_disabled_tasks();
        select_legends();
        reconcile_defence();
        for (Defence &d : defences) d.loss = 0;
        debts.clear(); publish_player();
        return player_hp > 0 || player_shield > 0;
    }
    void restore_drone_contributions(bool schedule = true) {
        if (disabled_drones.empty() && rebuild_count == 0) return;
        discard_disabled_tasks();
        std::vector<int> restored;
        for (int i = 0; i < int(weapons.size()); ++i) {
            Weapon &w = weapons[i]; String id = w.entry.get("drone_id", "");
            if (!id.is_empty() && disabled_drones.count(id) && w.configured && !w.vacant) {
                w.enabled = true; restored.push_back(i);
            }
        }
        disabled_drones.clear(); rebuild_count = 0; rebuild_bonus = 0; ++rebuild_epoch;
        select_legends();
        if (schedule) for (int i : restored) roots.push({clock + (weapons[i].kind == 3 ? 0 : weapons[i].interval), ++event_serial, 0, i});
        reconcile_defence(); publish_player();
    }
    bool black_absorbing() const { return legend_active("black_hole") && black_until > 0 && clock < black_until; }
    void advance_legend_timers() {
        if (!legend_active("black_hole")) return;
        if (black_until > 0 && clock + 1e-9 >= black_until) {
            black_release = black_accumulated * legend_value("black_hole", "damage_multiplier");
            black_accumulated = 0; black_until = 0; black_release_order = next_contact_order();
        }
        if (black_next_at > 0 && clock + 1e-9 >= black_next_at) {
            black_until = clock + legend_constant("black_hole", "absorption_duration");
            black_next_at = clock + legend_constant("black_hole", "period");
        }
    }
    void release_black_hole() {
        Amount raw = black_release; black_release = 0;
        if (raw <= 0) return;
        for (Handle target : targets(0, clock)) {
            if (stopped || final_cleared) break;
            hit_enemy(target, raw, 0, {}, false, clock, -1, false, {}, "black_hole", true);
        }
    }
    bool dodge_incoming() {
        if (!legend_active("dodge_counter")) return false;
        double chance = 0; std::vector<int> sources;
        for (int i = 0; i < int(weapons.size()); ++i) {
            Weapon &w = weapons[i];
            if (w.hostile || !w.enabled || w.vacant) continue;
            double original = std::clamp(w.crit_rate + (branch("critical", "b2") && clock < w.critical_until ? w.critical_stacks * enhancement_rule("critical_b2_probability") : 0.0), 0.0, 1.0);
            double probability = branch("critical", "b3") ? 1.0 : original;
            chance = maximum(chance, minimum(1.0, probability + drone_scalar("critical_rate_bonus")));
            sources.push_back(i);
        }
        const bool rolled = rng->randf() < minimum(chance, legend_value("dodge_counter", "maximum_dodge"));
        if (!rolled || clock < dodge_ready_at) return false;
        dodge_ready_at = clock + legend_constant("dodge_counter", "cooldown");
        if (!sources.empty()) {
            int wi = sources[size_t(rng->randi_range(0, int(sources.size()) - 1))]; const Weapon &w = weapons[wi];
            auto a = std::make_shared<Attack>(); a->birth = w.birth;
            if (w.kind == 2) a->context = missile_context(w,true);
            a->damage = evaluate_module_value(w.base, attack_counter, counter_growth, counter_level, counter_log_base, counter_round_scale, w.branch_factors, w.external_factors) * w.factor * drone_weapon(w.kind) * (1.0 + legend_value("dodge_counter", "counter_damage_bonus"));
            auto choices = targets(w.type, clock);
            if (!choices.empty()) launch(wi, choices.front(), a, 1, true);
        }
        return true;
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
            d.maximum = evaluate_module_value(d.base, incoming_counter, defence_counter_growth, counter_level, counter_log_base, counter_round_scale, d.branch_factors, d.external_factors) * d.factor * drone_defence(d.layer);
            d.loss = minimum(d.loss, d.maximum);
            d.buffer = minimum(d.buffer, d.maximum * d.memory_cap);
        }
        // Capacity changes preserve absolute health; the module losses own it.
        set_layer_health(0, before[0]); set_layer_health(1, before[1]);
    }
    Amount protection(Amount amount, Amount &absorbed, int type = 0) {
        Amount rest = amount;
        for (Defence &d : defences) {
            if (rest <= 0)
                break;
            Amount cover_paid = minimum(d.cover, rest);
            d.cover -= cover_paid; rest -= cover_paid; absorbed += cover_paid;
        }
        for (Defence &d : defences) {
            if (rest <= 0) break;
            double factor = type > 0 && type == d.protection_type && defence_time < d.protection_until ? 1.0 - enhancement_rule("memory_b2_resistance") : 1.0;
            Amount paid = minimum(d.buffer, rest * factor);
            d.buffer -= paid;
            rest = factor > 0 ? rest - paid / factor : Amount{};
            absorbed += paid;
            if (paid > 0)
                d.last_hit = defence_time;
        }
        return rest;
    }
    void publish_player() {
        player_hp = layer_health(1); player_shield = layer_health(0);
        Dictionary row; row["x"] = player_point.x; row["y"] = player_point.y;
        row["max_armour"] = wire(capacity(1)); row["max_shield"] = wire(capacity(0));
        row["armour"] = wire(player_hp); row["shield"] = wire(player_shield);
        row.make_read_only(); player_row = row;
    }
    void finish_player_hit() {

        publish_player();
        if (player_hp <= 0 && player_shield <= 0)
            if (!try_rebuild()) cancel();
    }
    void queue_debt(int layer, Amount amount) {
        if (amount <= 0)
            return;
        int portions = maximum(1, int(ceil_number(deferred_duration / deferred_interval)));
        // deferred_tick names the last settled global tick. A hit between ticks
        // begins paying at the next tick, including when it lands just before it.
        int64_t first = deferred_tick + 1;
        Amount unit = amount / portions, remaining = amount;
        for (int i = 0; i < portions; ++i) {
            Amount part = i == portions - 1 ? remaining : minimum(unit, remaining);
            remaining -= part;
            debts[first + i][layer] += part;
        }
    }
    void pay_debt(Amount amount, double at) {
        Amount absorbed = 0;
        Amount rest = protection(amount, absorbed);
        Amount loss = 0;
        for (int layer = 0; layer < 2 && rest > 0; ++layer) {
            Amount total = 0;
            for (const Defence &d : defences)
                if (d.layer == layer)
                    total += d.maximum - d.loss;
            Amount taken = minimum(total, rest);
            std::vector<Amount> old_losses;
            old_losses.reserve(defences.size());
            for (const Defence &d : defences) old_losses.push_back(d.loss);
            set_layer_health(layer, total - taken);
            for (size_t i = 0; i < defences.size(); ++i)
                if (defences[i].layer == layer && defences[i].loss > old_losses[i]) defences[i].last_hit = defence_time;
            loss += total - layer_health(layer);
            rest -= taken;
        }
        if (loss > 0 || absorbed > 0) finish_player_hit();
    }
    void recover(double dt, double begin_at) {
        double seconds_left = dt;
        while (seconds_left > 1e-9 && !stopped) {
            double piece = minimum(seconds_left, minimum(memory_interval - memory_elapsed, deferred_interval - deferred_elapsed));
            for (const Defence &d : defences) if (branch("adaptation", "b2")) {
                if (d.cover_next > defence_time + 1e-9) piece = minimum(piece, d.cover_next - defence_time);
                if (d.cover_until > defence_time + 1e-9) piece = minimum(piece, d.cover_until - defence_time);
            }
            const double previous = defence_time;
            defence_time += piece; memory_elapsed += piece; deferred_elapsed += piece;
            seconds_left = nonnegative(seconds_left - piece);
            int shields = 0;
            for (const Defence &d : defences) if (d.layer == 0) ++shields;
            for (Defence &d : defences) {
                if (d.cover_until <= defence_time + 1e-9) d.cover = 0;
                if (d.protection_until <= defence_time) d.protection_type = 0;
                if (d.layer == 0) {
                    const double ready = d.last_hit + d.delay;
                    const double elapsed = nonnegative(defence_time - ready) - nonnegative(previous - ready);
                    d.loss -= minimum(d.loss, d.maximum * d.rate * elapsed);
                }
                if (branch("adaptation", "b2") && d.cover_next <= defence_time + 1e-9) {
                    d.cover = (d.maximum + d.maximum * d.memory_cap) * enhancement_rule("adaptation_b2_capacity_multiplier");
                    d.cover_until = defence_time + enhancement_rule("adaptation_b2_duration");
                    d.cover_next = defence_time + enhancement_rule("adaptation_b2_interval");
                }
            }
            const bool memory = memory_elapsed + 1e-9 >= memory_interval;
            if (memory) memory_elapsed = nonnegative(memory_elapsed - memory_interval);
            bool positive_recovery = false;
            for (Defence &d : defences) if (memory && d.memory_heal > 0) {
                Amount healing = d.maximum * d.memory_heal;
                Amount recovered = minimum(d.loss, healing);
                d.loss -= recovered;
                double charging = branch("memory", "b3") ? 1.0 + shields * enhancement_rule("memory_b3_shield_charge_bonus") : 1.0;
                Amount buffer_before = d.buffer;
                d.buffer = minimum(d.maximum * d.memory_cap, d.buffer + (healing - recovered) * charging);
                positive_recovery = positive_recovery || recovered > 0 || d.buffer > buffer_before;
            }
            if (positive_recovery && branch("memory", "b1") && rng->randf() < enhancement_rule("memory_b1_probability"))
                memory_reduction_until = defence_time + enhancement_rule("memory_b1_duration");
            // Covers and memory recover before the same global debt payment.
            if (deferred_elapsed + 1e-9 >= deferred_interval) {
                deferred_elapsed = nonnegative(deferred_elapsed - deferred_interval);
                ++deferred_tick;
                auto at = debts.find(deferred_tick);
                if (at != debts.end()) {
                    auto due = at->second; debts.erase(at);
                    const uint64_t before_rebuild = rebuild_epoch;
                    for (int layer = 0; layer < 2 && !stopped; ++layer) {
                        if (due[layer] > 0) pay_debt(due[layer], begin_at + dt - seconds_left);
                        if (rebuild_epoch != before_rebuild) break;
                    }
                    if (!stopped && rng->randf() < clear_probability) {
                        debts.clear();
                        if (branch("deferred", "b1")) deferred_reduction_until = defence_time + enhancement_rule("deferred_b1_duration");
                    }
                }
            }
            publish_player();
        }
    }
    void player_hit(Amount raw, int type, int64_t source_uid = 0) {
        if (final_cleared) return;
        if (!increment_history(incoming_counter)) return;
        reconcile_defence();
        if (black_absorbing() || dodge_incoming()) { finish_player_hit(); return; }
        if (legend_active("drone_master")) raw *= 1.0 - minimum(1.0, legend_value("drone_master", "maximum_reduction") * highest_drone_quality() / legend_constant("drone_master", "quality_ratios/ultimate"));
        if (defence_time < memory_reduction_until) raw *= 1.0 - enhancement_rule("memory_b1_reduction");
        if (defence_time < deferred_reduction_until) raw *= 1.0 - enhancement_rule("deferred_b1_reduction");
        if (branch("deferred", "b2")) raw *= 1.0 - deferred_unforced_probability * enhancement_rule("deferred_b2_probability_conversion");
        if (branch("deferred", "b3")) raw *= 1.0 + (1.0 - deferred_unforced_probability) * enhancement_rule("deferred_b3_damage_scale");
        // A hit restarts every shield delay, even when cover or armour pays it.
        for (Defence &d : defences)
            if (d.layer == 0)
                d.last_hit = defence_time;
        Amount absorbed = 0;
        for (Defence &d : defences) if (branch("memory", "b2") && type > 0) {
            if (d.protection_type && d.protection_type != type && defence_time < d.protection_until) {
                d.protection_type = 0; d.protection_until = 0; d.protection_lockout = defence_time + enhancement_rule("memory_b2_lockout");
            } else if (defence_time >= d.protection_lockout) {
                d.protection_type = type; d.protection_until = defence_time + enhancement_rule("memory_b2_duration");
            }
        }
        Amount rest = protection(raw, absorbed, type);
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
                    available[i] = defences[i].maximum - defences[i].loss;
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
                double layer_resistance = minimum(1.0, resistance + (branch("adaptation", "b3") ? enhancement_rule("adaptation_b3_resistance_bonus") : 0.0));
                double factor = type > 0 && type == d.type ? 1 - layer_resistance : 1;
                if (branch("adaptation", "b1") && source_uid != 0) factor *= maximum(0.0, 1.0 - d.source_stacks[source_uid] * enhancement_rule("adaptation_b1_reduction"));
                Amount weighted = incoming * available[i] / total;
                Amount part = weighted * factor;
                Amount payable = available[i] / (1 - d.deferred_fraction);
                Amount taken = layer == 1 ? part : minimum(payable, part);
                Amount delayed = taken * d.deferred_fraction;
                Amount immediate = taken - delayed;
                if (layer == 0 && taken >= payable) {
                    immediate = available[i];
                    delayed = taken - immediate;
                }
                deferred[layer] = deferred[layer] || delayed > 0;
                queue_debt(layer, delayed);
                d.loss = minimum(d.maximum, d.loss + immediate);
                payments[layer] += immediate;
                spent += factor <= 0 ? weighted : taken / factor;
                if (taken > 0)
                    d.last_hit = defence_time;
            }
            rest = incoming - spent;
        }
        Amount loss = 0;
        for (int layer = 0; layer < 2; ++layer) {
            Amount paid = minimum(before[layer], deferred[layer] ? payments[layer] : ceil_number(payments[layer]));
            set_layer_health(layer, before[layer] - paid);
            loss += before[layer] - layer_health(layer);
        }
        if (loss > 0 && damage_receipts_emitted < 64) {
            Effect receipt;
            receipt.kind = 8; receipt.type = type; receipt.hostile = true;
            receipt.time = clock; receipt.point = player_point; receipt.damage = loss;
            feedback.push_back(receipt);
            ++damage_receipts_emitted;
        }
        if (branch("adaptation", "b1") && source_uid != 0) for (Defence &d : defences)
            d.source_stacks[source_uid] = minimum(int(enhancement_rule("adaptation_b1_stacks")), d.source_stacks[source_uid] + 1);
        finish_player_hit();
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
            auto salvo_context = repeated ? missile_context(w,true,a->context) : a->context;
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
            }
            if (!repeated)
                weapons[wi].beam = id;
        } else if (w.kind == 1 && !w.hostile) {
            if (a->higgs && !repeated) {
                Vector2 origin = w.muzzle, direction = unit(f.aim - origin);
                double reach = std::numeric_limits<double>::infinity();
                if (direction.x > 1e-9) reach = minimum(reach, (battle_width - double(origin.x)) / direction.x);
                else if (direction.x < -1e-9) reach = minimum(reach, -double(origin.x) / direction.x);
                if (direction.y > 1e-9) reach = minimum(reach, (battle_height - double(origin.y)) / direction.y);
                else if (direction.y < -1e-9) reach = minimum(reach, -double(origin.y) / direction.y);
                reach = maximum(0.0, finite(reach) ? reach : 0.0) + a->higgs_width;
                struct Candidate { Handle target; Vector2 point; double range; int64_t uid; };
                std::vector<Candidate> frozen;
                for (size_t i = 0; i < actors.size(); ++i) if (actors[i].live) {
                    Vector2 delta = actors[i].point - origin; double along = delta.dot(direction);
                    if (along >= 0 && along <= reach && std::abs(double(delta.cross(direction))) <= a->higgs_width * 0.5)
                        frozen.push_back({handle(i), actors[i].point, double(delta.length_squared()), actors[i].uid});
                }
                std::sort(frozen.begin(), frozen.end(), [](const Candidate &a, const Candidate &b) { return a.range == b.range ? a.uid < b.uid : a.range < b.range; });
                for (const Candidate &candidate : frozen) {
                    if (stopped || final_cleared || !f.live) break;
                    if (!resolve(candidate.target)) continue;
                    effect(1, f, candidate.point, clock);
                    hit_enemy(candidate.target, f.damage, f.type, inst, true, clock, wi, true);
                }
            } else {
                effect(1, f, f.aim, clock);
                hit_enemy(target, f.damage, f.type, inst, !repeated, clock, wi, true);
            }
            retire(id);
        }
    }
    bool primary(int wi) {
        Weapon &w = weapons[wi];
        if (w.hostile && !resolve(w.source))
            return false;
        if (w.kind == 3 && w.beam >= 0 && flights[w.beam].live)
            return false;
        auto candidates = targets(w.type, clock);
        if (!w.hostile && candidates.empty())
            return false;
        auto a = std::make_shared<Attack>();
        a->birth = w.birth;
        a->strange_enabled = !w.hostile && w.kind == 1 && strange_enabled;
        if (a->strange_enabled) {
            a->strange_probability = strange_probability; a->strange_delay = strange_delay;
            a->strange_multiplier = strange_multiplier; a->strange_kill_spawns = strange_kill_spawns;
            a->strange_type = strange_type;
        }

        if (!w.hostile && !increment_history(attack_counter)) return false;
        // Match weapon_multiplier grouping before multiplying the rounded base.
        double legendary = !w.hostile && w.kind == 0 ?
            (scatter && candidates.size() == 1 ? 1 + scatter_bonus : 1) * laser_charge_multiplier : 1;
        a->damage = (w.hostile ? w.base : evaluate_module_value(w.base, attack_counter, counter_growth, counter_level, counter_log_base, counter_round_scale, w.branch_factors, w.external_factors)) *
                    w.factor * legendary * (w.hostile ? Amount(1) : drone_weapon(w.kind));
        if (!w.hostile) {
            if (w.kind == 1 && legend_active("higgs_cannon")) {
                a->higgs = true; a->higgs_width = maximum(higgs_minimum_width, rail_trail_width) * maximum(1.0, 1.0 + legend_value("higgs_cannon", "area_bonus"));
                a->damage *= 1.0 + legend_value("higgs_cannon", "damage_bonus");
            }
            if (branch("proficiency", "b1")) {
                int64_t uid = actors[candidates.front().index].uid;
                if (w.focus_uid != uid) { w.focus_uid = uid; w.focus_since = clock; }
                double ticks = std::floor(maximum(0.0, clock - w.focus_since) / enhancement_rule("proficiency_b1_interval"));
                a->damage *= Amount(1.0 + enhancement_rule("proficiency_b1_growth")).power(ticks);
            }
            if (clock >= w.critical_until) w.critical_stacks = 0;
            if (branch("critical", "b1") && w.critical_attacks > 0) { a->damage *= 1.0 + enhancement_rule("critical_b1_damage_bonus"); --w.critical_attacks; }
            if (branch("critical", "b2")) a->damage *= 1.0 + w.critical_stacks * enhancement_rule("critical_b2_damage_bonus");
            double original = std::clamp(w.crit_rate + (branch("critical", "b2") ? w.critical_stacks * enhancement_rule("critical_b2_probability") : 0.0), 0.0, 1.0);
            double drone = drone_scalar("critical_rate_bonus");
            double probability = std::clamp((branch("critical", "b3") ? enhancement_rule("critical_b3_guaranteed_rate") : original) + drone, 0.0, 1.0);
            a->critical = rng->randf() < probability;
            a->critical_bonus_applied = a->critical;
            if (a->critical && branch("critical", "b3")) a->critical_bonus_applied = rng->randf() < original;
            if (a->critical_bonus_applied) a->damage *= w.crit_multiplier * (1.0 + drone_scalar("critical_damage_bonus"));
        }
        bool wild = !w.hostile && w.kind == 2 && wild_enabled && missile_attacks % (wild_period+1) == wild_period;
        if (!w.hostile && w.kind == 2) {
            ++missile_attacks;
            a->context = missile_context(w,wild);
            if (wild) {

                a->damage *= wild_multiplier;
                a->context->wild = true; a->context->blast = wild_blast;
                auto birth = std::make_shared<BirthConfig>(*a->birth); birth->salvo = 1;
                a->birth = birth;
            }
        }
        a->secondary = !w.hostile && !wild && rng->randf() < w.secondary_probability;
        a->repeats = !w.hostile && !wild && rng->randf() < std::clamp(w.repeat_probability + drone_scalar("repeat_probability_bonus"), 0.0, 1.0);
        if (w.hostile) {
            launch(wi, {}, a, 1);
            return true;
        }
        auto primary_instance = instance(a);
        if (scatter && w.kind == 0) {
            for (Handle h : candidates)
                birth(wi, h, primary_instance, 1);
        } else
            launch(wi, candidates.front(), a, 1, false, true, -1, primary_instance);
        if (a->critical) {
            if (branch("critical", "b1")) w.critical_attacks = int(enhancement_rule("critical_b1_attacks"));
            if (branch("critical", "b2")) { w.critical_stacks = minimum(int(enhancement_rule("critical_b2_stacks")), w.critical_stacks + 1); w.critical_until = clock + enhancement_rule("critical_b2_duration"); }
        }
        if (final_cleared) return true;
        if (w.kind != 3 && a->repeats)
            repeats.push(
                {clock + a->birth->repeat_delay, ++event_serial, 2, wi, 0, candidates.front(), a, a->birth->repeat_multiplier});
        if (w.kind != 3 && a->secondary && candidates.size() > 1) {
            launch(wi, candidates[1], a, 1, true, false, -1, primary_instance);
        }
        return true;
    }
    bool endless_eligible(const Flight &f) const {
        return f.live && f.beam && !f.hostile && !f.repeated && weapons[f.weapon].endless &&
               !stopped && !final_cleared &&
               (player_hp > 0 || player_shield > 0);
    }
    // One owner keeps the existing attack, charge, tick clock and frozen link count.
    // Rebinding happens only at the next segment start, never halfway through hits.
    bool retain_endless_target(Flight &f, double at, bool rebind) {
        if (!endless_eligible(f)) return false;
        f.await_target = true;
        auto inst = f.instance;
        inst->links.clear(); inst->ended = false;
        if (!rebind) return true;
        auto candidates = targets(f.type, at);
        if (candidates.empty()) return true;
        f.target = candidates.front(); inst->primary = f.target;
        f.await_target = false; f.target_lost = false;
        f.aim = actors[f.target.index].point;
        if (f.prism) std::sort(candidates.begin(), candidates.end(), [&](Handle a, Handle b) {
            return distance(actors[a.index].point,f.aim) < distance(actors[b.index].point,f.aim);
        });
        for (Handle h : candidates) if (h.index != f.target.index && int(inst->links.size()) < inst->count) inst->links.push_back(h);
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
            f.launch_point = muzzle;
            Actor *target = resolve(f.target);
            f.aim = f.hostile ? player_point : target ? target->point : f.aim;
            motion.direction = unit(f.aim - muzzle);
            if (f.born_step < step_serial)
                f.age += dt;
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
        double duration = f.charge >= 0 ? (f.ticks - 1) * f.interval : due;
        double ramp = f.ramp > 0 ? std::clamp(duration / f.ramp, 0.0, 1.0) : 1;
        Amount raw = f.damage * (1 + (f.maximum - 1) * ramp);
        if (f.hostile)
            player_hit(raw, f.type, f.source_uid);
        else
            hit_enemy(f.target, raw, f.type, f.instance, !f.repeated, at, f.weapon, true);
        if (!final_cleared && f.ticks == 1 && !f.hostile && !f.repeated && f.instance->attack->secondary) {
            auto candidates = targets(f.type, at);
            for (Handle h : candidates)
                if (h.index != f.target.index) {
                    hit_enemy(h, raw, f.type, f.instance, false, at, f.weapon);
                    break;
                }
        }
        if (!final_cleared && f.ticks == 1 && !f.repeated && f.instance->attack->repeats) {
            Timed pending{at + f.instance->attack->birth->repeat_delay,
                          ++event_serial,
                          2,
                          f.weapon,
                          0,
                          f.target,
                          f.instance->attack,
                          f.instance->attack->birth->repeat_multiplier};
            pending.owner_flight = id;
            pending.owner_generation = f.generation;
            repeats.push(pending);
        }
    }
    void advance_flight(size_t id, double dt) {
        Flight &f = flights[id];
        if (!f.live || f.beam || f.born_step >= step_serial)
            return;

        Motion &m = f.lease->motion();
        Actor *t = resolve(f.target);
        Vector2 aim = f.hostile ? player_point : t ? t->point : m.last_aim;
        if (!f.hostile && !t) {
            f.target_lost = true;
        }
        bool impact = false;
        if (m.kind == 1) {
            m.age += dt;
            if ((f.hostile || t) && m.age > lifetime) {
                retire(id);
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
                    retire(id);
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
                        if (!(t->stationary_geometry && f.contact_distance >= 0 &&
                            progress + m.speed * dt < f.contact_distance - margin)) {

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
                player_hit(f.damage, f.type, f.source_uid);
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
        struct Contact { double at, due; size_t id; uint32_t generation; bool beam, hostile; int source_slot, module_slot; uint64_t serial; };
        std::vector<Contact> contacts;
        for (size_t id : active) {
            const Flight &f = flights[id];
            if (!f.live) continue;
            if (f.beam && !f.await_target) {
                for (double due = f.next_hit; due <= f.age + 1e-9; due += f.interval) {
                    double at = clock - f.age + due;
                    if (std::abs(at - clock) <= 1e-9) at = clock;
                    contacts.push_back({at, due, id, f.generation, true, f.hostile, f.source_slot, weapons[f.weapon].slot, f.contact_order});
                }
            } else if (!f.beam && f.born_step < step_serial) {
                contacts.push_back({clock, 0, id, f.generation, false, f.hostile, f.source_slot, weapons[f.weapon].slot, f.contact_order});
            }
        }
        if (black_release > 0) {
            Dictionary owner = selected_legends.get("black_hole", Dictionary()); String id = owner.get("id", "");
            int slot = INT32_MAX;
            for (const Weapon &w : weapons) if (w.enabled && String(w.entry.get("drone_id", "")) == id) { slot = w.slot; break; }
            contacts.push_back({clock, 0, SIZE_MAX, 0, false, false, slot, slot, black_release_order});
        }
        // Snapshot identities, never the mutable dense active order. Each hit and
        // its local derivatives finish before the next source gets to settle.
        auto contact_before = [](const Contact &a, const Contact &b) {
            if (a.at != b.at) return a.at < b.at;
            if (a.hostile != b.hostile) return !a.hostile;
            if (a.source_slot != b.source_slot) return a.source_slot < b.source_slot;
            if (a.module_slot != b.module_slot) return a.module_slot < b.module_slot;
            if (a.serial != b.serial) return a.serial < b.serial;
            return a.due < b.due;
        };
        std::sort(contacts.begin(), contacts.end(), contact_before);
        size_t index = 0;
        while (!stopped && !final_cleared) {
            // Merge due packets into the already sorted contact stream. Newly
            // created zero-delay packets are eligible here without recursive hits.
            auto packet = strange_pending.begin();
            bool due_packet = packet != strange_pending.end() && std::get<0>(packet->first) <= clock + 1e-9;
            if (due_packet) {
                const StrangePacket &value = packet->second;
                Contact candidate{std::get<0>(packet->first), 0, SIZE_MAX, 0, false, false,
                                  value.source_slot, value.source_slot, value.order};
                if (index == contacts.size() || contact_before(candidate, contacts[index])) {
                    StrangePacket owned = value; strange_pending.erase(packet);
                    settle_strange(owned, candidate.at);
                    continue;
                }
            }
            if (index == contacts.size()) break;
            const Contact &contact = contacts[index++];
            if (contact.id == SIZE_MAX) { release_black_hole(); continue; }
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
        advance_legend_timers();
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
            if (!weapons[q.weapon].enabled) continue;
            if (q.kind == 0) {
                const bool fired = primary(q.weapon);
                const Weapon &weapon = weapons[q.weapon];
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
            if ((weapons[i].hostile || !weapons[i].configured) && !retained[i]) {
                weapons[i] = Weapon{};
                weapons[i].hostile = true;
                weapons[i].vacant = true;
            }
        }
        // Global encounter generations invalidate every old target/source
        // handle while independent live enemy carriers keep their weapon slot.
        actors.clear(); actor_view_changes.clear();
    }
    bool install_actors(Array values) {
        for (int i = 0; i < values.size(); ++i) {
            Dictionary v = values[i];
            Actor a;
            a.generation = encounter_generation;
            a.uid = v["uid"];
            // Only current geometry and HUD consumers receive a persistent row.
            for (const char *key : {"uid", "slot", "x", "y", "size", "wave_final", "formation_count", "hull_scale", "hp", "dead"})
                if (v.has(key)) a.view[key] = v[key];
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
            actors.push_back(a);
            actor_view_changes.insert(actors.size() - 1);
        }
        return true;
    }
    bool read_weapon(Dictionary v, int i, double delay, Weapon &w, Dictionary initial = Dictionary()) const {
        w.kind = v["kind"];
        w.type = v.get("type", 1);
        w.slot = v.get("slot", i);
        w.hostile = v.get("hostile", false);
        int source = v.get("source", -1);
        if (w.hostile) {
            w.source.index = uint32_t(source); // Generation and encounter offset belong to installation.
        }
        w.interval = v.get("interval", 1.0); w.normal_interval = w.interval; w.base_interval = v.get("base_interval", w.interval);
        w.base = read_amount(v.get("damage", 1.0));
        read_amount(v.get("maximum", 1.0)); // Validate the legacy scalar spelling once.
        w.remaining = v.get("remaining", w.kind == 3 ? 0.0 : w.interval);
        w.branch_factors = read_factors(v.get("branch_factors", Array()));
        w.external_factors = read_factors(v.get("external_factors", Array()));
        w.factor = v.get("factor", 1.0);
        w.speed = v.get("speed", 720.0);
        w.salvo = v.get("salvo", 1);
        w.crit_rate = v.get("critical_rate", initial.is_empty() ? crit_rate : double(initial.get("critical_rate", 0.0)));
        w.crit_multiplier = v.get("critical_multiplier", initial.is_empty() ? crit_multiplier : double(initial.get("critical_multiplier", 2.0)));
        w.repeat_probability = v.get("repeat_probability", initial.is_empty() ? repeat_probability : double(initial.get("repeat_probability", 0.0)));
        w.repeat_multiplier = v.get("repeat_multiplier", initial.is_empty() ? repeat_multiplier : double(initial.get("repeat_multiplier", 1.0)));
        w.secondary_probability = v.get("secondary_probability", initial.is_empty() ? secondary_probability : double(initial.get("secondary_probability", 0.0)));
        w.chain_count = v.get("chain_count", initial.is_empty() ? chain_count : int(initial.get("chain_count", 0))); w.normal_chain_count = w.chain_count;
        w.charge = v.get("charge", 0.0);
        w.ramp = v.get("ramp", 1.0);
        w.maximum = v.get("maximum", 1.0); w.normal_maximum = w.maximum;
        w.muzzle = v.get("muzzle", Vector2(286, 520));
        w.entry = Dictionary(v.get("entry", Dictionary())).duplicate(true);
        w.birth = birth_config(w, v, delay);
        return true;
    }
    static Defence read_defence(Dictionary row) {
        Defence value;
        value.entry = Dictionary(row.get("entry", Dictionary())).duplicate(true);
        value.layer = row.get("layer", 0); value.type = row.get("type", 0);
        value.base = read_amount(row.get("base", 0.0));
        value.branch_factors = read_factors(row.get("branch_factors", Array()));
        value.external_factors = read_factors(row.get("external_factors", Array()));
        value.factor = row.get("factor", 1.0);
        value.maximum = read_amount(row.get("maximum", 0.0));
        value.loss = read_amount(row.get("loss", 0.0)); value.buffer = read_amount(row.get("buffer", 0.0));
        value.delay = row.get("delay", 0.0); value.rate = row.get("rate", 0.0); value.last_hit = row.get("last_hit", 0.0);
        value.memory_heal = row.get("memory_heal", 0.0); value.memory_cap = row.get("memory_cap", 0.0);
        value.deferred_fraction = row.get("deferred_fraction", 0.0);
        return value;
    }
    static std::vector<std::array<Amount, 2>> read_drone_globals(Array rows) {
        std::vector<std::array<Amount, 2>> values; values.reserve(rows.size());
        for (int i = 0; i < rows.size(); ++i) {
            if (Variant(rows[i]).get_type() != Variant::DICTIONARY) throw std::invalid_argument("InvalidDroneContribution");
            Dictionary row = rows[i];
            values.push_back({read_amount(row.get("global_weapon_bonus", String("0"))),
                              read_amount(row.get("global_defence_bonus", String("0")))});
        }
        return values;
    }
    void apply_defence_capacity(const String &change_kind, const Amount (&before)[2], const Amount (&old_capacity)[2], const std::vector<size_t> *changed = nullptr) {
        unsigned layers = changed ? 0 : 3;
        for (size_t i = 0; i < defences.size(); ++i) {
            if (changed && std::find(changed->begin(), changed->end(), i) == changed->end()) continue;
            Defence &value = defences[i]; layers |= 1u << value.layer;
            const Amount health = value.maximum - value.loss;
            value.maximum = evaluate_module_value(value.base, incoming_counter, defence_counter_growth, counter_level, counter_log_base, counter_round_scale, value.branch_factors, value.external_factors) * value.factor * drone_defence(value.layer);
            if (change_kind == "refit") value.loss = value.maximum;
            else if (change_kind == "upgrade" && !retreating) value.loss = minimum(value.loss, value.maximum);
            else value.loss = value.maximum - minimum(value.maximum, health);
            value.buffer = minimum(value.buffer, value.maximum * value.memory_cap);
        }
        for (int layer = 0; layer < 2; ++layer) {
            if (!(layers & (1u << layer))) continue;
            Amount target = before[layer];
            if (change_kind == "refit") target = old_capacity[layer] > 0 ? capacity(layer) * before[layer] / old_capacity[layer] : Amount{};
            // Paid upgrades preserve each module's loss; other actions coordinate
            // absolute health, or rebuild losses from the explicit refit ratio.
            if (change_kind != "upgrade" || retreating) set_layer_health(layer, target);
        }
    }
    void install_weapons(std::vector<Weapon> prepared, int actor_offset) {
        for (Weapon &w : prepared) {
            if (w.hostile) w.source = handle(w.source.index + actor_offset);
            int index = 0;
            while (index < int(weapons.size()) && !weapons[index].vacant) ++index;
            if (index == int(weapons.size())) weapons.push_back(std::move(w));
            else weapons[index] = std::move(w);
            roots.push({clock + weapons[index].remaining, ++event_serial, 0, index});
        }
    }

  protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("set_player_configuration", "descriptor", "change_kind"), &SpaceCombatKernel::set_player_configuration);
        ClassDB::bind_method(D_METHOD("set_player_values", "weapons", "defences", "kind", "iron_factor", "enhancement"), &SpaceCombatKernel::set_player_values, DEFVAL(String()), DEFVAL(Dictionary()));
        ClassDB::bind_method(D_METHOD("take_results"), &SpaceCombatKernel::take_results);
        ClassDB::bind_method(D_METHOD("presentation_clock"), &SpaceCombatKernel::presentation_clock);
        ClassDB::bind_method(D_METHOD("read_history"), &SpaceCombatKernel::read_history);
        ClassDB::bind_method(D_METHOD("persistent_state"), &SpaceCombatKernel::persistent_state);
        ClassDB::bind_method(D_METHOD("active_flight_count"), &SpaceCombatKernel::active_flight_count);
        ClassDB::bind_method(D_METHOD("workload_metrics"), &SpaceCombatKernel::workload_metrics);
        ClassDB::bind_method(D_METHOD("restore_persistent_state", "state"), &SpaceCombatKernel::restore_persistent_state);
        ClassDB::bind_method(D_METHOD("clear_encounter", "reason"), &SpaceCombatKernel::clear_encounter);
        ClassDB::bind_method(D_METHOD("finish_retreat"), &SpaceCombatKernel::finish_retreat);
        ClassDB::bind_method(D_METHOD("begin_retreat"), &SpaceCombatKernel::begin_retreat);
        ClassDB::bind_method(D_METHOD("finish_wave", "final"), &SpaceCombatKernel::finish_wave);
        ClassDB::bind_method(D_METHOD("start_wave", "wave"), &SpaceCombatKernel::start_wave);
        ClassDB::bind_method(D_METHOD("initialize", "descriptor"), &SpaceCombatKernel::initialize);
        ClassDB::bind_method(D_METHOD("input_geometry", "points", "muzzles"),
                             &SpaceCombatKernel::input_geometry);
        ClassDB::bind_method(D_METHOD("input_ballistic_geometry", "hulls", "points", "muzzles", "stationary"), &SpaceCombatKernel::input_ballistic_geometry, DEFVAL(PackedByteArray()));
        ClassDB::bind_method(D_METHOD("advance", "seconds"), &SpaceCombatKernel::advance);
        ClassDB::bind_method(D_METHOD("input_player_point", "point"), &SpaceCombatKernel::input_player_point);
        ClassDB::bind_method(D_METHOD("input_player_hull", "hull"), &SpaceCombatKernel::input_player_hull);
        ClassDB::bind_method(D_METHOD("enemy_views"), &SpaceCombatKernel::enemy_views);
        ClassDB::bind_method(D_METHOD("player_view"), &SpaceCombatKernel::player_view);
        ClassDB::bind_method(D_METHOD("set_damage_stats_enabled", "enabled"), &SpaceCombatKernel::set_damage_stats_enabled);
        ClassDB::bind_method(D_METHOD("take_damage_stats"), &SpaceCombatKernel::take_damage_stats);
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
        if (!finite(clock + seconds + strange_delay)) return false;
        long double attack_end = static_cast<long double>(attack_counter) + root_bound + double(repeats.size()) + periods;
        // Every retained wild context can explode once; no recursive explosion.
        hits *= 1 + double(actors.size());
        long double incoming_end = static_cast<long double>(incoming_counter) + hits;
        double events = births + hits + root_bound + periods + retained_drop_bound + strange_births;
        if (!finite(events) || events >= exact_limit || attack_end >= exact_limit || incoming_end >= exact_limit ||
            double(event_serial) + events >= exact_limit || double(flight_serial) + births >= exact_limit ||
            double(step_serial) + segments >= exact_limit ||
            double(missile_attacks) + root_bound >= exact_limit) return false;
        return true;
    }
    // One kernel owns the session. New waves append generations; they never
    // configure a replacement owner or discard legal carriers from an earlier wave.
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
        std::vector<Weapon> prepared;
        try {
            if (!configuration_schema(descriptor) || Array(descriptor["enemies"]).is_empty()) return false;
            Array rows = descriptor["weapons"];
            for (int i = 0; i < rows.size(); ++i) {
                Weapon value;
                if (!read_weapon(rows[i], i, repeat_delay, value)) return false;
                prepared.push_back(std::move(value));
            }
        } catch (const std::exception &) {
            return false; // Decoding cannot retire the old encounter or change its failure state.
        }
        reclaim_finished_wave();
        if (final_cleared) {
            compact();
            actors.clear(); actor_view_changes.clear();
            weapons.erase(std::remove_if(weapons.begin(), weapons.end(), [](const Weapon &w) { return w.hostile || !w.configured; }), weapons.end());
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
        if (!install_actors(descriptor["enemies"])) return false;
        install_weapons(std::move(prepared), actor_offset);
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
        restore_drone_contributions(!final);
        if (final) { final_encounter = true; commit_final_wipe(); }
    }
    void begin_retreat() {
        if (executing) return;
        cancel(); wave_active = false; retreating = true;
        restore_drone_contributions(false);
        black_accumulated = black_release = 0; black_until = 0;
        if (legend_active("black_hole")) black_next_at = clock + legend_constant("black_hole", "period");
        for (Defence &d : defences) d.source_stacks.clear();
        for (size_t i = 0; i < actors.size(); ++i) {
            Actor &a = actors[i]; a.live = false;
            if (!bool(a.view.get("dead", false))) { a.view["dead"] = true; actor_view_changes.insert(i); }
            ++a.generation;
        }
        debts.clear();
    }
    void finish_retreat() {
        if (executing || !stopped || !admitted) return;
        actors.clear(); actor_view_changes.clear();
        weapons.erase(std::remove_if(weapons.begin(), weapons.end(), [](const Weapon &w) { return w.hostile || !w.configured; }), weapons.end());
        for (Defence &d : defences) { d.loss = 0; d.buffer = 0; d.cover = 0; d.source_stacks.clear(); d.protection_type = 0; d.protection_until = d.protection_lockout = 0; d.cover_next = branch("adaptation", "b2") ? defence_time + enhancement_rule("adaptation_b2_interval") : 0; }
        reconcile_defence(); publish_player();
        stopped = false; retreating = false; final_encounter = final_cleared = false;
        for (int i = 0; i < int(weapons.size()); ++i) {
            weapons[i].beam = -1;
            roots.push({clock, ++event_serial, 0, i});
        }
    }
    SpaceCombatKernel() {
        actor_view_rows.set_typed(Variant::DICTIONARY, StringName(), Variant()); actor_view_rows.make_read_only();
        player_row.make_read_only();
    }
    void clear_encounter(const String &) { begin_retreat(); battle_started = false; }
    double presentation_clock() const { return clock; }
    Dictionary read_history() const {
        Dictionary out; out["attacks"] = int64_t(attack_counter); out["incoming"] = int64_t(incoming_counter); return out;
    }
    // No encounter objects cross the save boundary. Decimal strings preserve
    // all counters through JSON without rounding them through a double.
    Dictionary persistent_state() const {
        Dictionary history, ids, out;
        history["attacks"] = String::num_int64(attack_counter);
        history["incoming"] = String::num_int64(incoming_counter);
        ids["encounter"] = String::num_int64(int64_t(encounter_generation));
        ids["attack"] = String::num_int64(int64_t(flight_serial));
        ids["emitter"] = String::num_int64(int64_t(event_serial));
        ids["drop"] = String::num_int64(drop_uid);
        out["history_counts"] = history;
        out["rng_state"] = String::num_int64(rng.is_valid() ? int64_t(rng->get_state()) : 0);
        out["next_ids"] = ids;
        return out;
    }
    int64_t active_flight_count() const {
        int64_t count = 0;
        for (size_t id : active) if (id < flights.size() && flights[id].live) ++count;
        return count;
    }
    Dictionary workload_metrics() const {
        Dictionary metrics;
        metrics["active_flights"] = active_flight_count();
        metrics["flight_slots"] = int64_t(flights.size());
        metrics["active_capacity"] = int64_t(active.capacity());
        metrics["root_queue"] = int64_t(roots.size());
        metrics["ejection_queue"] = int64_t(ejections.size());
        metrics["repeat_queue"] = int64_t(repeats.size());
        metrics["strange_queue"] = int64_t(strange_pending.size());
        metrics["feedback_capacity"] = int64_t(feedback.capacity());
        return metrics;
    }
    bool restore_persistent_state(const Dictionary &state) {
        if (!admitted || executing || !state.has("history_counts") || !state.has("rng_state") || !state.has("next_ids") ||
            Variant(state["history_counts"]).get_type() != Variant::DICTIONARY ||
            Variant(state["next_ids"]).get_type() != Variant::DICTIONARY ||
            Variant(state["rng_state"]).get_type() != Variant::STRING) return false;
        Dictionary history = state["history_counts"], ids = state["next_ids"];
        auto signed_value = [](const Variant &value, int64_t &out, bool allow_negative = false) -> bool {
            if (value.get_type() != Variant::STRING) return false;
            String text = value;
            if (text.is_empty() || !text.is_valid_int() || (!allow_negative && text.begins_with("-")) || text != String::num_int64(text.to_int())) return false;
            out = text.to_int(); return true;
        };
        int64_t attacks, incoming, drop, encounter, attack, emitter, random_state;
        if (!signed_value(history.get("attacks", Variant()), attacks) ||
            !signed_value(history.get("incoming", Variant()), incoming) ||
            !signed_value(ids.get("drop", Variant()), drop) ||
            !signed_value(ids.get("encounter", Variant()), encounter) ||
            !signed_value(ids.get("attack", Variant()), attack) ||
            !signed_value(ids.get("emitter", Variant()), emitter) ||
            !signed_value(state.get("rng_state", Variant()), random_state, true) ||
            encounter < 1 || encounter >= INT32_MAX) return false;
        attack_counter = attacks; incoming_counter = incoming;
        encounter_generation = uint32_t(encounter);
        flight_serial = uint64_t(attack); event_serial = uint64_t(emitter);
        drop_uid = drop;
        rng->set_state(uint64_t(random_state));
        return true;
    }
    Dictionary take_results() {
        Dictionary out; Array events, drops;
        for (const Effect &e : feedback) {
            if (e.kind == 7) {
                Dictionary drop = e.drop; drop["created_at"] = e.time; drops.push_back(drop);
            } else {
                Dictionary contact;
                contact["kind"] = e.kind; contact["type"] = e.type;
                contact["hostile"] = e.hostile; contact["critical"] = e.critical;
                contact["critical_bonus_applied"] = e.critical_bonus_applied;
                contact["clock"] = e.time; contact["position"] = e.point; contact["direction"] = e.direction;
                if (e.kind == 8) contact["damage"] = wire(e.damage);
                events.push_back(contact);
            }
        }
        feedback.clear();
        bool cleared = wave_active;
        for (const Actor &a : actors) if (a.live) { cleared = false; break; }
        out["events"] = events; out["drops"] = drops;
        out["wave_cleared"] = cleared; out["final_cleared"] = cleared && final_cleared;
        out["player_dead"] = player_hp <= 0 && player_shield <= 0; out["error"] = failure_reason;
        if (cleared) wave_active = false;
        return out;
    }

    bool configure(Dictionary d) {
        std::vector<Weapon> prepared_weapons;
        std::vector<Defence> prepared_defences;
        std::vector<std::array<Amount, 2>> drone_values;
        try {
            if (!configuration_schema(d, false)) return false;
            Array source_rows = d["weapons"];
            for (int i = 0; i < source_rows.size(); ++i) {
                Weapon value;
                if (!read_weapon(source_rows[i], i, d.get("repeat_delay", 0.5), value, d)) return false;
                prepared_weapons.push_back(std::move(value));
            }
            Array module_rows = d.get("defences", Array());
            for (int i = 0; i < module_rows.size(); ++i) prepared_defences.push_back(read_defence(module_rows[i]));
            drone_values = read_drone_globals(d.get("equipped_drones", Array()));
            if (!configuration_arithmetic(d, int64_t(d.get("attack_counter",int64_t(0))),
                    int64_t(d.get("incoming_counter",int64_t(0))), prepared_weapons, prepared_defences)) return false;
        } catch (const std::exception &) {
            return false; // Admission failure: no owner mutation or stopped/failure state change.
        }
        cancel();
        feedback.clear();
        actors.clear();
        weapons.clear();
        defences.clear();
        debts.clear();
        actor_view_changes.clear();
        admitted = false;
        stopped = false; retreating = false;
        final_encounter = d.get("final_encounter", false); final_cleared = false;
        ++encounter_generation;

        target_slot_center = d["target_slot_center"];
        battle_width = d.get("battle_width", 0.0); battle_height = d.get("battle_height", 0.0);
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
        flight_serial = d.get("projectile_serial", 0);
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
        Dictionary initial_player = d["player"];
        player_point = Vector2(initial_player.get("x", 286.0), initial_player.get("y", 520.0));
        player_collision_hull.clear();
        player_hp = 0; player_shield = 0; // Read-only module-health projections, populated below.
        rng.instantiate();
        rng->set_state(int64_t(d.get("rng_state", 1)));
        missile_attacks = d.get("missile_attacks",0);
        crit_rate = d.get("critical_rate", 0.0);
        crit_multiplier = d.get("critical_multiplier", 2.0);
        repeat_probability = d.get("repeat_probability", 0.0);
        repeat_multiplier = d.get("repeat_multiplier", 1.0);
        repeat_delay = d.get("repeat_delay", 0.1);
        secondary_probability = d.get("secondary_probability", 0.0);
        chain_count = d.get("chain_count", 0);
        if (!install_actors(d["enemies"])) return false;
        install_weapons(std::move(prepared_weapons), 0);
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
        defences = std::move(prepared_defences);
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
        failure_reason = "";
        configure_enhancement(d); configure_legends(d, drone_values);
        wave_active = !actors.empty(); battle_started = wave_active;
        admitted = !defences.empty() &&
                   (!bool(d.get("requires_drop_rules", false)) || drop_rules);
        for (Defence &defence : defences) {
            defence.maximum = evaluate_module_value(defence.base, incoming_counter, defence_counter_growth, counter_level, counter_log_base, counter_round_scale, defence.branch_factors, defence.external_factors) * defence.factor * drone_defence(defence.layer);
            defence.loss = 0;
        }
        retain_configuration_bounds(true);
        publish_player();
        return admitted;
    }
    bool prepare_player_configuration(Dictionary d, String change_kind, std::vector<Weapon> &prepared,
            std::vector<Defence> &modules, std::vector<std::array<Amount, 2>> &drone_values) const {
        try {
        if (!admitted || executing || (change_kind != "upgrade" && change_kind != "refit" && change_kind != "growth" && change_kind != "selection")) return false;
        if (!configuration_schema(d, false)) return false;
        Array drones = d.get("equipped_drones", Array()); Dictionary limits = d.get("drone_limits", Dictionary());
        if (drones.size() > int(d.get("drone_capacity", 0))) return false;
        int legendary_count = 0, ultimate_count = 0; bool higgs = false;
        std::set<String> drone_ids;
        for (int i = 0; i < drones.size(); ++i) {
            if (Variant(drones[i]).get_type() != Variant::DICTIONARY) return false;
            Dictionary row = drones[i]; String id = row.get("id", ""), quality = row.get("quality", "");
            if (id.is_empty() || !drone_ids.insert(id).second || !row.has("weapon")) return false;
            if (quality == "legendary") ++legendary_count;
            else if (quality == "ultimate") ++ultimate_count;
            else if (quality != "white" && quality != "blue" && quality != "gold") return false;
            // Range metadata comes from the authoritative Excel rows, including
            // the separate historical drone_master interval (a union, not an overlap).
            for (const char *field : {"laser_damage_bonus", "cannon_damage_bonus", "missile_damage_bonus", "long_laser_damage_bonus",
                 "critical_damage_bonus", "critical_rate_bonus", "repeat_probability_bonus", "attack_speed_bonus",
                 "chain_count_bonus", "shield_capacity_bonus", "armour_capacity_bonus"}) {
                Variant value = row.get(field, 0.0);
                if ((value.get_type() != Variant::INT && value.get_type() != Variant::FLOAT) || !finite(double(value)) || double(value) < 0) return false;
            }
            double chains = row.get("chain_count_bonus", 0.0);
            if (chains != std::floor(chains) || chains > std::numeric_limits<int>::max()) return false;
            String effect = row.get("legendary_effect", "");
            if (!effect.is_empty()) {
                Dictionary definitions = d.get("legendary_definitions", Dictionary()), all_ranges = d.get("legendary_ranges", Dictionary());
                if (!definitions.has(effect)) return false;
                Dictionary ranges = all_ranges.get(effect, Dictionary()), parameters = row.get("legendary_parameters", Dictionary());
                if (parameters.size() != ranges.size()) return false;
                Array keys = ranges.keys();
                for (int j = 0; j < keys.size(); ++j) {
                    Variant key = keys[j]; if (!parameters.has(key)) return false;
                    Variant raw = parameters[key]; if (raw.get_type() != Variant::INT && raw.get_type() != Variant::FLOAT) return false;
                    double value = raw; Dictionary range = ranges[key];
                    bool current = value >= double(range["minimum"]) && value <= double(range["maximum"]);
                    bool historical = range.has("compatibility_minimum") && value >= double(range["compatibility_minimum"]) && value <= double(range["compatibility_maximum"]);
                    if (!finite(value) || (!current && !historical)) return false;
                }
            }
            if (effect == "higgs_cannon") higgs = true;
        }
        double chains = 0, speed = 0;
        for (int i = 0; i < drones.size(); ++i) { Dictionary row = drones[i]; chains += double(row.get("chain_count_bonus", 0.0)); speed += double(row.get("attack_speed_bonus", 0.0)); }
        Array sources_for_bounds = d["weapons"];
        for (int i = 0; i < sources_for_bounds.size(); ++i) {
            Dictionary row = sources_for_bounds[i];
            const double interval = double(row.get("interval", 1.0)) / (1.0 + speed);
            if (!finite(speed) || chains + double(row.get("chain_count", 0)) > std::numeric_limits<int>::max() ||
                interval <= 0 || clock + interval <= clock) return false;
        }
        if (legendary_count > int(limits.get("maximum_legendary", 0)) || ultimate_count > int(limits.get("maximum_ultimate", 0))) return false;
        if (higgs) {
            int cannons = 0; Array sources = d["weapons"];
            for (int i = 0; i < sources.size(); ++i) if (int(Dictionary(sources[i]).get("kind", -1)) == 1) ++cannons;
            Dictionary all = d.get("legendary_constants", Dictionary()), constants = all.get("higgs_cannon", Dictionary());
            if (cannons > int(constants.get("maximum_cannon_sources", 0))) return false;
        }
        std::set<String> identities;
        for (const char *field : {"weapons", "defences"}) {
            Array rows = d.get(field, Array());
            for (int i = 0; i < rows.size(); ++i) {
                Dictionary row = rows[i], entry = row.get("entry", Dictionary());
                String id = entry.get("id", "");
                if (id.is_empty() || !identities.insert(id).second || bool(row.get("hostile", false))) return false;
                if (String(field) == "weapons") { Weapon parsed; if (!read_weapon(row, i, d.get("repeat_delay", repeat_delay), parsed)) return false; prepared.push_back(std::move(parsed)); }
                else modules.push_back(read_defence(row));
            }
        }
        drone_values = read_drone_globals(drones);
        return configuration_arithmetic(d, attack_counter, incoming_counter, prepared, modules);
        } catch (const std::exception &) { return false; }
    }
    Dictionary set_player_configuration(Dictionary d, String change_kind) {
        Dictionary outcome;
        try {
        std::vector<Weapon> prepared;
        std::vector<Defence> modules;
        std::vector<std::array<Amount, 2>> drone_values;
        if (!prepare_player_configuration(d, change_kind, prepared, modules, drone_values)) {
            outcome["ok"] = false; outcome["fault"] = false; outcome["reason"] = "NativeConfigurationRejected";
            return outcome; // No owner mutation has happened.
        }
        const Amount before[2] = {layer_health(0), layer_health(1)}, old_capacity[2] = {capacity(0), capacity(1)};
        const size_t old_size = weapons.size();
        std::vector<bool> was_configured(old_size);
        for (size_t i = 0; i < old_size; ++i) {
            was_configured[i] = weapons[i].configured;
            if (!weapons[i].hostile) { weapons[i].enabled = false; weapons[i].configured = false; }
        }
        Array rows = d["weapons"];
        for (int n = 0; n < rows.size(); ++n) {
            Dictionary row = rows[n], entry = row["entry"];
            Weapon replacement = std::move(prepared[n]);
            size_t match = SIZE_MAX;
            for (size_t i = 0; i < old_size; ++i) {
                const Weapon &old = weapons[i];
                if (!old.hostile && was_configured[i] && old.entry.get("id", "") == entry.get("id", "") &&
                    old.entry.get("generation", int64_t(0)) == entry.get("generation", int64_t(0)) && old.entry.get("key", "") == entry.get("key", "")) { match = i; break; }
            }
            replacement.enabled = !disabled_drones.count(String(entry.get("drone_id", "")));
            if (match != SIZE_MAX) {
                replacement.focus_uid = weapons[match].focus_uid; replacement.focus_since = weapons[match].focus_since;
                replacement.critical_stacks = weapons[match].critical_stacks; replacement.critical_until = weapons[match].critical_until; replacement.critical_attacks = weapons[match].critical_attacks;
                replacement.beam = weapons[match].beam;
                replacement.muzzle = weapons[match].muzzle; replacement.screen_muzzle = weapons[match].screen_muzzle;
                weapons[match] = replacement; // Existing roots keep their due time; Attacks keep immutable birth snapshots.
            } else {
                int index = 0;
                while (index < int(weapons.size()) && !weapons[index].vacant) ++index;
                if (index == int(weapons.size())) weapons.push_back(replacement); else weapons[index] = replacement;
                roots.push({clock + replacement.remaining, ++event_serial, 0, index});
            }
        }
        for (size_t id : active) if (flights[id].live && flights[id].beam && !weapons[flights[id].weapon].enabled) retire(id);
        auto filter = [&](auto &queue) {
            std::vector<Timed> kept;
            while (!queue.empty()) { Timed event = queue.top(); queue.pop(); if (weapons[event.weapon].enabled) kept.push_back(event); }
            for (const Timed &event : kept) queue.push(event);
        };
        filter(roots); filter(ejections); filter(repeats);
        std::vector<bool> referenced(weapons.size(), false);
        for (size_t id : active) if (flights[id].live) referenced[flights[id].weapon] = true;
        for (size_t i = 0; i < weapons.size(); ++i) if (!weapons[i].configured && !referenced[i]) weapons[i].vacant = true;
        std::vector<Defence> next;
        Array defs = d["defences"];
        for (int i = 0; i < defs.size(); ++i) {
            Defence value = std::move(modules[i]);
            value.maximum = value.loss = value.buffer = 0;
            value.last_hit = 0;
            for (const Defence &old : defences) if (old.entry.get("id", "") == value.entry.get("id", "") && old.entry.get("key", "") == value.entry.get("key", "") && old.entry.get("generation", int64_t(0)) == value.entry.get("generation", int64_t(0))) {
                value.maximum = old.maximum; value.loss = old.loss;
                value.buffer = old.buffer; value.last_hit = old.last_hit;
                value.cover = old.cover; value.cover_next = old.cover_next; value.cover_until = old.cover_until;
                value.protection_type = old.protection_type; value.protection_until = old.protection_until; value.protection_lockout = old.protection_lockout;
                value.source_stacks = old.source_stacks; break;
            }
            next.push_back(value);
        }
        defences = std::move(next);
        counter_growth = d.get("counter_growth", 0.0); defence_counter_growth = d.get("defence_counter_growth", 0.0);
        counter_level = d.get("counter_level", int64_t(0)); counter_log_base = d.get("counter_log_base", counter_log_base); counter_round_scale = d.get("counter_round_scale", counter_round_scale);
        repeat_delay = d.get("repeat_delay", repeat_delay); memory_interval = d.get("memory_interval", memory_interval);
        deferred_interval = d.get("deferred_interval", deferred_interval); deferred_duration = d.get("deferred_duration", deferred_duration); clear_probability = d.get("clear_probability", 0.0);
        configure_enhancement(d); configure_legends(d, drone_values);
        apply_defence_capacity(change_kind, before, old_capacity);
        publish_player(); retain_configuration_bounds(); compact();
        outcome["ok"] = true; outcome["fault"] = false;
        return outcome;
        } catch (const std::exception &e) {
            failure_reason = String(e.what()); stopped = true; executing = false;
            outcome["ok"] = false; outcome["fault"] = true; outcome["reason"] = failure_reason;
            return outcome; // A commit fault can leave partial native state; never resume it.
        }
    }
    // Atomic, O(weapon slots), reusable across arbitrary art/configuration edits.
    // Empty rows select the existing numerical display fallback.
    void apply_muzzles(Dictionary rows, bool screen) {
        for (Weapon &w : weapons) {
            if (w.vacant || (!w.hostile && !w.configured)) continue;
            String key = w.hostile && w.source.index < actors.size()
                ? String("enemy:") + String::num_int64(actors[w.source.index].uid) + ":" + String::num_int64(w.slot)
                : String(w.entry.get("id", ""));
            if (!rows.has(key) || Variant(rows[key]).get_type() != Variant::VECTOR2) continue;
            Vector2 point = rows[key];
            if (!point.is_finite()) continue;
            if (screen) w.screen_muzzle = point; else w.muzzle = point;
        }
    }
    void input_ballistic_geometry(Array hulls, PackedVector2Array points, Dictionary muzzles, PackedByteArray stationary = PackedByteArray()) {
        for (int i = 0; i < int(actors.size()) && i < hulls.size() && i < points.size(); ++i) {
            const PackedVector2Array hull = hulls[i];
            const bool fixed = i < stationary.size() && stationary[i] != 0;
            if (actors[i].collision_hull != hull || actors[i].stationary_geometry != fixed)
                ++actors[i].geometry_revision;
            actors[i].collision_hull = hull;
            actors[i].stationary_geometry = fixed;
            actors[i].screen_point = points[i];
        }
        apply_muzzles(muzzles, true);
    }
    void refresh_ray_contact(Flight &f, const Actor &target) {

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
    void input_geometry(PackedVector2Array points, Dictionary muzzles) {
        for (int i = 0; i < points.size() && i < int(actors.size()); ++i)
            actors[i].point = points[i];
        apply_muzzles(muzzles, false);
    }
    bool advance(double seconds) {
        try {
        if (!can_advance(seconds)) return false;
        damage_receipts_emitted = 0;
        if (retreating) { clock += seconds; return true; }
        double end = clock + seconds;
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
            if (!strange_pending.empty()) {
                double due = std::get<0>(strange_pending.begin()->first);
                if (due > clock + 1e-9) next = minimum(next, due);
            }
            if (black_until > clock + 1e-9) next = minimum(next, black_until);
            if (black_next_at > clock + 1e-9) next = minimum(next, black_next_at);
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
    Array enemy_views() const {
        if (!actor_view_changes.empty() || actor_view_rows.size() != int64_t(actors.size())) {
            Array rows;
            if (actor_view_changes.size() == actors.size()) rows.set_typed(Variant::DICTIONARY, StringName(), Variant());
            else rows = actor_view_rows.duplicate();
            rows.resize(actors.size());
            for (size_t i : actor_view_changes) {
                Dictionary row = actors[i].view.duplicate(); row.make_read_only(); rows[i] = row;
            }
            rows.make_read_only(); actor_view_rows = rows; actor_view_changes.clear();
        }
        return actor_view_rows;
    }
    // Native drawing reads typed ownership; no projectile dictionary inventory.
    struct PresentationFlight {
        uint64_t serial = 0;
        Ref<SpaceMotionLease> motion;
        int kind = 0, type = 0, ticks = 0, links = 0;
        bool hostile = false, beam = false, fixed = false, awaiting = false, powered = false;
        Vector2 launch, ray_origin, ray_step;
        double age = 0, charge = 0, ramp = 1;
    };
    bool presentation_running() const { return admitted && !stopped; }
    size_t presentation_slots() const { return flights.size(); }
    size_t presentation_count() const { return active.size(); }
    size_t presentation_index(size_t order) const { return active[order]; }
    bool presentation_matches(size_t id, uint64_t serial, const Ref<SpaceMotionLease> &lease) const {
        return id < flights.size() && flights[id].live && flights[id].serial == serial && flights[id].lease == lease;
    }
    bool presentation_read(size_t id, PresentationFlight &view) const {
        if (id >= flights.size() || !flights[id].live) return false;
        const Flight &f = flights[id];
        view.serial = f.serial; view.motion = f.lease; view.kind = f.instance->attack->birth->kind;
        view.hostile = f.hostile; view.beam = f.beam; view.type = f.type;
        view.awaiting = f.await_target; view.powered = view.kind == 2 && !f.chain && !f.target_lost;
        view.fixed = f.fixed_ray; view.launch = f.launch_point;
        view.ray_origin = f.ray_origin;
        view.ray_step = f.ray_step;
        view.age = f.age; view.charge = f.charge; view.ramp = f.ramp; view.ticks = f.ticks;
        view.links = f.beam ? int(f.instance->links.size()) : 0;
        return true;
    }
    bool presentation_endpoint(size_t id, int link, Vector2 &point) const {
        const Flight &f = flights[id];
        if (link < 0 && f.hostile) { point = Vector2(player_row["x"], player_row["y"]); return !bool(player_row.get("dead", false)); }
        const Actor *target = resolve(link < 0 ? f.target : f.instance->links[link]);
        if (!target) return false;
        point = target->logical; return true;
    }
    Dictionary player_view() const {
        return player_row;
    }
    Dictionary set_player_values(Dictionary weapon_values, Dictionary defence_values, String kind, String iron_factor, Dictionary upgrades) {
        Dictionary result; result["ok"] = false; result["fault"] = false; result["reason"] = "NativeConfigurationRejected";
        if (!admitted || executing || (kind != "growth" && kind != "selection" && kind != "refit" && kind != "upgrade")) return result;
        bool committing = false;
        try {
            Amount iron;
            if (!iron_factor.is_empty()) iron = read_amount(iron_factor);
            if (!finite_descriptor(upgrades)) return result;
            Dictionary g = upgrades.get("globals", Dictionary()), ew = upgrades.get("weapon", Dictionary()), ed = upgrades.get("defence", Dictionary());
            double attack_growth = g.get("counter_growth", counter_growth), defence_growth = g.get("defence_counter_growth", defence_counter_growth);
            int64_t level = g.get("counter_level", counter_level);
            double log_base = g.get("counter_log_base", counter_log_base), round_scale = g.get("counter_round_scale", counter_round_scale);
            bool defence_history = defence_growth != defence_counter_growth || ((defence_growth != 0 || defence_counter_growth != 0) && level != counter_level);
            bool attack_history = attack_growth != counter_growth || ((attack_growth != 0 || counter_growth != 0) && level != counter_level);
            std::vector<std::pair<size_t, Weapon>> sources;
            std::vector<std::pair<size_t, Defence>> modules;
            for (bool defence : {false, true}) {
                Dictionary inputs = defence ? defence_values : weapon_values;
                Array keys = inputs.keys();
                for (int n = 0; n < keys.size(); ++n) {
                    if (Variant(keys[n]).get_type() != Variant::STRING || Variant(inputs[keys[n]]).get_type() != Variant::DICTIONARY) return result;
                    String id = keys[n]; Dictionary row = inputs[keys[n]];
                    if (!schema_required(row, {"key", "generation"}) || !schema_types(row, Variant::STRING, {"key"}) || !schema_integers(row, {"generation"}, false)) return result;
                    size_t found = SIZE_MAX;
                    if (defence) {
                        for (size_t i = 0; i < defences.size(); ++i) if (defences[i].entry.get("id", "") == id && defences[i].entry.get("key", "") == row["key"] && defences[i].entry.get("generation", int64_t(0)) == row["generation"]) { found = i; break; }
                        if (found == SIZE_MAX) return result;
                        Defence next = defences[found];
                        if (row.has("base")) next.base = read_amount(row["base"]);
                        if (row.has("external")) next.external_factors = read_factors(row["external"]);
                        if (next.base == defences[found].base && next.external_factors == defences[found].external_factors) continue;
                        modules.push_back({found, std::move(next)});
                    } else {
                        for (size_t i = 0; i < weapons.size(); ++i) if (!weapons[i].hostile && weapons[i].configured && !weapons[i].vacant && weapons[i].entry.get("id", "") == id && weapons[i].entry.get("key", "") == row["key"] && weapons[i].entry.get("generation", int64_t(0)) == row["generation"]) { found = i; break; }
                        if (found == SIZE_MAX) return result;
                        Weapon next = weapons[found];
                        if (row.has("base")) next.base = read_amount(row["base"]);
                        if (row.has("external")) next.external_factors = read_factors(row["external"]);
                        if (row.has("paid_level") && (next.entry.get("paid_level", 0) != row["paid_level"] || next.entry.get("effective_level", 0) != row["effective_level"])) {
                            next.entry = next.entry.duplicate(); next.entry["paid_level"] = row["paid_level"]; next.entry["effective_level"] = row["effective_level"];
                            auto birth = std::make_shared<BirthConfig>(*next.birth); birth->entry = next.entry.duplicate(true); birth->entry.make_read_only(); next.birth = birth;
                        }
                        if (next.base == weapons[found].base && next.external_factors == weapons[found].external_factors && next.birth == weapons[found].birth) continue;
                        sources.push_back({found, std::move(next)});
                    }
                }
            }
            if (!ew.is_empty() || attack_history) for (size_t i = 0; i < weapons.size(); ++i) {
                if (weapons[i].hostile || !weapons[i].configured || weapons[i].vacant) continue;
                auto found = std::find_if(sources.begin(), sources.end(), [i](const auto &v) { return v.first == i; });
                if (found == sources.end()) { sources.push_back({i, weapons[i]}); found = sources.end() - 1; }
                enhance_weapon(found->second, ew);
            }
            if (!ed.is_empty() || defence_history) for (size_t i = 0; i < defences.size(); ++i) {
                auto found = std::find_if(modules.begin(), modules.end(), [i](const auto &v) { return v.first == i; });
                if (found == modules.end()) { modules.push_back({i, defences[i]}); found = modules.end() - 1; }
                Defence &d = found->second;
                if (ed.has("branch_factors")) d.branch_factors = read_factors(ed["branch_factors"]);
                d.memory_heal = ed.get("memory_heal", d.memory_heal); d.memory_cap = ed.get("memory_cap", d.memory_cap); d.deferred_fraction = ed.get("deferred_fraction", d.deferred_fraction);
            }
            for (const auto &v : sources) {
                const Weapon &w = v.second;
                evaluate_module_value(w.base, attack_counter, attack_growth, level, log_base, round_scale, w.branch_factors, w.external_factors) * w.factor * drone_weapon(w.kind);
            }
            std::vector<size_t> changed;
            for (const auto &v : modules) {
                const Defence &d = v.second;
                Amount maximum = evaluate_module_value(d.base, incoming_counter, defence_growth, level, log_base, round_scale, d.branch_factors, d.external_factors) * d.factor * drone_defence(d.layer);
                if (maximum != defences[v.first].maximum) changed.push_back(v.first);
            }
            Amount before[2], old_capacity[2];
            if (!changed.empty()) {
                before[0] = layer_health(0); before[1] = layer_health(1);
                old_capacity[0] = capacity(0); old_capacity[1] = capacity(1);
            }
            committing = true;
            bool endless_changed = false;
            for (auto &value : sources) {
                Weapon &target = weapons[value.first];
                endless_changed = endless_changed || (target.kind == 3 && target.entry.get("paid_level", 1) != value.second.entry.get("paid_level", 1));
                target = std::move(value.second);
                retained_min_interval = minimum(retained_min_interval, target.interval); retained_chain_bound = maximum(retained_chain_bound, target.chain_count);
            }
            if (endless_changed) select_endless_source();
            for (auto &value : modules) defences[value.first] = std::move(value.second);
            counter_growth = attack_growth; defence_counter_growth = defence_growth; counter_level = level; counter_log_base = log_base; counter_round_scale = round_scale;
            repeat_delay = g.get("repeat_delay", repeat_delay); memory_interval = g.get("memory_interval", memory_interval);
            deferred_interval = g.get("deferred_interval", deferred_interval); deferred_duration = g.get("deferred_duration", deferred_duration);
            if (!upgrades.is_empty()) {
                Dictionary descriptor, state; state["effects"] = upgrades.get("effects", Dictionary()); descriptor["enhancement_state"] = state;
                descriptor["clear_probability"] = g.get("clear_probability", deferred_unforced_probability); configure_enhancement(descriptor, true);
            }
            if (!iron_factor.is_empty()) iron_drop_factor = iron;
            if (!changed.empty()) { apply_defence_capacity(kind, before, old_capacity, &changed); publish_player(); }
            if (ed.has("memory_cap")) for (const auto &value : modules) if (std::find(changed.begin(), changed.end(), value.first) == changed.end()) {
                Defence &d = defences[value.first]; d.buffer = minimum(d.buffer, d.maximum * d.memory_cap);
            }
            result["defence_changed"] = !changed.empty();
            result["ok"] = true; result.erase("reason"); return result;
        } catch (const std::exception &e) {
            if (committing) { failure_reason = String(e.what()); stopped = true; result["fault"] = true; result["reason"] = failure_reason; }
            return result;
        }
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
    void cancel() {
        stopped = true;
        strange_pending.clear();
        while (!roots.empty())
            roots.pop();
        while (!ejections.empty())
            ejections.pop();
        while (!repeats.empty())
            repeats.pop();
        for (size_t id : active)
            retire(id);
        if (!executing)
            compact();
    }
};
