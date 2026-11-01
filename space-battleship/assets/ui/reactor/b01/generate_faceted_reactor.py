"""Deterministic faceted reactor parts with one source-coordinate port contract.
--export-glb writes the editable runtime model and installation metadata.
Optional author renders stay under /tmp and never bake native UI text.
"""
import bpy,json,math,os,sys,hashlib
from pathlib import Path
from mathutils import Vector
from bpy_extras.object_utils import world_to_camera_view
ROOT=Path(__file__).resolve().parent
GENERATOR_BYTES=Path(__file__).read_bytes()
GENERATOR_SHA=hashlib.sha256(GENERATOR_BYTES).hexdigest()
DATA=json.loads((ROOT/'reactor_ports.json').read_text());W,H=DATA['source_size']
OUT=Path(os.environ.get('REACTOR_FACETED_BUILD','/tmp/reactor-faceted-build'));OUT.mkdir(parents=True,exist_ok=True)
(OUT/('generator-'+GENERATOR_SHA+'.py')).write_bytes(GENERATOR_BYTES)
def material(name,color,glow=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;n=m.node_tree.nodes;n.clear();o=n.new('ShaderNodeOutputMaterial')
 if glow:
  b=n.new('ShaderNodeEmission');b.inputs['Color'].default_value=(*color,1);b.inputs['Strength'].default_value=1.25
 else:
  diffuse=n.new('ShaderNodeBsdfDiffuse');diffuse.inputs['Color'].default_value=(1,1,1,1)
  rgb=n.new('ShaderNodeShaderToRGB');ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='CONSTANT'
  ramp.color_ramp.elements[0].position=.12;ramp.color_ramp.elements[0].color=tuple(c*.25 for c in color)+(1,)
  ramp.color_ramp.elements[1].position=.55;ramp.color_ramp.elements[1].color=(*color,1)
  mid=ramp.color_ramp.elements.new(.25);mid.color=tuple(c*.58 for c in color)+(1,)
  b=n.new('ShaderNodeEmission');m.node_tree.links.new(diffuse.outputs[0],rgb.inputs[0]);m.node_tree.links.new(rgb.outputs[0],ramp.inputs[0]);m.node_tree.links.new(ramp.outputs[0],b.inputs['Color'])
 m.node_tree.links.new(b.outputs[0],o.inputs['Surface']);return m

def mesh(name,vertices,faces,mat):
 d=bpy.data.meshes.new(name);d.from_pydata(vertices,[],faces);d.update();d.materials.append(mat)
 o=bpy.data.objects.new(name,d);bpy.context.collection.objects.link(o);return o

SIDES={}
def plate(name,outline,z,depth,mat,shift=(7,6)):
 k=len(outline);v=[(x,-y,z) for x,y in outline]+[(x+shift[0],-y-shift[1],z-depth) for x,y in outline]
 f=[tuple(range(k-1,-1,-1)),tuple(range(k,2*k))]+[(i,(i+1)%k,(i+1)%k+k,i+k) for i in range(k)]
 o=mesh(name,v,f,mat)
 if mat.name not in SIDES: SIDES[mat.name]=material(mat.name+' side',tuple(c*.74 for c in mat.diffuse_color[:3]),False)
 o.data.materials.append(SIDES[mat.name])
 for face in o.data.polygons:
  if face.index>0:face.material_index=1
 b=o.modifiers.new('armor arris','BEVEL');b.width=2.4;b.segments=1;o.modifiers.new('face normals','WEIGHTED_NORMAL');return o

def armor_panel(name,outline,z,depth,mat):
 center=Vector((sum(p[0] for p in outline)/len(outline),sum(p[1] for p in outline)/len(outline)))
 inset=[]
 for p in outline:
  delta=center-Vector(p);inset.append(Vector(p)+delta.normalized()*min(7,delta.length*.16))
 n=len(outline)
 vertices=[(x,-y,z-5) for x,y in outline]+[(p.x,-p.y,z+3) for p in inset]
 vertices.append((center.x,-center.y,z+18))
 vertices.extend([(x+4,-y-3,z-depth) for x,y in outline])
 faces=[]
 for i in range(n):
  j=(i+1)%n
  faces.extend([(i,j,n+j,n+i),(n+i,n+j,2*n),(i,2*n+1+i,2*n+1+j,j)])
 faces.append(tuple(range(3*n,2*n,-1)))
 faces=[tuple(reversed(face)) for face in faces]
 o=mesh(name,vertices,faces,mat)
 # Separate front-plane normals retain broad facets instead of a flat lid.
 b=o.modifiers.new('formed armor edge','BEVEL');b.width=1.2;b.segments=1
 o.modifiers.new('formed armor normals','WEIGHTED_NORMAL')
 return o

def armor_box(name,x,y,w,h,z,depth,mat):
 c=min(10,w*.16,h*.16)
 return armor_panel(name,[(x-w/2+c,y-h/2),(x+w/2-c,y-h/2),(x+w/2,y-h/2+c),(x+w/2,y+h/2-c),(x+w/2-c,y+h/2),(x-w/2+c,y+h/2),(x-w/2,y+h/2-c),(x-w/2,y-h/2+c)],z,depth,mat)

def box(name,x,y,w,h,z,depth,mat):
 c=min(12,w*.18,h*.18)
 return plate(name,[(x-w/2+c,y-h/2),(x+w/2-c,y-h/2),(x+w/2,y-h/2+c),(x+w/2,y+h/2-c),(x+w/2-c,y+h/2),(x-w/2+c,y+h/2),(x-w/2,y+h/2-c),(x-w/2,y-h/2+c)],z,depth,mat)

def disc(name,x,y,r,z,mat,sides=16):
 return plate(name,[(x+r*math.cos(math.tau*i/sides),y+r*math.sin(math.tau*i/sides)) for i in range(sides)],z,8,mat,shift=(3,3))

def ring(name,x,y,r,width,z,depth,mat,start=0,end=math.tau,segments=16):
 outer=[(x+r*math.cos(start+(end-start)*i/segments),y+r*math.sin(start+(end-start)*i/segments)) for i in range(segments+1)]
 inner=[(x+(r-width)*math.cos(start+(end-start)*i/segments),y+(r-width)*math.sin(start+(end-start)*i/segments)) for i in range(segments+1)]
 return plate(name,outer+inner[::-1],z,depth,mat,shift=(4,4))

def rod(name,a,b,r,mat):
 a=Vector((a[0],-a[1],a[2]));b=Vector((b[0],-b[1],b[2]));d=b-a
 bpy.ops.mesh.primitive_cylinder_add(vertices=12,radius=r,depth=d.length,location=(a+b)/2)
 o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(mat);return o

def socket_surface(p,axis,rise,z,along,radius,angle):
 normal=Vector((-axis.y,axis.x));height=radius*math.sin(angle)/math.sqrt(1+rise*rise)
 q=p+axis*along+normal*radius*math.cos(angle)-axis*(rise*height)
 return Vector((q.x,-q.y,z+along*rise+height))

def hollow_socket(name,p,axis,rise,z,near,far,r,m,inspection=False):
 axis=Vector(axis).normalized();n=16
 along=[near,-3,38,far] if inspection else [near,far]
 vertices=[]
 for at in along:
  for rr in (r+6,r):
   for i in range(n):vertices.append(socket_surface(p,axis,rise,z,at,rr,math.tau*i/n))
 faces=[];roles=[]
 for band in range(len(along)-1):
  a=band*2*n;b=(band+1)*2*n
  for i in range(n):
   j=(i+1)%n
   if inspection and band==1 and 2<=i<6:continue
   faces.extend([(a+i,a+j,b+j,b+i),(a+n+j,a+n+i,b+n+i,b+n+j)]);roles.extend([0,1])
 # Axial front/back rings and the four return walls around the actual window.
 for end in [0,len(along)-1]:
  a=end*2*n
  for i in range(n):
   j=(i+1)%n;faces.append((a+i,a+n+i,a+n+j,a+j));roles.append(2 if end==0 else 0)
 if inspection:
  for band in [1,2]:
   a=band*2*n
   for i in range(2,6):
    j=i+1;faces.append((a+i,a+j,a+n+j,a+n+i));roles.append(0)
  for i in [2,6]:
   a=2*n;b=4*n;faces.append((a+i,a+n+i,b+n+i,b+i));roles.append(0)
 o=mesh(name,vertices,faces,m['edge']);o.data.materials.append(m['dark']);o.data.materials.append(m['copper'])
 for face,role in zip(o.data.polygons,roles):face.material_index=role
 return o

def receiver_window(id,p,axis,r,m):
 axis=Vector(axis).normalized()
 for name,radius,mat in [(' window seat',r+2.7,m['glass']),(' acknowledgement',r+4.0,m['cyan'])]:
  vertices=[];longitudinal=6;radial=8
  for j in range(longitudinal+1):
   along=-1+37*j/longitudinal
   for k in range(radial+1):
    angle=math.pi*.25+.08+(math.pi*.50-.16)*k/radial
    vertices.append(socket_surface(p,axis,.35,28,along,radius,angle))
  faces=[]
  for j in range(longitudinal):
   for k in range(radial):
    a=j*(radial+1)+k;face=(a,a+1,a+radial+2,a+radial+1)
    if (vertices[face[1]]-vertices[face[0]]).cross(vertices[face[2]]-vertices[face[0]]).z<0:face=face[::-1]
    faces.append(face)
  o=mesh(id+' receiver'+name,vertices,faces,mat)
  uv=o.data.uv_layers.new(name='receiver_axial_fill')
  for face in o.data.polygons:
   for loop in face.loop_indices:
    i=o.data.loops[loop].vertex_index;uv.data[loop].uv=(i//(radial+1)/longitudinal,i%(radial+1)/radial)

def socket(id,m):
 d=DATA['devices'][id];p=Vector(d['device_port']);axis=Vector(d['axis_to_device']).normalized()
 far=55 if id=='condensation' else 60
 hollow_socket(id+' hollow receiver',p,axis,.35,28,-15,far,d['socket_radius'],m,inspection=True)
 # The socket terminates in a closed receiver body embedded in the machine,
 # not a second open tube end facing the working chamber.
 a=p+axis*(far-4);b=p+axis*(far+18)
 rod(id+' receiver foundation',(a.x,a.y,28+(far-4)*.35),(b.x,b.y,28+(far+18)*.35),d['socket_radius']+8,m['shade'])
 receiver_window(id,p,axis,d['socket_radius'],m)


def opening(name,x,y,w,h,front,back,m):
 # A real tapered cavity: lip, return walls and rear opening share vertices.
 rings=[]
 for ww,hh,z in [(w,h,front-4),(w-8,h-8,front),(w-20,h-20,front-4),(w-30,h-30,back)]:
  rings.extend([(x-ww/2,-y+hh/2,z),(x+ww/2,-y+hh/2,z),(x+ww/2,-y-hh/2,z),(x-ww/2,-y-hh/2,z)])
 faces=[]
 for ring_index in range(3):
  for i in range(4):
   j=(i+1)%4;faces.append((ring_index*4+i,(ring_index+1)*4+i,(ring_index+1)*4+j,ring_index*4+j))
 o=mesh(name,rings,faces,m['shade']);o.data.materials.append(m['glass']);o.data.materials.append(m['armor'])
 for f in o.data.polygons:f.material_index=1 if f.index>=8 else 2 if f.index<4 else 0
 return o

def armor_arc(name,x,y,r,width,z,depth,m,start,end):
 profile=[(r,z-depth),(r,z-5),(r-5,z+3),(r-width+5,z+3),(r-width,z-5),(r-width-5,z-depth)]
 n=5;vertices=[]
 for i in range(n+1):
  a=start+(end-start)*i/n
  for radius,zz in profile:vertices.append((x+radius*math.cos(a),-(y+radius*math.sin(a)),zz))
 faces=[]
 for i in range(n):
  for j in range(len(profile)-1):
   a=i*6+j;faces.append((a,a+1,a+7,a+6))
 faces.extend([tuple(range(5,-1,-1)),tuple(n*6+i for i in range(6))])
 o=mesh(name,vertices,faces,m['armor']);o.data.materials.append(m['shade']);o.data.materials.append(m['glass'])
 for f in o.data.polygons:
  band=f.index%5;f.material_index=2 if band==4 else 1 if band in (0,3) else 0
 return o

def mount(name,x,y,w,m):
 box(name+' load foot',x,y,w,18,5,10,m['edge']);box(name+' seat',x,y-6,w-18,9,18,5,m['shade'])
 if y<400:
  for side in (-1,1):
   q=x+side*(w*.32)
   plate(name+' wall gusset',[(q-12,y+2),(q+12,y+2),(q+8,y+28),(q-8,y+38)],-8,9,m['shade'],shift=(2,2))

def weapon(m,phase=.65):
 mount('weapon',180,313,222,m);box('weapon navy shell',183,204,184,202,40,35,m['dark'])
 armor_panel('weapon left armor',[(81,126),(111,102),(142,109),(136,164),(124,184),(128,264),(103,278),(78,258)],65,25,m['armor'])
 armor_panel('weapon right armor',[(225,107),(255,112),(278,138),(274,258),(249,278),(225,259)],65,25,m['shade'])
 armor_box('weapon top bridge',180,112,108,27,76,16,m['armor']);armor_box('weapon bottom bridge',180,278,113,26,76,16,m['shade'])
 box('weapon chamber',181,195,74,133,38,8,m['glass'])
 opening('weapon aperture return',181,195,104,165,92,40,m)
 rod('weapon chamber glazing',(181,128,48),(181,262,48),37,m['field'])
 for i,y in enumerate((153,190,227)):
  charge=max(0.,min(1.,(phase/.65)*3-i))
  if charge>0.:rod('weapon charge segment '+str(i),(181,y+11-22*charge,60),(181,y+11,60),29,m['charge'])
  box('weapon retainer '+str(i),181,y+12,76,8,100,8,m['edge'])
 box('weapon ship bus bed',63,196,74,25,88,8,m['dark'])
 for y in (182,210):box('weapon ship bus rail',63,y,78,6,112,10,m['edge'])
 box('weapon ship bus wall cap',28,196,14,38,122,12,m['dark'])
 box('weapon focusing exit',117,196,59,35,85,18,m['dark'])
 if phase>=.65 and phase<.85:
  pulse=math.sin((phase-.65)/.20*math.pi)
  box('weapon output',99,196,15,23,97,6,m['charge'])
  plate('weapon output pulse',[(90,190),(90,202),(62-38*pulse,196)],102,2,m['charge'],shift=(0,0))
 socket('weapons',m)

def defence(m,phase=1.):
 mount('shield',1017,300,220,m);box('shield shell',968,199,102,150,42,28,m['dark'])
 ring('shield load ring',1045,177,84,20,44,26,m['dark']);disc('shield glass',1045,177,63,47,m['glass'])
 for i in range(6):
  a=math.tau*i/6;armor_arc('shield armor '+str(i),1045,177,91,23,78,28,m,a+.08,a+.94)
  disc('shield joint '+str(i),1045+74*math.cos(a),177+74*math.sin(a),6,91,m['copper'],6)
 ring('shield active rim',1045,177,61,7,69,6,m['cyan']);disc('shield projector',1045,177,19,91,m['edge'],8)
 # A real bowed surface, divided into broad facets, projects beyond the
 # ring. Its source-space boundary is shared with the work/occlusion export.
 verts=[];rows,cols=24,5
 for j in range(rows+1):
  angle=math.tau*j/rows
  for k in range(cols+1):
   t=k/cols;radius=20+106*t*max(.03,min(1.,phase))
   verts.append((1045+radius*math.cos(angle),-(177+radius*math.sin(angle)),70+62*math.sqrt(max(.0,1-(radius/140)**2))))
 faces=[]
 for j in range(rows):
  for k in range(cols):
   a=j*(cols+1)+k;faces.append((a,a+1,a+cols+2,a+cols+1))
 mesh('shield bowed field',verts,faces,m['field'])
 socket('defence',m)

def furnace(m):
 mount('furnace',198,678,260,m);box('furnace deep shell',173,478,192,162,35,33,m['dark'])
 armor_panel('furnace left armor',[(77,421),(105,389),(145,397),(139,436),(120,453),(123,526),(99,548),(75,525)],64,23,m['armor'])
 armor_panel('furnace right armor',[(215,397),(245,405),(275,435),(268,528),(244,547),(221,523),(222,450),(205,431)],64,23,m['shade'])
 armor_box('furnace crown',177,405,112,28,75,16,m['armor']);box('furnace cavity',175,476,103,83,30,6,m['glass'])
 opening('furnace refractory return',175,477,128,112,81,34,m)
 plate('furnace throat',[(132,483),(220,483),(216,507),(177,520),(136,507)],49,5,m['orange'],shift=(0,0))
 for i in range(3):
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=11,location=(160+i*15,-442,67))
  o=bpy.context.object;o.name='furnace feed '+str(i);o.data.materials.append(m['copper'])
 box('furnace dark lip',175,522,102,20,77,18,m['dark']);box('furnace tap',175,519,54,15,87,8,m['copper'])
 disc('furnace vessel',176,597,86,34,m['dark'],12);disc('furnace liquid',176,594,67,48,m['orange'],12)
 ring('furnace vessel bank',176,597,87,17,58,23,m['shade'],.50,math.tau-.10,12)
 rod('furnace pour',(175,520,90),(175,582,58),10,m['orange'])
 plate('furnace outlet bed',[(226,604),(244,601),(309,662),(293,674)],27,11,m['dark'])
 plate('furnace outlet liquid',[(233,608),(240,607),(300,664),(295,669)],39,3,m['orange'])
 for obj in bpy.context.scene.objects:
  if obj.name.startswith(('furnace vessel','furnace liquid')) and obj.type=='MESH':
   for vertex in obj.data.vertices:vertex.co.y=-597+(vertex.co.y+597)*.48
 for x in (114,233):box('furnace basin support',x,647,24,63,9,26,m['dark'])
 socket('smelting',m)

def crystal(m,growth=1.):
 mount('crystal',1014,683,244,m);box('crystal base',1013,624,202,72,41,27,m['dark']);box('crystal back',1020,514,153,166,28,22,m['glass'])
 for x in (934,1100):
  armor_box('crystal pillar',x,557,30,195,66,27,m['armor'] if x<1000 else m['shade']);box('crystal foot',x,661,53,28,75,17,m['dark'])
 armor_box('crystal crown',1017,433,184,32,78,21,m['armor']);box('crystal seed bed',1017,603,143,29,65,14,m['copper'])
 box('crystal chamber front sill',1017,635,151,15,91,16,m['shade'])
 for i,(x,h) in enumerate([(974,53),(997,88),(1022,114),(1047,79),(1071,48)]):
  hh=12+(h-12)*growth;y=592
  plate('crystal body '+str(i),[(x-13,y),(x+13,y),(x+15,y-hh+17),(x+2,y-hh),(x-14,y-hh+16)],77,18,m['violet'],shift=(7,4))
  plate('crystal bright facet '+str(i),[(x+2,y-hh),(x+15,y-hh+17),(x+13,y),(x+2,y-4)],79,1,m['violet_light'],shift=(0,0))
 socket('condensation',m)

def core(m):
 x,y=594,340
 disc('core seat',x,y,181,14,m['dark'],24)
 ring('core copper restraint',x,y,174,11,32,18,m['copper'],segments=24)
 # Open containment volume: dark rear cavity, an internal three-dimensional
 # plasma mass and sparse field paths. There is no opaque facing-gradient disc.
 disc('core rear cavity',x,y,144,24,m['glass'],24)
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=145,location=(x,-y,70))
 globe=bpy.context.object;globe.name='core containment glass';globe.scale.z=.82;globe.data.materials.append(m['field'])
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=3,radius=108,location=(x,-y,70))
 plasma=bpy.context.object;plasma.name='core plasma mass';plasma.scale=(.92,1.10,.94);plasma.rotation_euler=(.17,.31,.20)
 plasma.data.materials.append(m['cyan'])
 for polygon in plasma.data.polygons:polygon.use_smooth=True
 bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=28,location=(x,-y,100))
 kernel=bpy.context.object;kernel.name='core plasma kernel';kernel.data.materials.append(m['cyan'])
 for vertex in kernel.data.vertices:
  q=vertex.co;vertex.co*=1.0+.12*math.sin(q.x*.13)*math.sin(q.y*.11)*math.sin(q.z*.17)
 for polygon in kernel.data.polygons:polygon.use_smooth=True
 # Each path winds from a pole toward the active mass. These are energy
 # strands, never moving mechanical bars; their real depth passes behind it.
 for j,(id,d) in enumerate(DATA['devices'].items()):
  target=Vector((d['core_port'][0]-x,d['core_port'][1]-y));angle=math.atan2(target.y,target.x)
  points=[]
  for i in range(25):
   t=i/24;a=angle+.32*t;r=118*(1-t)
   points.append(Vector((x+r*math.cos(a),-(y+r*math.sin(a)),85+25*math.sin(a))))
  vertices=[];sides=6
  for i,p in enumerate(points):
   tangent=(points[min(i+1,24)]-points[max(0,i-1)]).normalized();u=tangent.cross(Vector((0,0,1))).normalized();v=tangent.cross(u).normalized()
   for k in range(sides):vertices.append(p+(2.0+9.0*math.sin(math.pi*i/24)**.7)*(u*math.cos(math.tau*k/sides)+v*math.sin(math.tau*k/sides)))
  faces=[]
  for i in range(24):
   for k in range(sides):
    a=i*sides+k;b=i*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides))
  mesh('core plasma strand '+str(j),vertices,faces,m['cyan'])
  bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=10,location=(x,-y,100))
  o=bpy.context.object;o.name='core transfer packet '+id;o.data.materials.append(m['cyan'])
 for yy in (-139,139):
  box('core pole shoe',x,y+yy,48,22,114,28,m['dark'])
  box('core pole contact',x,y+yy,26,9,135,8,m['copper'])
 ring('core glass rim',x,y,148,5,49,6,m['edge'],segments=24)
 for i,a in enumerate((0,math.pi/2,math.pi,math.pi*1.5)):
  ring('core armor '+str(i),x,y,191,35,68,38,m['armor'] if i<2 else m['shade'],a+.16,a+1.39,4)
  aa=a+.77
  box('core armor lock '+str(i),x+171*math.cos(aa),y+171*math.sin(aa),20,17,105,10,m['dark'])

