#!/usr/bin/env python3
"""Fit a static, multi-part character model onto the game's procedural skeleton.

The game's characters are animated in code by a joint rig (scripts/characters/
humanoid.gd). A static model made of separate parts (helmet, upper arm,
forearm, thigh, boot...) can ride on that rig if every part is re-expressed in
the local space of the joint that should carry it. This script does that:

    python3 tools/rig_model.py assets/models/source/medieval_guard.glb \\
        assets/models/medieval_guard_rigged.glb

- Turns the model to face -Z (the game's forward) and scales it to the rig.
- Finds the model's own shoulder, elbow, wrist, hip, knee and ankle from its
  limb parts and swings the arms down from their spread pose to hang along
  the rig's bones, stretching each limb segment to the rig's bone length.
- Writes one node per part named "<joint>__<part>", with vertices already in
  that joint's local space, so the game only has to re-parent each part.
- Adds smooth vertex normals (the source has none).
"""
import re
import sys

import numpy as np
import trimesh

# The rig's rest pose (scripts/characters/humanoid.gd), feet at the origin,
# facing -Z. Left is -X.
HIP_Y = 0.95
JOINTS = {
    "pelvis": (0.0, HIP_Y, 0.0),
    "front_panel": (0.0, HIP_Y - 0.02, 0.0),
    "back_panel": (0.0, HIP_Y - 0.02, 0.0),
    "chest": (0.0, HIP_Y + 0.28, 0.0),
    "neck": (0.0, HIP_Y + 0.53, 0.0),
    "head": (0.0, HIP_Y + 0.62, 0.0),
    "l_shoulder": (-0.2, HIP_Y + 0.47, 0.0),
    "r_shoulder": (0.2, HIP_Y + 0.47, 0.0),
    "l_elbow": (-0.2, HIP_Y + 0.18, 0.0),
    "r_elbow": (0.2, HIP_Y + 0.18, 0.0),
    "l_hip": (-0.095, HIP_Y - 0.02, 0.0),
    "r_hip": (0.095, HIP_Y - 0.02, 0.0),
    "l_knee": (-0.095, HIP_Y - 0.46, 0.0),
    "r_knee": (0.095, HIP_Y - 0.46, 0.0),
}
BONE = {"shoulder": 0.29, "elbow": 0.255, "hip": 0.44}


def joint_for(name):
    """Which rig joint carries a part, from the part's name, and the side."""
    m = re.search(r" (-?1)(?: |$)", name)
    side = None
    if m:
        # The source faces +Z; turned to face -Z, its +X side becomes the rig's left.
        side = "l" if m.group(1) == "1" else "r"
    n = name.lower()
    if side:
        if any(k in n for k in ("shoulder", "upper arm")):
            return f"{side}_shoulder"
        if any(k in n for k in ("forearm", "vambrace", "bracer", "glove", "thumb")):
            return f"{side}_elbow"
        if "thigh" in n:
            return f"{side}_hip"
        if any(k in n for k in ("mail leg", "boot", "knee")):
            return f"{side}_knee"
    if "tunic panel" in n:
        return None  # decided by which way it faces, below
    if any(k in n for k in ("belt", "buckle", "pouch", "clasp")):
        return "pelvis"
    if any(k in n for k in ("hauberk", "surcoat", "shield")):
        return "chest"
    # Everything else (face, helmet, and the mail coif that wraps the head)
    # turns with the head.
    return "head"


def axis_ends(v):
    """Principal axis of a limb part and its two ends, top end first."""
    c = v.mean(axis=0)
    _, _, vt = np.linalg.svd(v - c)
    a = vt[0]
    if a[1] > 0:
        a = -a  # point down the limb
    t = (v - c) @ a
    radial = np.linalg.norm((v - c) - np.outer(t, a), axis=1).mean()
    top = c + a * (t.min() + radial * 0.6)
    bottom = c + a * (t.max() - radial * 0.6)
    return top, bottom


