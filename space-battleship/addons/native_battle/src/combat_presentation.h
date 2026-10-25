// Presentation only. Owns visual age/trails/contact buffers; never advances or settles combat.
class SpaceCombatPresentation;
struct PreparedFlight {
    Array segments;
    Ref<SpaceMotionLease> motion;
    Vector2 point;
    int kind=0;
    bool hostile=false,chain=false;
    uint64_t serial=0;
    int render_kind=-1,damage_type=0;
    bool beam=false,fixed=false,draw=true,awaiting=false,powered=false;
    Vector2 launch,ray_origin,ray_step,ray_direction,axis;
    double anchor_time=0,anchor_speed=0;
    Vector2 anchor_point;
    std::array<Vector2,14> trail;
    int head=0,samples=1;
    double motion_age=0,visual_angle=0;
};
class SpaceCombatPresentation;
class SpaceCombatFlightFrame : public RefCounted {
    GDCLASS(SpaceCombatFlightFrame,RefCounted)
    friend class SpaceCombatPresentation;
    std::vector<PreparedFlight> flights;
    std::vector<size_t> order, background;
protected:
    static void _bind_methods(){}
public:
};
class SpaceCombatPresentation : public RefCounted {
    GDCLASS(SpaceCombatPresentation,RefCounted)
    friend class SpaceCombatFlightFrame;
    Ref<SpaceCombatKernel> display_kernel;
    RID display_canvas;
    Callable draw_beams;
    Ref<SpaceCombatKernel> retained_kernel;
    Ref<SpaceCombatFlightFrame> retained_frame;
    Ref<ShaderMaterial> retained_material;
    Ref<ArrayMesh> retained_mesh;
    std::vector<Ref<MultiMesh>> retained_batches;
    std::vector<PackedFloat32Array> retained_buffers;
    std::vector<float> retained_upload;
    std::vector<RID> retained_canvases;
    size_t retained_cursor=0;
    void clear_retained_frame() {
        if(retained_frame.is_valid()){retained_frame->order.clear();retained_frame->background.clear();retained_frame->flights.clear();}
        retained_frame.unref();retained_kernel.unref();
        for(auto &batch:retained_batches)batch->set_visible_instance_count(0);
    }
    bool advance_retained();
    void prepare_retained(Vector2 offset);
    void draw_retained(Vector2 offset);
    void prepare_retained_mesh();
    void flush_retained(RID canvas);

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
    struct ContactEvent {Vector2 point,direction;double born;bool launch,critical;int type;};
    std::array<std::vector<ContactEvent>,2> contact_events;
    RID gpu_contact_canvas;
    Ref<ShaderMaterial> gpu_contact_material;
    std::array<Ref<MultiMesh>,2> gpu_contact_batches;
    std::array<PackedFloat32Array,2> gpu_contact_buffers;
    std::array<bool,2> contact_dirty{{true,true}};
    double contact_epoch=0;

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
    void template_at(const std::vector<Vector2>& points, const std::vector<Color>& tints, Vector2 point, Vector2 axis) {
        Transform2D transform(double(axis.angle()) + Math::PI / 2.0, point);
        for (size_t i = 0; i < points.size(); ++i) { vertices.push_back(transform.xform(points[i])); colors.push_back(tints[i]); }
    }
protected:
    static void _bind_methods();
public:
    void configure_retained_gpu(Ref<ShaderMaterial> material) {
        for(RID canvas:retained_canvases)if(canvas.is_valid())RenderingServer::get_singleton()->canvas_item_set_material(canvas,RID());
        retained_canvases.clear();
        if(retained_frame.is_valid()){retained_frame->order.clear();retained_frame->background.clear();retained_frame->flights.clear();}
        retained_frame.unref();retained_kernel.unref();retained_material=material;
        // Canvas commands retain RIDs, not Ref ownership. Hide until their next
        // repaint instead of freeing meshes referenced by an existing command.
        for(auto &batch:retained_batches)batch->set_visible_instance_count(0);
        retained_upload.clear();
    }
    void record_contact(int category,Vector2 point,Vector2 direction,double born,bool launch,bool critical,int type) {
        ERR_FAIL_INDEX(category,2);
        contact_events[category].push_back({point,direction,born,launch,critical,type});contact_dirty[category]=true;
    }
    void prune_contacts(double now) {
        for(int k=0;k<2;++k){auto &events=contact_events[k];size_t old_size=events.size();
            events.erase(std::remove_if(events.begin(),events.end(),[&](const ContactEvent &e){return !(now-e.born<(k==0?0.12:0.14));}),events.end());if(events.size()!=old_size)contact_dirty[k]=true;}
    }
    void configure_contact_gpu(Array meshes,RID canvas,Ref<ShaderMaterial> material) {
        gpu_contact_canvas=canvas;gpu_contact_material=material;
        for(int k=0;k<2;++k){gpu_contact_batches[k].unref();gpu_contact_buffers[k]=PackedFloat32Array();contact_dirty[k]=true;}
        if(!canvas.is_valid()||material.is_null())return;
        ERR_FAIL_COND(meshes.size()!=2);
        RenderingServer::get_singleton()->canvas_item_set_material(canvas,material->get_rid());
        for(int k=0;k<2;++k){auto &batch=gpu_contact_batches[k];batch.instantiate();batch->set_transform_format(MultiMesh::TRANSFORM_2D);batch->set_use_custom_data(true);batch->set_mesh(meshes[k]);
            batch->set_custom_aabb(AABB(Vector3(-8192,-8192,-1),Vector3(16384,16384,2)));
        }
    }
    void configure_surface(Ref<SpaceCombatKernel> kernel, RID canvas, Callable beams) {
        display_kernel=kernel; display_canvas=canvas; draw_beams=beams;
    }
    bool retained_ready() const {
        return display_kernel.is_valid() && retained_material.is_valid();
    }
    void begin() { prepare_templates(); vertices.clear(); colors.clear(); }
    void paint(RID canvas) {
        if (vertices.empty()) return;
        packed_vertices.resize(vertices.size()); packed_colors.resize(colors.size());
        std::copy(vertices.begin(), vertices.end(), packed_vertices.ptrw());
        std::copy(colors.begin(), colors.end(), packed_colors.ptrw());
        RenderingServer::get_singleton()->canvas_item_add_triangle_array(canvas, PackedInt32Array(), packed_vertices, packed_colors);
        vertices.clear(); colors.clear();
    }
    void draw_contacts(double now);
    void flight(const PreparedFlight &visual,Vector2 offset);
    Ref<SpaceCombatFlightFrame> prepare_flights(Vector2 offset);
    void draw_flights(Ref<SpaceCombatFlightFrame> prepared,Vector2 offset);
    void advance_visuals();
};
void SpaceCombatPresentation::line(Vector2 from, Vector2 to, Color color, double width) {
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
void SpaceCombatPresentation::ribbon(const std::vector<Vector2> &p, Color color, double requested_width, bool closed) {
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
void SpaceCombatPresentation::prepare_templates() {
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
void SpaceCombatPresentation::flight(const PreparedFlight &visual,Vector2 offset) {
    Vector2 point=visual.point+offset,axis=visual.axis;
    const double age=visual.motion->motion().age;const bool powered=visual.powered;
    prepare_templates();axis=axis.length_squared()>0.0001?axis.normalized():Vector2(0,-1);
    Color amber=Color::html("ffad4c"),hot=Color::html("fff0be"),smoke=Color::html("aaa4a1");
    if(powered&&age>=0.22) {
        int count=std::min(visual.samples,4),head=visual.head;
        auto sample=[&](int index)->Vector2{return visual.trail[index];};
        if(count>=2) {
            Vector2 newest=sample(head)-axis*23.0;ribbon_input.clear();ribbon_input.reserve(4);
            for(int i=0;i<count;++i){Vector2 p=sample((head-i+14)%14)-axis*23.0,delta=p-newest;
                if(delta.length()>28.0){ribbon_input.push_back(newest+delta.normalized()*28.0+offset);break;}ribbon_input.push_back(p+offset);}
            amber.a=0.38;ribbon(ribbon_input,amber,1.4,false);
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
void SpaceCombatPresentation::draw_contacts(double now) {
    if(!gpu_contact_canvas.is_valid()||gpu_contact_material.is_null())return;
    if(std::abs(now-contact_epoch)>128.0){contact_epoch=now;contact_dirty={true,true};}
    gpu_contact_material->set_shader_parameter("clock",float(now-contact_epoch));
    for(int k=0;k<2;++k){auto &batch=gpu_contact_batches[k];auto &events=contact_events[k];
        if(contact_dirty[k]){
            int capacity=batch->get_instance_count();if(capacity<int(events.size())){capacity=std::max(capacity,8);while(capacity<int(events.size()))capacity*=2;batch->set_instance_count(capacity);}
            auto &buffer=gpu_contact_buffers[k];buffer.resize(capacity*12);float *out=buffer.ptrw();
            for(size_t i=0;i<events.size();++i){const auto &e=events[i];float *row=out+i*12;Vector2 p=e.point,axis=(k==0&&!e.launch&&e.type==2)?Vector2(1,0):e.direction;
                // Contacts use the exact supplied direction, not a new targeting solve.
                row[0]=axis.x;row[1]=-axis.y;row[2]=0;row[3]=p.x;row[4]=axis.y;row[5]=axis.x;row[6]=0;row[7]=p.y;
                row[8]=float(e.born-contact_epoch);row[9]=(e.type==2?100.0f:0.0f)+float(engine_angle(axis));row[10]=e.launch?11.0f:10.0f;row[11]=e.critical?1.0f:0.0f;
                if(!p.is_finite()||!axis.is_finite()||(k==1&&e.launch&&axis.is_zero_approx())){row[0]=row[1]=row[4]=row[5]=0;row[3]=row[7]=0;}
            }
            if(capacity>0)batch->set_buffer(buffer);contact_dirty[k]=false;
        }
        batch->set_visible_instance_count(events.size());
        if(batch->get_visible_instance_count()>0)RenderingServer::get_singleton()->canvas_item_add_multimesh(gpu_contact_canvas,batch->get_rid());
    }
}
void SpaceCombatPresentation::prepare_pulse_mesh() {
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
Ref<SpaceCombatFlightFrame> SpaceCombatPresentation::prepare_flights(Vector2 offset) {
    if(retained_frame.is_valid())prepare_retained(offset);
    return retained_frame;
}
void SpaceCombatPresentation::draw_flights(Ref<SpaceCombatFlightFrame> prepared,Vector2 offset) {
    if(prepared.is_valid()&&prepared==retained_frame)draw_retained(offset);
}
void SpaceCombatPresentation::advance_visuals() { advance_retained(); }
#include "combat_retained_presentation.h"
void SpaceCombatPresentation::_bind_methods(){
    ClassDB::bind_method(D_METHOD("configure_retained_gpu","material"),&SpaceCombatPresentation::configure_retained_gpu);
    ClassDB::bind_method(D_METHOD("configure_contact_gpu","meshes","canvas","material"),&SpaceCombatPresentation::configure_contact_gpu);
    ClassDB::bind_method(D_METHOD("advance_visuals"),&SpaceCombatPresentation::advance_visuals);
    ClassDB::bind_method(D_METHOD("configure_surface","kernel","canvas","beams"),&SpaceCombatPresentation::configure_surface);
    ClassDB::bind_method(D_METHOD("prepare_flights","offset"),&SpaceCombatPresentation::prepare_flights);
    ClassDB::bind_method(D_METHOD("draw_flights","flights","offset"),&SpaceCombatPresentation::draw_flights);
    ClassDB::bind_method(D_METHOD("record_contact","category","point","direction","born","launch","critical","type"),&SpaceCombatPresentation::record_contact);
    ClassDB::bind_method(D_METHOD("prune_contacts","now"),&SpaceCombatPresentation::prune_contacts);
    ClassDB::bind_method(D_METHOD("draw_contacts","now"),&SpaceCombatPresentation::draw_contacts);
}
