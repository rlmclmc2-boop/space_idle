"""Rounded orbital headquarters matching the selected cartoon 3D art direction."""
import math
import bpy
from mathutils import Vector


def build(root, h):
    palette={
        'CorePearl':((.86,.88,.83),0,.04,.64),
        'CorePanel':((.25,.38,.49),0,.08,.62),
        'CoreDark':((.055,.095,.15),0,.08,.62),
        'CoreMetal':((.12,.20,.28),0,.16,.58),
        'CoreGlass':((.025,.46,.57),.015,.08,.43),
        'CoreReflection':((.25,.67,.72),.04,.22,.20),
        'CoreLight':((1.0,.53,.13),.65,.05,.32),
        'CoreMark':((.68,.40,.10),0,.08,.48),
    }
    for name,(color,emission,metal,roughness) in palette.items():
        h.material(name,color,emission,metal)
        h.MATS[name].node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=roughness

    def surface(name,vertices,faces,mat,parent,smooth=True):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        h.finish(obj,name,mat,parent)
        for p in mesh.polygons:p.use_smooth=smooth
        return obj

    def rounded_box(name,xyz,dims,mat,parent,bevel=.18,angle=0):
        obj=h.box(name,xyz,dims,mat,parent,angle=angle,bevel=0)
        modifier=obj.modifiers.new('RoundedEdges','BEVEL');modifier.width=bevel;modifier.segments=5
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=modifier.name)
        for p in obj.data.polygons:p.use_smooth=True
        modifier=obj.modifiers.new('SoftWeightedNormals','WEIGHTED_NORMAL');modifier.keep_sharp=True;modifier.weight=50
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        return obj

    def lathe(name,profile,mat,parent,segments=96):
        vertices=[(r*math.cos(i*math.tau/segments),r*math.sin(i*math.tau/segments),z) for r,z in profile for i in range(segments)]
        faces=[]
        for row in range(len(profile)-1):
            for i in range(segments):
                j=(i+1)%segments;a=row*segments;b=(row+1)*segments
                faces.append((a+i,a+j,b+j,b+i))
        return surface(name,vertices,faces,mat,parent)

    def arc(name,radius,width,height,z,mat,parent,start=0,end=math.tau):
        # Smooth superellipse cross-section gives a thick rounded shell.
        count=max(24,round((end-start)*radius*2.1));cross=24
        vertices=[]
        for i in range(count+1):
            a=start+(end-start)*i/count
            for j in range(cross):
                t=j*math.tau/cross;c=math.cos(t);s=math.sin(t)
                rr=radius+width*.5*math.copysign(abs(c)**.48,c)
                zz=z+height*.5*math.copysign(abs(s)**.48,s)
                vertices.append((rr*math.cos(a),rr*math.sin(a),zz))
        faces=[]
        for i in range(count):
            for j in range(cross):
                k=(j+1)%cross;faces.append((i*cross+j,(i+1)*cross+j,(i+1)*cross+k,i*cross+k))
        if end-start<math.tau-.01:
            faces.extend([tuple(reversed(range(cross))),tuple(count*cross+j for j in range(cross))])
        return surface(name,vertices,faces,mat,parent)

    def bridge(parent,angle,z,height,width,mat):
        vertices=[];steps=20;cross=16
        forward=Vector((math.cos(angle),math.sin(angle),0));side=Vector((-math.sin(angle),math.cos(angle),0))
        for i in range(steps+1):
            t=i/steps
            center=forward*(3.0+5.7*t)+side*(.65*math.sin(math.pi*t))+Vector((0,0,z+.25*math.sin(math.pi*t)))
            for j in range(cross):
                a=j*math.tau/cross;c=math.cos(a);s=math.sin(a)
                vertices.append(center+side*(width*.5*math.copysign(abs(c)**.5,c))+Vector((0,0,height*.5*math.copysign(abs(s)**.5,s))))
        faces=[]
        for i in range(steps):
            for j in range(cross):
                k=(j+1)%cross;faces.append((i*cross+j,i*cross+k,(i+1)*cross+k,(i+1)*cross+j))
        return surface('CurvedTransitArm',vertices,faces,mat,parent)

    # The ring is broad, calm and rounded, with six readable clasp modules.
    arc('NavyRing',9.6,3.0,2.0,4.3,'CoreDark',root)
    arc('UpperArmor',9.6,3.12,.87,5.17,'CorePearl',root)
    arc('LowerArmor',9.6,3.02,.46,3.39,'CorePanel',root)
    arc('InnerRim',8.12,.16,.20,4.82,'CoreMetal',root)
    arc('OuterRim',11.1,.14,.20,4.83,'CoreMetal',root)
    for i in range(6):
        a=i*math.tau/6
        arc('SoftRingClasp',9.6,3.63,2.42,4.66,'CorePearl',root,a-.16,a+.16)
        radial=h.empty('ClaspLamp',(11.44*math.cos(a),11.44*math.sin(a),4.64),root)
        radial.rotation_euler.z=a
        rounded_box('LampSocket',(0,0,0),(.18,1.25,.47),'CoreDark',radial,.15)
        rounded_box('AmberWindow',(.10,0,0),(.13,.96,.25),'CoreLight',radial,.095)
        middle=a+math.pi/6
        radial=h.empty('RingWindow',(11.105*math.cos(middle),11.105*math.sin(middle),4.30),root)
        radial.rotation_euler.z=middle
        rounded_box('WindowRecess',(0,0,0),(.12,.96,.34),'CoreMetal',radial,.10)
        rounded_box('WarmWindow',(.07,0,0),(.07,.62,.14),'CoreLight',radial,.045)
    for i in range(3):
        a=i*math.tau/3+math.pi/6
        bridge(root,a,4.40,1.12,1.95,'CoreDark')
        bridge(root,a,4.98,.75,1.95,'CorePearl')

    # Squat command tower with a large panoramic teal cockpit.
    lathe('LowerEngineeringHull',[(0,1.2),(1.7,1.2),(2.3,1.5),(2.55,2.0),(2.55,3.5),(2.9,3.8),(0,3.8)],'CoreDark',root)
    lathe('LowerPearlBand',[(2.2,1.7),(2.55,1.85),(2.68,2.05),(2.68,2.32),(2.55,2.46),(2.4,2.48)],'CorePanel',root)
    lathe('TowerArmor',[(0,3.4),(2.8,3.4),(3.15,3.6),(3.32,3.9),(3.32,4.9),(3.15,5.23),(2.95,5.32)],'CorePearl',root)
    lathe('CockpitLowerFrame',[(2.8,5.03),(3.20,5.08),(3.42,5.26),(3.42,5.48),(3.25,5.60),(2.9,5.6)],'CoreMetal',root)
    lathe('PanoramicCockpit',[(2.98,5.38),(3.19,5.65),(3.27,6.15),(3.20,6.75),(3.02,7.24),(2.81,7.48)],'CoreGlass',root)
    lathe('CockpitHood',[(2.72,7.25),(3.14,7.28),(3.25,7.45),(3.20,7.65),(2.93,7.82),(2.74,8.05),(2.62,8.35),(2.32,8.62),(2.0,8.68)],'CorePearl',root)
    lathe('UpperObservationBand',[(1.95,8.35),(2.17,8.6),(2.22,9.12),(2.04,9.35),(1.6,9.35)],'CoreDark',root)
    lathe('RoundedCrown',[(0,9.1),(1.88,9.1),(2.04,9.28),(2.02,9.55),(1.82,10.05),(1.42,10.42),(.9,10.6),(0,10.6)],'CorePearl',root)
    for i in range(10):
        a=i*math.tau/10
        # Thick, softly bevelled glazing mullions; each pane remains large.
        x,y=3.22*math.cos(a),3.22*math.sin(a)
        rounded_box('CockpitMullion',(x,y,6.40),(.10,.13,1.44),'CoreMetal',root,.04,a)
    # Restrained broad reflection shapes help the glass read without environment probes.
    for a in (-1.6,-1.05,.4):
        mesh=arc('CockpitReflection',3.23,.025,.75,6.54,'CoreReflection',root,a,a+.09)
    for i in range(6):
        a=i*math.tau/6+math.pi/6
        lamp=h.empty('TowerLamp',(3.28*math.cos(a),3.28*math.sin(a),4.48),root);lamp.rotation_euler.z=a
        rounded_box('Housing',(0,0,0),(.20,.85,.42),'CoreDark',lamp,.12)
        rounded_box('Window',(.12,0,0),(.10,.59,.22),'CoreLight',lamp,.065)
        upper=h.empty('UpperLamp',(2.18*math.cos(a),2.18*math.sin(a),8.92),root);upper.rotation_euler.z=a
        rounded_box('UpperWindow',(0,0,0),(.09,.48,.17),'CoreLight',upper,.055)
    lathe('BeaconBase',[(0,10.2),(.62,10.2),(.73,10.45),(.65,10.75),(.40,10.85),(.35,11.7),(0,11.75)],'CoreMetal',root,48)
    lathe('BeaconGlow',[(0,11.35),(.23,11.35),(.27,11.55),(.27,12.02),(.20,12.22),(0,12.27)],'CoreLight',root,48)
    h.material('CoreActivity',(1,.5,.12),.5,.05)
    arc('ActivityRing',1.40,.17,.18,1.20,'CoreActivity',root)

    for i,a in enumerate((-math.pi/2,math.pi/6)):
        pad=h.empty('LandingPad',(11.6*math.cos(a),11.6*math.sin(a),4.33),root);pad.rotation_euler.z=a
        rounded_box('PadHull',(0,0,0),(4.0,3.25,.65),'CorePearl',pad,.36)
        rounded_box('PadInset',(.1,0,.37),(3.46,2.77,.17),'CoreDark',pad,.26)
        # Guideline ring and two broad runway marks, all real geometry.
        arc('LandingGuide',.95,.045,.02,.475,'CoreMark',pad)
        for y in (-1.05,1.05):rounded_box('GuideMark',(.1,y,.475),(1.25,.05,.015),'CoreMark',pad,.015)
        if i==0:
            h.empty('DockSocket',(1.8,0,.64),pad)
            rounded_box('ParkedShuttle',(-.25,0,.83),(1.40,.80,.58),'CorePearl',pad,.25)
            rounded_box('ShuttleCanopy',(-.04,0,1.12),(.65,.58,.20),'CoreGlass',pad,.13)
            for y in (-.53,.53):rounded_box('ShuttleEngine',(-.52,y,.72),(.86,.25,.30),'CorePanel',pad,.12)