def pipes(m):
 for id,d in DATA['devices'].items():
  curve=bpy.data.curves.new(id+' conduit','CURVE');curve.dimensions='3D';curve.resolution_u=24;sp=curve.splines.new('BEZIER');sp.bezier_points.add(3)
  axis=Vector(d['axis_to_device']).normalized();end=Vector(d['device_port'])+axis*(d['insert_depth']-15)
  for i,(b,q) in enumerate(zip(sp.bezier_points,[d['core_port'],*d['controls'],end])):
   b.co=(q[0],-q[1],(28,16,10,28)[i]);b.handle_left_type='AUTO';b.handle_right_type='AUTO'
  # Preserve the exact socket axis at the inserted end, including its rise.
  end_z=28+(d['insert_depth']-15)*.35
  last=sp.bezier_points[-1];last.co.z=end_z;last.handle_left_type='FREE';last.handle_right_type='FREE'
  tangent=Vector((axis.x,-axis.y,.35))*40
  last.handle_left=last.co-tangent;last.handle_right=last.co+tangent
  curve.bevel_depth=18;curve.bevel_resolution=1;o=bpy.data.objects.new(id+' conduit',curve);bpy.context.collection.objects.link(o);o.data.materials.append(m['edge'])

def room(m):
 # Continuous hull planes, not a grid of shelving around four exhibits.
 plate('rear blue room',[(-80,0),(W+80,0),(W+80,H),(-80,H)],-90,8,m['room'],shift=(0,0))
 plate('port hull shoulder',[(-80,0),(145,0),(102,118),(70,528),(-80,626)],-76,6,m['window'],shift=(0,0))
 plate('starboard hull shoulder',[(1040,0),(W+80,0),(W+80,626),(1110,528),(1080,118)],-76,6,m['window'],shift=(0,0))
 plate('upper hull sweep',[(145,0),(1040,0),(1080,76),(1008,65),(188,65),(102,118)],-79,5,m['shade'],shift=(0,0))
 plate('upper hull inner',[(188,27),(1008,27),(1030,45),(174,45)],-70,3,m['edge'],shift=(0,0))
 # A shallow central recess gives the reactor a ship-installed setting while
 # the flanking hull stays quiet behind the device silhouettes.
 plate('room floor',[(-80,600),(W+80,600),(W+80,H),(-80,H)],-60,9,m['floor'],shift=(0,0))
 for x in (185,1010):box('room overhead light',x,47,58,6,-55,3,m['lamp'])

