// Single native presentation table. Kernel active order/generation is read-only authority.
// Per-slot descriptors are populated only at birth; dynamic motion remains in its lease.
bool SpaceCombatPresentation::advance_retained(Object *surface,double dt) {
    Object *game=surface->get("game");Object *session=game->get("native_execution");
    Ref<SpaceCombatKernel> kernel;
    if(session&&!bool(session->get("handed_off")))kernel=session->get("kernel");
    if(!supports_compact_lasers(surface)||kernel.is_null()||!kernel->admitted||kernel->stopped||
       !bool(surface->get("prototype_enabled"))||!bool(surface->get("pulse_vfx_enabled"))||
       !bool(surface->get("enemy_vfx_enabled"))||!bool(surface->get("missile_vfx_enabled"))) {
        // Materialize before changing presentation owner. Failure keeps the
        // retained table and kernel intact; advance_visuals must not fall back.
        if (kernel.is_valid() && kernel->admitted && !kernel->stopped && kernel->set_compact_laser_births(false)<0) return true;
        surface->call("restore_native_laser_visuals");
        clear_retained_frame();
        return false;
    }
    ++retained_advances;
    Array visuals=surface->get("projectile_visuals");
    if(retained_kernel!=kernel||retained_frame.is_null()||retained_encounter!=kernel->encounter_generation) {
        // Cold ownership/reset boundary only: serials may restart. Keep records
        // registered for this exact flight, never a same-number previous encounter.
        std::unordered_map<uint64_t,const SpaceCombatKernel::Flight*> current;
        for(size_t id:kernel->active)if(kernel->flights[id].live)current[kernel->flights[id].serial]=&kernel->flights[id];
        visual_by_serial.clear();
        for(int i=visuals.size()-1;i>=0;--i){Dictionary v=visuals[i],shot=v["shot"];uint64_t serial=int64_t(shot.get("serial",0));auto found=current.find(serial);
            if(found==current.end()||!same(found->second->view,shot))visuals.remove_at(i);
            else visual_by_serial[int64_t(serial)]=v;
        }
        retained_kernel=kernel;retained_encounter=kernel->encounter_generation;retained_frame.instantiate();retained_frame->persistent=true;retained_frame->kernel=kernel;
    }
    auto forget_visual=[&](const Variant &serial,const Dictionary &shot){Dictionary indexed=visual_by_serial.get(serial,Dictionary());if(!indexed.is_empty()&&same(indexed["shot"],shot))visual_by_serial.erase(serial);};
    auto &frame=*retained_frame.ptr();
    // Lease lifetime is not liveness. Check the kernel slot, generation AND lease.
    for(size_t id:frame.order) {
        auto &f=frame.flights[id];
        if(id>=kernel->flights.size()||!kernel->flights[id].live||kernel->flights[id].generation!=f.generation||kernel->flights[id].lease!=f.motion) {
            forget_visual(int64_t(f.serial),f.shot);f=PreparedFlight();
        }
    }
    // The capped compatibility/decorative records survive fallback. No active-shot
    // dictionary or serial index is rebuilt. Retired-before-first-display births
    // are removed here too, so their references cannot pin a motion slot forever.
    for(int i=visuals.size()-1;i>=0;--i) {
        Dictionary v=visuals[i],shot=v["shot"];
        if(bool(shot.get("dead",false))){forget_visual(shot.get("serial",Variant()),shot);visuals.remove_at(i);}
    }
    frame.flights.resize(kernel->flights.size());frame.order.clear();frame.background.clear();
    frame.order.reserve(kernel->active.size());int density=0;
    for(size_t id:kernel->active) {
        const auto &source=kernel->flights[id];if(!source.live)continue;
        auto &f=frame.flights[id];
        if(f.generation!=source.generation||f.motion!=source.lease||(f.shot.is_empty()&&!source.view.is_empty())) {
            ++retained_births;f=PreparedFlight();f.generation=source.generation;f.serial=source.serial;
            f.shot=source.view;f.motion=source.lease;f.hostile=source.hostile;f.chain=source.chain;f.beam=source.beam;f.damage_type=source.type;
            f.key=source.compact_laser ? String("laser") : String(source.view.get(source.chain ? "chain_weapon" : "key","")).replace("_mon","").replace("-mon","");
            f.visual=visual_by_serial.get(int64_t(source.serial),Dictionary());
            if(!f.visual.is_empty()&&!same(f.visual["shot"],source.view))f.visual=Dictionary();
            f.visual_state=f.visual.get("visual_lease",Variant());
            f.fixed=source.fixed_ray;
            if(f.fixed){f.launch=source.launch_point;f.ray_origin=source.ray_origin;f.ray_step=source.ray_step;f.ray_direction=f.motion->motion().direction;}
            else if(f.visual.has("fixed_step")){f.fixed=true;f.launch=f.visual["logical_origin"];f.ray_origin=f.visual["fixed_origin"];f.ray_step=f.visual["fixed_step"];f.ray_direction=f.visual["fixed_direction"];}
            f.render_kind=f.beam?-1:(!f.hostile&&f.key=="laser")?0:(f.hostile&&(f.key=="laser"||f.key=="cannon"))?(source.type==2?3:2):-1;
            f.anchor_speed=-1;
        }
        frame.order.push_back(id);f.draw=true;
        const Motion &m=f.motion->motion();Vector2 logical=position(m);
        const bool missile=!f.hostile&&f.key=="missile";
        if(missile)++density;
        if(f.render_kind==0&&f.fixed) {
            // Straight motion has fixed birth velocity. Re-anchor only on actual
            // velocity changes, not every display. Shader clock is simulation time.
            if(f.anchor_speed!=m.speed||f.ray_direction!=m.direction) {
                f.anchor_speed=m.speed;f.anchor_time=kernel->clock;f.ray_direction=m.direction;
                f.anchor_point=f.ray_origin+f.ray_step*double((logical-f.launch).dot(f.ray_direction));
                f.axis=f.ray_step.normalized();
            }
            f.point=f.anchor_point;
        } else {
            f.point=f.fixed?f.ray_origin+f.ray_step*double((logical-f.launch).dot(f.ray_direction)):battle_point(logical);
            if(f.chain)f.axis=(battle_point(logical+m.direction)-battle_point(logical)).normalized();
            else if(f.fixed)f.axis=f.ray_step.normalized();
            else f.axis=m.direction.normalized();
        }
        if(f.visual_state.is_valid()) {
            auto &v=*f.visual_state.ptr();v.age+=dt;
            if(missile) {
                Vector2 delta=battle_point(logical)-battle_point(v.trail[v.head]);
                double wanted=delta.length_squared()>0.001?double(delta.angle()):double(m.direction.angle());
                v.angle=Math::lerp_angle(v.angle,wanted,1.0-std::exp(-dt*16.0));
                if(dt>0){v.head=(v.head+1)%14;v.times[v.head]=v.age;v.trail[v.head]=logical;v.samples=std::min(14,v.samples+1);}
                if(v.samples>1){delta=battle_point(v.trail[v.head])-battle_point(v.trail[(v.head+13)%14]);if(delta.length_squared()>0.001)v.angle=delta.angle();}
                v.last_render=v.trail[v.head];v.last_logical=logical;v.had_target=!Dictionary(f.shot["target"]).is_empty();
                f.axis=engine_from_angle(v.angle);
            } else {
                if(f.visual.has("fixed_step")&&!f.fixed)f.axis=Vector2(f.visual["fixed_step"]).normalized();
                v.angle=f.axis.angle();
            }
        }
        if(f.beam||f.hostile||missile||f.render_kind<0)frame.background.push_back(id);
    }
    surface->set("missile_density",density);
    return true;
}
void SpaceCombatPresentation::prepare_retained(Object *surface,Vector2 offset) {
    retained_frame->presentation_time=retained_kernel->clock;retained_frame->presentation_offset=offset;
    Object *canvas=surface->get("draw_surface");RID rid=canvas->call("get_canvas_item");begin();
    Array particles=surface->get("particles");
    for(size_t id:retained_frame->background) {
        auto &f=retained_frame->flights[id];
        if(f.beam||(f.render_kind<0&&!(f.key=="missile"&&!f.hostile))) {
            paint(rid);Dictionary legacy=surface->call("_prepare_projectile_flight",f.shot,visual_by_serial,offset);
            f.draw=!legacy.is_empty();if(f.draw){f.point=Vector2(legacy["pos"])-offset;f.budget=legacy.get("budget",1);}
        } else if(f.hostile) {
            Color color=Color::html(f.damage_type==2?"ffaf61":"64b5ff");color.a=0.16;line(f.point+offset-f.axis*15,f.point+offset,color,1.0);
        } else if(f.key=="missile") {
            f.budget=1;
            if(f.visual_state.is_valid()&&f.visual_state->samples>5){int nearby=0;for(int j=0;j<particles.size();++j){Dictionary p=particles[j];if(Vector2(p["pos"]).distance_squared_to(f.point+offset)<6400)++nearby;}f.budget=std::min(1,std::max(0,18-nearby));}
        }
    }
    paint(rid);
}
void SpaceCombatPresentation::prepare_retained_mesh() {
    if(retained_mesh.is_valid())return;
    prepare_pulse_mesh();prepare_templates();
    PackedVector3Array points;PackedColorArray tints;PackedVector2Array tags;PackedInt32Array indices;
    auto append=[&](const std::vector<Vector2> &v,const std::vector<Color> &c,int kind,bool turn){
        for(size_t i=0;i<v.size();++i){Vector2 p=turn?Vector2(-v[i].y,v[i].x):v[i];indices.push_back(points.size());points.push_back(Vector3(p.x,p.y,0));tints.push_back(c[i]);tags.push_back(Vector2(kind,0));}
    };
    Array pulse=pulse_mesh->surface_get_arrays(0);PackedVector3Array pv=pulse[Mesh::ARRAY_VERTEX];PackedColorArray pc=pulse[Mesh::ARRAY_COLOR];
    for(int i=0;i<pv.size();++i){indices.push_back(points.size());points.push_back(pv[i]);tints.push_back(pc[i]);tags.push_back(Vector2(0,0));}
    append(chain,chain_colors,1,true);
    for(int kind=2;kind<=3;++kind) {
        begin();Color color=Color::html(kind==3?"ffaf61":"64b5ff");
        if(kind==3){Color glow=color;glow.a=0.5;line(Vector2(-9,0),Vector2(-1,0),glow,1.5);line(Vector2(),Vector2(8,0),color,3.5);line(Vector2(5,0),Vector2(8,0),Color::html("ffe5bf"),2.0);}
        else{line(Vector2(-9,0),Vector2(9,0),color,2.0);line(Vector2(-7,0),Vector2(7,0),Color::html("d8f3ff"),1.0);}
        append(vertices,colors,kind,false);
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
    retained_upload_bytes+=size*sizeof(float);RenderingServer::get_singleton()->canvas_item_add_multimesh(canvas,batch->get_rid());retained_upload.clear();
}
void SpaceCombatPresentation::draw_retained(Object *surface,Vector2 offset) {
    ++retained_draws;prepare_retained_mesh();Object *canvas=surface->get("draw_surface");RID rid=canvas->call("get_canvas_item");
    if(std::find(retained_canvases.begin(),retained_canvases.end(),rid)==retained_canvases.end()){retained_canvases.push_back(rid);RenderingServer::get_singleton()->canvas_item_set_material(rid,retained_material->get_rid());}
    double epoch=std::floor(retained_kernel->clock/128.0)*128.0;
    retained_material->set_shader_parameter("simulation_clock",float(retained_kernel->clock-epoch));
    retained_cursor=0;retained_upload.clear();begin();bool script_run=false;
    for(size_t id:retained_frame->order) {
        const auto &f=retained_frame->flights[id];if(!f.draw)continue;
        if(f.render_kind>=0) {
            if(script_run){surface->call("flush_projectile_packet_batch");script_run=false;}
            paint(rid);Vector2 p=f.point+offset,axis=f.axis;
            // One shared topology stream retains mixed pulse/chain/enemy order.
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
        if(!f.hostile&&f.key=="missile"&&!f.beam) {
            if(script_run){surface->call("flush_projectile_packet_batch");script_run=false;}
            flight(f.point+offset,f.axis,f.motion->motion().age,!Dictionary(f.shot["target"]).is_empty(),f.visual,offset,f.budget==0?0.5:1.0);
        } else {
            paint(rid);Dictionary legacy=f.legacy();legacy["pos"]=f.point+offset;surface->call("_draw_projectile_foreground_flight",legacy,offset);script_run=true;
        }
    }
    paint(rid);flush_retained(rid);if(script_run)surface->call("flush_projectile_packet_batch");
    for(size_t i=retained_cursor;i<retained_batches.size();++i)retained_batches[i]->set_visible_instance_count(0);
}
