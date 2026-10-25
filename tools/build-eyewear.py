"""Original RetroFit eyewear. Run inside Blender; preserves the user's open scene.
AR coordinates: metres, +X right, +Y up, +Z towards the camera.
"""
import bpy, bmesh, math, json, tempfile
from pathlib import Path
from mathutils import Vector
from pxr import Sdf, Tf, Usd, UsdShade, UsdUtils

REPO = Path(__file__).resolve().parents[1]
PREVIEWS = REPO / 'build/eyewear-previews'
PREVIEWS.mkdir(parents=True, exist_ok=True)
SPECS = [
    dict(id='ice-blue-rimless-shades', model='Y2K_Ice_Blue_Rimless', title='Ice Blue Rimless', shape=4.5, width=.029, height=.013, rim=0, lens=(.10,.49,.74), alpha=.78, frame=(.72,.79,.85), metal=.92),
    dict(id='candy-pink-oval-shades', model='Y2K_Candy_Pink_Oval', title='Candy Pink Ovals', shape=2.0, width=.027, height=.016, rim=.0032, lens=(.29,.025,.12), alpha=.88, frame=(.82,.055,.30), metal=.12),
    dict(id='amber-wrap-shades', model='Y2K_Amber_Wrap', title='Amber Wrap Shades', shape=3.2, width=.030, height=.014, rim=.0024, lens=(.43,.15,.025), alpha=.86, frame=(.09,.032,.012), metal=.16),
]
KINDS = ['objects','meshes','curves','materials','cameras','lights','worlds','collections','images','scenes']
before = {kind:set(getattr(bpy.data,kind)) for kind in KINDS}
original_scene = bpy.context.window.scene
original_active = bpy.context.view_layer.objects.active
original_selected = list(bpy.context.selected_objects)
scenes=[]; reports=[]

def xyz(p):
    return (p[0],-p[2],p[1])

def material(name,color,metal=0,rough=.25,alpha=1):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,alpha);m.use_nodes=True
    bs=m.node_tree.nodes.get('Principled BSDF')
    bs.inputs['Base Color'].default_value=(*color,1)
    bs.inputs['Metallic'].default_value=metal
    bs.inputs['Roughness'].default_value=rough
    bs.inputs['Alpha'].default_value=alpha
    # Culling exports as doubleSided = 0, so each copy of a see-through sheet draws from one side only.
    if alpha<1:m.surface_render_method='DITHERED';m.use_backface_culling=True
    return m

def add_opacity(layer,materials):
    """Blender's USD export writes every material as opaque. Copy each Principled BSDF's Alpha
    into the preview surface's opacity so the tinted lenses stay see-through in the app."""
    alphas={Tf.MakeValidIdentifier(m.name):next(n for n in m.node_tree.nodes if n.type=='BSDF_PRINCIPLED').inputs['Alpha'].default_value for m in materials}
    stage=Usd.Stage.Open(str(layer));patched=set()
    for prim in stage.Traverse():
        alpha=alphas.get(prim.GetName(),1) if prim.IsA(UsdShade.Material) else 1
        if alpha>=1:continue
        for child in prim.GetChildren():
            shader=UsdShade.Shader(child)
            if shader and shader.GetIdAttr().Get()=='UsdPreviewSurface':
                shader.CreateInput('opacity',Sdf.ValueTypeNames.Float).Set(float(alpha));patched.add(prim.GetName())
    missing={name for name,alpha in alphas.items() if alpha<1}-patched
    if missing:raise RuntimeError('No USD preview surface for '+', '.join(sorted(missing)))
    stage.GetRootLayer().Save()

def mesh(name,verts,faces,mat,scene):
    data=bpy.data.meshes.new(name);data.from_pydata([xyz(v) for v in verts],[],faces);data.update()
    o=bpy.data.objects.new(name,data);scene.collection.objects.link(o);data.materials.append(mat)
    for p in data.polygons:p.use_smooth=True
    return o

def tube(name,path,radius,mat,scene,closed=False,sides=8):
    verts=[];faces=[];count=len(path);previous_normal=None
    for i,p in enumerate(path):
        prev=Vector(path[(i-1)%count] if closed or i else path[0])
        nxt=Vector(path[(i+1)%count] if closed or i<count-1 else path[-1])
        tangent=(nxt-prev).normalized();ref=Vector((0,0,1))
        if abs(tangent.dot(ref))>.9:ref=Vector((0,1,0))
        a=(previous_normal-tangent*previous_normal.dot(tangent)).normalized() if previous_normal is not None else tangent.cross(ref).normalized()
        b=tangent.cross(a).normalized();previous_normal=a
        for j in range(sides):
            angle=2*math.pi*j/sides
            q=Vector(p)+radius*(math.cos(angle)*a+math.sin(angle)*b)
            verts.append(tuple(q))
    for i in range(count if closed else count-1):
        for j in range(sides):faces.append((i*sides+j,i*sides+(j+1)%sides,((i+1)%count)*sides+(j+1)%sides,((i+1)%count)*sides+j))
    if not closed:
        faces.extend([tuple(reversed(range(sides))),tuple((count-1)*sides+j for j in range(sides))])
    return mesh(name,verts,faces,mat,scene)