def core_mount(m):
 plate('core rear recess',[(430,86),(758,86),(842,324),(759,588),(430,588),(350,324)],-82,3,m['window'],shift=(0,0))
 plate('central floor facing',[(438,720),(750,720),(882,914),(306,914)],-56,3,m['floor'],shift=(0,0))
 plate('central service deck',[(390,600),(790,600),(862,688),(790,739),(390,739),(320,688)],-25,8,m['edge'],shift=(3,3))
 plate('central deck inset',[(405,610),(777,610),(841,685),(777,726),(405,726),(343,685)],-10,4,m['floor'],shift=(0,0))
 box('core lower pedestal',594,591,100,122,18,18,m['dark'])
 armor_panel('pedestal left armor',[(539,535),(555,535),(558,640),(539,651),(526,641)],39,12,m['shade'])
 armor_panel('pedestal right armor',[(632,535),(648,535),(663,641),(650,651),(630,640)],39,12,m['shade'])

def console_layout(count):
 row_h=72;offset=(4-count)*row_h-{1:120,2:72,3:36,4:0}[count];top=730+offset;header_y=819+offset;rows_top=878+offset
 footer_y=rows_top+count*row_h+64;bottom=footer_y+78
 return {'count':count,'top':top,'header_y':header_y,'rows_top':rows_top,'footer_y':footer_y,
  'header_rect':[76,header_y-48,1036,96],
  'row_rects':[[76,rows_top+i*row_h+8,1036,row_h-16] for i in range(count)],
  'transaction_rect':[76,footer_y-48,1036,96],'visible_bottom':bottom}

