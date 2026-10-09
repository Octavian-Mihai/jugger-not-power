#!/usr/bin/env python3
"""Convert Resources/ExerciseLibrary markdown into JSON + flat images for the app."""
import json, re, shutil, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "Resources" / "ExerciseLibrary"
OUT = ROOT / "Ferrum" / "Resources"
IMG_OUT = OUT / "ExerciseImages"

def slug(s):
    s = s.lower().replace("&", "and").replace("’", "").replace("'", "")
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")

ALIASES = {"chest": "chest-pectorals"}

# Name-based inference is a first guess; these ids are corrected by hand.
EQUIPMENT_OVERRIDES = {
    "chest-supported-t-bar-row": "machine", "goblet-squat": "dumbbell", "cossack-squat": "bodyweight",
    "bulgarian-split-squat": "dumbbell", "single-leg-romanian-deadlift": "dumbbell",
    "hip-thrust": "bodyweight", "hammer-curl": "dumbbell", "concentration-curl": "dumbbell",
    "spider-curl": "dumbbell", "wrist-curl": "dumbbell", "reverse-wrist-curl": "dumbbell",
    "nordic-curl": "bodyweight", "preacher-curl": "dumbbell",
}

def equipment_for(name, pattern):
    n = name.lower()
    rules = [
        ("trap bar", "trap bar"), ("safety bar", "safety bar"), ("smith", "smith machine"),
        ("barbell", "barbell"), ("dumbbell", "dumbbell"), ("kettlebell", "kettlebell"),
        ("cable", "cable"), ("machine", "machine"), ("landmine", "landmine"), ("zercher", "barbell"),
        ("band", "band"), ("rack pull", "barbell"), ("face pull", "cable"), ("pushdown", "cable"),
        ("leg extension", "machine"), ("leg curl", "machine"), ("calf raise", "machine"),
        ("skull crusher", "barbell"), ("lateral raise", "dumbbell"), ("front raise", "dumbbell"),
        ("rear delt fly", "dumbbell"), ("glute kickback", "cable"), ("step-up", "dumbbell"),
        ("lunge", "dumbbell"), ("box jump", "bodyweight"), ("ab wheel", "ab wheel"),
        ("sit-up", "bodyweight"), ("russian twist", "bodyweight"), ("tibialis", "bodyweight"),
        ("gripper", "gripper"), ("external rotation", "cable"), ("internal rotation", "cable"),
        ("assisted", "machine"), ("pulldown", "cable"), ("pec deck", "machine"), ("leg press", "machine"),
        ("hack squat", "machine"), ("belt squat", "machine"), ("pendulum", "machine"),
        ("push-up", "bodyweight"), ("pull-up", "bodyweight"), ("chin-up", "bodyweight"),
        ("dips", "bodyweight"), ("pistol", "bodyweight"), ("sissy", "bodyweight"),
        ("inverted row", "bodyweight"), ("plank", "bodyweight"), ("hanging", "bodyweight"),
        ("glute-ham", "machine"), ("reverse hyper", "machine"), ("back extension", "machine"),
        ("bench press", "barbell"), ("squat", "barbell"), ("deadlift", "barbell"),
        ("good morning", "barbell"), ("hip thrust", "barbell"), ("curl", "barbell"),
        ("row", "barbell"), ("press", "barbell"), ("clean", "barbell"), ("snatch", "barbell"),
        ("farmer", "dumbbell"), ("get-up", "kettlebell"), ("swing", "kettlebell"),
    ]
    for key, eq in rules:
        if key in n:
            return eq, False
    return "bodyweight", True  # uncertain

# ---- muscles
def real_suffix(path):
    head = path.read_bytes()[:12]
    if head.startswith(b"\x89PNG"): return ".png"
    if head.startswith(b"\xff\xd8"): return ".jpg"
    return path.suffix.lower()

def parse_muscles():
    text = (SRC / "muscles.md").read_text()
    out = []
    for block in re.split(r"\n(?=## )", text)[1:]:
        name = block.splitlines()[0][3:].strip()
        img = re.search(r"!\[.*?\]\((.*?)\)", block)
        def field(label):
            m = re.search(rf"- \*\*{label}:\*\* (.*)", block)
            return m.group(1).strip() if m else ""
        out.append({
            "id": slug(name), "name": name, "region": field("Region"),
            "split": field("Training split"), "role": field("Training role"),
            "function": field("Function"),
            "examples": [x.strip() for x in field("Example exercises").split(",") if x.strip()],
            "patterns": [x.strip() for x in field("Movement patterns").split(",") if x.strip()],
            "image": Path(img.group(1)).name if img else None,
        })
    return out

