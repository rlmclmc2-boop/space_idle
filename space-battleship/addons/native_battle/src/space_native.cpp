#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/font.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/core/math.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <deque>
#include <vector>

using namespace godot;
static_assert(sizeof(real_t)==4 && sizeof(double)==8,"This build must match Godot single vectors and GDScript doubles.");

namespace {
// Use the engine's original builtin methods for transcendental/vector methods.
// This is a native ptrcall, never a GDScript callback. It also avoids CRT/compiler
// differences changing a single rounded motion component over many substeps.
struct VectorMethods {
    GDExtensionPtrBuiltInMethod angle, normalized, distance, from_angle;
    VectorMethods() {
        StringName a("angle"),n("normalized"),d("distance_to"),f("from_angle");
        angle=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,a._native_ptr(),466405837);
        normalized=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,n._native_ptr(),2428350749);
        distance=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,d._native_ptr(),3819070308);
        from_angle=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,f._native_ptr(),889263119);
    }
};
VectorMethods &vector_methods(){static VectorMethods methods;return methods;}
double engine_angle(const Vector2 &v){double result;vector_methods().angle(const_cast<Vector2*>(&v),nullptr,&result,0);return result;}
double engine_distance(const Vector2 &a,const Vector2 &b){double result;const void *args[]={&b};vector_methods().distance(const_cast<Vector2*>(&a),args,&result,1);return result;}
Vector2 engine_normalized(const Vector2 &v){Vector2 result;vector_methods().normalized(const_cast<Vector2*>(&v),nullptr,&result,0);return result;}
Vector2 engine_from_angle(double angle){Vector2 result;const void *args[]={&angle};vector_methods().from_angle(nullptr,args,&result,1);return result;}
// GDScript scalar values are double, but every Vector2 operation rounds to the
// single-precision real_t of this engine. Do not combine consecutive multiplies.
struct Motion {
    double x = 0, y = 0, speed = 0, age = 0, orphan = 0;
    Vector2 direction, last_aim;
    uint64_t generation = 0;
    int kind = 0; // 0 straight, 1 presented missile, 2 chain, 3 ordinary homing
    bool missile_fields = false;
};
bool same(const Variant &a, const Variant &b) { return UtilityFunctions::is_same(a, b); }
bool chain_hp_positive(const Variant &hp) {
    // GrowthNumber.compare(hp,0), including its mantissa/exponent authority.
    return hp.get_type()==Variant::DICTIONARY ? double(Dictionary(hp)["m"])!=0.0 : double(hp)>0.0;
}
Vector2 position(const Motion &m) { return Vector2(m.x, m.y); }
Vector2 movement(const Motion &m, double dt) { return (m.direction * m.speed) * dt; }
Vector2 battle_point(Vector2 p) { return Vector2(p.x, double(p.y) + Math::smoothstep(220.0, 420.0, double(p.y)) * 220.0); }
Vector2 inverse_battle_point(Vector2 p) {
    constexpr double offset=110.0/(1<<20);
    if(p.y>=-512.0&&p.y<=220.0)return Vector2(p.x,double(p.y)-offset);
    if(p.y>=640.0&&p.y<=2048.0)return Vector2(p.x,double(p.y)-220.0+offset);
    double low=double(p.y)-220.0,high=p.y;
    for(int i=0;i<20;++i){double middle=(low+high)*0.5;if(battle_point(Vector2(0,middle)).y<p.y)low=middle;else high=middle;}
    return Vector2(p.x,(low+high)*0.5);
}
}

class SpaceNativePipeline;
// History owns only immutable scalar payloads. Formatting and translation remain
// in the existing display formatter, invoked only by a public history read.
class SpaceDamageHistory : public RefCounted {
    GDCLASS(SpaceDamageHistory,RefCounted)
    struct Number {
        Variant scalar,m,e; bool large=false;
        void capture(const Variant &value) {
            large=value.get_type()==Variant::DICTIONARY;
            if(large){Dictionary d=value;m=d["m"];e=d["e"];scalar=Variant();}
            else {scalar=value;m=Variant();e=Variant();}
        }
        Variant value() const {if(!large)return scalar;Dictionary d;d["m"]=m;d["e"]=e;return d;}
    };
    struct Record {bool player=false,critical=false;Variant uid;int type=0;Number amount,absorbed;};
    std::array<Record,40> records;
    size_t head=0,count=0;
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("append","player","uid","type","critical","amount","absorbed"),&SpaceDamageHistory::append);
        ClassDB::bind_method(D_METHOD("snapshot"),&SpaceDamageHistory::snapshot);
    }
public:
    void append(bool player,Variant uid,int type,bool critical,Variant amount,Variant absorbed) {
        size_t at=(head+count)%40;if(count==40){at=head;head=(head+1)%40;}else ++count;
        Record &r=records[at];r.player=player;r.uid=uid;r.type=type;r.critical=critical;r.amount.capture(amount);r.absorbed.capture(absorbed);
    }
    Array snapshot() const {
        Array result;result.resize(count);
        for(size_t i=0;i<count;++i){const Record &r=records[(head+i)%40];Array row;
            row.push_back(r.player);row.push_back(r.uid);row.push_back(r.type);row.push_back(r.critical);row.push_back(r.amount.value());row.push_back(r.absorbed.value());result[i]=row;}
        return result;
    }
};

// One synchronous final display transaction owns these reusable metrics and
// occupied rectangles. No cache survives reset and no entity graph is copied.
class SpaceDamageLayout : public RefCounted {
    GDCLASS(SpaceDamageLayout,RefCounted)
    struct Occupied {Dictionary entry;Rect2 rect;bool incoming;};
    struct Metric {String text;int size;Dictionary values;};
    std::vector<Occupied> occupied;
    std::vector<Metric> metrics;
    static Rect2 bounds(Vector2 p,double width,double ascent,double height) {
        return Rect2(p-Vector2(std::max(0.0,92.0-width)/2.0,ascent),Vector2(std::max(92.0,width),height)).grow(4);
    }
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("reset"),&SpaceDamageLayout::reset);
        ClassDB::bind_method(D_METHOD("metrics","font","text","size"),&SpaceDamageLayout::get_metrics);
        ClassDB::bind_method(D_METHOD("occupy","entry","rect"),&SpaceDamageLayout::occupy);
        ClassDB::bind_method(D_METHOD("overlaps_incoming","rect"),&SpaceDamageLayout::overlaps_incoming);
        ClassDB::bind_method(D_METHOD("position","origin","width","ascent","height","excluded","bottom","obstacles","ready","battlefield_width"),&SpaceDamageLayout::place);
    }