def console(m,count=4):
 # Every legal display count gets a complete fitted control deck. No empty
 # baked four-row grooves remain behind one or two native allocation rows.
 row_h=72;offset=(4-count)*row_h-{1:120,2:72,3:36,4:0}[count];top=730+offset;header_y=819+offset;rows_top=878+offset
 footer_y=rows_top+count*row_h+64;bottom=footer_y+78
 plate('console unified chassis',[(44,top+12),(1143,top+12),(1164,top+33),(1164,bottom-46),(1137,bottom-12),(52,bottom-12),(24,bottom-46),(24,top+33)],12,16,m['edge'])
 plate('console dark face',[(53,top+23),(1134,top+23),(1154,top+43),(1154,bottom-54),(1124,bottom-23),(64,bottom-23),(34,bottom-54),(34,top+43)],35,10,m['dark'])
 for y,h in ((header_y,96),(rows_top+count*row_h/2,count*row_h-4),(footer_y,96)):
  box('console grouped working glass',594,y,1068,h,48,4,m['glass'])
 for i in range(1,count):box('allocation row separator',594,rows_top+i*row_h,1020,2,54,1,m['edge'])
 for side in (-1,1):
  x=594+side*548
  plate('console corner armor',[(x-5,top+39),(x+5,top+39),(x+5,top+75),(x-5,top+83)],57,6,m['shade'],shift=(2,2))
 return console_layout(count)