def smooth_path(points,steps=5):
    result=[]
    for i in range(len(points)-1):
        p0=Vector(points[max(0,i-1)]);p1=Vector(points[i]);p2=Vector(points[i+1]);p3=Vector(points[min(len(points)-1,i+2)])
        for j in range(steps):
            t=j/steps
            result.append(tuple(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)))
    result.append(points[-1]);return result

def sphere(name,center,radii,mat,scene):
    verts=[];faces=[];segs=16;rings=8
    for i in range(rings+1):
        a=math.pi*i/rings
        for j in range(segs):
            b=2*math.pi*j/segs
            verts.append((center[0]+radii[0]*math.sin(a)*math.cos(b),center[1]+radii[1]*math.sin(a)*math.sin(b),center[2]+radii[2]*math.cos(a)))
    for i in range(rings):
        for j in range(segs):faces.append((i*segs+j,i*segs+(j+1)%segs,(i+1)*segs+(j+1)%segs,(i+1)*segs+j))
    return mesh(name,verts,faces,mat,scene)

def lens_outline(spec,side):
    points=[]
    for i in range(64):
        t=2*math.pi*i/64;c=math.cos(t);s=math.sin(t);e=2/spec['shape']
        x=side*.035+spec['width']*math.copysign(abs(c)**e,c)
        y=spec['height']*math.copysign(abs(s)**e,s)
        if spec['id']=='amber-wrap-shades':y+=.003*(abs(x)-.035)/.03
        z=.032-.018*(abs(x)/.073)**2
        points.append((x,y,z))
    return points

def lens_sheet(name,path,mat,scene):
    # See-through plastic: one curved fan, once facing out and once facing the eyes. A closed thin
    # shell would draw both of its layers over each other and sort into streaks in the app.
    count=len(path);centre=(sum(p[0] for p in path)/count,sum(p[1] for p in path)/count,.032)
    fan=[(0,1+i,1+(i+1)%count) for i in range(count)]
    return mesh(name,[centre,*path]*2,fan+[tuple(count+1+v for v in reversed(f)) for f in fan],mat,scene)

