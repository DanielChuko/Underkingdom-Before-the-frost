#!/usr/bin/env python3
"""Fit a static, multi-part glTF character onto the game's procedural skeleton,
keeping the model's own proportions, textures and blend shapes.

    python3 tools/rig_model_v2.py assets/models/source/medieval_guard_v5.glb \\
        assets/models/medieval_guard_v5_rigged.glb

Writes two files:
  <out>.glb       one node per part named "<joint>__<part>", geometry in that
                  joint's local space (the game re-parents each part)
  <out>.rig.json  the model's own joint positions, which the game uses to build
                  the skeleton for this character instead of its default one

What it does:
- Turns the model to face -Z (the game's forward).
- Finds shoulder, elbow, wrist, hip, knee and ankle from the limb parts, and
  swings each limb segment to hang straight down from its joint.
- Splits single-piece legs at the knee (with a little overlap so no gap opens
  when the knee bends) and splits a mail or cloth skirt into front and back
  panels that swing out of the way of the legs.
- Keeps UVs, materials, the texture and the face's blend shapes (jawOpen,
  eyeBlink...) so the game can animate speech and blinking.

The glTF is read and written directly (no third-party mesh library), so
nothing in the source is lost by a round trip.
"""
import json
import re
import struct
import sys

import numpy as np

COMP = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


def read_glb(path):
    b = open(path, "rb").read()
    json_len = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20:20 + json_len])
    bin_start = 20 + json_len + 8
    return j, b[bin_start:]


def accessor(j, binary, index):
    a = j["accessors"][index]
    view = j["bufferViews"][a["bufferView"]]
    dtype = COMP[a["componentType"]]
    n = NCOMP[a["type"]]
    offset = view.get("byteOffset", 0) + a.get("byteOffset", 0)
    stride = view.get("byteStride", 0)
    item = np.dtype(dtype).itemsize * n
    if stride and stride != item:
        raw = np.frombuffer(binary, dtype=np.uint8, count=stride * a["count"], offset=offset)
        arr = np.stack([np.frombuffer(raw[i * stride:i * stride + item].tobytes(), dtype=dtype) for i in range(a["count"])])
    else:
        arr = np.frombuffer(binary, dtype=dtype, count=a["count"] * n, offset=offset).reshape(a["count"], n)
    return arr.copy()


class Writer:
    def __init__(self):
        self.chunks = []
        self.size = 0
        self.views = []
        self.accessors = []

    def view(self, data, target=None):
        pad = (-self.size) % 4
        if pad:
            self.chunks.append(b"\0" * pad)
            self.size += pad
        v = {"buffer": 0, "byteOffset": self.size, "byteLength": len(data)}
        if target:
            v["target"] = target
        self.chunks.append(data)
        self.size += len(data)
        self.views.append(v)
        return len(self.views) - 1

    def add(self, arr, kind):
        arr = np.ascontiguousarray(arr)
        if kind == "SCALAR":
            arr = arr.astype(np.uint32).reshape(-1)
            view = self.view(arr.tobytes(), 34963)
            acc = {"bufferView": view, "componentType": 5125, "count": int(arr.size), "type": "SCALAR"}
        else:
            arr = arr.astype(np.float32)
            view = self.view(arr.tobytes(), 34962)
            acc = {"bufferView": view, "componentType": 5126, "count": int(arr.shape[0]), "type": kind}
            if kind == "VEC3":
                acc["min"] = arr.min(axis=0).tolist()
                acc["max"] = arr.max(axis=0).tolist()
        self.accessors.append(acc)
        return len(self.accessors) - 1


def axis_ends(v, inset=0.6):
    c = v.mean(axis=0)
    _, _, vt = np.linalg.svd(v - c)
    a = vt[0]
    if a[1] > 0:
        a = -a
    t = (v - c) @ a
    radial = np.linalg.norm((v - c) - np.outer(t, a), axis=1).mean()
    return c + a * (t.min() + radial * inset), c + a * (t.max() - radial * inset)


