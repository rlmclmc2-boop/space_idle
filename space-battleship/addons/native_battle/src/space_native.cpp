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

using namespace godot;
static_assert(sizeof(real_t)==4 && sizeof(double)==8,"This build must match Godot single vectors and GDScript doubles.");

namespace {
// Use the engine's original builtin methods for transcendental/vector methods.
// This is a native ptrcall, never a GDScript callback. It also avoids CRT/compiler
// differences changing a single rounded motion component over many substeps.
struct VectorMethods {
    GDExtensionPtrBuiltInMethod angle, from_angle, rotated;
    VectorMethods() {
        StringName a("angle"),f("from_angle");
        angle=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,a._native_ptr(),466405837);
        from_angle=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,f._native_ptr(),889263119);
        StringName r("rotated");rotated=gdextension_interface::variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_VECTOR2,r._native_ptr(),2544004089);
    }
};
VectorMethods &vector_methods(){static VectorMethods methods;return methods;}
double engine_angle(const Vector2 &v){double result;vector_methods().angle(const_cast<Vector2*>(&v),nullptr,&result,0);return result;}
Vector2 engine_from_angle(double angle){Vector2 result;const void *args[]={&angle};vector_methods().from_angle(nullptr,args,&result,1);return result;}
Vector2 engine_rotated(const Vector2 &v,double angle){Vector2 result;const void *args[]={&angle};vector_methods().rotated(const_cast<Vector2*>(&v),args,&result,1);return result;}
// GDScript scalar values are double, but every Vector2 operation rounds to the
// single-precision real_t of this engine. Do not combine consecutive multiplies.
struct Motion {
    double x = 0, y = 0, speed = 0, age = 0, orphan = 0;
    Vector2 direction, last_aim;
    uint64_t generation = 0;
    int kind = 0; // 0 straight, 1 presented missile, 2 chain, 3 ordinary homing
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
Vector2 position(const Motion &m) { return Vector2(m.x, m.y); }
Vector2 battle_point(Vector2 p) { return Vector2(p.x, double(p.y) + Math::smoothstep(220.0, 420.0, double(p.y)) * 220.0); }

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

};
Motion &SpaceMotionLease::motion() const { return arena->motions[slot]; }
SpaceMotionLease::~SpaceMotionLease() { if (arena) arena->release(slot, generation); }
void SpaceMotionLease::_bind_methods() {}
#include "combat_execution_kernel.h"
#include "combat_presentation.h"
#include "amount_api.hpp"
#include "foundation_disk.hpp"

void initialize(ModuleInitializationLevel level) {
    if(level!=MODULE_INITIALIZATION_LEVEL_SCENE)return;
    ClassDB::register_class<FoundationAmount>();ClassDB::register_class<FoundationDisk>();
    ClassDB::register_class<SpaceMotionLease>();ClassDB::register_class<SpaceCombatKernel>();
    ClassDB::register_class<SpaceCombatFlightFrame>();ClassDB::register_class<SpaceCombatPresentation>();
}
void terminate(ModuleInitializationLevel) {}
extern "C" GDExtensionBool GDE_EXPORT space_native_init(GDExtensionInterfaceGetProcAddress get_proc,GDExtensionClassLibraryPtr library,GDExtensionInitialization *initialization) {
    GDExtensionBinding::InitObject init(get_proc,library,initialization);
    init.register_initializer(initialize);init.register_terminator(terminate);
    init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);return init.init();
}
