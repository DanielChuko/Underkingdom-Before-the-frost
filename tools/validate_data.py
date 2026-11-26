#!/usr/bin/env python3
"""Validate dialogue and quest data.

Checks every dialogue file in data/dialogue/ (except barks.json) for:
  * a valid "start" node and "nodes" table
  * every "next" / choice / branch target existing (or "end")
  * every node being reachable from "start"
  * every shown line having a speaker
and checks data/quests.json for unique ids and well-formed objectives.

Events that quests wait for but no dialogue raises are listed as info: they
are raised from game code (see scripts/) or belong to content not built yet.

Usage: python3 tools/validate_data.py   (exit code 1 on errors)
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
DIALOGUE_DIR = ROOT / "data" / "dialogue"
QUESTS = ROOT / "data" / "quests.json"
CHARACTERS = ROOT / "data" / "characters.json"
COLOR_KEYS = {"skin", "hair", "eyes", "shirt", "mail", "gambeson", "gloves", "surcoat", "emblem", "trousers",
              "boots", "belt", "robe", "cape", "collar", "apron", "helmet", "crown", "cap"}

errors: list[str] = []
raised_events: set[str] = set()


def err(msg: str) -> None:
    errors.append(msg)


def targets(node: dict) -> list[str]:
    out = []
    if "next" in node:
        out.append(node["next"])
    for c in node.get("choices", []):
        out.append(c.get("next", "end"))
    for b in node.get("branch", []):
        out.append(b.get("next", "end"))
    if "text" in node and "next" not in node and not node.get("choices"):
        out.append("end")
    return out


def collect_events(x: dict) -> None:
    for e in x.get("events", []):
        raised_events.add(e)


def check_dialogue(path: pathlib.Path) -> None:
    name = path.name
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        err(f"{name}: invalid JSON: {e}")
        return
    if data.get("id") != path.stem:
        err(f"{name}: 'id' should be '{path.stem}'")
    nodes = data.get("nodes")
    start = data.get("start")
    if not isinstance(nodes, dict) or not nodes:
        err(f"{name}: missing 'nodes'")
        return
    if start not in nodes:
        err(f"{name}: start node '{start}' does not exist")
        return
    collect_events(data.get("on_end", {}))
    for nid, node in nodes.items():
        collect_events(node)
        for c in node.get("choices", []):
            collect_events(c)
            if not c.get("text"):
                err(f"{name}:{nid}: choice without text")
        if "text" in node and not node.get("speaker"):
            err(f"{name}:{nid}: line without a speaker")
        if "text" not in node and not node.get("branch") and "next" not in node:
            err(f"{name}:{nid}: node has no text, branch or next")
        if "choices" in node and "next" in node:
            err(f"{name}:{nid}: has both 'choices' and 'next' ('next' is ignored)")
        for t in targets(node):
            if t != "end" and t not in nodes:
                err(f"{name}:{nid}: points to missing node '{t}'")
    seen, todo = set(), [start]
    while todo:
        nid = todo.pop()
        if nid in seen or nid not in nodes:
            continue
        seen.add(nid)
        todo.extend(t for t in targets(nodes[nid]) if t != "end")
    for nid in nodes:
        if nid not in seen:
            err(f"{name}:{nid}: unreachable from start")


def check_barks(path: pathlib.Path) -> None:
    data = json.loads(path.read_text(encoding="utf-8"))
    for key, lines in data.items():
        if not isinstance(lines, list) or not lines or not all(isinstance(s, str) and s for s in lines):
            err(f"barks.json:{key}: must be a non-empty list of strings")


def check_quests() -> set[str]:
    data = json.loads(QUESTS.read_text(encoding="utf-8"))
    ids, waited = set(), set()
    for q in data.get("quests", []):
        qid = q.get("id")
        if not qid or qid in ids:
            err(f"quests.json: missing or duplicate quest id '{qid}'")
        ids.add(qid)
        if not q.get("title"):
            err(f"quests.json:{qid}: missing title")
        objs = q.get("objectives", [])
        if not objs:
            err(f"quests.json:{qid}: no objectives")
        for o in objs:
            if not o.get("text") or not o.get("complete_on"):
                err(f"quests.json:{qid}: objective needs 'text' and 'complete_on'")
            else:
                waited.add(o["complete_on"])
    return waited


def check_characters() -> None:
    import re
    data = json.loads(CHARACTERS.read_text(encoding="utf-8"))
    for cid, look in data.items():
        if cid.startswith("_"):
            continue
        for key, value in look.items():
            if key in COLOR_KEYS and not re.fullmatch(r"#[0-9a-fA-F]{6}", str(value)):
                err(f"characters.json:{cid}.{key}: '{value}' is not a #rrggbb colour")
    used = set()
    for script in (ROOT / "scripts").rglob("*.gd"):
        used.update(re.findall(r'G\.npc\([^\n]*"([a-z_]+)"\)', script.read_text(encoding="utf-8")))
    for cid in sorted(used - set(data)):
        err(f"scripts use character look '{cid}' which is missing from characters.json")


def main() -> int:
    for path in sorted(DIALOGUE_DIR.glob("*.json")):
        if path.name == "barks.json":
            check_barks(path)
        else:
            check_dialogue(path)
    waited = check_quests()
    check_characters()
    for e in sorted(waited - raised_events):
        print(f"info: quest event '{e}' is not raised by any dialogue (game code or future content)")
    if errors:
        print("\n".join(f"error: {e}" for e in errors))
        return 1
    print("data OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