# Explicit semantic pass ownership. Front parts are real geometry, not a
# rectangle painted over a failed joint. Names are emitted by this generator.
WORK_NAMES={
 'weapons': ['weapon chamber glazing','weapon charge segment','weapon output'],
 'defence': ['shield active rim','shield bowed field'],
 'smelting': ['furnace feed','furnace throat','furnace liquid','furnace pour','furnace outlet liquid'],
 'condensation': ['crystal body','crystal bright facet'],
 'core': ['core containment glass','core plasma kernel','core plasma mass','core plasma strand','core transfer packet']}
for id in DATA['devices']:WORK_NAMES[id].append(id+' receiver acknowledgement')
FRONT_NAMES={
 'weapons':['weapon retainer','weapon focusing exit','weapon top bridge','weapon bottom bridge'],
 'defence':['shield armor','shield joint','shield projector'],
 'smelting':['furnace dark lip','furnace tap','furnace vessel bank'],
 'condensation':['crystal pillar','crystal crown','crystal seed bed'],
 'core':['core armor']}

def select_pass(name,layer):
 for o in bpy.context.scene.objects:
  if o.type in ('LIGHT','CAMERA'):continue
  work=any(o.name.startswith(v) for v in WORK_NAMES.get(name,[]))
  front=any(o.name.startswith(v) for v in FRONT_NAMES.get(name,[]))
  o.hide_render=not({'work':work,'front':front,'base':not work and not front}.get(layer,True))


