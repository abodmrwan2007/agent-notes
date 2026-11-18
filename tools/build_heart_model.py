"""Builds the heart model for the anatomy atlas from BodyParts3D meshes.

Source: BodyParts3D, (c) The Database Center for Life Science, release 4.0
(https://dbarchive.biosciencedbc.jp/en/bodyparts3d/). The OBJ files state the license as
CC Attribution-Share Alike 2.1 Japan; the website's license page states CC BY 4.0. The derived
model files are distributed under CC BY-SA 2.1 JP (the stricter of the two) with attribution.

The archives are NOT in the repository. Download them yourself and run:

    python -I tools/build_heart_model.py <partof zip> <isa zip>

Output (committed): App/Resources/Atlas.xcassets/heart-model.dataset/heart.bin and
heart-parts.dataset/parts.json.

Each part is picked from the archives by its English name, merged, reduced by vertex clustering,
centred on the heart and turned from BodyParts3D's z-up millimetres into y-up centimetres.

Binary layout (little endian): for each part in parts.json order, `vertexCount` vertices of
6 float32 (position x y z, normal x y z), then `indexCount` uint32 triangle indices (local to the
part). parts.json gives each part's byte offsets.
"""
import json
import math
import pathlib
import struct
import sys
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "App" / "Resources" / "Atlas.xcassets"

# (id, English name in the app, Arabic name, group, colour, English names in BodyParts3D, cell mm)
PARTS = [
    # Walls (made see-through by the app's slider) and the blood cavities inside them.
    ("rightAtrium", "Right atrium (wall)", "الأذين الأيمن (الجدار)", "chambers", "6F8FD8", ["Wall of right atrium"], 1.6),
    ("leftAtrium", "Left atrium (wall)", "الأذين الأيسر (الجدار)", "chambers", "D87A6F", ["Wall of left atrium"], 1.6),
    ("ventricles", "Ventricles (muscle wall)", "البطينان (الجدار العضلي)", "chambers", "C2564D", ["Wall of ventricle"], 1.6),
    ("rightAtriumCavity", "Right atrium (cavity)", "تجويف الأذين الأيمن", "chambers", "2F5FC0", ["Cavity of right atrium"], 1.4),
    ("leftAtriumCavity", "Left atrium (cavity)", "تجويف الأذين الأيسر", "chambers", "C0392B", ["Cavity of left atrium"], 1.4),
    ("rightVentricle", "Right ventricle (cavity)", "تجويف البطين الأيمن", "chambers", "3A6ED6", ["Cavity of right ventricle"], 1.4),
    ("leftVentricle", "Left ventricle (cavity)", "تجويف البطين الأيسر", "chambers", "D0453A", ["Cavity of left ventricle"], 1.4),
    ("tricuspidValve", "Tricuspid valve", "الصمام ثلاثي الشرفات", "valves", "F2E3B3",
     ["Anterior leaflet of tricuspid valve", "Posterior leaflet of tricuspid valve", "Septal leaflet of tricuspid valve"], 0.9),
    ("mitralValve", "Mitral valve", "الصمام التاجي", "valves", "F5D58A",
     ["Anterior leaflet of mitral valve", "Posterior leaflet of mitral valve"], 0.9),
    ("pulmonaryValve", "Pulmonary valve", "الصمام الرئوي", "valves", "EFE6C8",
     ["Left anterior cusp of pulmonary valve", "Right anterior cusp of pulmonary valve", "Posterior cusp of pulmonary valve"], 0.8),
    ("aorticValve", "Aortic valve", "الصمام الأبهري", "valves", "F7CF7A",
     ["Right posterior cusp of aortic valve", "Anterior cusp of aortic valve", "Left posterior cusp of aortic valve"], 0.8),
    ("papillaryRight", "Papillary muscles (right ventricle)", "العضلات الحليمية (البطين الأيمن)", "valves", "B07A6A",
     ["Anterior papillary muscle of right ventricle", "Posterior papillary muscle of right ventricle", "Septal papillary muscle of right ventricle"], 1.0),
    ("papillaryLeft", "Papillary muscles (left ventricle)", "العضلات الحليمية (البطين الأيسر)", "valves", "B5675C",
     ["Lateral papillary muscle of left ventricle", "Anterolateral head of lateral papillary muscle of left ventricle"], 1.0),
    ("aorta", "Aorta (ascending and arch)", "الأبهر (الصاعد والقوس)", "vessels", "D93A30", ["Ascending aorta", "Arch of aorta"], 1.6),
    ("pulmonaryTrunk", "Pulmonary trunk and arteries", "الجذع الرئوي والشريانان الرئويان", "vessels", "3F66C4",
     ["Pulmonary trunk", "Left pulmonary artery", "Right pulmonary artery"], 1.6),
    ("pulmonaryVeins", "Pulmonary veins", "الأوردة الرئوية", "vessels", "E0685E",
     ["Left superior pulmonary vein", "Left inferior pulmonary vein", "Right superior pulmonary vein", "Right inferior pulmonary vein"], 1.4),
    ("superiorVenaCava", "Superior vena cava", "الوريد الأجوف العلوي", "vessels", "3355B0", ["Superior vena cava"], 1.6),
    ("inferiorVenaCava", "Inferior vena cava", "الوريد الأجوف السفلي", "vessels", "2E4FA6", ["Inferior vena cava"], 1.6),
    ("coronaryArteries", "Coronary arteries", "الشرايين التاجية", "coronary", "E6463C", ["#coronary artery", "Right conus artery"], 0.9),
    ("cardiacVeins", "Cardiac veins and coronary sinus", "الأوردة القلبية والجيب التاجي", "coronary", "5C7FD6",
     ["Coronary sinus", "Great cardiac vein", "Middle cardiac vein", "Small cardiac vein", "Posterior vein of left ventricle"], 0.9),
]

