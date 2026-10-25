// Presentation only. Owns visual age/trails/contact buffers; never advances or settles combat.
class SpaceCombatPresentation;
struct PreparedFlight {
    Array segments;
    Ref<SpaceMotionLease> motion;
    Vector2 point;
    String key;
    bool hostile=false,chain=false;
    uint64_t serial=0;
    int render_kind=-1,damage_type=0;
    bool beam=false,fixed=false,draw=true,awaiting=false,powered=false;
    Vector2 launch,ray_origin,ray_step,ray_direction,axis;
    double anchor_time=0,anchor_speed=0;
    Vector2 anchor_point;
    std::array<Vector2,14> trail;
    int head=0,samples=1;
    double visual_age=0,visual_angle=0;
};
class SpaceCombatPresentation;
class SpaceCombatFlightFrame : public RefCounted {
    GDCLASS(SpaceCombatFlightFrame,RefCounted)
    friend class SpaceCombatPresentation;
    std::unordered_map<uint64_t, PreparedFlight> flights;
    std::vector<size_t> order, background;
protected:
    static void _bind_methods(){ClassDB::bind_method(D_METHOD("size"),&SpaceCombatFlightFrame::size);}
public:
    int64_t size() const{return order.size();}
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
    int64_t retained_advances=0,retained_births=0,retained_draws=0,retained_upload_bytes=0;
    void clear_retained_frame() {
        if(retained_frame.is_valid()){retained_frame->order.clear();retained_frame->background.clear();retained_frame->flights.clear();}
        retained_frame.unref();retained_kernel.unref();
        for(auto &batch:retained_batches)batch->set_visible_instance_count(0);
    }
    bool advance_retained(double dt);
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
    bool logical_coordinates = false;
    Vector2 display_point(Vector2 point) const { return logical_coordinates ? point : battle_point(point); }
    Vector2 logical_point(Vector2 point) const { return logical_coordinates ? point : inverse_battle_point(point); }
    Ref<ArrayMesh> pulse_mesh;
    std::vector<Ref<MultiMesh>> pulse_pool;
    std::vector<PackedFloat32Array> pulse_buffers;
    std::vector<Transform2D> pulse_transforms;
    size_t pulse_cursor = 0;
    struct ContactEvent {Vector2 point,direction;double born;bool launch,critical;int type;};
    std::array<std::vector<ContactEvent>,2> contact_events;
    std::vector<Vector2> contact_path;
    RID gpu_contact_canvas;
    Ref<ShaderMaterial> gpu_contact_material;
    std::array<Ref<MultiMesh>,2> gpu_contact_batches;
    std::array<PackedFloat32Array,2> gpu_contact_buffers;
    std::array<bool,2> contact_dirty{{true,true}};
    double contact_epoch=0;
    int64_t gpu_contact_uploads=0,gpu_contact_instances=0;
    bool draw_gpu_contacts(double now,bool pulse_enabled);

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
    void configure_logical_coordinates(bool enabled) { logical_coordinates = enabled; clear_retained_frame(); }
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
    Dictionary retained_metrics() const {Dictionary d;d["advances"]=retained_advances;d["births"]=retained_births;d["draws"]=retained_draws;d["upload_bytes"]=retained_upload_bytes;d["live"]=retained_frame.is_valid()?retained_frame->size():0;return d;}
    Vector2 battle_logical_point(Vector2 point) const { return logical_point(point); }
    double rotated_outlines_min_y(const Array &outlines,double angle) const {
        // Same per-vertex float rotation as Vector2.rotated in the script solver.
        // Batch the reduction across the ABI; no shape approximation or cache.
        double top=0.0;
        for(int i=0;i<outlines.size();++i) {
            PackedVector2Array outline=outlines[i];
            for(int j=0;j<outline.size();++j)top=std::min(top,double(outline[j].rotated(angle).y));
        }
        return top;
    }
    Vector2 damage_text_position(Vector2 origin,const Dictionary &metrics,Vector2 limits,const Dictionary &excluded,const Array &occupied,const Array &enemies) const {
        // One synchronous search over the caller's current layout. No cached text,
        // identity, age or enemy state survives this invocation.
        double width=metrics["width"],height=metrics["height"],ascent=metrics["ascent"];
        std::vector<Rect2> text_bounds,enemy_bounds;
        text_bounds.reserve(occupied.size());enemy_bounds.reserve(enemies.size());
        for(int i=0;i<occupied.size();++i){Array row=occupied[i];if(!same(row[0],excluded))text_bounds.push_back(row[1]);}
        for(int i=0;i<enemies.size();++i)enemy_bounds.push_back(enemies[i]);
        for(int row=0;row<2;++row)for(int shift:{0,-56,56,-140,140}){
            // Utility clamp preserves the script's edge behavior for text wider
            // than the available view; do not use std::clamp with inverted limits.
            Vector2 point(UtilityFunctions::clampf(double(origin.x)-width/2.0+shift,8.0,double(limits.x)-8.0-width),double(origin.y)-row*(height+8.0));
            Rect2 bounds=Rect2(display_point(point)-Vector2(0,ascent),Vector2(width,height)).grow(4);
            if(bounds.position.y<8||(bounds.position+bounds.size).y>double(limits.y)-8)continue;
            bool blocked=false;Rect2 text_clearance=bounds.grow(8);
            for(const Rect2 &other:text_bounds)if(text_clearance.intersects(other)){blocked=true;break;}
            if(!blocked)for(const Rect2 &other:enemy_bounds)if(bounds.intersects(other)){blocked=true;break;}
            if(!blocked)return point;
        }
        return Vector2(INFINITY,INFINITY);
    }
    void record_contact(int category,Vector2 point,Vector2 direction,double born,bool launch,bool critical,int type) {
        ERR_FAIL_INDEX(category,2);
        contact_events[category].push_back({point,direction,born,launch,critical,type});contact_dirty[category]=true;
    }
    void prune_contacts(double now,bool clear_enemy) {
        for(int k=0;k<2;++k){auto &events=contact_events[k];size_t old_size=events.size();
            events.erase(std::remove_if(events.begin(),events.end(),[&](const ContactEvent &e){return (k==0&&clear_enemy)||!(now-e.born<(k==0?0.12:0.14));}),events.end());if(events.size()!=old_size)contact_dirty[k]=true;}
    }
    void clear_contacts(){for(int k=0;k<2;++k){contact_events[k].clear();contact_dirty[k]=true;if(gpu_contact_batches[k].is_valid())gpu_contact_batches[k]->set_visible_instance_count(0);}}
    void configure_contact_gpu(Array meshes,RID canvas,Ref<ShaderMaterial> material) {
        gpu_contact_canvas=canvas;gpu_contact_material=material;
        for(int k=0;k<2;++k){gpu_contact_batches[k].unref();gpu_contact_buffers[k]=PackedFloat32Array();contact_dirty[k]=true;}
        if(!canvas.is_valid()||material.is_null())return;
        ERR_FAIL_COND(meshes.size()!=2);
        for(int k=0;k<2;++k){auto &batch=gpu_contact_batches[k];batch.instantiate();batch->set_transform_format(MultiMesh::TRANSFORM_2D);batch->set_use_custom_data(true);batch->set_mesh(meshes[k]);
            batch->set_custom_aabb(AABB(Vector3(-8192,-8192,-1),Vector3(16384,16384,2)));
        }
    }
    Dictionary contact_gpu_metrics() const {Dictionary result;result["enabled"]=gpu_contact_canvas.is_valid();result["uploads"]=gpu_contact_uploads;result["uploaded_instances"]=gpu_contact_instances;return result;}
    Array contact_snapshot(int category) const {
        ERR_FAIL_INDEX_V(category,2,Array());
        Array result;for(const ContactEvent &e:contact_events[category]){Dictionary d;d["position"]=e.point;d["direction"]=e.direction;d["born"]=e.born;
            if(category==0){d["damage_type"]=e.type;if(e.launch)d["kind"]="fire";}
            else {d["kind"]=e.launch?"fire":"hit";d["critical"]=e.critical;}result.push_back(d);}return result;
    }
    void configure_surface(Ref<SpaceCombatKernel> kernel, RID canvas, Callable beams) {
        display_kernel=kernel; display_canvas=canvas; draw_beams=beams;
    }
    bool supports_compact_lasers() const {
        return display_kernel.is_valid() && retained_material.is_valid();
    }
    void begin() { prepare_templates(); vertices.clear(); colors.clear(); }
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
    void draw_contacts(RID canvas,double now,bool pulse_enabled);
    void flight(const PreparedFlight &visual,Vector2 offset);
    Ref<SpaceCombatFlightFrame> prepare_flights(Vector2 offset);
    void draw_flights(Ref<SpaceCombatFlightFrame> prepared,Vector2 offset);
    void advance_visuals(double dt);
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
    const double age=visual.visual_age;const bool powered=visual.powered;
    prepare_templates();axis=axis.length_squared()>0.0001?axis.normalized():Vector2(0,-1);
    Color amber=Color::html("ffad4c"),hot=Color::html("fff0be"),smoke=Color::html("aaa4a1");
    if(powered&&age>=0.22) {
        int count=std::min(visual.samples,4),head=visual.head;
        auto sample=[&](int index)->Vector2{return visual.trail[index];};
        if(count>=2) {
            Vector2 newest=display_point(sample(head))-axis*23.0;ribbon_input.clear();ribbon_input.reserve(4);
            for(int i=0;i<count;++i){Vector2 p=display_point(sample((head-i+14)%14))-axis*23.0,delta=p-newest;
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
bool SpaceCombatPresentation::draw_gpu_contacts(double now,bool pulse_enabled) {
    if(!gpu_contact_canvas.is_valid()||gpu_contact_material.is_null())return false;
    if(std::abs(now-contact_epoch)>128.0){contact_epoch=now;contact_dirty={true,true};}
    gpu_contact_material->set_shader_parameter("clock",float(now-contact_epoch));
    for(int k=0;k<2;++k){auto &batch=gpu_contact_batches[k];auto &events=contact_events[k];
        if(contact_dirty[k]){
            int capacity=batch->get_instance_count();if(capacity<int(events.size())){capacity=std::max(capacity,8);while(capacity<int(events.size()))capacity*=2;batch->set_instance_count(capacity);}
            auto &buffer=gpu_contact_buffers[k];buffer.resize(capacity*12);float *out=buffer.ptrw();
            for(size_t i=0;i<events.size();++i){const auto &e=events[i];float *row=out+i*12;Vector2 p=display_point(e.point),axis=(k==0&&!e.launch&&e.type==2)?Vector2(1,0):e.direction;
                // Contacts use the exact supplied direction, not a new targeting solve.
                row[0]=axis.x;row[1]=-axis.y;row[2]=0;row[3]=p.x;row[4]=axis.y;row[5]=axis.x;row[6]=0;row[7]=p.y;
                row[8]=float(e.born-contact_epoch);row[9]=(e.type==2?100.0f:0.0f)+float(engine_angle(axis));row[10]=e.launch?11.0f:10.0f;row[11]=e.critical?1.0f:0.0f;
                if(!p.is_finite()||!axis.is_finite()||(k==1&&e.launch&&axis.is_zero_approx())){row[0]=row[1]=row[4]=row[5]=0;row[3]=row[7]=0;}
            }
            if(capacity>0)batch->set_buffer(buffer);++gpu_contact_uploads;gpu_contact_instances+=events.size();contact_dirty[k]=false;
        }
        batch->set_visible_instance_count(k==1&&!pulse_enabled?0:events.size());
        if(batch->get_visible_instance_count()>0)RenderingServer::get_singleton()->canvas_item_add_multimesh(gpu_contact_canvas,batch->get_rid());
    }
    return true;
}
void SpaceCombatPresentation::draw_contacts(RID canvas,double now,bool pulse_enabled) {
    if(draw_gpu_contacts(now,pulse_enabled))return;
    begin();
    for(const ContactEvent &e:contact_events[0]) {
        Vector2 p=display_point(e.point),axis=e.direction,side=axis.orthogonal();double age=now-e.born;
        double fade=Math::clamp(1.0-age/0.12,0.0,1.0);bool physical=e.type==2;
        Color color(Color::html(physical?"ffaf61":"64b5ff"),fade);
        if(e.launch){if(physical)line(p-axis*2,p+axis*4,color,2.5);else for(int sign:{-1,1})line(p+side*sign*2,p+axis*4,color,1.0);continue;}
        double radius=3.0+4.0*(1.0-fade);
        if(physical){contact_path.clear();for(int i=0;i<11;++i){float angle=float(double(i)/11.0*float(Math::TAU));contact_path.push_back(p+engine_from_angle(angle)*float(radius));}ribbon(contact_path,color,1.2,true);}
        else {line(p-side*radius,p+side*radius,color,1.2);line(p-axis*radius*0.6,p+axis*radius*0.6,color,1.0);}
    }
    if(pulse_enabled)for(const ContactEvent &e:contact_events[1]) {
        double age=now-e.born;Vector2 p=display_point(e.point),axis=e.direction,across=axis.orthogonal();
        Color cyan=Color::html("42edee"),blue=Color::html("398bdf"),white=Color::html("f1ffff");
        if(e.launch) {
            if(!std::isfinite(age)||age>=0.075||!p.is_finite()||!axis.is_finite()||axis.is_zero_approx())continue;
            double t=Math::clamp(age/0.075,0.0,1.0),fade=1.0-t;
            Vector2 kick=p-axis*(3.0*UtilityFunctions::sin(t*Math::PI)),back=kick-axis*2.0,center=kick+axis*9.0*fade;
            Vector2 a=kick+axis*15.0*fade+across*4.0*fade,b=kick+axis*15.0*fade-across*4.0*fade;
            if(std::abs(double((a-back).cross(center-back)))>0.00001)tri(back,a,center,Color(cyan,fade));
            if(std::abs(double((center-back).cross(b-back)))>0.00001)tri(back,center,b,Color(cyan,fade));
            line(kick-across*(4.0+3.0*t),kick+across*(4.0+3.0*t),Color(blue,fade*0.9),2.3);
            line(kick,kick+axis*11.0*fade,Color(white,fade),3.0*fade+0.5);
        } else {
            double t=Math::clamp(age/0.13,0.0,1.0),fade=1.0-t,size=(4.0+10.0*t)*(e.critical?1.15:1.0);
            contact_path={p+axis*size*0.65,p+across*size,p-axis*size*0.65,p-across*size};
            ribbon(contact_path,Color(cyan,fade*0.9),2.0*fade+0.5,true);
            if(t<0.45){PackedVector2Array points;for(Vector2 q:{p+axis*5.0,p+across*4.0,p-axis*5.0,p-across*4.0})points.push_back(q);
                PackedInt32Array indexes=Geometry2D::get_singleton()->triangulate_polygon(points);
                for(int i=0;i<indexes.size();i+=3)tri(points[indexes[i]],points[indexes[i+1]],points[indexes[i+2]],Color(white,fade));}
            for(int i=0;i<4;++i){Vector2 direction=engine_rotated(-axis,(-1.5+double(i))*0.7);
                line(p+direction*(4.0+8.0*t),p+direction*(8.0+14.0*t),Color(i%2==0?cyan:blue,fade),1.8);}
        }
    }
    paint(canvas);
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
void SpaceCombatPresentation::flush_pulses(RID canvas) {
    if(pulse_transforms.empty())return;
    if(pulse_cursor==pulse_pool.size()) {
        Ref<MultiMesh> batch;batch.instantiate();batch->set_transform_format(MultiMesh::TRANSFORM_2D);batch->set_mesh(pulse_mesh);pulse_pool.push_back(batch);pulse_buffers.emplace_back();
    }
    const size_t slot=pulse_cursor++;
    Ref<MultiMesh> batch=pulse_pool[slot];
    if(batch->get_instance_count()<int64_t(pulse_transforms.size())) {
        int capacity=std::max(8,batch->get_instance_count());while(capacity<int64_t(pulse_transforms.size()))capacity*=2;batch->set_instance_count(capacity);
    }
    // Godot 4.7.2 TRANSFORM_2D, without colors/custom data: two padded
    // rows of four floats. Upload allocated capacity, draw only live instances.
    PackedFloat32Array &buffer=pulse_buffers[slot];
    const int64_t buffer_size=int64_t(batch->get_instance_count())*8;
    if(buffer.size()!=buffer_size){buffer.resize(buffer_size);buffer.fill(0.0f);}
    float *write=buffer.ptrw();
    for(size_t i=0;i<pulse_transforms.size();++i) {
        const Transform2D &t=pulse_transforms[i];float *row=write+i*8;
        row[0]=t[0].x;row[1]=t[1].x;row[2]=0.0f;row[3]=t[2].x;
        row[4]=t[0].y;row[5]=t[1].y;row[6]=0.0f;row[7]=t[2].y;
    }
    batch->set_buffer(buffer);
    batch->set_visible_instance_count(pulse_transforms.size());
    RenderingServer::get_singleton()->canvas_item_add_multimesh(canvas,batch->get_rid());pulse_transforms.clear();
}
Ref<SpaceCombatFlightFrame> SpaceCombatPresentation::prepare_flights(Vector2 offset) {
    if(retained_frame.is_valid())prepare_retained(offset);
    return retained_frame;
}
void SpaceCombatPresentation::draw_flights(Ref<SpaceCombatFlightFrame> prepared,Vector2 offset) {
    if(prepared.is_valid()&&prepared==retained_frame)draw_retained(offset);
}
void SpaceCombatPresentation::advance_visuals(double dt) { advance_retained(dt); }
#include "combat_retained_presentation.h"
void SpaceCombatPresentation::_bind_methods(){
    ClassDB::bind_method(D_METHOD("supports_compact_lasers"),&SpaceCombatPresentation::supports_compact_lasers);
    ClassDB::bind_method(D_METHOD("configure_logical_coordinates","enabled"),&SpaceCombatPresentation::configure_logical_coordinates);
    ClassDB::bind_method(D_METHOD("configure_retained_gpu","material"),&SpaceCombatPresentation::configure_retained_gpu);
    ClassDB::bind_method(D_METHOD("retained_metrics"),&SpaceCombatPresentation::retained_metrics);
    ClassDB::bind_method(D_METHOD("configure_contact_gpu","meshes","canvas","material"),&SpaceCombatPresentation::configure_contact_gpu);
    ClassDB::bind_method(D_METHOD("contact_gpu_metrics"),&SpaceCombatPresentation::contact_gpu_metrics);
    ClassDB::bind_method(D_METHOD("damage_text_position","origin","metrics","limits","excluded","occupied","enemies"),&SpaceCombatPresentation::damage_text_position);
    ClassDB::bind_method(D_METHOD("battle_logical_point","point"),&SpaceCombatPresentation::battle_logical_point);
    ClassDB::bind_method(D_METHOD("rotated_outlines_min_y","outlines","angle"),&SpaceCombatPresentation::rotated_outlines_min_y);
    ClassDB::bind_method(D_METHOD("advance_visuals","dt"),&SpaceCombatPresentation::advance_visuals);
    ClassDB::bind_method(D_METHOD("configure_surface","kernel","canvas","beams"),&SpaceCombatPresentation::configure_surface);
    ClassDB::bind_method(D_METHOD("prepare_flights","offset"),&SpaceCombatPresentation::prepare_flights);
    ClassDB::bind_method(D_METHOD("draw_flights","flights","offset"),&SpaceCombatPresentation::draw_flights);
    ClassDB::bind_method(D_METHOD("record_contact","category","point","direction","born","launch","critical","type"),&SpaceCombatPresentation::record_contact);
    ClassDB::bind_method(D_METHOD("prune_contacts","now","clear_enemy"),&SpaceCombatPresentation::prune_contacts);
    ClassDB::bind_method(D_METHOD("clear_contacts"),&SpaceCombatPresentation::clear_contacts);
    ClassDB::bind_method(D_METHOD("contact_snapshot","category"),&SpaceCombatPresentation::contact_snapshot);
    ClassDB::bind_method(D_METHOD("draw_contacts","canvas","now","pulse_enabled"),&SpaceCombatPresentation::draw_contacts);
}
