"""Deterministic offline 3D emission/absorption integration for the core.
Unlimited-free local NumPy/Pillow; no service, stochastic denoising or runtime
ray marching. Run python generate_plasma_atlas.py; build files stay in /tmp.
"""
from pathlib import Path
import os,json,math,time,hashlib
import numpy as np
from PIL import Image
OUT=Path(os.environ.get('REACTOR_PLASMA_BUILD','/tmp/reactor-plasma-clean'));OUT.mkdir(parents=True,exist_ok=True)
RECIPE_SHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()
SIZE=256;STEPS=64;FRAMES=int(os.environ.get('REACTOR_PLASMA_FRAME_LIMIT','32'))
axis=(np.arange(SIZE,dtype=np.float32)+.5)/SIZE*2.25-1.125
x,y=np.meshgrid(axis,-axis);radius_xy=x*x+y*y;ds=2.1/STEPS
absorption=np.array([1.15,.80,.55],dtype=np.float32)
def lattice(ix,iy,iz):
 h=(ix.astype(np.uint32)*np.uint32(73856093))^(iy.astype(np.uint32)*np.uint32(19349663))^(iz.astype(np.uint32)*np.uint32(83492791))
 h^=h>>np.uint32(13);h*=np.uint32(1274126177);h^=h>>np.uint32(16)
 return (h&np.uint32(16777215)).astype(np.float32)/16777215.
def noise(qx,qy,qz):
 ix=np.floor(qx);iy=np.floor(qy);iz=np.floor(qz);fx=qx-ix;fy=qy-iy;fz=qz-iz
 fx=fx*fx*(3-2*fx);fy=fy*fy*(3-2*fy);fz=fz*fz*(3-2*fz)
 a=lattice(ix,iy,iz)*(1-fx)+lattice(ix+1,iy,iz)*fx
 b=lattice(ix,iy+1,iz)*(1-fx)+lattice(ix+1,iy+1,iz)*fx
 c=lattice(ix,iy,iz+1)*(1-fx)+lattice(ix+1,iy,iz+1)*fx
 d=lattice(ix,iy+1,iz+1)*(1-fx)+lattice(ix+1,iy+1,iz+1)*fx
 return (a*(1-fy)+b*fy)*(1-fz)+(c*(1-fy)+d*fy)*fz
start=time.time()
for frame in range(FRAMES):
 theta=math.tau*frame/32.;ct,st=math.cos(theta),math.sin(theta)
 centre_x=.45*np.cos(3.5*y+theta);centre_z=.45*np.sin(3.5*y+theta)
 secondary_x=.55*np.cos(-2.3*y+theta+1.4);secondary_z=.55*np.sin(-2.3*y+theta+1.4)
 trans=np.ones((SIZE,SIZE,3),dtype=np.float32);light=np.zeros_like(trans)
 for step in range(STEPS):
  z=1.05-(step+.5)*ds
  mask=np.maximum(0.,1.-radius_xy-z*z)**.6
  n=noise((ct*x+st*z)*1.9+.42*st,y*.96+.18*math.sin(theta*2),(-st*x+ct*z)*1.9+.42*ct)
  fine=noise((ct*x+st*z)*3.8+.7, y*2.5-.25*st,(-st*x+ct*z)*3.8+.3)
  n=n*.72+fine*.28
  flux=np.exp(-((x-centre_x-.14*(n-.5))**2+(z-centre_z)**2)/.018)
  secondary=np.exp(-((x-secondary_x)**2+(z-secondary_z)**2)/.015)
  cloud=np.maximum(n-.35,0.)**1.4*2.8
  density=(cloud+4.*flux*(.15+.85*n*n)+2.8*secondary*(.2+.8*n))*mask
  hot=np.clip(flux*n*.80+secondary*n*.65+np.maximum(n-.35,0.)*.85,0.,1.)
  cool=np.array([.005,.08,.40],dtype=np.float32)
  cyan=np.array([.05,.75,1.7],dtype=np.float32)
  white=np.array([.9,1.5,1.9],dtype=np.float32)
  tint=cool+(cyan-cool)*np.clip(hot/.65,0,1)[...,None]
  tint+=(white-cyan)*np.clip((hot-.65)/.35,0,1)[...,None]
  att=np.exp(-density[...,None]*ds*absorption)
  light+=trans*(1.-att)*tint*(1.2+1.2*flux[...,None]);trans*=att
 alpha=np.clip(1.-trans.mean(axis=2),0,1)
 straight=light*2.5
 # Filmic response preserves hot blue-white structure instead of clipping.
 rgb=np.clip((straight*(2.51*straight+.03))/(straight*(2.43*straight+.59)+.14),0,1)
 rgb=np.where(rgb<=.0031308,rgb*12.92,1.055*np.maximum(rgb,0)**(1/2.4)-.055)
 rgba=np.concatenate((rgb,alpha[...,None]),axis=2);rgba[alpha<1/255.]=0
 Image.fromarray(np.round(np.clip(rgba,0,1)*255).astype(np.uint8)).save(OUT/f'plasma-{frame:02d}.png')
 print('PLASMA_FRAME',frame,'seconds',round(time.time()-start,3),flush=True)
(OUT/'render.json').write_text(json.dumps({'frames':FRAMES,'tile':[SIZE,SIZE],'layout':[8,4],'engine':'deterministic CPU emission/absorption volume integration','steps':STEPS,'recipe_sha256':RECIPE_SHA256,'original_procedural_material':True,'cost':'local unlimited-free NumPy/Pillow','loop_seconds':4.8,'source_box':[594,-340,300]},indent=2))
