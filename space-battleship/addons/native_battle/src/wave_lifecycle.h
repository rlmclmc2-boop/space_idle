// Included inside SpaceCombatKernel's public section. Uses its one set of
// actors, sources, flights, queues, defence, history, and random stream.
    Dictionary read_history() const {
        Dictionary value; value["attacks"]=attack_counter;value["incoming"]=incoming_counter;return value;
    }
    void retain_live_sources() {
        std::vector<bool> keep(weapons.size(),false);
        for(size_t i=0;i<weapons.size();++i) keep[i]=!weapons[i].hostile;
        for(size_t id:active) if(flights[id].weapon>=0) keep[flights[id].weapon]=true;
        std::vector<int> mapping(weapons.size(),-1);
        std::vector<Weapon> retained;
        for(size_t i=0;i<weapons.size();++i) if(keep[i]) {mapping[i]=int(retained.size());retained.push_back(weapons[i]);}
        RootQueue next_roots;
        for(Timed task:roots.entries()) if(!weapons[task.weapon].hostile) {task.weapon=mapping[task.weapon];next_roots.push(task);}
        roots=std::move(next_roots);
        auto filter=[&](auto &queue) {
            std::decay_t<decltype(queue)> next;
            while(!queue.empty()) {
                Timed task=queue.top();queue.pop();
                if(weapons[task.weapon].hostile) continue;
                task.weapon=mapping[task.weapon];next.push(task);
            }
            queue=std::move(next);
        };
        filter(ejections);filter(repeats);
        for(size_t id:active) flights[id].weapon=mapping[flights[id].weapon];
        weapons=std::move(retained);
    }
    bool start_wave(Dictionary wave) {
        try {
            if(!admitted || executing || stopped || !native_error.is_empty() ||
                !wave.has("enemies") || !wave.has("weapons") || !wave.has("final") ||
                wave["enemies"].get_type()!=Variant::ARRAY || wave["weapons"].get_type()!=Variant::ARRAY ||
                wave["final"].get_type()!=Variant::BOOL || Array(wave["enemies"]).is_empty()) return false;
            for(const Actor &actor:actors) if(actor.live) return false;
            Array sources=wave["weapons"];
            for(int i=0;i<sources.size();++i) {
                if(sources[i].get_type()!=Variant::DICTIONARY || !bool(Dictionary(sources[i]).get("hostile",false))) return false;
            }
            Dictionary descriptor=session_descriptor.duplicate(true);
            descriptor["player"]=player_row.duplicate(true);descriptor["enemies"]=wave["enemies"];descriptor["weapons"]=sources;
            descriptor["defences"]=Array();descriptor["requires_module_defense"]=false;
            descriptor["clock"]=clock;descriptor["attack_counter"]=attack_counter;descriptor["incoming_counter"]=incoming_counter;
            descriptor["final_encounter"]=wave["final"];
            if(wave.has("jewel_ratio")) descriptor["jewel_ratio"]=wave["jewel_ratio"];
            Ref<SpaceCombatKernel> candidate;candidate.instantiate();
            // Admission only: the candidate is never advanced and never draws RNG.
            if(!candidate->configure(descriptor)) return false;
            if(encounter_generation>=UINT32_MAX-1 || actor_id>INT64_MAX-int64_t(candidate->actors.size()) || encounter_id==INT64_MAX)
                throw std::overflow_error("IntegerRangeExceeded");
            const bool restart=final_cleared;
            retain_live_sources();
            actors.clear();actor_rows.clear();
            ++encounter_generation;checked_increment(encounter_id);
            for(Actor actor:candidate->actors) {
                actor.generation=encounter_generation;actor.uid=checked_increment(actor_id);
                actor.view["uid"]=actor.uid;actors.push_back(actor);actor_rows.push_back(actor.view);
            }
            if(restart) for(size_t i=0;i<weapons.size();++i) if(!weapons[i].hostile) {
                weapons[i].beam=-1;
                roots.push({clock+(weapons[i].kind==3?0:weapons[i].interval),checked_id(event_serial),0,int(i)});
            }
            for(Weapon weapon:candidate->weapons) {
                weapon.source.generation=encounter_generation;
                const int index=int(weapons.size());weapons.push_back(weapon);
                roots.push({clock+weapon.remaining,checked_id(event_serial),0,index});
            }
            final_encounter=wave["final"];final_cleared=false;wave_running=true;
            jewel_ratio=candidate->jewel_ratio;
            retain_configuration_bounds();
            return true;
        } catch(const std::exception &error) {stopped=true;native_error=String(error.what());return false;}
    }
    bool finish_wave(bool final) {
        if(executing || final!=final_encounter) return false;
        for(const Actor &actor:actors) if(actor.live) return false;
        if(final) commit_final_wipe();
        else {
            RootQueue remaining;
            for(const Timed &task:roots.entries()) if(!weapons[task.weapon].hostile) remaining.push(task);
            roots=std::move(remaining);
        }
        return true;
    }
    Dictionary take_results() {
        Dictionary result;Array events=take_feedback(),drops;
        for(int i=0;i<events.size();++i) {
            Dictionary event=events[i];
            if(int(event["kind"])==7) {
                Dictionary drop=Dictionary(event["shot"]).duplicate(true);drop["created_at"]=event["clock"];drops.push_back(drop);
            }
        }
        bool live=false;for(const Actor &actor:actors) live=live||actor.live;
        bool cleared=wave_running&&!live;
        if(cleared) wave_running=false;
        const bool died=player_hp<=0&&!death_reported;
        if(died) death_reported=true;
        result["events"]=events;result["drops"]=drops;result["wave_cleared"]=cleared;
        result["final_cleared"]=cleared&&final_encounter;result["player_died"]=died;
        result["history"]=read_history();result["encounter_id"]=encounter_id;result["error"]=native_error;
        result["clock"]=clock;
        return result;
    }
    bool begin_retreat() {
        if(executing || !native_error.is_empty()) return false;
        cancel();debts.clear();strange_pending.clear();retain_live_sources();
        actors.clear();actor_rows.clear();wave_running=false;final_cleared=false;
        return true;
    }
    bool finish_retreat() {
        if(executing || !native_error.is_empty()) return false;
        for(Defence &defence:defences) {defence.loss=0;defence.buffer=0;defence.last_hit=defence_time;}
        player_hp=module_defence?capacity(1):CombatAmount(Dictionary(session_descriptor["player"])["armour"]);
        player_shield=module_defence?capacity(0):CombatAmount(Dictionary(session_descriptor["player"])["shield"]);
        stopped=false;death_reported=false;
        for(size_t i=0;i<weapons.size();++i) if(!weapons[i].hostile) {
            weapons[i].beam=-1;
            roots.push({clock+(weapons[i].kind==3?0:weapons[i].interval),checked_id(event_serial),0,int(i)});
        }
        publish_player();return player_hp>0;
    }