def setup():
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 colors={'armor':(.72,.77,.73),'shade':(.30,.42,.49),'dark':(.035,.085,.13),'edge':(.16,.28,.35),'glass':(.015,.055,.095),'copper':(.55,.33,.12),'charge':(.95,.62,.13),'cyan':(.04,.64,.83),'orange':(.94,.31,.025),'violet':(.32,.09,.58),'violet_light':(.65,.31,.94),'field':(.035,.30,.47),'room':(.045,.10,.16),'window':(.055,.12,.18),'floor':(.09,.14,.20),'lamp':(1.,.76,.39)}
 m={k:material(k,c,k in ['charge','cyan','orange','violet_light','lamp']) for k,c in colors.items()}
 s=bpy.context.scene;s.render.engine='BLENDER_EEVEE_NEXT';s.render.resolution_x=W;s.render.resolution_y=H;s.render.resolution_percentage=100;s.render.film_transparent=True;s.world.color=(.16,.22,.30);s.view_settings.view_transform='Standard'
 for name,loc,color,power,size in [('warm key',(250,-100,600),(1,.82,.60),1800000,650),('cool fill',(1020,-500,380),(.35,.65,1),950000,700)]:
  l=bpy.data.lights.new(name,'AREA');l.energy=power;l.shape='DISK';l.size=size;l.color=color;o=bpy.data.objects.new(name,l);bpy.context.collection.objects.link(o);o.location=loc
 c=bpy.data.cameras.new('source pixel camera');o=bpy.data.objects.new('source pixel camera',c);bpy.context.collection.objects.link(o);o.location=(W/2,-H/2,1500);c.type='ORTHO';c.ortho_scale=H;c.clip_end=4000;s.camera=o
 s.render.use_freestyle=True;s.render.line_thickness=1.3
 ls=bpy.context.view_layer.freestyle_settings.linesets[0];ls.select_silhouette=True;ls.select_crease=False;ls.linestyle.color=(.012,.025,.04);ls.linestyle.thickness=1.3
 return m

def route_samples(d,steps=40):
 from mathutils.geometry import interpolate_bezier
 p0=Vector((*d['core_port'],28));p1=Vector((*d['controls'][0],16));p2=Vector((*d['controls'][1],10))
 axis=Vector(d['axis_to_device']).normalized();end=Vector(d['device_port'])+axis*(d['insert_depth']-15)
 p3=Vector((end.x,end.y,28+(d['insert_depth']-15)*.35))
 # Cubic has a prescribed endpoint tangent, identical to the receiver.
 h=p3-Vector((axis.x,axis.y,.35))*55
 return interpolate_bezier(p0,p1,h,p3,steps)

def route_distances(d):
 pts=route_samples(d);distances=[0.0]
 for a,b in zip(pts,pts[1:]):distances.append(distances[-1]+(b-a).length)
 return pts,[v/distances[-1] for v in distances]

def receiver_u(d):
 pts,distances=route_distances(d);axis=Vector(d['axis_to_device']).normalized();p=Vector(d['device_port'])-axis*3
 target=Vector((p.x,p.y,28-3*.35))
 return distances[min(range(len(pts)),key=lambda i:(pts[i]-target).length_squared)]