def outward_half(o):
    """The copy of a lens sheet that faces the camera. Cycles can't cull back faces, and two
    coincident copies would sort at random into streaks in the product shot."""
    half=o.data.copy();bm=bmesh.new();bm.from_mesh(half);bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm,geom=bm.faces[len(bm.faces)//2:],context='FACES');bm.to_mesh(half);bm.free()
    return half

def aim(obj,target):obj.rotation_euler=(Vector(target)-obj.location).to_track_quat('-Z','Y').to_euler()

try:
    with bpy.data.libraries.load(str(REPO/'art/y2k_hats.blend'),link=False) as (src,dst):
        dst.objects=[name for name in ['Cam','Key','Fill','Rim'] if name in src.objects]
    rig={o.name.split('.')[0]:o for o in dst.objects if o}
    for spec in SPECS:
        scene=bpy.data.scenes.new(spec['model']);scenes.append(scene);bpy.context.window.scene=scene
        scene.unit_settings.system='METRIC';scene.unit_settings.scale_length=1
        scene.render.engine='CYCLES';scene.cycles.samples=48;scene.cycles.use_denoising=True
        scene.render.resolution_x=1200;scene.render.resolution_y=1200;scene.render.resolution_percentage=100
        scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
        scene.view_settings.view_transform='AgX'
        world=bpy.data.worlds.new(spec['model']+'_World');world.use_nodes=True
        world.node_tree.nodes['Background'].inputs[0].default_value=(.32,.37,.45,1)
        world.node_tree.nodes['Background'].inputs[1].default_value=.45;scene.world=world
        frame=material(spec['model']+'_Frame',spec['frame'],spec['metal'],.18)
        lens=material(spec['model']+'_Lens',spec['lens'],.2,.12,spec['alpha'])
        chrome=material(spec['model']+'_Chrome',(.7,.76,.83),.92,.18)
        pad=material(spec['model']+'_Nose_Pads',(.55,.52,.52),0,.38,.82)
        sheets=[]
        for side in [-1,1]:
            label='Left' if side<0 else 'Right';path=lens_outline(spec,side)
            sheets.append(lens_sheet(label+'_Lens',path,lens,scene))
            if spec['rim']:tube(label+'_Rim',path,spec['rim'],frame,scene,True,10)
            else:
                for x in [side*.012,side*.060]:sphere(label+'_Rimless_Rivet',(x,.004,.032-.018*(abs(x)/.073)**2+.0015),(.0016,.0016,.001),chrome,scene)
            # Hinges, contoured temples, earpieces and nose pads make complete wearable meshes.
            outer=side*(.035+spec['width']+spec['rim'])
            tube(label+'_Temple',smooth_path([(outer,.006,.015),(side*.073,.006,.004),(side*.076,.006,-.023),(side*.075,.005,-.065),(side*.073,.002,-.089),(side*.069,-.012,-.112)]),.0017 if not spec['rim'] else .0025,frame,scene,sides=10)
            sphere(label+'_Temple_Tip',(side*.069,-.012,-.112),(.0017,.0017,.0017) if not spec['rim'] else (.0025,.0025,.0025),frame,scene)
            sphere(label+'_Hinge',(outer,.006,.014),(.003,.003,.003),chrome,scene)
            sphere(label+'_Nose_Pad',(side*.011,-.007,.022),(.0024,.004,.0017),pad,scene)
            # Two small chrome dots echo early-2000s hardware without third-party branding.
            if spec['rim']:
                for dz in [.003,-.003]:sphere(label+'_Chrome_Accent',(side*.0745,.006,dz),(.0008,.0013,.0013),chrome,scene)
        tube('Arched_Bridge',[(-.011,.003,.029),(-.008,.007,.032),(0,.009,.034),(.008,.007,.032),(.011,.003,.029)],.0013 if not spec['rim'] else .0021,chrome if not spec['rim'] else frame,scene,sides=10)
        models=[o for o in scene.objects if o.type=='MESH']
        for o in models:
            o.select_set(True)
            # The sheets face both ways on purpose; recalculating would turn one copy round.
            if o in sheets:continue
            bm=bmesh.new();bm.from_mesh(o.data)
            bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
            if bm.calc_volume(signed=True)<0:bmesh.ops.reverse_faces(bm,faces=list(bm.faces))
            bm.to_mesh(o.data);bm.free();o.data.update()
        bpy.context.view_layer.objects.active=models[0]
        scene['design_note']='Original RetroFit procedural eyewear; no third-party geometry or textures.'
        scene['ar_convention']='metres; +Y up, +Z forward in exported USD; compatible with bounds-based glasses fitting'
        out=REPO/'TheoRaff/Resources'/f"{spec['model']}.usdz"
        layer=Path(tempfile.mkdtemp(prefix='y2k_usd_'))/f"{spec['model']}.usdc"
        bpy.ops.wm.usd_export(filepath=str(layer),selected_objects_only=True,export_materials=True,export_lights=False,export_cameras=False,convert_orientation=True,export_global_forward_selection='NEGATIVE_Z',export_global_up_selection='Y',triangulate_meshes=True)
        add_opacity(layer,[frame,lens,chrome,pad])
        out.unlink(missing_ok=True)
        if not UsdUtils.CreateNewUsdzPackage(str(layer),str(out)):raise RuntimeError(f'Could not package {out}')
        triangles=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in models)
        # Use independent copies of the established product-shot rig.
        for name,src in rig.items():
            o=src.copy();o.data=src.data.copy();scene.collection.objects.link(o);o.name=spec['model']+'_'+name
            if name=='Cam':
                scene.camera=o;o.data.type='ORTHO';o.data.ortho_scale=.235
                o.location=xyz((.155,.105,.31));aim(o,xyz((0,0,-.025)));o.data.lens=60;o.data.clip_start=.001;o.data.clip_end=10
            else:
                positions={'Key':(-.16,.23,.25),'Fill':(.24,.10,.15),'Rim':(-.10,.20,-.22)}
                energies={'Key':5,'Fill':2.5,'Rim':6}
                o.location=xyz(positions[name]);o.data.energy=energies[name];o.data.shape='DISK';o.data.size=.22;aim(o,xyz((0,0,-.025)))
        scene.render.filepath=str(PREVIEWS/f"{spec['id']}.png")
        # Shoot the lenses as the app draws them, one layer deep; the saved source keeps both copies.
        full={o:o.data for o in sheets}
        for o in sheets:o.data=outward_half(o)
        bpy.ops.render.render(write_still=True)
        for o in sheets:half=o.data;o.data=full[o];bpy.data.meshes.remove(half)
        reports.append(dict(id=spec['id'],model=spec['model'],triangles=triangles,bytes=out.stat().st_size))
    # Write a separate source library; never save or rename the user's unsaved session.
    bpy.data.libraries.write(str(REPO/'art/y2k_eyewear.blend'),set(scenes),fake_user=True,compress=True)
    (PREVIEWS/'manifest.json').write_text(json.dumps(reports,indent=2))
    print('EYEWEAR_BUILD',json.dumps(reports))
finally:
    bpy.context.window.scene=original_scene
    for scene in scenes:
        if scene.name in bpy.data.scenes:bpy.data.scenes.remove(scene)
    for kind in KINDS:
        if kind=='scenes':continue
        collection=getattr(bpy.data,kind)
        for item in list(collection):
            if item not in before[kind]:collection.remove(item,do_unlink=True)
    bpy.context.view_layer.objects.active=original_active
    for o in original_selected:o.select_set(True)
    print('RESTORED',original_scene.name,sorted(o.name for o in original_scene.objects))