public:
    void reset(){occupied.clear();metrics.clear();}
    Dictionary get_metrics(Ref<Font> font,String text,int size) {
        for(const Metric &m:metrics)if(m.size==size&&m.text==text)return m.values;
        Dictionary values;values["width"]=font->get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x;
        values["ascent"]=font->get_ascent(size);values["height"]=font->get_height(size);
        metrics.push_back({text,size,values});return values;
    }
    void occupy(Dictionary entry,Rect2 rect) {
        for(Occupied &o:occupied)if(same(o.entry,entry)){o.rect=rect;return;}
        occupied.push_back({entry,rect,bool(entry.get("incoming_lane",false))});
    }
    bool overlaps_incoming(Rect2 rect) const {
        for(const Occupied &o:occupied)if(o.incoming&&o.rect.grow(8).intersects(rect))return true;return false;
    }
    Vector2 place(Vector2 origin,double width,double ascent,double height,Dictionary excluded,double bottom,Array obstacles,bool ready,double battlefield_width) const {
        for(int row=0;row<2;++row)for(int shift:{0,-56,56,-140,140}) {
            Vector2 p(Math::clamp(double(origin.x)-width/2.0+shift,8.0,battlefield_width-8.0-width),double(origin.y)-row*40.0);
            Rect2 rect=bounds(battle_point(p),width,ascent,height);if(rect.position.y<8)continue;
            bool blocked=false;
            for(const Occupied &o:occupied)if(double(o.entry.get("life",0.0))>0&&!same(o.entry,excluded)&&rect.grow(8).intersects(o.rect)){blocked=true;break;}
            if(blocked)continue;
            if(rect.position.y<bottom) {
                // Preserve lazy canonical enemy geometry acquisition exactly.
                if(!ready)return Vector2(-INFINITY,-INFINITY);
                for(int i=0;i<obstacles.size();++i)if(rect.intersects(Rect2(obstacles[i]))){blocked=true;break;}
            }
            if(!blocked)return p;
        }
        return Vector2(INFINITY,INFINITY);
    }
};
class SpaceVisualLease : public RefCounted {
    GDCLASS(SpaceVisualLease,RefCounted)
    friend class SpaceNativePipeline;
    double age=0,angle=0;
    std::array<Vector2,14> trail;
    std::array<float,14> times{};
    int head=0,samples=1;
    Vector2 last_render,last_logical;
    bool had_target=false;
protected:
    static void _bind_methods(){ClassDB::bind_method(D_METHOD("read","key"),&SpaceVisualLease::read);}
public:
    Variant read(StringName key) const {
        if(key==StringName("age"))return age;if(key==StringName("angle"))return angle;
        if(key==StringName("head"))return head;if(key==StringName("samples"))return samples;
        if(key==StringName("last_render_point"))return last_render;if(key==StringName("last_logical_point"))return last_logical;
        if(key==StringName("had_target"))return had_target;
        if(key==StringName("trail")){PackedVector2Array result;result.resize(14);std::copy(trail.begin(),trail.end(),result.ptrw());return result;}
        if(key==StringName("trail_times")){PackedFloat32Array result;result.resize(14);std::copy(times.begin(),times.end(),result.ptrw());return result;}
        return Variant();
    }
};
class SpaceMotionLease : public RefCounted {
    GDCLASS(SpaceMotionLease, RefCounted)
    friend class SpaceNativePipeline;
    Ref<SpaceNativePipeline> owner;
    size_t slot = 0;
    uint64_t generation = 0;
    Motion &motion() const;
protected:
    static void _bind_methods();
public:
    ~SpaceMotionLease();
    Vector2 get_position() const { return position(motion()); }
    Vector2 get_direction() const { return motion().direction; }
    double get_x() const { return motion().x; }
    double get_y() const { return motion().y; }
    double get_speed() const { return motion().speed; }
    double get_age() const { return motion().age; }
    double get_orphan() const { return motion().orphan; }
    Vector2 get_last_aim() const { return motion().last_aim; }
    bool has_missile_fields() const { return motion().missile_fields; }
    void set_position(Vector2 p) { motion().x = p.x; motion().y = p.y; }
    void set_direction(Vector2 v) { motion().direction = v; }
    void set_speed(double v) { motion().speed = v; }
    void set_age(double v) { motion().age = v; }
    void set_orphan(double v) { motion().orphan = v; }
};

struct PreparedFlight {
    Dictionary shot,visual;
    Ref<SpaceMotionLease> motion;
    Ref<SpaceVisualLease> visual_state;
    Vector2 point;
    String key;
    int budget=1;
    bool hostile=false,chain=false;
    Dictionary legacy() const {
        Dictionary f;f["shot"]=shot;f["visual"]=visual;f["pos"]=point;f["budget"]=budget;return f;
    }
};
class SpaceFlightFrame : public RefCounted {
    GDCLASS(SpaceFlightFrame,RefCounted)
    friend class SpaceNativePipeline;
    Ref<SpaceNativePipeline> recycler;
    std::vector<PreparedFlight> flights;
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("size"),&SpaceFlightFrame::size);
        ClassDB::bind_method(D_METHOD("to_array"),&SpaceFlightFrame::to_array);
    }
public:
    ~SpaceFlightFrame();
    int64_t size() const {return flights.size();}
    // Compatibility/reference inspection only, never the native production path.
    Array to_array() const {Array result;for(const PreparedFlight &f:flights)result.push_back(f.legacy());return result;}
};

class SpaceNativePipeline : public RefCounted {
    GDCLASS(SpaceNativePipeline, RefCounted)
    friend class SpaceMotionLease;
    friend class SpaceFlightFrame;
    // Only empty vector capacities are pooled. No frame/shot/lease references
    // are owned by this pool, so deferred canvas frames cannot create a cycle.
    std::vector<std::vector<PreparedFlight>> spare_frames;
    void recycle_frame(std::vector<PreparedFlight> &flights) {
        flights.clear();if(spare_frames.size()<4){spare_frames.emplace_back();spare_frames.back().swap(flights);}
    }
    std::deque<Motion> motions;
    std::vector<size_t> free_slots;
    uint64_t next_generation = 0;
    std::vector<Dictionary> pending;
    std::vector<Ref<SpaceMotionLease>> pins;
    std::vector<Vector2> vertices;
    std::vector<Color> colors;
    PackedVector2Array packed_vertices;
    PackedColorArray packed_colors;
    std::vector<Vector2> body;
    std::vector<Color> body_colors;
    std::vector<Vector2> chain;
    std::vector<Color> chain_colors;
    std::vector<Vector2> ribbon_input;
    std::array<std::vector<Vector2>,3> ribbon_points;
    std::array<std::vector<Color>,3> ribbon_colors;
    std::array<Vector2, 65> circle;
    bool templates_ready = false;
    Ref<ArrayMesh> pulse_mesh;
    std::vector<Ref<MultiMesh>> pulse_pool;
    std::vector<Transform2D> pulse_transforms;
    size_t pulse_cursor = 0;