def channel_pipe(id,m):
 d=DATA['devices'][id];pts,distances=route_distances(d);normals=[]
 delta=Vector(d['controls'][0])-Vector(d['core_port']);core_axis=delta.normalized();rise=-12.0/delta.length
 hollow_socket(id+' core outlet',Vector(d['core_port']),core_axis,rise,28,-20,26,24,m)
 verticals=[]
 for i,p in enumerate(pts):
  tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
  if i==0:
   delta=Vector((*d['controls'][0],16))-Vector((*d['core_port'],28));tangent=delta.normalized()
  elif i==len(pts)-1:
   axis=Vector(d['axis_to_device']).normalized();tangent=Vector((axis.x,axis.y,.35)).normalized()
  normals.append(Vector((-tangent.y,tangent.x,0)).normalized())
  denominator=tangent.x*tangent.x+tangent.y*tangent.y
  verticals.append(Vector((-tangent.x*tangent.z/denominator,-tangent.y*tangent.z/denominator,1)).normalized())
 # Open U-profile. A recessed working channel lies below the two lips;
 # the inlet collars and receiver therefore occlude it by actual depth.
 profile=[(-18,-12),(-18,12),(-10,17),(-8,6),(8,6),(10,17),(18,12),(18,-12)]
 vertices=[]
 for p,n,vertical in zip(pts,normals,verticals):
  for side,height in profile:
   q=p+n*side+vertical*height;vertices.append((q.x,-q.y,q.z))
 faces=[]
 for i in range(len(pts)-1):
  for j in range(len(profile)):
   a=i*8+j;b=i*8+(j+1)%8;faces.append((a,b,b+8,a+8))
 shell=mesh(id+' channel shell',vertices,faces,m['edge'])
 v=[]
 for p,n,vertical in zip(pts,normals,verticals):
  for side in (-7,7):
   q=p+n*side+vertical*7;v.append((q.x,-q.y,q.z))
 work=mesh(id+' channel work',v,[(i*2,i*2+1,i*2+3,i*2+2) for i in range(len(pts)-1)],m['cyan'])
 uv=work.data.uv_layers.new(name='route_distance')
 for polygon in work.data.polygons:
  for loop in polygon.loop_indices:
   idx=work.data.loops[loop].vertex_index;uv.data[loop].uv=(distances[idx//2],idx%2)
 for idx in (1,len(pts)-3):
  p=pts[idx]+verticals[idx]*18;n=normals[idx]
  rod(id+' channel collar', (p.x+n.x*21,p.y+n.y*21,p.z),(p.x-n.x*21,p.y-n.y*21,p.z),5,m['dark'])
 return shell,work

def export_glb():
 m=setup();groups={}
 def group(name,fn):
  before=set(bpy.data.objects);fn();objects=set(bpy.data.objects)-before
  root=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(root)
  for o in objects:o.parent=root
  groups[name]=root
 group('bay',lambda:room(m));group('core_mount',lambda:core_mount(m));group('core',lambda:core(m))
 for id,fn in [('weapons',lambda:weapon(m,.72)),('defence',lambda:defence(m,1.)),('smelting',lambda:furnace(m)),('condensation',lambda:crystal(m,1.))]:
  group(id,fn);group('pipe_'+id,lambda id=id:channel_pipe(id,m))
 # The single-smelter composition is an authored transform of the same
 # independent parts. Its conduit is generated from those exact transformed
 # ports, not stretched between visually guessed screen points.
 original=DATA['devices']['smelting'];single=dict(original)
 single['core_port']=[original['core_port'][0]+130,original['core_port'][1]]
 single['device_port']=[original['device_port'][0]+200,original['device_port'][1]-50]
 single['controls']=[[565,453],[535,472]]
 DATA['devices']['smelting']=single
 group('pipe_single_smelting',lambda:channel_pipe('smelting',m))
 DATA['devices']['smelting']=original
 for count in (1,2,3,4):group('console_'+str(count),lambda count=count:console(m,count))
 def merge(objects,name):
  if not objects:return
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join();objects[0].name=name
 # Consolidate fixed geometry by part. Runtime keeps only genuinely moving
 # working mechanisms separate; tiny bolts/strands do not become draw nodes.
 merge([o for o in groups['core'].children if o.name.startswith('core plasma strand')],'core plasma strands')
 for i in range(5):merge([o for o in groups['condensation'].children if o.name in ('crystal body '+str(i),'crystal bright facet '+str(i))],'crystal body '+str(i))
 for name,root in groups.items():
  prefixes=WORK_NAMES.get(name,[])
  fixed=[o for o in root.children if o.type=='MESH' and not any(o.name.startswith(v) for v in prefixes) and 'channel work' not in o.name]
  merge(fixed,name+' structure')
 for id,d in DATA['devices'].items():
  p=Vector(d['device_port']);axis=Vector(d['axis_to_device']).normalized()
  inlet=bpy.data.objects.new('power_in_'+id,None);bpy.context.collection.objects.link(inlet);inlet.parent=groups[id]
  inlet.location=(p.x,-p.y,28);inlet.rotation_euler=Vector((axis.x,-axis.y,.35)).to_track_quat('Z','Y').to_euler();inlet['bore_radius']=d['socket_radius']
  delta=Vector(d['controls'][0])-Vector(d['core_port'])
  outlet=bpy.data.objects.new('power_out_'+id,None);bpy.context.collection.objects.link(outlet);outlet.parent=groups['core']
  outlet.location=(d['core_port'][0],-d['core_port'][1],28);outlet.rotation_euler=Vector((delta.x,-delta.y,-12)).to_track_quat('Z','Y').to_euler()
 delta=Vector(single['controls'][0])-Vector(single['core_port'])
 marker=bpy.data.objects.new('power_out_single_smelting',None);bpy.context.collection.objects.link(marker);marker.parent=groups['core']
 marker.location=(single['core_port'][0]-130,-single['core_port'][1],28)
 marker.rotation_euler=Vector((delta.x,-delta.y,-12)).to_track_quat('Z','Y').to_euler()
 # Export ordinary palette data, not Blender-only ShaderToRGB nodes. Godot
 # supplies the same faceted surface lighting plus distinct working shaders.
 for mat in bpy.data.materials:
  color=mat.diffuse_color[:];mat.use_nodes=True;nodes=mat.node_tree.nodes;nodes.clear()
  out=nodes.new('ShaderNodeOutputMaterial');bsdf=nodes.new('ShaderNodeBsdfPrincipled');bsdf.inputs['Base Color'].default_value=color;bsdf.inputs['Roughness'].default_value=.72
  mat.node_tree.links.new(bsdf.outputs['BSDF'],out.inputs['Surface'])
 for o in list(bpy.context.scene.objects):
  if o.type in ('LIGHT','CAMERA'):bpy.data.objects.remove(o,do_unlink=True)
 for o in list(bpy.context.scene.objects):
  if o.type=='CURVE':
   bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.convert(target='MESH')
  if o.type=='MESH':
   bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o;bpy.ops.object.origin_set(type='ORIGIN_GEOMETRY',center='BOUNDS')
 bpy.ops.object.select_all(action='SELECT')
 path=ROOT/'faceted-reactor.glb'
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',export_yup=False,export_apply=True,export_cameras=False,export_lights=False,export_extras=True)
 bpy.context.view_layer.update()
 parts={}
 for key,root in groups.items():
  points=[o.matrix_world@Vector(corner) for o in root.children if o.type=='MESH' for corner in o.bound_box]
  x0=min(q.x for q in points);y0=min(-q.y for q in points);x1=max(q.x for q in points);y1=max(-q.y for q in points)
  parts[key]={'node':key,'visible_rect_source':[x0,y0,x1-x0,y1-y0]}
 ports={}
 for id,d in DATA['devices'].items():
  p=Vector(d['device_port']);axis=Vector(d['axis_to_device']).normalized();mouth=p-axis*15;end=p+axis*(d['insert_depth']-15)
  ports[id]={'interface_center_source3d':[p.x,-p.y,28],'axis_to_device_source3d':list(Vector((axis.x,-axis.y,.35)).normalized()),
   'receiver_mouth_source3d':[mouth.x,-mouth.y,22.75],'pipe_end_source3d':[end.x,-end.y,28+(d['insert_depth']-15)*.35],
   'bore_radius':d['socket_radius'],'projected_insert_depth_px':d['insert_depth'],'axial_insert_depth_source_units':d['insert_depth']*math.sqrt(1+.35*.35)}
  delta=Vector(d['controls'][0])-Vector(d['core_port']);out=Vector((delta.x,-delta.y,-12.0)).normalized()
  ports[id]['core_interface_source3d']=[d['core_port'][0],-d['core_port'][1],28]
  ports[id]['core_axis_out_source3d']=list(out)
  ports[id]['device_marker']=id+'/power_in_'+id;ports[id]['core_marker']='core/power_out_'+id
  ports[id]['receiver_u']=receiver_u(d)
 layout={'source_size':[W,H],'content_size':[808,835],'scale':835/H,'offset':[(808-W*835/H)/2,0],
  'single_smelting':{'shifts':{'core':[130,0],'core_mount':[130,0],'smelting':[200,-50]},'route':single,'core_marker':'core/power_out_single_smelting','device_marker':'smelting/power_in_smelting','receiver_u':receiver_u(single)},'console':{str(i):console_layout(i) for i in (1,2,3,4)},'parts':parts,'ports':ports,'generator_sha256':GENERATOR_SHA,'asset_sha256':hashlib.sha256(path.read_bytes()).hexdigest()}
 (ROOT/'faceted-layout.json').write_text(json.dumps(layout,indent=2))
 print('EXPORTED_FACETED_GEOMETRY',path,layout['asset_sha256'])

def arg(key,default):
 return sys.argv[sys.argv.index(key)+1] if key in sys.argv else default

def run():
 name=arg('--only','assembly');layer=arg('--pass','composite');count=int(arg('--count','4'));growth=float(arg('--growth','1'));phase=float(arg('--phase','.72'))
 assert count in (1,2,3,4)
 m=setup();builders={'weapons':lambda m:weapon(m,phase),'defence':lambda m:defence(m,min(1.,phase*2)),'smelting':furnace,'condensation':lambda m:crystal(m,growth),'core':core,'room':room,'console':lambda m:console(m,count),'pipes':pipes}
 if name=='assembly':
  room(m);console(m,count);pipes(m);core(m)
  for id in ('weapons','defence','smelting','condensation'):builders[id](m)
 else:builders[name](m)
 bpy.context.view_layer.update()
 for id,d in DATA['devices'].items():
  p=d['device_port'];q=world_to_camera_view(bpy.context.scene,bpy.context.scene.camera,Vector((p[0],-p[1],28)))
  assert max(abs(q.x*W-p[0]),abs((1-q.y)*H-p[1]))<.02,(id,q)
 if '--validate-only' in sys.argv:
  print('SOURCE_PORT_PROJECTION_OK',list(DATA['devices']));return
 select_pass(name,layer)
 stem=name+('-'+layer if layer!='composite' else '')+('-'+str(count) if name=='console' else '')
 path=OUT/(stem+'.png');bpy.context.scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 scale=835/H
 (OUT/(stem+'.json')).write_text(json.dumps({'status':'study','canvas_px':[W,H],'layer':layer,'part':name,'growth':growth,'phase':phase,
  'uniform_transform':{'scale':scale,'offset':[(808-W*scale)/2,0],'content_size':[808,835]},
  'console_layout':console_layout(count) if name in ('console','assembly') else None,
  'image':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'source_generator_sha256':GENERATOR_SHA},indent=2))
 print('FACETED_PROTOTYPE',stem,'source_canvas',W,H)
if '--export-glb' in sys.argv:
 export_glb()
elif '--export-study' in sys.argv:
 for name,layer,count in [('weapons','base',4),('weapons','work',4),('weapons','front',4),('console','composite',1),('console','composite',4),('assembly','composite',4)]:
  sys.argv=['blender','--only',name,'--pass',layer,'--count',str(count)]
  run()
else:run()
