"""Makes the Violet Butterfly's lenses see-through. Run inside Blender with the model's source open:

    /Applications/Blender.app/Contents/MacOS/Blender -b art/y2k_violet_butterfly.blend --python tools/patch-violet-butterfly.py

The model has no build script, so this edits the shipped USDZ in place and leaves its gradient
texture alone. Blender's USD export writes every material as opaque: each material whose Principled
BSDF Alpha is below 1 gets that opacity back, and its meshes cull back faces. Each lens was a closed
thin shell, whose two see-through layers sort into streaks in the app; it becomes its front fan,
stored once facing out and once facing the eyes. On a model that's already patched it changes nothing.
"""
import shutil, tempfile, zipfile
from collections import Counter
from pathlib import Path

import bpy
from pxr import Gf, Sdf, Tf, Usd, UsdGeom, UsdShade, UsdUtils, Vt

REPO = Path(__file__).resolve().parents[1]
MODEL = REPO / 'TheoRaff/Resources/Y2K_Violet_Butterfly.usdz'
LENSES = ['Left_Violet_Lens', 'Right_Violet_Lens']


def see_through_alphas():
    """Alpha of every see-through material in the open .blend, keyed by its USD prim name."""
    alphas = {}
    for m in bpy.data.materials:
        bsdf = next((n for n in m.node_tree.nodes if n.type == 'BSDF_PRINCIPLED'), None) if m.node_tree else None
        if bsdf and bsdf.inputs['Alpha'].default_value < 1:
            alphas[Tf.MakeValidIdentifier(m.name)] = bsdf.inputs['Alpha'].default_value
    return alphas


def front_sheet(mesh):
    """Turns a lens shell (a front fan, a back fan and the wall between) into the front fan stored
    twice with opposite winding. Returns False if the lens is already an open sheet."""
    indices = list(mesh.GetFaceVertexIndicesAttr().Get())
    if set(mesh.GetFaceVertexCountsAttr().Get()) != {3} or mesh.GetOrientationAttr().Get() != UsdGeom.Tokens.rightHanded:
        raise RuntimeError(f'{mesh.GetPath()} must be right-handed triangles')
    tris = [indices[i:i + 3] for i in range(0, len(indices), 3)]
    edges = Counter(tuple(sorted((t[k], t[(k + 1) % 3]))) for t in tris for k in range(3))
    if 1 in edges.values():
        return False
    st = UsdGeom.PrimvarsAPI(mesh).GetPrimvar('st')
    if not st.IsIndexed() or st.GetInterpolation() != UsdGeom.Tokens.faceVarying:
        raise RuntimeError(f'{mesh.GetPath()} needs indexed face-varying UVs')
    points = mesh.GetPointsAttr().Get()
    world = UsdGeom.Xformable(mesh.GetPrim()).ComputeLocalToWorldTransform(Usd.TimeCode.Default())
    # The two fan centres are shared by every triangle of their fan; the front one is nearer the camera (+z).
    centres = [v for v, uses in Counter(indices).most_common(2) if uses > 8]
    if len(centres) != 2:
        raise RuntimeError(f'{mesh.GetPath()} is not a two-fan lens shell')
    front = max(centres, key=lambda v: world.Transform(Gf.Vec3d(points[v]))[2])
    fan = [t for t, tri in enumerate(tris) if front in tri]

    def normal(tri):
        a, b, c = (Gf.Vec3d(points[v]) for v in tri)
        return (b - a) ^ (c - a)
    facing_out = sum(world.TransformDir(normal(tris[t]))[2] for t in fan) > 0
    st_indices = list(st.GetIndices())
    outward = [(tris[t], st_indices[3 * t:3 * t + 3]) for t in fan]
    if not facing_out:
        outward = [(tri[::-1], uv[::-1]) for tri, uv in outward]

    keep = sorted({v for tri, _ in outward for v in tri})
    remap = {v: i for i, v in enumerate(keep)}
    summed = {v: Gf.Vec3d(0) for v in keep}
    for tri, _ in outward:
        for v in tri:
            summed[v] += normal(tri)
    normals = [Gf.Vec3f(summed[v].GetNormalized()) for v in keep]
    faces = [remap[v] for tri, _ in outward for v in tri]
    faces += [len(keep) + remap[v] for tri, _ in outward for v in reversed(tri)]
    uvs = [i for _, uv in outward for i in uv] + [i for _, uv in outward for i in reversed(uv)]
    sheet = Vt.Vec3fArray([points[v] for v in keep] * 2)
    mesh.GetPointsAttr().Set(sheet)
    mesh.GetNormalsAttr().Set(Vt.Vec3fArray(normals + [-n for n in normals]))
    mesh.SetNormalsInterpolation(UsdGeom.Tokens.vertex)
    mesh.GetFaceVertexCountsAttr().Set(Vt.IntArray([3] * (len(faces) // 3)))
    mesh.GetFaceVertexIndicesAttr().Set(Vt.IntArray(faces))
    st.SetIndices(Vt.IntArray(uvs))
    mesh.GetExtentAttr().Set(UsdGeom.PointBased.ComputeExtent(sheet))
    return True


def patch(layer, alphas):
    """Patches the layer, saving it only if anything changed, and reports what it did."""
    stage = Usd.Stage.Open(str(layer))
    report = {'opacity': {}, 'sheets': [], 'changed': False}
    for prim in stage.Traverse():
        if prim.IsA(UsdShade.Material) and prim.GetName() in alphas:
            alpha = float(alphas[prim.GetName()])
            for child in prim.GetChildren():
                shader = UsdShade.Shader(child)
                if shader and shader.GetIdAttr().Get() == 'UsdPreviewSurface':
                    opacity = shader.GetInput('opacity')
                    current = opacity.Get() if opacity else None
                    if current is None or abs(current - alpha) > 1e-6:
                        shader.CreateInput('opacity', Sdf.ValueTypeNames.Float).Set(alpha)
                        report['changed'] = True
                    report['opacity'][prim.GetName()] = round(alpha, 3)
        elif prim.IsA(UsdGeom.Mesh):
            mesh = UsdGeom.Mesh(prim)
            bound = UsdShade.MaterialBindingAPI(prim).GetDirectBinding().GetMaterialPath()
            if bound.name in alphas and mesh.GetDoubleSidedAttr().Get():
                mesh.GetDoubleSidedAttr().Set(False)
                report['changed'] = True
            if prim.GetName() in LENSES and front_sheet(mesh):
                report['sheets'].append(prim.GetName())
                report['changed'] = True
    missing = set(alphas) - set(report['opacity'])
    if missing:
        raise RuntimeError('No USD preview surface for ' + ', '.join(sorted(missing)))
    if report['changed']:
        stage.GetRootLayer().Save()
    return report


with tempfile.TemporaryDirectory(prefix='violet_usd_') as work:
    with zipfile.ZipFile(MODEL) as package:
        package.extractall(work)
        layer = Path(work) / package.namelist()[0]
    report = patch(layer, see_through_alphas())
    # An already patched model is left alone, so running this again doesn't touch the file.
    if report['changed']:
        packaged = Path(work) / MODEL.name
        if not UsdUtils.CreateNewUsdzPackage(str(layer), str(packaged)):
            raise RuntimeError(f'Could not package {MODEL}')
        shutil.move(packaged, MODEL)
print('VIOLET_PATCH', report, MODEL.stat().st_size, 'bytes')