    void release(size_t slot, uint64_t gen) {
        if (motions[slot].generation == gen) { motions[slot].generation = 0; free_slots.push_back(slot); }
    }
    void tri(Vector2 a, Vector2 b, Vector2 c, Color ca, Color cb, Color cc) {
        vertices.push_back(a); vertices.push_back(b); vertices.push_back(c);
        colors.push_back(ca); colors.push_back(cb); colors.push_back(cc);
    }
    void tri(Vector2 a, Vector2 b, Vector2 c, Color color) { tri(a, b, c, color, color, color); }
    void quad(Vector2 a, Vector2 b, Vector2 c, Vector2 d, Color ca, Color cb, Color cc, Color cd) {
        tri(a,b,c,ca,cb,cc); tri(a,c,d,ca,cc,cd);
    }
    void line(Vector2 from, Vector2 to, Color color, double width);
    void ribbon(const std::vector<Vector2> &points, Color color, double width, bool closed);
    void disk(Vector2 center, double radius, Color color) {
        for (int i = 0; i < 64; ++i) tri(center, center + circle[i] * radius, center + circle[i+1] * radius, color);
    }
    void prepare_templates();
    void prepare_pulse_mesh();
    void flush_pulses(RID canvas);
    void template_at(const std::vector<Vector2>& points, const std::vector<Color>& tints, Vector2 point, Vector2 axis) {
        Transform2D transform(double(axis.angle()) + Math::PI / 2.0, point);
        for (size_t i = 0; i < points.size(); ++i) { vertices.push_back(transform.xform(points[i])); colors.push_back(tints[i]); }
    }
protected:
    static void _bind_methods();
public:
    Ref<SpaceMotionLease> bind_motion(Dictionary shot) {
        Ref<SpaceMotionLease> lease; lease.instantiate();
        const size_t slot = free_slots.empty() ? motions.size() : free_slots.back();
        if (free_slots.empty()) motions.emplace_back(); else free_slots.pop_back();
        Motion &m = motions[slot]; m = Motion(); m.generation = ++next_generation;
        m.x = shot["x"]; m.y = shot["y"]; m.direction = shot["direction"]; m.speed = shot["speed"];
        m.missile_fields = shot.has("motion_age");
        m.age = shot.get("motion_age", 0.0); m.orphan = shot.get("orphan_age", 0.0);
        m.last_aim = shot.get("last_target_point", Vector2());
        const String key = shot.get("key", "");
        m.kind = bool(shot.get("chain_hop", false)) ? 2 : bool(shot.get("prototype_missile", false)) ? 1 : key.replace("_mon", "").replace("-mon", "") == "missile" ? 3 : 0;
        lease->owner = Ref<SpaceNativePipeline>(this); lease->slot = slot; lease->generation = m.generation;
        shot["motion_lease"] = lease;
        for (const char *key : {"x", "y", "direction", "speed", "motion_age", "orphan_age", "last_target_point"}) shot.erase(key);
        return lease;
    }
    void advance(Object *game, double dt, bool shield_timing, Array snapshot);
    Ref<SpaceFlightFrame> prepare_flights(Object *surface, Array shots, Vector2 offset);
    void draw_flights(Object *surface, Variant prepared, Vector2 offset);
    void bind_visual(Dictionary visual) {
        if(visual.is_empty()||visual.has("visual_lease"))return;
        Dictionary shot=visual["shot"];
        if(!bool(shot.get("prototype_missile",false))&&!visual.has("fixed_step"))return;
        Ref<SpaceVisualLease> v;v.instantiate();v->age=visual.get("age",0.0);v->angle=visual.get("angle",0.0);
        v->head=visual.get("head",0);v->samples=visual.get("samples",1);
        PackedVector2Array points=visual.get("trail",PackedVector2Array());PackedFloat32Array times=visual.get("trail_times",PackedFloat32Array());
        for(int i=0;i<14;++i){v->trail[i]=points.size()==14?points[i]:Vector2(visual["origin"]);v->times[i]=times.size()==14?times[i]:0;}
        v->last_render=visual.get("last_render_point",Vector2());v->last_logical=visual.get("last_logical_point",Vector2());v->had_target=visual.get("had_target",false);
        visual["visual_lease"]=v;
        for(const char *key:{"age","angle","head","samples","trail","trail_times","last_render_point","last_logical_point","had_target"})visual.erase(key);
    }
    void advance_visuals(Object *surface,double dt);
    void begin() { prepare_templates(); vertices.clear(); colors.clear(); }
    void flight(Vector2 point, Vector2 axis, double age, bool powered, Dictionary visual, Vector2 offset, double budget);
    void chain_flight(Vector2 point, Vector2 direction) {
        prepare_templates(); Vector2 axis = direction.is_zero_approx() ? Vector2(0,-1) : direction.normalized();
        template_at(chain, chain_colors, point, axis);
    }
    void paint(RID canvas) {
        if (vertices.empty()) return;
        packed_vertices.resize(vertices.size()); packed_colors.resize(colors.size());
        std::copy(vertices.begin(), vertices.end(), packed_vertices.ptrw());
        std::copy(colors.begin(), colors.end(), packed_colors.ptrw());
        RenderingServer::get_singleton()->canvas_item_add_triangle_array(canvas, PackedInt32Array(), packed_vertices, packed_colors);
        vertices.clear(); colors.clear();
    }
};

Motion &SpaceMotionLease::motion() const { return owner->motions[slot]; }
SpaceMotionLease::~SpaceMotionLease() { if (owner.is_valid()) owner->release(slot, generation); }
SpaceFlightFrame::~SpaceFlightFrame() {if(recycler.is_valid())recycler->recycle_frame(flights);}

