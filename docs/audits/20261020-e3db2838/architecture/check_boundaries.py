"""Static boundary evidence only; does not run the game or builders."""
import ast,csv,json,re,subprocess,argparse
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--repo',type=Path,default=Path.cwd());p.add_argument('--output',type=Path,required=True);a=p.parse_args();BASE='e3db28386fd0d402f2dc6ae2b2ac4ab7f81674b3'
def read(path):return subprocess.check_output(['git','-C',str(a.repo),'show',BASE+':'+path]).decode('utf8')
rows=list(csv.DictReader((a.output/'files.csv').open()));paths={r['path'] for r in rows}
refs=list(csv.DictReader((a.output/'references.csv').open()))
tree=ast.parse(read('space-battleship/tools/build_result_analyzer.py'))
scripts=[]
for node in tree.body:
 if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='SCRIPTS' for t in node.targets):scripts=ast.literal_eval(node.value)
copied={'space-battleship/scripts/'+x for x in scripts}
missing=sorted({r['target'] for r in refs if r['kind']=='literal_resource_reference' and r['source'] in copied and r['target'].startswith('space-battleship/scripts/') and r['target'].endswith('.gd') and r['target'] not in copied})
release=read('space-battleship/tools/build_release.ps1');chunk=re.search(r'foreach \(\$dataFile in @\((.*?)\)\)',release).group(1);release_data=re.findall("'([^']+)'",chunk)
arch=read('space-battleship/docs/ARCHITECTURE.md');stale=sorted({x for x in re.findall(r'scripts/[\w_]+\.gd',arch) if 'space-battleship/'+x not in paths})
runner=read('test/run.py');runner_tree=ast.parse(runner);native_setup=[]
for node in ast.walk(runner_tree):
 if isinstance(node,ast.If) and 'isolated native build missing' in ast.get_source_segment(runner,node):
  native_setup+=re.findall(r'["\']([^"\']+\.gd)["\']',ast.get_source_segment(runner,node.test))
native_tests=sorted(r['path'] for r in rows if r['path'].startswith('test/test_') and '/' not in r['path'][5:] and 'native' in r['path'] and r['path'].endswith('.gd'))
result={'baseline':BASE,'analyzer_copied_script_count':len(scripts),'analyzer_direct_script_dependencies_missing_from_allowlist':missing,'release_data_allowlist':release_data,'architecture_doc_nonexistent_scripts':stale,'native_setup_named_tests':sorted(set(native_setup)),'root_native_named_tests':native_tests,'native_named_tests_without_special_setup':[x for x in native_tests if Path(x).name not in native_setup],'tracked_runtime_extension_descriptors':[x for x in sorted(paths) if x.startswith('space-battleship/') and x.endswith('.gdextension')],'notes':['Missing analyzer dependencies are static packaging-closure failures, not a claim that an invalid package was released.','No native test was executed in this supplement. Tests may have other documented bespoke runners.','Literal resource scanning excludes dynamic resource composition and cannot prove complete dependency closure.']}
(a.output/'boundary_checks.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print(json.dumps(result,ensure_ascii=False,indent=2))
