#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/rendering_server.hpp>
#include <godot_cpp/classes/geometry2d.hpp>
#include <godot_cpp/classes/array_mesh.hpp>
#include <godot_cpp/classes/multi_mesh.hpp>
#include <godot_cpp/classes/shader_material.hpp>
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
#include <memory>
#include <unordered_map>
#ifdef _WIN32
#include <windows.h>
#else
#include <cerrno>
#include <fcntl.h>
#include <sys/file.h>
#include <unistd.h>
#endif

using namespace godot;
static_assert(sizeof(real_t)==4 && sizeof(double)==8,"This build must match Godot single vectors and GDScript doubles.");

namespace {
// Use the engine's original builtin methods for transcendental/vector methods.
// This is a native ptrcall, never a GDScript callback. It also avoids CRT/compiler
// differences changing a single rounded motion component over many substeps.
struct VectorMethods {
    GDExtensionPtrBuiltInMethod angle, normalized, distance, from_angle, rotated;
    VectorMethods() {
        StringName a("angle"),n("normalized"),d("distance_to"),f("from_angle");
        angle=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,a._native_ptr(),466405837);
        normalized=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,n._native_ptr(),2428350749);
        distance=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,d._native_ptr(),3819070308);
        from_angle=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,f._native_ptr(),889263119);
        StringName r("rotated");rotated=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,r._native_ptr(),2544004089);
    }
};
VectorMethods &vector_methods(){static VectorMethods methods;return methods;}
double engine_angle(const Vector2 &v){double result;vector_methods().angle(const_cast<Vector2*>(&v),nullptr,&result,0);return result;}
double engine_distance(const Vector2 &a,const Vector2 &b){double result;const void *args[]={&b};vector_methods().distance(const_cast<Vector2*>(&a),args,&result,1);return result;}
Vector2 engine_normalized(const Vector2 &v){Vector2 result;vector_methods().normalized(const_cast<Vector2*>(&v),nullptr,&result,0);return result;}
Vector2 engine_from_angle(double angle){Vector2 result;const void *args[]={&angle};vector_methods().from_angle(nullptr,args,&result,1);return result;}
Vector2 engine_rotated(const Vector2 &v,double angle){Vector2 result;const void *args[]={&angle};vector_methods().rotated(const_cast<Vector2*>(&v),args,&result,1);return result;}
// GDScript scalar values are double, but every Vector2 operation rounds to the
// single-precision real_t of this engine. Do not combine consecutive multiplies.
struct Motion {
    double x = 0, y = 0, speed = 0, age = 0, orphan = 0;
    Vector2 direction, last_aim;
    uint64_t generation = 0;
    int kind = 0; // 0 straight, 1 presented missile, 2 chain, 3 ordinary homing
    bool missile_fields = false;
};
// Numeric arena has no facade, lease or pipeline references. Surviving public
// leases retain their numeric state without retaining the lifecycle store.
struct MotionArena {
    std::deque<Motion> motions;
    std::vector<size_t> free_slots;
    uint64_t next_generation=0;
    void release(size_t slot,uint64_t generation) {
        if(motions[slot].generation==generation){motions[slot].generation=0;free_slots.push_back(slot);}
    }
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

class SpaceMotionLease : public RefCounted {
    GDCLASS(SpaceMotionLease, RefCounted)
    friend class SpaceCombatKernel;
    friend class SpaceCombatPresentation;
    std::shared_ptr<MotionArena> arena;
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
Motion &SpaceMotionLease::motion() const { return arena->motions[slot]; }
SpaceMotionLease::~SpaceMotionLease() { if (arena) arena->release(slot, generation); }
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
#include "combat_execution_kernel.h"
#include "combat_presentation.h"

// The sidecar is deliberately permanent. Its contents and PID do not grant
// ownership; only an open OS handle does. Closing the process releases it.
class SpaceSaveLock : public RefCounted {
    GDCLASS(SpaceSaveLock, RefCounted)
#ifdef _WIN32
    HANDLE handle = INVALID_HANDLE_VALUE;
#else
    int handle = -1;
#endif
protected:
    static void _bind_methods() {
        ClassDB::bind_method(D_METHOD("acquire", "path"), &SpaceSaveLock::acquire);
        ClassDB::bind_method(D_METHOD("owns"), &SpaceSaveLock::owns);
    }
public:
    ~SpaceSaveLock() { release(); }
    bool owns() const {
#ifdef _WIN32
        return handle != INVALID_HANDLE_VALUE;
#else
        return handle >= 0;
#endif
    }
    void release() {
        if (!owns()) return;
#ifdef _WIN32
        CloseHandle(handle);
        handle = INVALID_HANDLE_VALUE;
#else
        flock(handle, LOCK_UN);
        close(handle);
        handle = -1;
#endif
    }
    bool acquire(const String &path) {
        if (owns()) return false;
#ifdef _WIN32
        Char16String wide = path.utf16();
        handle = CreateFileW(reinterpret_cast<const wchar_t *>(wide.get_data()),
            GENERIC_READ | GENERIC_WRITE, 0, nullptr, OPEN_ALWAYS,
            FILE_ATTRIBUTE_NORMAL, nullptr);
#else
        CharString bytes = path.utf8();
        handle = open(bytes.get_data(), O_RDWR | O_CREAT | O_CLOEXEC, 0600);
        if (handle >= 0 && flock(handle, LOCK_EX | LOCK_NB) != 0) {
            close(handle);
            handle = -1;
        }
#endif
        return owns();
    }
};

void initialize(ModuleInitializationLevel level) {
    if(level!=MODULE_INITIALIZATION_LEVEL_SCENE)return;
    ClassDB::register_class<SpaceSaveLock>();
    ClassDB::register_class<SpaceMotionLease>();ClassDB::register_class<SpaceCombatKernel>();
    ClassDB::register_class<SpaceVisualLease>();ClassDB::register_class<SpaceCombatFlightFrame>();ClassDB::register_class<SpaceCombatPresentation>();
}
void terminate(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT space_native_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc,library,initialization);
    init.register_initializer(initialize);init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