void SpaceNativePipeline::advance(Object *game, double dt, bool shield_timing, Array snapshot) {
    Array live = game->get("projectiles");
    pending.clear(); pins.clear(); pending.reserve(live.size()); pins.reserve(live.size());
    for (int i = 0; i < snapshot.size(); ++i) {
        Dictionary shot = snapshot[i]; pending.push_back(shot);
        pins.push_back(shot.get("motion_lease", Variant()));
    }
    Array enemies = game->get("enemies");
    Dictionary registry = game->get("missile_target_registry");
    Dictionary publication = game->get("projectile_target_points");
    Dictionary player = game->get("player");
    bool player_alive = game->call("_native_player_target_alive",player);
    const double launch_speed = game->get("MISSILE_LAUNCH_SPEED");
    const double cruise_default = game->get("MISSILE_CRUISE_SPEED");
    const double ignition = game->get("MISSILE_IGNITION");
    const double cruise_at = game->get("MISSILE_CRUISE_AT");
    const double lifetime = game->get("MISSILE_LIFETIME");
    const double brake_range = game->get("MISSILE_BRAKE_RANGE");
    const double brake_angle = game->get("MISSILE_BRAKE_ANGLE");
    const double min_speed = game->get("MISSILE_MIN_GUIDED_SPEED");
    const double turn_rate = game->get("MISSILE_TURN_RATE");
    const double brake_factor = game->get("MISSILE_BRAKE_FACTOR");
    const double seek_start = game->get("MISSILE_SEEK_START");
    const double hit_radius = game->get("MISSILE_HIT_RADIUS");
    const double orphan_lifetime = game->get("ORPHAN_LIFETIME");
    double maximum_turn_error = game->get("maximum_turn_step_error");
    // Canonical fallback points are transient to this ordered substep and are
    // discarded after every synchronous callback. Never retain a second target
    // graph or substitute logical coordinates for a presentation provider.
    struct SourcePoint { Dictionary entity; Variant x, y; Vector2 point; };
    std::vector<SourcePoint> source_points;
    auto publication_current = [&]() {
        if (!bool(game->get("projectile_target_points_active"))) return false;
        Object *spatial = game->get("target_spatial_source");
        bool geometry_current = !spatial ||
            (same(spatial->get("shape_revision"), game->get("projectile_target_points_shape_version")) &&
             same(spatial->get("geometry_revision"), game->get("projectile_target_points_geometry_version")));
        if (!geometry_current || !same(game->get("state"), game->get("projectile_target_points_state")) ||
            !same(player, game->get("projectile_target_points_player")) ||
            enemies.size() != int64_t(game->get("projectile_target_points_roster_size"))) {
            game->call("invalidate_projectile_target_points"); return false;
        }
        return true;
    };
    bool publication_valid = publication_current();
    auto refresh = [&]() {
        live = game->get("projectiles"); enemies = game->get("enemies"); registry = game->get("missile_target_registry"); player = game->get("player");
        player_alive = game->call("_native_player_target_alive",player);
        source_points.clear();
        // Match target_point's rejection rules after an actual callback. A
        // rejected publication stays rejected until the next real substep.
        publication_valid = publication_current();
        publication = game->get("projectile_target_points");
    };
    auto aim_for = [&](Dictionary target, Dictionary shot, bool ballistic) -> Vector2 {
        if (ballistic && shot.has("ballistic_target_origin")) return Vector2(shot["ballistic_target_origin"]) + Vector2(target["x"],target["y"]) - Vector2(shot["ballistic_target_logical"]);
        if (same(target, player)) return Vector2(target["x"], target["y"]);
        const int64_t uid = target.get("uid", -1);
        Dictionary row = publication_valid ? Dictionary(publication.get(uid, Dictionary())) : Dictionary();
        if (!row.is_empty() && same(row["entity"], target) && same(row["x"], target["x"]) && same(row["y"], target["y"]) &&
            same(row["version"], game->get("projectile_target_points_version"))) {
            int64_t target_index = row["index"];
            if (target_index >= 0 && target_index < enemies.size() && same(enemies[target_index], target)) return row["point"];
        }
        if (publication_valid) { game->call("invalidate_projectile_target_points"); publication_valid = false; }
        for (const SourcePoint &entry : source_points)
            if (same(entry.entity,target) && same(entry.x,target["x"]) && same(entry.y,target["y"])) return entry.point;
        Vector2 point = game->call("_source_target_point", target);
        source_points.push_back({target,target["x"],target["y"],point});
        return point;
    };
    for (size_t index = 0; index < pending.size(); ++index) {
        Dictionary shot = pending[index];
        if ((index >= size_t(live.size()) || !same(live[index], shot)) && !live.has(shot)) continue;
        Ref<SpaceMotionLease> lease = pins[index];
        if (lease.is_null()) {
            game->call("_native_unpacked_projectile", shot, dt, shield_timing);
            refresh(); if (live.is_empty()) break; continue;
        }
        Motion &m = lease->motion();
        if(m.kind==2 && bool(shot.get("dead",false)))continue;
        Dictionary target = shot["target"];
        const bool hostile = shot["hostile"];
        const bool target_alive = !target.is_empty() && (m.kind == 1 ? double(target.get("hp",0)) > 0 && same(registry.get(int64_t(target.get("uid",-1)), Variant()), target) : hostile ? player_alive : (m.kind==2?chain_hp_positive(target.get("hp",0)):double(target.get("hp",0))>0) && enemies.has(target));
        if (!target_alive) { target = Dictionary(); shot["target"] = target; }
        bool impact = false;
        Vector2 aim;
        if (m.kind == 1) {
            m.age += dt;
            if (!target.is_empty() && m.age > lifetime) {
                game->call("_native_missile_retire", shot, "lifetime"); refresh(); continue;
            }
            const Vector2 p = position(m);
            const double old_angle = engine_angle(m.direction);
            double speed = UtilityFunctions::lerpf(launch_speed, double(shot.get("cruise_speed",cruise_default)), UtilityFunctions::smoothstep(ignition,cruise_at,m.age));
            if (!target.is_empty()) {
                m.orphan = 0; aim = aim_for(target,shot,false); m.last_aim = aim;
                const double wanted = engine_angle(aim-p);
                const double range = engine_distance(p,aim);
                if (range < brake_range && std::abs(UtilityFunctions::angle_difference(old_angle,wanted)) > brake_angle) speed = std::min(speed,std::max(min_speed,range*turn_rate*brake_factor));
                m.speed = speed;
                if (m.age >= seek_start) {
                    const double angle = UtilityFunctions::rotate_toward(old_angle,wanted,turn_rate*dt);
                    maximum_turn_error = std::max(maximum_turn_error,std::abs(UtilityFunctions::angle_difference(old_angle,angle))-turn_rate*dt);
                    m.direction = engine_from_angle(angle);
                }
                const Vector2 next = p + movement(m,dt);
                const Vector2 closest=Geometry2D::get_singleton()->get_closest_point_to_segment(aim,p,next);
                impact = engine_distance(closest,aim) <= hit_radius;
            } else {
                m.orphan += dt;
                if (m.orphan >= orphan_lifetime) { game->call("_native_missile_retire",shot,"orphan_timeout"); refresh(); continue; }
                m.speed = std::max(m.speed,speed);
            }
        } else if (!target.is_empty()) {
            aim = hostile ? Vector2(target["x"],target["y"]) : aim_for(target,shot,m.kind != 2);
            const Vector2 delta = aim-position(m);
            if (m.kind == 2) {
                impact = engine_distance(position(m),aim) <= m.speed*dt;
                if (impact) { m.x = aim.x; m.y = aim.y; } else m.direction = engine_normalized(delta);
            } else {
                if (m.kind == 3) m.direction = engine_normalized(delta);
                const double along = delta.dot(m.direction);
                impact = m.kind == 3 ? delta.length() <= m.speed*dt : along >= 0 && along <= m.speed*dt && std::abs(double(delta.cross(m.direction))) <= 0.5;
            }
        }
        if (impact) {
            shot["dead"] = true;
            game->set("maximum_turn_step_error",maximum_turn_error);
            game->call("_native_projectile_contact",shot,aim,m.kind);
            refresh(); if (live.is_empty()) break; continue;
        }
        const Vector2 step = movement(m,dt); m.x += step.x; m.y += step.y;
        if (m.x < -32 || m.x > 572+32 || m.y < -32 || m.y > 696 + (m.kind == 1 ? 80 : 32)) shot["dead"] = true;
    }
    game->set("maximum_turn_step_error",maximum_turn_error);
    pending.clear(); pins.clear();
}

