// Renderer cache uses only published serials, motion leases and drawing outputs.
// Per-slot descriptors are populated only at birth; dynamic motion remains in its lease.
bool SpaceCombatPresentation::advance_retained() {
    Ref<SpaceCombatKernel> kernel=display_kernel;
    if(!retained_ready()||!kernel->presentation_running()) {
        clear_retained_frame();return false;
    }
    if(retained_kernel!=kernel||retained_frame.is_null()) {
        clear_retained_frame();retained_kernel=kernel;retained_frame.instantiate();
    }
    auto &frame=*retained_frame.ptr();
    for(size_t id:frame.order) if(!kernel->presentation_matches(id,frame.flights[id].serial,frame.flights[id].motion)) frame.flights[id]=PreparedFlight();
    frame.flights.resize(kernel->presentation_slots());frame.order.clear();frame.background.clear();
    for(size_t order=0;order<kernel->presentation_count();++order) {
        size_t id=kernel->presentation_index(order);SpaceCombatKernel::PresentationFlight source;
        if(!kernel->presentation_read(id,source))continue;
        auto &f=frame.flights[id];const bool born=f.motion!=source.motion;
        if(born) {
            f=PreparedFlight();f.serial=source.serial;
            f.motion=source.motion;f.hostile=source.hostile;f.beam=source.beam;f.damage_type=source.type;
            f.kind=source.kind;
            f.fixed=source.fixed;
            if(f.fixed){f.launch=source.launch;f.ray_origin=source.ray_origin;f.ray_step=source.ray_step;f.ray_direction=f.motion->motion().direction;}
            f.render_kind=f.beam?-1:(!f.hostile&&f.kind==0)?0:(f.hostile&&(f.kind==0||f.kind==1))?(source.type==2?3:2):-1;
            f.anchor_speed=-1;f.trail.fill(position(f.motion->motion()));f.visual_angle=f.motion->motion().direction.angle();
        }
        f.segments.clear();f.awaiting=source.awaiting;f.powered=source.powered;frame.order.push_back(id);f.draw=true;
        Vector2 point;
        if(f.beam&&!f.awaiting&&kernel->presentation_endpoint(id,-1,point)) {
            const double power=source.ramp>0?std::clamp(std::max(0.0,source.age-source.charge)/source.ramp,0.0,1.0):1.0;
            Dictionary segment;segment["from"]=source.launch;segment["to"]=point;segment["power"]=power;
            segment["charge"]=source.ticks>0?-1.0:std::clamp(source.age/std::max(source.charge,0.001),0.0,1.0);segment["link"]=false;f.segments.push_back(segment);
            for(int link=0;link<source.links;++link) {Vector2 target;if(!kernel->presentation_endpoint(id,link,target))continue;
                Dictionary part;part["from"]=point;part["to"]=target;part["power"]=power;part["charge"]=source.ticks>0?-1.0:0.0;part["link"]=true;f.segments.push_back(part);
            }
        }
        const Motion &m=f.motion->motion();Vector2 logical=position(m);
        const bool missile=!f.hostile&&f.kind==2;
        if(f.render_kind==0&&f.fixed) {
            // Straight motion has fixed birth velocity. Re-anchor only on actual
            // velocity changes, not every display. Shader clock is simulation time.
            if(f.anchor_speed!=m.speed||f.ray_direction!=m.direction) {
                f.anchor_speed=m.speed;f.anchor_time=kernel->presentation_clock();f.ray_direction=m.direction;
                f.anchor_point=f.ray_origin+f.ray_step*double((logical-f.launch).dot(f.ray_direction));
                f.axis=f.ray_step.normalized();
            }
            f.point=f.anchor_point;
        } else {
            f.point=f.fixed?f.ray_origin+f.ray_step*double((logical-f.launch).dot(f.ray_direction)):logical;
            if(f.fixed)f.axis=f.ray_step.normalized();
            else f.axis=m.direction.normalized();
        }
        if(missile) {
            const double elapsed=std::max(0.0,m.age-f.motion_age);f.motion_age=m.age;Vector2 delta=logical-f.trail[f.head];
            double wanted=delta.length_squared()>0.001?double(delta.angle()):double(m.direction.angle());
            f.visual_angle=Math::lerp_angle(f.visual_angle,wanted,1.0-std::exp(-elapsed*16.0));
            if(!born&&elapsed>0){f.head=(f.head+1)%14;f.trail[f.head]=logical;f.samples=std::min(14,f.samples+1);}
            if(f.samples>1){delta=f.trail[f.head]-f.trail[(f.head+13)%14];if(delta.length_squared()>0.001)f.visual_angle=delta.angle();}
            f.axis=engine_from_angle(f.visual_angle);
        }
        if(f.beam||f.hostile||missile||f.render_kind<0)frame.background.push_back(id);
    }
    return true;
}
void SpaceCombatPresentation::prepare_retained(Vector2 offset) {
    RID rid=display_canvas;begin();
    for(size_t id:retained_frame->background) {
        auto &f=retained_frame->flights[id];
        if(f.beam||(f.render_kind<0&&!(f.kind==2&&!f.hostile))) {
            f.draw=!f.awaiting;
            if(f.draw)f.point=position(f.motion->motion());
        } else if(f.hostile) {
            Color color=Color::html(f.damage_type==2?"ffaf61":"64b5ff");color.a=0.16;line(f.point+offset-f.axis*15,f.point+offset,color,1.0);
        }
    }
    paint(rid);
}
void SpaceCombatPresentation::prepare_retained_mesh() {
    if(retained_mesh.is_valid())return;
    prepare_templates();
    PackedVector3Array points;PackedColorArray tints;PackedVector2Array tags;PackedInt32Array indices;
    auto append=[&](const std::vector<Vector2> &v,const std::vector<Color> &c,int kind){
        for(size_t i=0;i<v.size();++i){Vector2 p=v[i];indices.push_back(points.size());points.push_back(Vector3(p.x,p.y,0));tints.push_back(c[i]);tags.push_back(Vector2(kind,0));}
    };
    // Type 0 is exactly the textured pulse quad consumed by the shader.
    for(Vector2 p:{Vector2(-17,-7),Vector2(17,-7),Vector2(17,7),Vector2(-17,-7),Vector2(17,7),Vector2(-17,7)}) {
        indices.push_back(points.size());points.push_back(Vector3(p.x,p.y,0));tints.push_back(Color(1,1,1));tags.push_back(Vector2(0,0));
    }
    for(int kind=2;kind<=3;++kind) {
        begin();Color color=Color::html(kind==3?"ffaf61":"64b5ff");
        if(kind==3){Color glow=color;glow.a=0.5;line(Vector2(-9,0),Vector2(-1,0),glow,1.5);line(Vector2(),Vector2(8,0),color,3.5);line(Vector2(5,0),Vector2(8,0),Color::html("ffe5bf"),2.0);}
        else{line(Vector2(-9,0),Vector2(9,0),color,2.0);line(Vector2(-7,0),Vector2(7,0),Color::html("d8f3ff"),1.0);}
        append(vertices,colors,kind);
    }
    Array arrays;arrays.resize(Mesh::ARRAY_MAX);arrays[Mesh::ARRAY_VERTEX]=points;arrays[Mesh::ARRAY_COLOR]=tints;arrays[Mesh::ARRAY_TEX_UV]=tags;arrays[Mesh::ARRAY_INDEX]=indices;
    retained_mesh.instantiate();retained_mesh->add_surface_from_arrays(Mesh::PRIMITIVE_TRIANGLES,arrays);begin();
}
void SpaceCombatPresentation::flush_retained(RID canvas) {
    if(retained_upload.empty())return;
    if(retained_cursor==retained_batches.size()){Ref<MultiMesh> batch;batch.instantiate();batch->set_transform_format(MultiMesh::TRANSFORM_2D);batch->set_use_custom_data(true);batch->set_mesh(retained_mesh);batch->set_custom_aabb(AABB(Vector3(-8192,-8192,-1),Vector3(16384,16384,2)));retained_batches.push_back(batch);retained_buffers.emplace_back();}
    const size_t slot=retained_cursor++;auto &batch=retained_batches[slot];const int count=retained_upload.size()/12;
    if(batch->get_instance_count()<count){int cap=std::max(8,batch->get_instance_count());while(cap<count)cap*=2;batch->set_instance_count(cap);}
    auto &buffer=retained_buffers[slot];int size=batch->get_instance_count()*12;if(buffer.size()!=size){buffer.resize(size);buffer.fill(0);}
    std::copy(retained_upload.begin(),retained_upload.end(),buffer.ptrw());batch->set_buffer(buffer);batch->set_visible_instance_count(count);
    RenderingServer::get_singleton()->canvas_item_add_multimesh(canvas,batch->get_rid());retained_upload.clear();
}
void SpaceCombatPresentation::draw_retained(Vector2 offset) {
    prepare_retained_mesh();RID rid=display_canvas;
    if(std::find(retained_canvases.begin(),retained_canvases.end(),rid)==retained_canvases.end()){retained_canvases.push_back(rid);RenderingServer::get_singleton()->canvas_item_set_material(rid,retained_material->get_rid());}
    double epoch=std::floor(retained_kernel->presentation_clock()/128.0)*128.0;
    retained_material->set_shader_parameter("simulation_clock",float(retained_kernel->presentation_clock()-epoch));
    retained_cursor=0;retained_upload.clear();begin();
    for(size_t id:retained_frame->order) {
        const auto &f=retained_frame->flights[id];if(!f.draw)continue;
        if(f.render_kind>=0) {

            paint(rid);Vector2 p=f.point+offset,axis=f.axis;
            // One shared topology stream retains mixed pulse/enemy order.
            // Only missiles and script operations form draw barriers.
            const bool ballistic=f.render_kind==0&&f.fixed;
            // Compatibility stores INSTANCE_CUSTOM in half floats. Split the
            // relative anchor so a 128-second clock cannot shift pulses by pixels.
            double relative=ballistic?f.anchor_time-epoch:0;
            double high=std::floor(relative*16.0)/16.0;
            double velocity=ballistic?f.anchor_speed*f.ray_step.length():0;
            if(std::abs(velocity)>60000.0) { // Preserve finite high-speed configurations.
                const Motion &m=f.motion->motion();p=f.ray_origin+f.ray_step*double((position(m)-f.launch).dot(m.direction))+offset;
                velocity=0;
            }
            float row[12]={axis.x,-axis.y,0,p.x,axis.y,axis.x,0,p.y,float(f.render_kind+32),float(high),float(relative-high),float(velocity)};
            retained_upload.insert(retained_upload.end(),row,row+12);continue;
        }
        flush_retained(rid);
        if(!f.hostile&&f.kind==2&&!f.beam) {

            flight(f,offset);
        } else {
            paint(rid);if(!f.segments.is_empty())draw_beams.call(f.segments);
        }
    }
    paint(rid);flush_retained(rid);
    for(size_t i=retained_cursor;i<retained_batches.size();++i)retained_batches[i]->set_visible_instance_count(0);
}