def rotation_to(a, b):
    """Rotation matrix turning unit vector a onto unit vector b."""
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1.0 / (1.0 + c))


def main(src, dst):
    scene = trimesh.load(src, force="scene")
    parts = {}
    for node in scene.graph.nodes_geometry:
        transform, geom = scene.graph[node]
        mesh = scene.geometry[geom].copy()
        mesh.apply_transform(transform)
        # Face -Z: turn half way round the vertical axis.
        mesh.vertices[:, 0] *= -1
        mesh.vertices[:, 2] *= -1
        parts[node] = mesh

    all_v = np.vstack([m.vertices for m in parts.values()])
    # Uniform scale from the model's hips to the rig's hips.
    thighs = [m for n, m in parts.items() if "thigh" in n.lower()]
    model_hip_y = max(m.vertices[:, 1].max() for m in thighs)
    scale = (HIP_Y - 0.02) / model_hip_y
    print(f"model height {all_v[:, 1].max():.3f} m, scale {scale:.3f}")

    # The model's own limb joints, from its limb parts.
    seg = {}
    for side, src_side in (("l", "1"), ("r", "-1")):
        up = parts[f"Mail upper arm {src_side}"].vertices
        fo = parts[f"Mail forearm {src_side}"].vertices
        th = parts[f"Padded thigh {src_side}"].vertices
        shin = np.vstack([parts[f"Mail leg {src_side}"].vertices, parts[f"Leather boot shaft {src_side}"].vertices])
        s_top, s_bot = axis_ends(up)
        f_top, f_bot = axis_ends(fo)
        elbow = (s_bot + f_top) * 0.5
        hip, _ = axis_ends(th)
        k_top, ankle = axis_ends(shin)
        knee = k_top
        seg[f"{side}_shoulder"] = (s_top, elbow, BONE["shoulder"])
        seg[f"{side}_elbow"] = (elbow, f_bot, BONE["elbow"])
        seg[f"{side}_hip"] = (hip, knee, BONE["hip"])
        # Size the shin so the boot soles land on the floor.
        sole_bottom = parts[f"Boot sole {src_side}"].vertices[:, 1].min()
        below_ankle = (ankle[1] - sole_bottom) * scale
        knee_height = JOINTS[f"{side}_knee"][1]
        seg[f"{side}_knee"] = (knee, ankle, knee_height - 0.005 - below_ankle)

    out = trimesh.Scene()
    for name, mesh in parts.items():
        joint = joint_for(name)
        v = mesh.vertices.copy()
        if joint is None:
            joint = "front_panel" if v[:, 2].mean() < 0 else "back_panel"
        origin = np.array(JOINTS[joint])
        if joint in seg:
            top, bottom, length = seg[joint]
            rot = rotation_to(bottom - top, np.array([0.0, -1.0, 0.0]))
            q = (v - top) @ rot.T
            end = np.linalg.norm(bottom - top)
            stretch = length / end
            # Along the bone the segment stretches to the rig's bone length;
            # whatever lies beyond its ends (hands, feet, shoulder caps) keeps
            # the model's proportions and simply moves with the end.
            y = q[:, 1]
            q[:, 1] = np.where(y > 0, y * scale, np.where(y < -end, -length + (y + end) * scale, y * stretch))
            q[:, 0] *= scale
            q[:, 2] *= scale
            v = q
        else:
            v = v * scale - origin
        mesh.vertices = v
        node_name = f"{joint}__{name}"
        if name == "Mouth":
            centre = mesh.vertices.mean(axis=0)
            mesh.vertices = mesh.vertices - centre
            transform = np.eye(4)
            transform[:3, 3] = centre
            out.add_geometry(mesh, node_name=node_name, geom_name=node_name, transform=transform)
        else:
            out.add_geometry(mesh, node_name=node_name, geom_name=node_name)
    out.export(dst, include_normals=True)
    print("wrote", dst, len(parts), "parts")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