# "Wall of ventricle" (one mesh for both ventricles) exists only in the is-a archive.

# Vessels are cut off this far (mm) from the heart centre so they do not run down the body.
CLIP_RADIUS = 95.0


def read_obj(data: bytes):
    header, vertices, faces = {}, [], []
    for raw in data.decode("utf-8", "replace").splitlines():
        if raw.startswith("# ") and " : " in raw:
            key, value = raw[2:].split(" : ", 1)
            header[key.strip()] = value.strip()
        elif raw.startswith("v "):
            _, x, y, z = raw.split()[:4]
            vertices.append((float(x), float(y), float(z)))
        elif raw.startswith("f "):
            idx = [int(p.split("/")[0]) - 1 for p in raw.split()[1:]]
            for k in range(1, len(idx) - 1):
                faces.append((idx[0], idx[k], idx[k + 1]))
    return header, vertices, faces


def load_archives(paths):
    meshes = []  # (english name, vertices, faces, source file id)
    seen = set()
    for path in paths:
        archive = zipfile.ZipFile(path)
        for name in archive.namelist():
            if not name.endswith(".obj"):
                continue
            header, vertices, faces = read_obj(archive.read(name))
            file_id = header.get("File ID", name)
            if file_id in seen:
                continue
            seen.add(file_id)
            meshes.append((header.get("English name", ""), vertices, faces, file_id))
    return meshes


def select(meshes, wanted):
    picked = []
    for pattern in wanted:
        if pattern.startswith("#"):
            needle = pattern[1:].lower()
            picked += [m for m in meshes if needle in m[0].lower()]
        else:
            picked += [m for m in meshes if m[0].lower() == pattern.lower()]
    return picked


def merge(picked):
    vertices, faces = [], []
    for _, v, f, _ in picked:
        base = len(vertices)
        vertices += v
        faces += [(a + base, b + base, c + base) for a, b, c in f]
    return vertices, faces


def cluster(vertices, faces, cell):
    """Vertex-clustering decimation: vertices in one grid cell become their average."""
    cells, remap, sums = {}, [], []
    for x, y, z in vertices:
        key = (math.floor(x / cell), math.floor(y / cell), math.floor(z / cell))
        index = cells.get(key)
        if index is None:
            index = len(sums)
            cells[key] = index
            sums.append([0.0, 0.0, 0.0, 0])
        s = sums[index]
        s[0] += x; s[1] += y; s[2] += z; s[3] += 1
        remap.append(index)
    new_vertices = [(s[0] / s[3], s[1] / s[3], s[2] / s[3]) for s in sums]
    new_faces, seen = [], set()
    for a, b, c in faces:
        a, b, c = remap[a], remap[b], remap[c]
        if a == b or b == c or a == c:
            continue
        key = tuple(sorted((a, b, c)))
        if key in seen:
            continue
        seen.add(key)
        new_faces.append((a, b, c))
    return new_vertices, new_faces