def rotation_to(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


def side_of(name):
    n = name.lower()
    # The source faces +Z; its "Right" side sits at -X and, turned to face -Z,
    # lands at +X, which is the rig's right.
    if re.search(r"\bright\b", n):
        return "r"
    if re.search(r"\bleft\b", n):
        return "l"
    return None


def classify(name):
    n = name.lower()
    s = side_of(name)
    if s:
        if "sleeve" in n or "upper arm" in n or "shoulder" in n:
            return s + "_upper"
        if any(k in n for k in ("cuff", "forearm", "vambrace", "glove", "gauntlet", "hand")):
            return s + "_fore"
        if any(k in n for k in ("chausses", "leg", "hose", "trouser")):
            return s + "_leg"
        if any(k in n for k in ("sabaton", "boot", "shoe", "foot")):
            return s + "_foot"
    if "skirt" in n or "tunic panel" in n:
        return "skirt"
    if "belt" in n or "pouch" in n:
        return "pelvis"
    if any(k in n for k in ("coat", "hauberk", "surcoat", "gambeson", "torso")):
        return "chest"
    return "head"


def main(src, dst):
    j, binary = read_glb(src)
    parts = {}
    for node in j["nodes"]:
        if "mesh" not in node:
            continue
        mesh = j["mesh" + "es"][node["mesh"]]
        prim = mesh["primitives"][0]
        pos = accessor(j, binary, prim["attributes"]["POSITION"]).astype(np.float64)
        pos[:, 0] *= -1  # face -Z
        pos[:, 2] *= -1
        p = {
            "name": node["name"], "pos": pos, "prim": prim, "mesh": mesh,
            "uv": accessor(j, binary, prim["attributes"]["TEXCOORD_0"]) if "TEXCOORD_0" in prim["attributes"] else None,
            "idx": accessor(j, binary, prim["indices"]).reshape(-1) if "indices" in prim else np.arange(len(pos)),
            "targets": [],
        }
        for t in prim.get("targets", []):
            d = accessor(j, binary, t["POSITION"]).astype(np.float64)
            d[:, 0] *= -1
            d[:, 2] *= -1
            p["targets"].append(d)
        parts[node["name"]] = p

    def pts(kind, skip=()):
        ks = [p for p in parts.values() if classify(p["name"]) == kind and not any(k in p["name"].lower() for k in skip)]
        return np.vstack([p["pos"] for p in ks]) if ks else None

    # --- The model's own joints ------------------------------------------------------
    joints = {}
    for s in ("l", "r"):
        up, leg, foot = pts(s + "_upper"), pts(s + "_leg"), pts(s + "_foot")
        # The forearm without the hand: the wrist is where the glove begins.
        fore = pts(s + "_fore", skip=("glove", "gauntlet", "hand"))
        s_top, s_bot = axis_ends(up)
        f_top, f_bot = axis_ends(fore)
        joints[s + "_shoulder"] = s_top
        joints[s + "_elbow"] = (s_bot + f_top) * 0.5
        joints[s + "_wrist"] = f_bot
        l_top, l_bot = axis_ends(leg, inset=0.3)
        hip = l_top + np.array([0.0, 0.07, 0.0])  # the hip joint sits up inside the skirt
        ankle = l_bot
        joints[s + "_hip"] = hip
        joints[s + "_knee"] = (hip + ankle) * 0.5 + np.array([0.0, 0.0, -0.01])
        joints[s + "_ankle"] = ankle
        joints[s + "_sole"] = foot[:, 1].min()
    hip_y = (joints["l_hip"][1] + joints["r_hip"][1]) * 0.5
    sh_y = (joints["l_shoulder"][1] + joints["r_shoulder"][1]) * 0.5
    face = [p for p in parts.values() if p["targets"]]
    chin_y = face[0]["pos"][:, 1].min() if face else sh_y + 0.12
    joints["pelvis"] = np.array([0.0, hip_y + 0.02, 0.0])
    joints["chest"] = np.array([0.0, hip_y + (sh_y - hip_y) * 0.45, 0.0])
    joints["neck"] = np.array([0.0, sh_y + 0.04, 0.0])
    joints["head"] = np.array([0.0, chin_y + 0.03, 0.0])
    joints["front_panel"] = joints["pelvis"] + np.array([0.0, -0.02, 0.0])
    joints["back_panel"] = joints["front_panel"]

    # --- Re-express every part in its joint's space ----------------------------------
    w = Writer()
    out_nodes = []
    out_meshes = []

    def emit(name, joint, pos, part, faces, rot=None, translation=None):
        used = np.unique(faces)
        remap = np.full(len(pos), -1, dtype=np.int64)
        remap[used] = np.arange(len(used))
        prim = {"attributes": {"POSITION": w.add(pos[used], "VEC3")}, "indices": w.add(remap[faces], "SCALAR"),
                "material": part["prim"].get("material", 0)}
        if part["uv"] is not None:
            prim["attributes"]["TEXCOORD_0"] = w.add(part["uv"][used], "VEC2")
        mesh = {"name": name, "primitives": [prim]}
        if part["targets"]:
            prim["targets"] = []
            for d in part["targets"]:
                dd = d[used] @ rot.T if rot is not None else d[used]
                prim["targets"].append({"POSITION": w.add(dd, "VEC3")})
            mesh["weights"] = [0.0] * len(part["targets"])
            if "extras" in part["mesh"]:
                mesh["extras"] = part["mesh"]["extras"]
        out_meshes.append(mesh)
        node = {"name": f"{joint}__{name}", "mesh": len(out_meshes) - 1}
        if translation is not None:
            node["translation"] = [float(x) for x in translation]
        out_nodes.append(node)

    for p in parts.values():
        kind = classify(p["name"])
        faces = p["idx"].reshape(-1, 3)
        v = p["pos"]
        if kind.endswith(("_upper", "_fore")):
            s = kind[0]
            top = joints[s + "_shoulder"] if kind.endswith("_upper") else joints[s + "_elbow"]
            end = joints[s + "_elbow"] if kind.endswith("_upper") else joints[s + "_wrist"]
            rot = rotation_to(end - top, np.array([0.0, -1.0, 0.0]))
            joint = s + ("_shoulder" if kind.endswith("_upper") else "_elbow")
            emit(p["name"], joint, (v - top) @ rot.T, p, faces, rot)
        elif kind.endswith(("_leg", "_foot")):
            s = kind[0]
            hip, knee, ankle = joints[s + "_hip"], joints[s + "_knee"], joints[s + "_ankle"]
            r_thigh = rotation_to(knee - hip, np.array([0.0, -1.0, 0.0]))
            r_shin = rotation_to(ankle - knee, np.array([0.0, -1.0, 0.0]))
            if kind.endswith("_foot"):
                emit(p["name"], s + "_knee", (v - knee) @ r_shin.T, p, faces, r_shin)
                continue
            # Split at the knee; triangles within the overlap band go to both halves.
            cy = v[faces].mean(axis=1)[:, 1]
            band = 0.025
            emit(p["name"] + " upper", s + "_hip", (v - hip) @ r_thigh.T, p, faces[cy > knee[1] - band], r_thigh)
            emit(p["name"] + " lower", s + "_knee", (v - knee) @ r_shin.T, p, faces[cy < knee[1] + band], r_shin)
        elif kind == "skirt":
            # Front half on the front panel, back half on the back panel (the rig's front is -Z).
            cz = v[faces].mean(axis=1)[:, 2]
            origin = joints["front_panel"]
            emit(p["name"] + " front", "front_panel", v - origin, p, faces[cz <= 0.0])
            emit(p["name"] + " back", "back_panel", v - origin, p, faces[cz > 0.0])
        else:
            joint = kind
            origin = joints[joint]
            if "mouth" in p["name"].lower():
                centre = v.mean(axis=0)
                emit(p["name"], joint, v - centre, p, faces, None, centre - origin)
            else:
                emit(p["name"], joint, v - origin, p, faces)

    # --- Copy images, textures, materials and samplers -------------------------------
    images = []
    for im in j.get("images", []):
        view = j["bufferViews"][im["bufferView"]]
        data = binary[view.get("byteOffset", 0):view.get("byteOffset", 0) + view["byteLength"]]
        images.append({"bufferView": w.view(data), "mimeType": im.get("mimeType", "image/png")})
    out = {
        "asset": {"version": "2.0", "generator": "underkingdom tools/rig_model_v2.py"},
        "scene": 0,
        "scenes": [{"nodes": [len(out_nodes)]}],
        "nodes": out_nodes + [{"name": "model", "children": list(range(len(out_nodes)))}],
        "meshes": out_meshes,
        "materials": j.get("materials", []),
        "textures": j.get("textures", []),
        "images": images,
        "accessors": w.accessors,
        "bufferViews": w.views,
        "buffers": [{"byteLength": w.size}],
    }
    if "samplers" in j:
        out["samplers"] = j["samplers"]
    blob = b"".join(w.chunks)
    blob += b"\0" * ((-len(blob)) % 4)
    out["buffers"][0]["byteLength"] = len(blob)
    js = json.dumps(out, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    glb = struct.pack("<4sII", b"glTF", 2, 12 + 8 + len(js) + 8 + len(blob))
    glb += struct.pack("<I4s", len(js), b"JSON") + js + struct.pack("<I4s", len(blob), b"BIN\0") + blob
    open(dst, "wb").write(glb)

    rig = {k: [round(float(x), 4) for x in np.atleast_1d(v)] for k, v in joints.items()}
    rig_path = re.sub(r"\.glb$", ".rig.json", dst)
    json.dump(rig, open(rig_path, "w"), indent=1)
    print(f"wrote {dst} ({len(out_nodes)} parts) and {rig_path}")
    for k in ("pelvis", "chest", "neck", "head", "l_shoulder", "l_elbow", "l_wrist", "l_hip", "l_knee", "l_ankle"):
        print(f"  {k:11s} {np.round(joints[k], 3)}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
