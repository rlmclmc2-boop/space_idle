import argparse,gzip,json,hashlib
from pathlib import Path
ap=argparse.ArgumentParser();ap.add_argument('--ready',type=Path,required=True);ap.add_argument('--work',type=Path,required=True);a=ap.parse_args();r=a.ready.resolve();w=a.work.resolve();w.mkdir(parents=True,exist_ok=True);source=w/'source32-to049.bin';assert not source.exists();b=gzip.decompress((r/'source32-to049.bin.gz').read_bytes());assert hashlib.sha256(b).hexdigest()=='1d3412d1a5bb7608a058a6a3760824168a572e757472fc76896a72ab04869522';source.write_bytes(b)
(w/'audit-request.json').write_text(json.dumps({'source':str(source),'output':str(w/'source-audit.json')},indent=2)+'\n')
(w/'transition-request.json').write_text(json.dumps({'source':str(source),'source_manifest':str(r/'source-manifest.json'),'whitelist':str(r/'exact-runtime-whitelist.json'),'audit':str(w/'source-audit.json'),'output':str(w/'source32-e528.bin')},indent=2)+'\n')
for name in ['data','config','cache']:(w/'xdg'/name).mkdir(parents=True,exist_ok=True)
print('READY_REQUESTS',w)