// The following AA primitive construction follows the same Godot 4.7.2 canvas
// widths, join clamps, 1.25px feathers and painter order as missile_body_mesh.gd.
void SpaceNativePipeline::line(Vector2 from, Vector2 to, Color color, double width) {
    if(width<=2.5)width*=0.5;
    else if(width<=5.0)width=Math::lerp(width*0.5,width-0.625,(width-2.5)/2.5);
    else width-=0.625;
    Vector2 diff = from-to, dir = diff.orthogonal().normalized(), t = dir*(width*0.5);
    Vector2 bl=from+t, br=from-t, el=to+t, er=to-t;
    double border_size = width<1.0 ? 1.25*width : 1.25;
    Vector2 border=dir*border_size, border2=diff.normalized()*border_size;
    Color clear=color; clear.a=0;
    quad(bl,br,er,el,color,color,color,color);
    quad(bl,bl+border,el+border,el,color,clear,clear,color);
    quad(br,br-border,er-border,er,color,clear,clear,color);
    quad(bl,bl+border2,br+border2,br,color,clear,clear,color);
    quad(el,el-border2,er-border2,er,color,clear,clear,color);
    quad(bl,bl+border2,bl+border+border2,bl+border,color,clear,clear,clear);
    quad(br,br+border2,br-border+border2,br-border,color,clear,clear,clear);
    quad(el,el-border2,el+border-border2,el+border,color,clear,clear,clear);
    quad(er,er-border2,er-border-border2,er-border,color,clear,clear,clear);
}

void SpaceNativePipeline::ribbon(const std::vector<Vector2> &p, Color color, double requested_width, bool closed) {
    if (p.size()<2) return;
    const double width = requested_width*0.5, feather = width<1.0 ? 1.25*width : 1.25;
    Color clear=color; clear.a=0;
    for(auto &v:ribbon_points)v.clear();for(auto &c:ribbon_colors)c.clear();
    auto &center=ribbon_points[0],&left=ribbon_points[1],&right=ribbon_points[2];
    auto &ct=ribbon_colors[0],&lt=ribbon_colors[1],&rt=ribbon_colors[2];
    auto pair=[&](std::vector<Vector2>&v,std::vector<Color>&c,Vector2 a,Vector2 b,Color ca,Color cb){v.push_back(a);v.push_back(b);c.push_back(ca);c.push_back(cb);};
    Vector2 first, last, previous;
    for (size_t i=1;i<p.size();++i) {first=(p[i]-p[i-1]).normalized();if(!first.is_zero_approx())break;}
    for (size_t i=p.size()-1;i>0;--i) {last=(p[i]-p[i-1]).normalized();if(!last.is_zero_approx())break;}
    const size_t count = p.size() + (closed ? 1 : 0);
    for(size_t i=0;i<count;++i) {
        const size_t at=i%p.size();
        Vector2 direction;
        if(closed) {previous=(p[at]-p[(at+p.size()-1)%p.size()]).normalized();direction=(p[(at+1)%p.size()]-p[at]).normalized();}
        else {direction=i==p.size()-1?previous:(p[i+1]-p[i]).normalized();if(direction.is_zero_approx())direction=previous;}
        Vector2 base;
        if(!closed&&i==0)base=first.orthogonal();
        else if(!closed&&i==p.size()-1)base=last.orthogonal();
        else {
            Vector2 bisector=(previous*direction.length()-direction*previous.length()).normalized();
            double sine=std::sin(std::atan2(double(bisector.cross(previous)),double(bisector.dot(previous))));
            double length=1.0;
            if(!Math::is_zero_approx(sine)&&!direction.is_equal_approx(previous))length=std::clamp(1.0/sine,-3.0,3.0);
            else bisector=direction.orthogonal();
            if(bisector.is_zero_approx())bisector=direction.orthogonal();base=bisector*length;
        }
        Vector2 edge=base*(width*0.5),border=base*feather,point=p[at];
        if(!closed&&i==0) {
            Vector2 cap=-direction*feather;
            pair(center,ct,point+edge+cap,point-edge+cap,clear,clear);
            pair(left,lt,point+edge+cap,point+edge+cap+border,clear,clear);
            pair(right,rt,point-edge+cap,point-edge+cap-border,clear,clear);
        }
        pair(center,ct,point+edge,point-edge,color,color);
        pair(left,lt,point+edge,point+edge+border,color,clear);
        pair(right,rt,point-edge,point-edge-border,color,clear);
        if(!closed&&i==p.size()-1) {
            Vector2 cap=previous*feather;
            pair(center,ct,point+edge+cap,point-edge+cap,clear,clear);
            for(auto data : {std::make_pair(&left,&lt),std::make_pair(&right,&rt)}) {
                Vector2 e=data.first==&left?edge:-edge,b=data.first==&left?border:-border;
                data.first->push_back(point+e);data.first->push_back(point+e+cap+b);data.first->push_back(point+e+cap);
                data.second->push_back(color);data.second->push_back(clear);data.second->push_back(clear);
            }
        }
        previous=direction;
    }
    auto strip=[&](const std::vector<Vector2>&v,const std::vector<Color>&c){for(size_t i=0;i+2<v.size();++i){size_t a=i%2?i+1:i,b=i%2?i:i+1;tri(v[a],v[b],v[i+2],c[a],c[b],c[i+2]);}};
    strip(center,ct);strip(left,lt);strip(right,rt);
}

void SpaceNativePipeline::prepare_templates() {
    if(templates_ready)return;templates_ready=true;
    for(int i=0;i<=64;++i){double angle=double(i)*Math::TAU/64.0;circle[i]=Vector2(std::cos(angle),std::sin(angle));}
    Color outline=Color::html("26313b"),red=Color::html("cc6354"),armor=Color::html("f2eee3"),shadow=Color::html("87949e");
    Vector2 axis(0,-1),side=axis.orthogonal();
    for(double sign:{-1.0,1.0}) {
        tri(-axis*16.0+side*sign*2.8,-axis*24.0+side*sign*6.2,-axis*22.0+side*sign*2.8,outline);
        line(-axis*19.0+side*sign*3.4,-axis*23.0+side*sign*5.0,red,1.5);
    }
    std::vector<Vector2> shape={axis,-axis*7.0-side*3.1,-axis*23.0-side*3.1,-axis*25.0,-axis*23.0+side*3.1,-axis*7.0+side*3.1};
    PackedVector2Array polygon;for(Vector2 p:shape)polygon.push_back(p);
    // Immutable body triangulation is resolved once by the same engine routine.
    PackedInt32Array indices=Geometry2D::get_singleton()->triangulate_polygon(polygon);
    for(int i=0;i<indices.size();i+=3)tri(shape[indices[i]],shape[indices[i+1]],shape[indices[i+2]],armor);
    ribbon(shape,outline,1.0,true);
    tri(axis,-axis*7.0-side*3.1,-axis*7.0+side*3.1,red);
    line(-axis*9.0+side*1.5,-axis*21.0+side*1.5,shadow,1.5);
    line(-axis*9.0-side*1.7,-axis*20.0-side*1.7,Color(1,1,1),0.9);
    body.swap(vertices);body_colors.swap(colors);
    Color chain_light=Color::html("a7fff0");chain_light.a=0.5;
    line(Vector2(0,18),Vector2(),chain_light,3.0);
    line(Vector2(0,10),Vector2(0,-2),Color::html("f2fffc"),1.4);
    disk(Vector2(),3,Color::html("a7fff0"));chain.swap(vertices);chain_colors.swap(colors);
}

