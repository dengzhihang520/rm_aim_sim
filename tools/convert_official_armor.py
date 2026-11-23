from pathlib import Path
import math, struct, json, hashlib
import argparse

parser = argparse.ArgumentParser(
    description="Tessellate official AM02/AM12 STEP without resizing"
)
parser.add_argument("--source-dir", type=Path, required=True)
parser.add_argument("--output-dir", type=Path, required=True)
args = parser.parse_args()
root = args.source_dir
from OCP.STEPControl import STEPControl_Reader
from OCP.TopExp import TopExp_Explorer
from OCP.TopAbs import TopAbs_SOLID, TopAbs_FACE, TopAbs_REVERSED
from OCP.TopoDS import TopoDS
from OCP.Bnd import Bnd_Box
from OCP.BRepBndLib import BRepBndLib
from OCP.BRepBuilderAPI import BRepBuilderAPI_Transform
from OCP.BRepMesh import BRepMesh_IncrementalMesh
from OCP.BRep import BRep_Tool
from OCP.TopLoc import TopLoc_Location
from OCP.gp import gp_Trsf, gp_Ax1, gp_Pnt, gp_Dir

out = args.output_dir
out.mkdir(parents=True, exist_ok=True)
manifest = {}
for model, plate_id, led_ids, nominal in [
    ("AM02", "002", ["003", "004"], [140, 125]),
    ("AM12", "12", ["10", "11"], [235, 127]),
]:
    source = root / (model + ".STEP")
    expected = {
        "AM02": "dcc2141c6a2928493f9f95ba00eb103ccd15354433f81b03dbba9f58e92e7e49",
        "AM12": "3793c09fd458c0f590ce92e5004016ad3530b3f48176f7c6cc8930b36704ffca",
    }
    if hashlib.sha256(source.read_bytes()).hexdigest() != expected[model]:
        raise ValueError("Unexpected official STEP source: " + str(source))
    reader = STEPControl_Reader()
    status = reader.ReadFile(str(source))
    if int(status) != 1:
        raise RuntimeError("Cannot read STEP: " + str(source))
    reader.TransferRoots()
    shape = reader.OneShape()
    solids = []
    ex = TopExp_Explorer(shape, TopAbs_SOLID)
    while ex.More():
        solid = ex.Current()
        label = (
            reader.WS()
            .TransferReader()
            .EntityFromShapeResult(solid, 1)
            .Name()
            .ToCString()
        )
        if model == "AM12":
            tr = gp_Trsf()
            tr.SetRotation(gp_Ax1(gp_Pnt(0, 0, 0), gp_Dir(0, 0, 1)), -math.pi / 3)
            solid = BRepBuilderAPI_Transform(solid, tr, True).Shape()
        b = Bnd_Box()
        BRepBndLib.AddOptimal_s(solid, b, False, False)
        solids.append((label, solid, b.Get()))
        ex.Next()
    plate = next(v for label, solid, v in solids if label == plate_id)
    origin = [plate[3], (plate[1] + plate[4]) / 2, (plate[2] + plate[5]) / 2]

    def transform(v):
        return [
            -(v[2] - origin[2]) * 0.001,
            (v[1] - origin[1]) * 0.001,
            (v[0] - origin[0]) * 0.001,
        ]

    blob = bytearray()
    views = []
    accessors = []
    meshes = []
    nodes = []
    metadata = []

    def accessor(values, kind):
        while len(blob) % 4:
            blob.append(0)
        start = len(blob)
        for v in values:
            blob.extend(struct.pack("<fff", *v))
        vi = len(views)
        views.append(
            dict(buffer=0, byteOffset=start, byteLength=len(blob) - start, target=34962)
        )
        ai = len(accessors)
        entry = dict(bufferView=vi, componentType=5126, count=len(values), type="VEC3")
        if kind == "position":
            entry.update(
                min=[min(v[i] for v in values) for i in range(3)],
                max=[max(v[i] for v in values) for i in range(3)],
            )
        accessors.append(entry)
        return ai

    for label, solid, box in solids:
        BRepMesh_IncrementalMesh(solid, 0.12, False, 0.20, True)
        vertices = []
        normals = []
        faces = TopExp_Explorer(solid, TopAbs_FACE)
        while faces.More():
            face = TopoDS.Face_s(faces.Current())
            loc = TopLoc_Location()
            tri = BRep_Tool.Triangulation_s(face, loc)
            if tri is not None:
                for i in range(1, tri.NbTriangles() + 1):
                    ids = list(tri.Triangle(i).Get())
                    if face.Orientation() == TopAbs_REVERSED:
                        ids[1], ids[2] = ids[2], ids[1]
                    pts = []
                    for idx in ids:
                        q = tri.Node(idx).Transformed(loc.Transformation())
                        pts.append(transform([q.X(), q.Y(), q.Z()]))
                    a = [pts[1][k] - pts[0][k] for k in range(3)]
                    b = [pts[2][k] - pts[0][k] for k in range(3)]
                    n = [
                        a[1] * b[2] - a[2] * b[1],
                        a[2] * b[0] - a[0] * b[2],
                        a[0] * b[1] - a[1] * b[0],
                    ]
                    length = math.sqrt(sum(x * x for x in n))
                    if length < 1e-14:
                        continue
                    n = [x / length for x in n]
                    vertices.extend(pts)
                    normals.extend([n] * 3)
            faces.Next()
        role = (
            "Lightbar"
            if label in led_ids
            else (
                "FacePlate"
                if label == plate_id
                else ("Housing" if label in ["001", "01"] else "Hardware")
            )
        )
        material = (
            1 if role == "Lightbar" else (0 if role in ["FacePlate", "Housing"] else 2)
        )
        name = role + "_" + label
        mi = len(meshes)
        meshes.append(
            dict(
                name=name,
                primitives=[
                    dict(
                        attributes={
                            "POSITION": accessor(vertices, "position"),
                            "NORMAL": accessor(normals, "normal"),
                        },
                        material=material,
                        mode=4,
                    )
                ],
            )
        )
        nodes.append(dict(name=name, mesh=mi))
        corners = [
            transform([box[x], box[y], box[z]])
            for x in [0, 3]
            for y in [1, 4]
            for z in [2, 5]
        ]
        lo = [min(p[i] for p in corners) for i in range(3)]
        hi = [max(p[i] for p in corners) for i in range(3)]
        metadata.append(
            dict(
                name=name,
                light=role == "Lightbar",
                minimum=lo,
                maximum=hi,
                triangles=len(vertices) // 3,
            )
        )
    materials = [
        dict(
            name="ArmorShell",
            pbrMetallicRoughness=dict(
                baseColorFactor=[0.025, 0.025, 0.028, 1],
                metallicFactor=0,
                roughnessFactor=0.85,
            ),
        ),
        dict(
            name="LightbarCover",
            pbrMetallicRoughness=dict(
                baseColorFactor=[0, 0.157, 1, 1], metallicFactor=0, roughnessFactor=0.3
            ),
        ),
        dict(
            name="Hardware",
            pbrMetallicRoughness=dict(
                baseColorFactor=[0.18, 0.19, 0.20, 1],
                metallicFactor=0.75,
                roughnessFactor=0.45,
            ),
        ),
    ]
    doc = dict(
        asset={
            "version": "2.0",
            "generator": "Official STEP millimeter tessellation; no fit-to-bounds rescaling",
        },
        scene=0,
        scenes=[dict(nodes=list(range(len(nodes))))],
        nodes=nodes,
        meshes=meshes,
        materials=materials,
        buffers=[dict(byteLength=len(blob))],
        bufferViews=views,
        accessors=accessors,
    )
    data = json.dumps(doc, separators=(",", ":")).encode()
    data += b" " * ((-len(data)) % 4)
    blob += b"\x00" * ((-len(blob)) % 4)
    glb = (
        struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(data) + 8 + len(blob))
        + struct.pack("<II", len(data), 0x4E4F534A)
        + data
        + struct.pack("<II", len(blob), 0x004E4942)
        + blob
    )
    (out / (model + ".glb")).write_bytes(glb)
    bounds = dict(
        minimum=[min(x["minimum"][i] for x in metadata) for i in range(3)],
        maximum=[max(x["maximum"][i] for x in metadata) for i in range(3)],
    )
    manifest[model] = dict(
        nominal_mm=nominal,
        parts=metadata,
        bounds=bounds,
        plate_size_mm=[
            (plate[5] - plate[2]),
            (plate[4] - plate[1]),
            (plate[3] - plate[0]),
        ],
        normal_thickness_mm=(bounds["maximum"][2] - bounds["minimum"][2]) * 1000,
        source_url="https://rm-static.djicdn.com/tem/17348/RoboMaster%20%E8%A3%85%E7%94%B2%E6%A8%A1%E5%9D%97%20"
        + model
        + "%202020.STEP",
        source_sha256=hashlib.sha256(
            (root / (model + ".STEP")).read_bytes()
        ).hexdigest(),
        glb_sha256=hashlib.sha256(glb).hexdigest(),
        optical_assumption="Uniform emission on exposed guide-cover mesh; actual LED luminous footprint and radiometry are not supplied by STEP.",
    )
    print(
        model,
        "glb bytes",
        len(glb),
        "triangles",
        sum(x["triangles"] for x in metadata),
        "normal depth mm",
        manifest[model]["normal_thickness_mm"],
    )
(out / "geometry.json").write_text(
    json.dumps(manifest, indent=2) + "\n", encoding="utf-8", newline="\n"
)
