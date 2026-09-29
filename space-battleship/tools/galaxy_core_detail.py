"""Portable vertex ambient occlusion for Galaxy core models."""
import math
from array import array
import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def bake_vertex_shading(obj):
    """Local 12-ray AO stored in GLB vertex colors; no runtime SSAO required."""
    mesh=obj.data
    mesh.update()
    vertices=[v.co.copy() for v in mesh.vertices]
    tree=BVHTree.FromPolygons(vertices,[tuple(p.vertices) for p in mesh.polygons])
    occlusion=[]
    for vertex in mesh.vertices:
        n=vertex.normal.normalized()
        tangent=n.cross(Vector((0,0,1)) if abs(n.z)<.9 else Vector((0,1,0))).normalized()
        bitangent=n.cross(tangent)
        blocked=0.0
        for i in range(12):
            z=math.sqrt((i+.5)/12)
            radial=math.sqrt(1-z*z);angle=i*2.39996323
            direction=n*z+tangent*(radial*math.cos(angle))+bitangent*(radial*math.sin(angle))
            hit,normal,index,distance=tree.ray_cast(vertex.co+n*.025,direction,1.6)
            if hit is not None:blocked+=1-distance/1.6
        occlusion.append(1-.55*blocked/12)
    attr=mesh.color_attributes.new(name='CoreAO',type='FLOAT_COLOR',domain='CORNER')
    values=array('f',[0])*(len(mesh.loops)*4)
    for face in mesh.polygons:
        mat=obj.data.materials[face.material_index]
        bs=mat.node_tree.nodes.get('Principled BSDF')
        color=bs.inputs['Base Color'].default_value[:3]
        emission=bs.inputs['Emission Strength'].default_value
        for loop_id in face.loop_indices:
            ao=1 if emission>0 else occlusion[mesh.loops[loop_id].vertex_index]
            for axis in range(3):values[loop_id*4+axis]=color[axis]*ao
            values[loop_id*4+3]=1
    attr.data.foreach_set('color',values)
    mesh.color_attributes.active_color=attr
    for mat in obj.data.materials:
        node=mat.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='CoreAO'
        mat.node_tree.links.new(node.outputs['Color'],mat.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    print('Core vertex AO baked:',len(mesh.vertices),'vertices',flush=True)