void SpaceNativePipeline::flight(Vector2 point,Vector2 axis,double age,bool powered,Dictionary visual,Vector2 offset,double budget) {
    prepare_templates();axis=axis.length_squared()>0.0001?axis.normalized():Vector2(0,-1);
    Color amber=Color::html("ffad4c"),hot=Color::html("fff0be"),smoke=Color::html("aaa4a1");
    if(powered&&age>=0.22) {
        Ref<SpaceVisualLease> native_visual=visual.get("visual_lease",Variant());
        PackedVector2Array samples=native_visual.is_null()?PackedVector2Array(visual.get("trail",PackedVector2Array())):PackedVector2Array();
        int count=std::min(native_visual.is_valid()?native_visual->samples:int(visual.get("samples",0)),4),head=native_visual.is_valid()?native_visual->head:int(visual.get("head",0));
        auto sample=[&](int index)->Vector2{return native_visual.is_valid()?native_visual->trail[index]:samples[index];};
        if(count>=2) {
            Vector2 newest=battle_point(sample(head))-axis*23.0;ribbon_input.clear();ribbon_input.reserve(4);
            for(int i=0;i<count;++i){Vector2 p=battle_point(sample((head-i+14)%14))-axis*23.0,delta=p-newest;
                if(delta.length()>28.0){ribbon_input.push_back(newest+delta.normalized()*28.0+offset);break;}ribbon_input.push_back(p+offset);}
            amber.a=0.22+std::clamp(budget,0.0,1.0)*0.16;ribbon(ribbon_input,amber,1.4,false);
        }
    }
    Vector2 side=axis.orthogonal(),nozzle=point-axis*23.0;
    if(powered&&age>=0.22) {
        double length=Math::lerp(5.0,18.0,Math::smoothstep(0.22,0.65,age));amber.a=0.82;
        tri(nozzle-side*2.4,nozzle-axis*length,nozzle+side*2.4,amber);
        tri(nozzle-side*1.1,nozzle-axis*length*0.55,nozzle+side*1.1,hot);
        double ignition=std::clamp(1.0-(age-0.22)/0.07,0.0,1.0);if(ignition>0){hot.a=ignition;disk(nozzle,3.5*ignition,hot);}
    } else if(age<0.22){smoke.a=(1.0-age/0.22)*0.30;disk(nozzle-axis*3.0,2.5,smoke);}
    template_at(body,body_colors,point,axis);
}