# ---- catalog (part 3)
def parse_catalog():
    text = (SRC / "learn-section.md").read_text()
    part = text.split("# Part 3", 1)[1].split("# Part 4", 1)[0]
    cat = {}
    for block in re.split(r"\n(?=### )", part)[1:]:
        name = block.splitlines()[0][4:].strip()
        m = re.search(r"\*\*Primary:\*\* (.*?) · \*\*Secondary:\*\* (.*)", block)
        prim = [slug(x) for x in m.group(1).split(",") if slug(x)] if m else []
        sec = [slug(x) for x in m.group(2).split(",") if slug(x)] if m else []
        prim = [ALIASES.get(x, x) for x in prim]
        sec = [ALIASES.get(x, x) for x in sec]
        cue_lines = [l for l in block.splitlines()[1:] if l.strip() and not l.startswith("**")]
        cat[slug(name)] = {"primary": prim, "secondary": sec, "cue": " ".join(cue_lines).strip()}
    return cat

# ---- patterns + images
def parse_patterns():
    text = (SRC / "movement-patterns.md").read_text()
    items = []
    for block in re.split(r"\n(?=## )", text)[1:]:
        title = block.splitlines()[0][3:]
        pattern = re.sub(r"\s*\(\d+\)$", "", title).strip()
        if pattern.startswith("Guide images"):
            continue
        for m in re.finditer(r"- \*\*(.+?)\*\* \((\w+)\) — (\S+)", block):
            items.append((pattern, m.group(1), m.group(2), m.group(3)))
    return items

def parse_rir():
    text = (SRC / "learn-section.md").read_text().split("# Part 4", 1)[1]
    out = []
    for block in re.split(r"\n(?=## )", text)[1:]:
        title = block.splitlines()[0][3:].strip()
        body = " ".join(l.strip() for l in block.splitlines()[1:] if l.strip())
        out.append({"title": title, "body": body})
    return out

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    if IMG_OUT.exists(): shutil.rmtree(IMG_OUT)
    IMG_OUT.mkdir()
    muscles = parse_muscles()
    muscle_ids = {m["id"] for m in muscles}
    catalog = parse_catalog()
    exercises, warnings = [], []
    for pattern, name, split, img in parse_patterns():
        eid = slug(name)
        c = catalog.get(eid)
        eq, uncertain = equipment_for(name, pattern)
        if eid in EQUIPMENT_OVERRIDES: eq = EQUIPMENT_OVERRIDES[eid]
        if not c:
            warnings.append(f"no catalog entry: {name}")
            c = {"primary": [], "secondary": [], "cue": ""}
        for mid in c["primary"] + c["secondary"]:
            if mid not in muscle_ids:
                warnings.append(f"{name}: unknown muscle '{mid}'")
        src = SRC / img
        image = None
        if src.exists():
            image = f"{eid}{real_suffix(src)}"
            shutil.copy(src, IMG_OUT / image)
        else:
            warnings.append(f"missing image: {img}")
        exercises.append({"id": eid, "name": name, "pattern": pattern, "split": split,
                          "primary": c["primary"], "secondary": c["secondary"], "cue": c["cue"],
                          "equipment": eq, "equipmentGuess": uncertain, "image": image})
    for m in muscles:
        if m["image"]:
            src = SRC / "guide-images" / m["image"]
            if src.exists(): 
                name = "guide-" + Path(m["image"]).stem + real_suffix(src)
                shutil.copy(src, IMG_OUT / name)
                m["image"] = name[len("guide-"):]
    (OUT / "exercises.json").write_text(json.dumps(exercises, indent=1, ensure_ascii=False))
    (OUT / "muscles.json").write_text(json.dumps(muscles, indent=1, ensure_ascii=False))
    (OUT / "rir.json").write_text(json.dumps(parse_rir(), indent=1, ensure_ascii=False))
    # Compact library for the program-builder website (opens from file://, so ship it as a script).
    muscle_names = {m["id"]: m["name"] for m in muscles}
    web = [{"id": e["id"], "name": e["name"], "pattern": e["pattern"], "equipment": e["equipment"],
            "muscles": [muscle_names.get(x, x) for x in e["primary"]], "primary": e["primary"]} for e in exercises]
    web_dir = ROOT / "web"; web_dir.mkdir(exist_ok=True)
    (web_dir / "exercises-data.js").write_text("window.FERRUM_EXERCISES = " + json.dumps(web, ensure_ascii=False, separators=(",", ":")) + ";\n")
    guessed = [e["name"] for e in exercises if e["equipmentGuess"]]
    print(f"{len(exercises)} exercises, {len(muscles)} muscles")
    print(f"equipment guessed (review): {guessed}")
    for w in warnings: print("WARN", w)

main()