def clip(vertices, faces, centre, radius):
    keep = [math.dist(v, centre) <= radius for v in vertices]
    faces = [f for f in faces if keep[f[0]] and keep[f[1]] and keep[f[2]]]
    used = sorted({i for f in faces for i in f})
    index = {old: new for new, old in enumerate(used)}
    return [vertices[i] for i in used], [(index[a], index[b], index[c]) for a, b, c in faces]


def normals(vertices, faces):
    acc = [[0.0, 0.0, 0.0] for _ in vertices]
    for a, b, c in faces:
        ax, ay, az = vertices[a]; bx, by, bz = vertices[b]; cx, cy, cz = vertices[c]
        ux, uy, uz = bx - ax, by - ay, bz - az
        vx, vy, vz = cx - ax, cy - ay, cz - az
        n = (uy * vz - uz * vy, uz * vx - ux * vz, ux * vy - uy * vx)
        for i in (a, b, c):
            acc[i][0] += n[0]; acc[i][1] += n[1]; acc[i][2] += n[2]
    result = []
    for x, y, z in acc:
        length = math.sqrt(x * x + y * y + z * z) or 1.0
        result.append((x / length, y / length, z / length))
    return result


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    meshes = load_archives(sys.argv[1:])
    print(f"read {len(meshes)} meshes")

    built = []
    for part_id, en, ar, group, colour, wanted, cell in PARTS:
        picked = select(meshes, wanted)
        if not picked:
            print(f"  MISSING {part_id}")
            continue
        vertices, faces = merge(picked)
        built.append([part_id, en, ar, group, colour, vertices, faces, cell, sorted({p[0] for p in picked})])

    # Heart centre: middle of the chambers' bounding box.
    chamber_points = [v for b in built if b[3] == "chambers" for v in b[5]]
    lo = [min(p[i] for p in chamber_points) for i in range(3)]
    hi = [max(p[i] for p in chamber_points) for i in range(3)]
    centre = tuple((lo[i] + hi[i]) / 2 for i in range(3))

    blob = bytearray()
    manifest = []
    total = 0
    for part_id, en, ar, group, colour, vertices, faces, cell, sources in built:
        vertices, faces = clip(vertices, faces, centre, CLIP_RADIUS)
        vertices, faces = cluster(vertices, faces, cell)
        if not faces:
            print(f"  EMPTY after reduction: {part_id}")
            continue
        # BodyParts3D: x = patient's left, y = posterior, z = up (mm).
        # App: x = viewer's right (patient's left), y = up, z = toward the viewer (anterior), cm.
        moved = [((x - centre[0]) / 10, (z - centre[2]) / 10, -(y - centre[1]) / 10) for x, y, z in vertices]
        # The y/z swap with a sign flip keeps the handedness, so face winding stays the same.
        norms = normals(moved, faces)
        vertex_offset = len(blob)
        for (x, y, z), (nx, ny, nz) in zip(moved, norms):
            blob += struct.pack("<6f", x, y, z, nx, ny, nz)
        index_offset = len(blob)
        for a, b, c in faces:
            blob += struct.pack("<3I", a, b, c)
        manifest.append({
            "id": part_id, "en": en, "ar": ar, "group": group, "color": colour,
            "vertexOffset": vertex_offset, "vertexCount": len(moved),
            "indexOffset": index_offset, "indexCount": len(faces) * 3,
            "sources": sources,
        })
        total += len(faces)
        print(f"  {part_id}: {len(moved)} vertices, {len(faces)} triangles from {sources}")

    model_dir = OUT / "heart-model.dataset"
    parts_dir = OUT / "heart-parts.dataset"
    model_dir.mkdir(parents=True, exist_ok=True)
    parts_dir.mkdir(parents=True, exist_ok=True)
    (OUT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    (model_dir / "heart.bin").write_bytes(bytes(blob))
    (model_dir / "Contents.json").write_text(json.dumps({
        "data": [{"filename": "heart.bin", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    (parts_dir / "parts.json").write_text(json.dumps({
        "source": "BodyParts3D release 4.0, (c) The Database Center for Life Science, CC BY-SA 2.1 JP",
        "parts": manifest}, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
    (parts_dir / "Contents.json").write_text(json.dumps({
        "data": [{"filename": "parts.json", "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print(f"wrote {len(manifest)} parts, {total} triangles, {len(blob) // 1024} KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