void SpaceMotionLease::_bind_methods() {
    ClassDB::bind_method(D_METHOD("position"),&SpaceMotionLease::get_position);
    ClassDB::bind_method(D_METHOD("direction"),&SpaceMotionLease::get_direction);
    ClassDB::bind_method(D_METHOD("x"),&SpaceMotionLease::get_x);
    ClassDB::bind_method(D_METHOD("y"),&SpaceMotionLease::get_y);
    ClassDB::bind_method(D_METHOD("speed"),&SpaceMotionLease::get_speed);
    ClassDB::bind_method(D_METHOD("age"),&SpaceMotionLease::get_age);
    ClassDB::bind_method(D_METHOD("orphan"),&SpaceMotionLease::get_orphan);
    ClassDB::bind_method(D_METHOD("last_aim"),&SpaceMotionLease::get_last_aim);
    ClassDB::bind_method(D_METHOD("missile_fields"),&SpaceMotionLease::has_missile_fields);
    ClassDB::bind_method(D_METHOD("set_position","value"),&SpaceMotionLease::set_position);
    ClassDB::bind_method(D_METHOD("set_direction","value"),&SpaceMotionLease::set_direction);
    ClassDB::bind_method(D_METHOD("set_speed","value"),&SpaceMotionLease::set_speed);
    ClassDB::bind_method(D_METHOD("set_age","value"),&SpaceMotionLease::set_age);
    ClassDB::bind_method(D_METHOD("set_orphan","value"),&SpaceMotionLease::set_orphan);
}
void SpaceNativePipeline::_bind_methods() {
    ClassDB::bind_method(D_METHOD("bind_motion","shot"),&SpaceNativePipeline::bind_motion);
    ClassDB::bind_method(D_METHOD("advance","game","dt","shield_timing","snapshot"),&SpaceNativePipeline::advance);
    ClassDB::bind_method(D_METHOD("prepare_flights","surface","shots","offset"),&SpaceNativePipeline::prepare_flights);
    ClassDB::bind_method(D_METHOD("begin"),&SpaceNativePipeline::begin);
    ClassDB::bind_method(D_METHOD("flight","point","axis","age","powered","visual","offset","budget"),&SpaceNativePipeline::flight);
    ClassDB::bind_method(D_METHOD("chain","point","direction"),&SpaceNativePipeline::chain_flight);
    ClassDB::bind_method(D_METHOD("paint","canvas"),&SpaceNativePipeline::paint);
    ClassDB::bind_method(D_METHOD("draw_flights","surface","flights","offset"),&SpaceNativePipeline::draw_flights);
    ClassDB::bind_method(D_METHOD("bind_visual","visual"),&SpaceNativePipeline::bind_visual);
    ClassDB::bind_method(D_METHOD("advance_visuals","surface","dt"),&SpaceNativePipeline::advance_visuals);
}
void SpaceNativePipeline::prepare_pulse_mesh() {
    if(pulse_mesh.is_valid())return;
    prepare_templates();begin();
    Color cyan=Color::html("42edee"),blue=Color::html("398bdf"),white=Color::html("f1ffff");
    Color glow=blue;glow.a=0.2;line(Vector2(-11,0),Vector2(9,0),glow,12);
    auto polygon=[&](std::initializer_list<Vector2> points,Color color) {
        std::vector<Vector2> p(points);for(size_t i=1;i+1<p.size();++i)tri(p[0],p[i],p[i+1],color);
    };
    polygon({Vector2(9,0),Vector2(0,-4.5),Vector2(-11,0),Vector2(0,4.5)},cyan);
    polygon({Vector2(9,0),Vector2(1,-2.2),Vector2(-6,0),Vector2(1,2.2)},white);
    blue.a=0.7;for(double side:{-1.0,1.0})line(Vector2(-11,-side*2),Vector2(-25,-side*3),blue,1.8);
    cyan.a=0.8;line(Vector2(2,5),Vector2(2,-5),cyan,1.2);
    PackedVector3Array points;PackedColorArray tints;PackedInt32Array indices;
    points.resize(vertices.size());tints.resize(colors.size());indices.resize(vertices.size());
    for(size_t i=0;i<vertices.size();++i){points[i]=Vector3(vertices[i].x,vertices[i].y,0);tints[i]=colors[i];indices[i]=i;}
    Array arrays;arrays.resize(Mesh::ARRAY_MAX);arrays[Mesh::ARRAY_VERTEX]=points;arrays[Mesh::ARRAY_COLOR]=tints;arrays[Mesh::ARRAY_INDEX]=indices;
    pulse_mesh.instantiate();pulse_mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES,arrays);begin();
}
void SpaceNativePipeline::flush_pulses(RID canvas) {
    if(pulse_transforms.empty())return;
    if(pulse_cursor==pulse_pool.size()) {
        Ref<MultiMesh> batch;batch.instantiate();batch->set_transform_format(MultiMesh::TRANSFORM_2D);batch->set_mesh(pulse_mesh);pulse_pool.push_back(batch);
    }
    Ref<MultiMesh> batch=pulse_pool[pulse_cursor++];
    if(batch->get_instance_count()<int64_t(pulse_transforms.size())) {
        int capacity=std::max(8,batch->get_instance_count());while(capacity<int64_t(pulse_transforms.size()))capacity*=2;batch->set_instance_count(capacity);
    }
    batch->set_visible_instance_count(pulse_transforms.size());
    for(size_t i=0;i<pulse_transforms.size();++i)batch->set_instance_transform_2d(i,pulse_transforms[i]);
    RenderingServer::get_singleton()->canvas_item_add_multimesh(canvas,batch->get_rid());pulse_transforms.clear();
}
Ref<SpaceFlightFrame> SpaceNativePipeline::prepare_flights(Object *surface,Array shots,Vector2 offset) {
    // References and the serial index exist only for this draw. The native
    // continuous state and the original visual records remain authoritative.
    Dictionary index;Array visuals=surface->get("projectile_visuals"),particles=surface->get("particles");
    for(int i=0;i<visuals.size();++i){Dictionary v=visuals[i],p=v["shot"];if(p.has("serial"))index[p["serial"]]=v;}
    Object *canvas=surface->get("draw_surface");RID rid=canvas->call("get_canvas_item");
    bool prototype=surface->get("prototype_enabled");
    bool missile_enabled=surface->get("missile_vfx_enabled"),pulse_enabled=surface->get("pulse_vfx_enabled"),enemy_enabled=surface->get("enemy_vfx_enabled");
    Ref<SpaceFlightFrame> result;result.instantiate();result->recycler=Ref<SpaceNativePipeline>(this);
    if(!spare_frames.empty()){result->flights.swap(spare_frames.back());spare_frames.pop_back();}
    result->flights.reserve(shots.size());
    auto append=[&](Dictionary p,Dictionary v,Ref<SpaceMotionLease> m,Ref<SpaceVisualLease> visual,Vector2 point,int budget,String key,bool hostile,bool chain) {
        PreparedFlight f;f.shot=p;f.visual=v;f.motion=m;f.visual_state=visual;f.point=point;f.budget=budget;f.key=key;f.hostile=hostile;f.chain=chain;
        result->flights.push_back(std::move(f));
    };
    for(int i=0;i<shots.size();++i) {
        Dictionary p=shots[i],v=index.get(p.get("serial",Variant()),Dictionary());
        Ref<SpaceMotionLease> m=p.get("motion_lease",Variant());Ref<SpaceVisualLease> visual=v.get("visual_lease",Variant());
        String key=String(p.get("key","")).replace("_mon","").replace("-mon","");bool hostile=p.get("hostile",false);
        bool chain=p.get("chain_hop",false),missile=prototype&&missile_enabled&&!hostile&&key=="missile"&&bool(p.get("prototype_missile",false));
        bool pulse=prototype&&pulse_enabled&&!hostile&&key=="laser",enemy=prototype&&enemy_enabled&&hostile&&(key=="laser"||key=="cannon");
        // The original visual list is capped at256. Unretained ordinary flights
        // still have an authoritative native position and heading; the cap must
        // not reintroduce one script call/getter for each flying projectile.
        if(m.is_null()||bool(p.get("beam",false))||!(chain||missile||((pulse||enemy)&&(v.is_empty()||(visual.is_valid()&&v.has("fixed_step")))))) {
            Dictionary f=surface->call("_prepare_projectile_flight",p,index,offset);
            if(!f.is_empty())append(p,f["visual"],m,Ref<SpaceVisualLease>(Dictionary(f["visual"]).get("visual_lease",Variant())),f["pos"],f["budget"],key,hostile,chain);
            continue;
        }
        Vector2 logical=position(m->motion());
        if(!missile&&!v.is_empty()&&v.has("fixed_step")) {
            double distance=(logical-Vector2(v["logical_origin"])).dot(Vector2(v["fixed_direction"]));
            logical=inverse_battle_point(Vector2(v["fixed_origin"])+Vector2(v["fixed_step"])*distance);
        }
        Vector2 point=battle_point(logical)+offset;int budget=1;
        if(missile&&visual.is_valid()&&visual->samples>5) {
            int nearby=0;for(int j=0;j<particles.size();++j){Dictionary particle=particles[j];if(Vector2(particle["pos"]).distance_squared_to(point)<6400)++nearby;}
            budget=std::min(1,std::max(0,18-nearby));
        }
        append(p,v,m,visual,point,budget,key,hostile,chain);
        if(enemy) {
            double angle=visual.is_valid()?visual->angle:engine_angle(m->motion().direction);Vector2 axis=engine_from_angle(angle);
            Color color=Color::html(int64_t(p.get("type",0))==2?"ffaf61":"64b5ff");color.a=0.16;
            RenderingServer::get_singleton()->canvas_item_add_line(rid,point-axis*15,point,color,1.0,true);
        }
    }
    return result;
}
void SpaceNativePipeline::draw_flights(Object *surface,Variant prepared,Vector2 offset) {
    Ref<SpaceFlightFrame> frame;
    if(prepared.get_type()==Variant::OBJECT)frame=prepared;
    std::vector<PreparedFlight> compatibility;
    if(frame.is_null()) {
        Array input=prepared;compatibility.reserve(input.size());
        for(int i=0;i<input.size();++i) {
            Dictionary f=input[i],shot=f["shot"],visual=f["visual"];PreparedFlight p;
            p.shot=shot;p.visual=visual;p.motion=shot.get("motion_lease",Variant());p.visual_state=visual.get("visual_lease",Variant());
            p.point=f["pos"];p.budget=f.get("budget",-1);p.key=String(shot.get("key","")).replace("_mon","").replace("-mon","");
            p.hostile=shot.get("hostile",false);p.chain=shot.get("chain_hop",false);compatibility.push_back(std::move(p));
        }
    }
    const std::vector<PreparedFlight> &flights=frame.is_valid()?frame->flights:compatibility;
    Object *canvas=surface->get("draw_surface");RID rid=canvas->call("get_canvas_item");
    const bool own_missiles=bool(surface->get("prototype_enabled"))&&bool(surface->get("missile_vfx_enabled"));
    const bool own_pulses=bool(surface->get("prototype_enabled"))&&bool(surface->get("pulse_vfx_enabled"));
    const bool simple_enemies=bool(surface->get("prototype_enabled"))&&bool(surface->get("enemy_vfx_enabled"));
    if(own_pulses)prepare_pulse_mesh();pulse_cursor=0;pulse_transforms.clear();
    begin();bool script_run=false;
    for(const PreparedFlight &f:flights) {
        const Dictionary &shot=f.shot,&visual=f.visual;Vector2 point=f.point;const Ref<SpaceMotionLease> &lease=f.motion;
        bool is_chain=f.chain;
        bool is_missile=own_missiles&&!f.hostile&&f.key=="missile";
        bool is_pulse=own_pulses&&!f.hostile&&f.key=="laser"&&!bool(shot.get("beam",false));
        bool is_enemy=simple_enemies&&f.hostile&&(f.key=="laser"||f.key=="cannon")&&!bool(shot.get("beam",false));
        if(is_chain||is_missile) {
            if(script_run){surface->call("flush_projectile_packet_batch");script_run=false;}
            flush_pulses(rid);
            Vector2 direction=lease.is_valid()?lease->motion().direction:Vector2(shot["direction"]);
            if(is_chain){Vector2 p=lease.is_valid()?position(lease->motion()):Vector2(shot["x"],shot["y"]);chain_flight(point,battle_point(p+direction)-battle_point(p));}
            else {
                const Ref<SpaceVisualLease> &native_visual=f.visual_state;
                double angle=native_visual.is_valid()?native_visual->angle:double(visual.get("angle",double(direction.angle())));
                double age=lease.is_valid()?lease->motion().age:double(shot.get("motion_age",native_visual.is_valid()?native_visual->age:double(visual.get("age",0.0))));
                Dictionary target=shot["target"];
                flight(point,engine_from_angle(angle),age,!target.is_empty(),visual,offset,f.budget==0?0.5:1.0);
            }
            continue;
        }
        if(is_pulse||is_enemy) {
            paint(rid);if(script_run){surface->call("flush_projectile_packet_batch");script_run=false;}
            const Ref<SpaceVisualLease> &native_visual=f.visual_state;
            Vector2 direction=lease.is_valid()?lease->motion().direction:Vector2(shot["direction"]);
            double angle=native_visual.is_valid()?native_visual->angle:double(visual.get("angle",engine_angle(direction)));Vector2 axis=engine_from_angle(angle);
            if(is_pulse){pulse_transforms.emplace_back(axis,-axis.orthogonal(),point);continue;}
            flush_pulses(rid);
            RenderingServer *rs=RenderingServer::get_singleton();Color color=Color::html(int64_t(shot.get("type",0))==2?"ffaf61":"64b5ff");
            if(int64_t(shot.get("type",0))==2) {
                Color glow=color;glow.a=0.5;rs->canvas_item_add_line(rid,point-axis*9,point-axis,glow,1.5,true);
                rs->canvas_item_add_line(rid,point,point+axis*8,color,3.5,true);
                rs->canvas_item_add_line(rid,point+axis*5,point+axis*8,Color::html("ffe5bf"),2.0,true);
            } else {
                rs->canvas_item_add_line(rid,point-axis*9,point+axis*9,color,2.0,true);
                rs->canvas_item_add_line(rid,point-axis*7,point+axis*7,Color::html("d8f3ff"),1.0,true);
            }
            continue;
        }
        paint(rid);flush_pulses(rid);surface->call("_draw_projectile_foreground_flight",f.legacy(),offset);script_run=true;
    }
    paint(rid);flush_pulses(rid);if(script_run)surface->call("flush_projectile_packet_batch");
}
void SpaceNativePipeline::advance_visuals(Object *surface,double dt) {
    Object *game=surface->get("game");Array shots=game->get("projectiles"),visuals=surface->get("projectile_visuals");
    Dictionary active;int density=0;
    for(int i=0;i<shots.size();++i){Dictionary shot=shots[i];if(shot.has("serial"))active[shot["serial"]]=shot;if(!bool(shot.get("hostile",false))&&String(shot.get("key",""))=="missile")++density;}
    surface->set("missile_density",density);
    auto inverse=[](Vector2 p)->Vector2 {
        constexpr double offset=110.0/(1<<20);
        if(p.y>=-512.0&&p.y<=220.0)return Vector2(p.x,double(p.y)-offset);
        if(p.y>=640.0&&p.y<=2048.0)return Vector2(p.x,double(p.y)-220.0+offset);
        double low=double(p.y)-220.0,high=p.y;
        for(int i=0;i<20;++i){double middle=(low+high)*0.5;if(battle_point(Vector2(0,middle)).y<p.y)low=middle;else high=middle;}
        return Vector2(p.x,(low+high)*0.5);
    };
    for(int i=visuals.size()-1;i>=0;--i) {
        Dictionary visual=visuals[i],shot=visual["shot"];
        bool alive=shot.has("serial")?same(active.get(shot["serial"],Variant()),shot):shots.has(shot);
        if(!alive){visuals.remove_at(i);continue;}
        Ref<SpaceVisualLease> v=visual.get("visual_lease",Variant());
        if(v.is_null()){surface->call("_advance_projectile_visual_record",visual,dt);continue;}
        Ref<SpaceMotionLease> m=shot.get("motion_lease",Variant());
        Vector2 logical=m.is_valid()?position(m->motion()):Vector2(shot["x"],shot["y"]);
        Vector2 direction=m.is_valid()?m->motion().direction:Vector2(shot["direction"]);
        Vector2 next=logical;
        if(visual.has("fixed_step")) {
            const double distance=(logical-Vector2(visual["logical_origin"])).dot(Vector2(visual["fixed_direction"]));
            next=inverse(Vector2(visual["fixed_origin"])+Vector2(visual["fixed_step"])*distance);
        }
        v->age+=dt;
        Vector2 delta=battle_point(next)-battle_point(v->trail[v->head]);
        double wanted=delta.length_squared()>0.001?double(delta.angle()):double(direction.angle());
        v->angle=Math::lerp_angle(v->angle,wanted,1.0-std::exp(-dt*16.0));
        if(dt>0){v->head=(v->head+1)%14;v->times[v->head]=v->age;v->trail[v->head]=next;v->samples=std::min(14,v->samples+1);}
        if(bool(shot.get("prototype_missile",false))) {
            if(v->samples>1){Vector2 delta=battle_point(v->trail[v->head])-battle_point(v->trail[(v->head+13)%14]);if(delta.length_squared()>0.001)v->angle=delta.angle();}
            v->last_render=v->trail[v->head];v->last_logical=logical;Dictionary target=shot["target"];v->had_target=!target.is_empty();
        }
    }
}
void initialize(ModuleInitializationLevel level) {
    if(level!=MODULE_INITIALIZATION_LEVEL_SCENE)return;
    ClassDB::register_class<SpaceDamageHistory>();ClassDB::register_class<SpaceDamageLayout>();
    ClassDB::register_class<SpaceMotionLease>();ClassDB::register_class<SpaceVisualLease>();ClassDB::register_class<SpaceFlightFrame>();ClassDB::register_class<SpaceNativePipeline>();
}
void terminate(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT space_native_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc,library,initialization);
    init.register_initializer(initialize);init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
