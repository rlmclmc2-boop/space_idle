// Diagnostic-only: read calling thread counters; no priority/affinity/power changes.
class SpaceThreadProbe : public RefCounted {
 GDCLASS(SpaceThreadProbe, RefCounted)
 struct Stamp { LONGLONG qpc; ULONG64 cycles; };
 struct Bucket { int64_t count=0,ticks=0,cycles=0; std::vector<Stamp> stack; };
 std::array<Bucket,5> buckets;
 int64_t errors=0;
 Stamp stamp() { LARGE_INTEGER q; ULONG64 c=0; if(!QueryPerformanceCounter(&q)||!QueryThreadCycleTime(GetCurrentThread(),&c))++errors; return {q.QuadPart,c}; }
 protected:
 static void _bind_methods(){
  ClassDB::bind_method(D_METHOD("sample"),&SpaceThreadProbe::sample);
  ClassDB::bind_method(D_METHOD("begin_span","id"),&SpaceThreadProbe::begin_span);
  ClassDB::bind_method(D_METHOD("end_span","id"),&SpaceThreadProbe::end_span);
  ClassDB::bind_method(D_METHOD("take"),&SpaceThreadProbe::take);
  ClassDB::bind_method(D_METHOD("info"),&SpaceThreadProbe::info);
 }
 public:
 PackedInt64Array sample(){
  FILETIME a,b,k,u; auto s=stamp(); bool ok=GetThreadTimes(GetCurrentThread(),&a,&b,&k,&u);
  if(!ok)++errors;
  uint64_t cpu=ok?((uint64_t(k.dwHighDateTime)<<32)|k.dwLowDateTime)+((uint64_t(u.dwHighDateTime)<<32)|u.dwLowDateTime):0;
  PackedInt64Array out;out.push_back(s.qpc);out.push_back(s.cycles);out.push_back(cpu);out.push_back(GetCurrentThreadId());out.push_back(errors);return out;
 }
 void begin_span(int64_t id){if(id<0||id>=5){++errors;return;}buckets[id].stack.push_back(stamp());}
 void end_span(int64_t id){auto end=stamp();if(id<0||id>=5||buckets[id].stack.empty()){++errors;return;}auto &b=buckets[id];auto start=b.stack.back();b.stack.pop_back();++b.count;b.ticks+=end.qpc-start.qpc;b.cycles+=end.cycles-start.cycles;}
 Array take(){Array out;for(auto &b:buckets){PackedInt64Array row;row.push_back(b.count);row.push_back(b.ticks);row.push_back(b.cycles);row.push_back(b.stack.size());out.push_back(row);b.count=b.ticks=b.cycles=0;}return out;}
 Dictionary info(){LARGE_INTEGER q;QueryPerformanceFrequency(&q);Dictionary d;d["qpc_frequency"]=q.QuadPart;d["calling_thread_id"]=int64_t(GetCurrentThreadId());d["process_id"]=int64_t(GetCurrentProcessId());d["errors"]=errors;return d;}
};
