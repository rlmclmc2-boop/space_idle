"""Predeclared balanced laser/missile AB/BA repeats, then separate QA profiling."""
from pathlib import Path
import argparse,datetime,json,subprocess,sys

def main():
    p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,required=True)
    p.add_argument('--project',type=Path,required=True);p.add_argument('--before-lib',type=Path,required=True)
    p.add_argument('--after-lib',type=Path,required=True);p.add_argument('--godot',type=Path,required=True)
    p.add_argument('--phase',choices=['repeats','profile'],required=True)
    a=p.parse_args();base=Path(__file__).resolve().parent;repo=a.repo.resolve()
    schedule=[(1,'laser','AB'),(1,'missile','BA'),(2,'missile','AB'),(2,'laser','BA'),
              (3,'laser','BA'),(3,'missile','AB'),(4,'missile','BA'),(4,'laser','AB')]
    if a.phase=='profile':schedule=[(1,'laser','AB'),(1,'missile','BA')]
    agenda={'phase':a.phase,'schedule':[{'index':i+1,'block':b,'case':c,'order':o} for i,(b,c,o) in enumerate(schedule)],
            'declared_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'purpose':'Uninstrumented balanced repeats' if a.phase=='repeats' else 'QA-only bounded RAM timers, not acceptance samples',
            'results':[]}
    path=base/(a.phase+'-agenda.json')
    if path.exists():raise RuntimeError('Refuse to overwrite declared agenda')
    path.write_text(json.dumps(agenda,indent=2),encoding='utf-8')
    for i,(block,case,order) in enumerate(schedule,1):
        out=base/a.phase/(f'{i:02d}-b{block}-{case}-{order}')
        args=[sys.executable,str(base/'run_repeat.py'),'--repo',str(repo),
              '--project',str(a.project.resolve()),'--before-lib',str(a.before_lib.resolve()),
              '--after-lib',str(a.after_lib.resolve()),'--godot',str(a.godot.resolve()),
              '--output',str(out),'--cases',case,'--order',order]
        if a.phase=='profile':args.append('--profile')
        started=datetime.datetime.now(datetime.timezone.utc).isoformat()
        print('BEGIN',a.phase,i,case,order,flush=True)
        proc=subprocess.run(args,cwd=repo)
        agenda['results'].append({'index':i,'case':case,'order':order,'started_utc':started,
            'ended_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
            'exit_code':proc.returncode,'output':str(out.relative_to(base)),'command':args})
        path.write_text(json.dumps(agenda,indent=2),encoding='utf-8')
        if proc.returncode:raise RuntimeError(f'{a.phase} {case} {order} failed; retain data and stop')
    print('COMPLETE',a.phase,len(schedule),'pairs',flush=True)

if __name__=='__main__':main()
