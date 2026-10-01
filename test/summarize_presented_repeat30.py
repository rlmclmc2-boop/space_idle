"""Keep formal five-shot observations separate from basic-table benchmarks."""
import argparse, collections, csv, json, pathlib, statistics
parser=argparse.ArgumentParser()
parser.add_argument('input',type=pathlib.Path)
parser.add_argument('--extra',type=pathlib.Path)
parser.add_argument('--output',type=pathlib.Path,default=pathlib.Path(__file__).parent/'enhancement_balance_report'/'presented_repeat30')
args=parser.parse_args();data=json.loads(args.input.read_text());rows=data['rows']
assert len(rows)==128 and data['runtime_class']=='PresentedBattleGame'
if args.extra:
    extra=json.loads(args.extra.read_text());assert len(extra['rows'])==128 and extra['runtime_commit']==data['runtime_commit'];rows+=extra['rows']
args.output.mkdir(parents=True,exist_ok=True)
def csv_write(name,records):
    fields=list(dict.fromkeys(k for r in records for k in r))
    with (args.output/name).open('w',encoding='utf-8-sig',newline='') as f:
        writer=csv.DictWriter(f,fieldnames=fields,lineterminator='\n');writer.writeheader()
        for r in records:writer.writerow({k:json.dumps(v,ensure_ascii=False,separators=(',',':'))if isinstance(v,(dict,list))else v for k,v in r.items()})
row_records=[];packet_records=[];maximum_lateness=0.0
for r in rows:
    counts=r['counts'];projected=r['projected_weapon'];assert projected['para1']==5 and projected['cd']==2.4
    assert counts['committed_packets']==r['groups']*5
    assert r['global_attacks_added']==counts.get('primary',0)+counts.get('extra_repeat',0)
    if r['targets']==1:assert counts.get('event_enhancement_secondary',0)==0
    record={k:v for k,v in r.items()if k!='launch_records'}
    record.update(primary=counts.get('primary',0),extra_repeats=counts.get('extra_repeat',0),secondary=counts.get('event_enhancement_secondary',0),committed_packets=counts['committed_packets'],released_packets=counts['released_packets'],hit_packets=counts.get('hit',0))
    row_records.append(record)
    for packet in r['launch_records']:
        assert packet['count']==5 and packet['ordinal'] in range(5)
        late=packet['time']-packet['due'];assert -.00000001<=late<=1/60+.00000001
        maximum_lateness=max(maximum_lateness,late)
        packet_records.append(dict(pattern=r['pattern'],seed=r['seed'],targets=r['targets'],measurement=r['measurement'],**packet))
csv_write('rows.csv',row_records);csv_write('released_packets.csv',packet_records)
groups=collections.defaultdict(dict)
for r in row_records:groups[r['targets'],r['measurement']][r['pattern'],r['seed']]=r
summaries=[]
for (targets,measurement),records in groups.items():
    for ap,bp in [('--A','--B'),('AAA','AAB')]:
        pairs=[(r,records[bp,seed])for(pattern,seed),r in records.items()if pattern==ap]
        adps=statistics.mean(a['dps']for a,b in pairs);bdps=statistics.mean(b['dps']for a,b in pairs)
        cleared=[(a,b)for a,b in pairs if a['wave_cleared']and b['wave_cleared']]
        summary=dict(targets=targets,measurement=measurement,A=ap,B=bp,paired_seeds=len(pairs),A_mean_dps=adps,B_mean_dps=bdps,B_over_A_dps=bdps/adps,B_dps_wins=sum(b['dps']>a['dps']for a,b in pairs),paired_dps_difference_sd=statistics.stdev(b['dps']-a['dps']for a,b in pairs),both_clear_pairs=len(cleared)if measurement=='ttk'else None,A_mean_ttk=statistics.mean(a['ttk']for a,b in cleared)if measurement=='ttk'and cleared else None,B_mean_ttk=statistics.mean(b['ttk']for a,b in cleared)if measurement=='ttk'and cleared else None,B_ttk_wins=sum(b['ttk']<a['ttk']for a,b in cleared)if measurement=='ttk'else None)
        for key in ['primary','extra_repeats','secondary','committed_packets','released_packets','hit_packets','queued_packets_remaining','queue_peak','queued_payload','released_payload','raw_hit_payload','actual_damage']:
            for choice,index in [('A',0),('B',1)]:summary[choice+'_'+key]=sum(pair[index][key]for pair in pairs)
        summaries.append(summary);print(targets,measurement,ap,bp,'DPS ratio',round(bdps/adps,4),'TTK',summary['A_mean_ttk'],summary['B_mean_ttk'],'B wins',summary['B_ttk_wins'])
csv_write('paired_summary.csv',summaries)
manifest={k:v for k,v in data.items()if k!='rows'}
manifest.update(completed_rows=len(rows),released_packet_rows=len(packet_records),max_release_lateness=maximum_lateness,no_tuning=True,scope='repeat30 only; actual formal player projection and projectile queue, default logical providers; no GUI/model pose/population claim',source_input=args.input.name)
(args.output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
