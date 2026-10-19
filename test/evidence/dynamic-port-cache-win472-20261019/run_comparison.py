"""Two balanced original-driver pairs per affected case; same Windows DLL."""
from pathlib import Path
import argparse,datetime,json,subprocess,sys
def main():
    p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True);p.add_argument('--project',type=Path,required=True)
    p.add_argument('--dll',type=Path,required=True);p.add_argument('--godot',type=Path,required=True);a=p.parse_args()
    out=Path(__file__).resolve().parent
    schedule=[('laser','AB'),('missile','BA'),('laser','BA'),('missile','AB')]
    agenda={'schedule':schedule,'declared_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'results':[],
            'scope':'Uninstrumented cache-only GDS comparison, same DLL and frozen fixtures'}
    path=out/'agenda.json'
    if path.exists():raise RuntimeError('Refuse to overwrite agenda')
    path.write_text(json.dumps(agenda,indent=2),encoding='utf-8')
    for index,(case,order) in enumerate(schedule,1):
        folder=out/'perf'/f'{index:02d}-{case}-{order}'
        args=[sys.executable,str(out/'run_cache_pair.py'),'--repo',str(a.repo.resolve()),
              '--project',str(a.project.resolve()),'--before-lib',str(a.dll.resolve()),'--after-lib',str(a.dll.resolve()),
              '--godot',str(a.godot.resolve()),'--output',str(folder),'--cases',case,'--order',order]
        begin=datetime.datetime.now(datetime.timezone.utc).isoformat();print('BEGIN',index,case,order,flush=True)
        proc=subprocess.run(args,cwd=a.repo.resolve())
        agenda['results'].append({'index':index,'case':case,'order':order,'output':folder.relative_to(out).as_posix(),
            'started_utc':begin,'ended_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'exit':proc.returncode,'command':args})
        path.write_text(json.dumps(agenda,indent=2),encoding='utf-8')
        if proc.returncode:raise RuntimeError('Run failed; preserve logs, do not replace')
    print('COMPLETE 4 pairs / 8 runs',flush=True)
if __name__=='__main__':main()
