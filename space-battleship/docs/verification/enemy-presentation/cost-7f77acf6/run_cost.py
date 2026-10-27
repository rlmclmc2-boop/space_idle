from pathlib import Path
import subprocess,os,json,sys,statistics

root=Path(r'C:/Users/Administrator/AppData/Local/Temp/space-idle-enemy-presentation-contract/cost-evidence')
repo=Path(r'C:/Users/Administrator/Documents/Codex/2026-10-27/task-5/main-candidate')
godot=r'D:/CodexTools/godot-4.7.2-stable/Godot_v4.7.2-stable_win64_console.exe'
script=Path(r'C:/Users/Administrator/Documents/Codex/2026-10-28/task/enemy_presentation_cost.gd')
variants=sys.argv[1:]
tag='-'.join(variants)
records=[]; expected={}
for case,recovery,visibility in [('loss-hidden',0.0,'hidden'),('loss-visible',0.0,'visible'),('recovery-hidden',1.0,'hidden'),('recovery-visible',1.0,'visible')]:
    for trial in range(3):
        order=variants if trial%2==0 else list(reversed(variants))
        for variant in order:
            name=f'{case}-{trial}-{variant}'
            env=os.environ.copy();env['SPACE_IDLE_NATIVE_EXTENSION']=str(root/(variant+'.gdextension'))
            args=[godot,'--headless','--path',str(repo/'space-battleship'),'--log-file',str(root/(name+'.log')),'--script',str(script),'--',str(recovery),visibility]
            result=subprocess.run(args,cwd=repo,env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
            (root/(name+'.txt')).write_bytes(result.stdout)
            assert result.returncode==0,result.stdout.decode(errors='replace')
            matches=[x for x in result.stdout.decode('utf-8').splitlines() if x.startswith('COST_JSON=')]
            assert len(matches)==1,result.stdout
            record=json.loads(matches[0].split('=',1)[1])
            assert 'error' not in record,record
            facts={k:v for k,v in record.items() if k!='elapsed_usec'}
            if case in expected: assert facts==expected[case],(case,variant,facts,expected[case])
            else: expected[case]=facts
            record.update({'case':case,'trial':trial,'variant':variant,'exit_code':result.returncode})
            records.append(record)
            (root/(tag+'-samples.json')).write_text(json.dumps(records,indent=2),encoding='utf-8')
            print(name,record['elapsed_usec'], 'us; simulation facts equal',flush=True)
summary=[]
for case in expected:
    times={v:[r['elapsed_usec'] for r in records if r['case']==case and r['variant']==v] for v in variants}
    medians={v:statistics.median(t) for v,t in times.items()}
    summary.append({'case':case,'samples_usec':times,'median_usec':medians,
                    'relative_to_'+variants[0]:{v:medians[v]/medians[variants[0]] for v in variants},
                    'simulation_facts_equal':True})
(root/(tag+'-summary.json')).write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(summary),flush=True)
