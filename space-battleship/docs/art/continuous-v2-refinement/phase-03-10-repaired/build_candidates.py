"""Offline candidate preparation. Never writes runtime assets or gameplay data."""
from pathlib import Path
import subprocess,tempfile,json,hashlib,shutil
from PIL import Image,ImageChops
import numpy as np
from scipy.ndimage import gaussian_filter
HERE=Path(__file__).resolve().parent
PROJECT=HERE.parents[3]
SOURCE=HERE/'source'; REVIEW=HERE/'review';REVIEW.mkdir(exist_ok=True)
OLD=HERE.parent/'phase-01-02-balanced/source/prepared-master.png'
def run(*args):subprocess.run([str(a) for a in args],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
def grain(path,where):
    a=np.asarray(Image.open(path).convert('L'),dtype=float)
    a=a[:48,180:500] if where=='top' else a[-48:,180:500]
    high=a-gaussian_filter(a,1.2)
    return float(np.percentile(np.abs(high),75))
report={'baseline':'2eba83917b09879dca76b676729f80c03eceec1d','runtime_exported':False,'extensions':[]}
with tempfile.TemporaryDirectory(prefix='opening-continuation-',dir='/tmp') as folder:
    t=Path(folder);previous=OLD;parts=[]
    for pair in ['03-04','05-06','07-08','09-10']:
        raw=SOURCE/f'extension-{pair}-repaint.png'
        with Image.open(raw) as im:assert im.width>=572 and im.height>=960
        native=t/'native.png';run('magick',raw,'-resize','572x960!','-channel','RGB','-fx','u<0.35?u:0.35+0.18*(1-exp(-(u-0.35)/0.18))',native)
        # Match low-frequency color only, leaving midtones above the join zone alone.
        run('magick',native,'-crop','572x320+0+640','+repage',t/'strip.png')
        run('magick',native,'-crop','572x1+0+959','+repage','-blur','0x24','-scale','572x320!',t/'new-field.png')
        run('magick',previous,'-crop','572x1+0+0','+repage','-blur','0x24','-scale','572x320!',t/'old-field.png')
        run('magick',t/'strip.png',t/'old-field.png',t/'new-field.png','-fx','u[0]+pow(j/319,2)*(3-2*j/319)*(u[1]-u[2])',t/'graded-strip.png')
        run('magick',native,t/'graded-strip.png','-geometry','+0+640','-composite',t/'graded.png')
        target=grain(previous,'top');choices=[]
        for sigma in [0,.35,.6,1.,1.5,2.5]:
            file=t/f'blur-{sigma}.png'
            if sigma:run('magick',t/'graded.png','-blur',f'0x{sigma}',file)
            else:shutil.copyfile(t/'graded.png',file)
            choices.append((abs(grain(file,'bottom')-target),sigma,file))
        _,sigma,filtered=min(choices)
        if pair=='03-04':sigma=2.5;filtered=t/'blur-2.5.png'
        run('magick',t/'graded.png',filtered,'-fx','u[0]*(1-pow(max(0,(j-640)/319),2))+u[1]*pow(max(0,(j-640)/319),2)',t/'grain.png')
        out=SOURCE/f'extension-{pair}-prepared.png'
        if pair=='03-04':
            run('inkscape',SOURCE/'mast-continuation.svg',f'--export-filename={t}/mast.png')
            run('magick',t/'grain.png',t/'mast.png','-composite',out)
            # Preserve the existing stage-2 top filter support when the new region scrolls in.
            im=Image.open(out).convert('RGB');old=Image.open(OLD).convert('RGB')
            for y in [958,959]:im.paste(old.crop((0,0,572,1)),(0,y))
            im.save(out)
        else:shutil.copyfile(t/'grain.png',out)
        report['extensions'].append({'pair':pair,'join_zone':320,'blur_sigma_at_join':sigma,'reference_grain':target,'source_sha256':hashlib.sha256(raw.read_bytes()).hexdigest()})
        previous=out;parts.append(out)
    master=Image.new('RGB',(572,5946));y=0
    for path in list(reversed(parts))+[OLD]:
        im=Image.open(path).convert('RGB');master.paste(im,(0,y));y+=im.height
    master.save(SOURCE/'continuous-master.png',optimize=True)
    assert ImageChops.difference(master.crop((0,3840,572,5946)),Image.open(OLD).convert('RGB')).getbbox() is None
    padded=Image.new('RGB',(572,5950));padded.paste(master,(0,2))
    for y in [0,1]:
        padded.paste(master.crop((0,0,572,1)),(0,y));padded.paste(master.crop((0,5945,572,5946)),(0,5948+y))
    for stage in range(1,11):
        if stage<=2:shutil.copyfile(PROJECT/f'assets/backgrounds/opening/stage_{stage:02d}.png',REVIEW/f'stage_{stage:02d}.png')
        else:
            origin=(10-stage)*480
            padded.crop((0,origin,572,origin+1444)).save(REVIEW/f'stage_{stage:02d}.png',optimize=True)
    report['old_master_pixels_preserved']=True
    report['source_master_size']=[572,5946]
    report['visual_strides']=[720,426]+[480]*8
    report['rgba8_equivalent_all_10_bytes']=sum(Image.open(REVIEW/f'stage_{s:02d}.png').width*Image.open(REVIEW/f'stage_{s:02d}.png').height*4 for s in range(1,11))
    report['pixel_overlap']=[]
    for stage in range(1,10):
        a=Image.open(REVIEW/f'stage_{stage:02d}.png').convert('RGB').crop((0,0,572,964))
        b=Image.open(REVIEW/f'stage_{stage+1:02d}.png').convert('RGB');stride=b.height-964;b=b.crop((0,stride,572,stride+964))
        d=ImageChops.difference(a,b);report['pixel_overlap'].append({'boundary':f'{stage}->{stage+1}','identical':d.getbbox() is None})
    (HERE/'asset-report.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report,indent=2))
