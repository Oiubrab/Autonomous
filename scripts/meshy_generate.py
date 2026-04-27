#!/usr/bin/env python3
"""
Generate Litta's rigged animations and weapons via Meshy API.

Usage:
    python3 scripts/meshy_generate.py

Outputs:
    assets/characters/litta/litta_<anim>.glb  (one per animation)
    assets/weapons/weapon_blade.glb
    assets/weapons/weapon_gun.glb
"""

import json
import os
import sys
import time
from pathlib import Path

import requests

API_KEY = os.environ.get("MESHY_API_KEY", "msy_w7bZJgTP3L7iAcILZSP83e8EHK9tlgC1DURF")
BASE = "https://api.meshy.ai"
HEADERS = {"Authorization": f"Bearer {API_KEY}"}

PROJECT = Path(__file__).parent.parent
LITTA_DIR = PROJECT / "assets" / "characters" / "litta"
WEAPON_DIR = PROJECT / "assets" / "weapons"

# Animations to generate: internal_name -> action_id
ANIMATIONS = {
    "idle":         0,    # Idle
    "walk":         30,   # Casual_Walk
    "run":          14,   # Run_02
    "dead":         8,    # Dead
    "jump":         466,  # Regular_Jump
    "run_jump":     463,  # Run_and_Jump
    "dodge":        158,  # Roll_Dodge
    "melee_attack": 199,  # Weapon_Combo
    "shoot":        104,  # Side_Shot
}

WEAPONS = {
    "weapon_blade": (
        "A biomechanical blade weapon, organic and grown-looking, made of dark chitinous "
        "material with bioluminescent veins running along the edge, alien in design, "
        "sci-fi, no handle guard, sleek and menacing, game asset, centered, no background"
    ),
    "weapon_gun": (
        "A bio-organic plasma pistol, alien design, made of dark bone-like material "
        "with glowing cyan bioluminescent nodes, bulbous organic shapes, living weapon, "
        "sci-fi, game asset, centered, no background"
    ),
}


def poll(url: str, label: str, interval: int = 8) -> dict:
    """Poll a task URL until SUCCEEDED or FAILED."""
    while True:
        r = requests.get(url, headers=HEADERS)
        r.raise_for_status()
        data = r.json()
        status = data.get("status", "")
        progress = data.get("progress", 0)
        print(f"  {label}: {status} {progress}%", end="\r", flush=True)
        if status == "SUCCEEDED":
            print(f"  {label}: SUCCEEDED          ")
            return data
        if status in ("FAILED", "CANCELED"):
            print(f"\n  {label}: {status}")
            print(json.dumps(data, indent=2))
            sys.exit(1)
        time.sleep(interval)


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    r = requests.get(url, stream=True)
    r.raise_for_status()
    with open(dest, "wb") as f:
        for chunk in r.iter_content(chunk_size=65536):
            f.write(chunk)
    print(f"  Saved: {dest.relative_to(PROJECT)}")


LITTA_PROMPT = (
    "An ice warrior woman in a T-pose, biomechanical armor with icy crystal shards, "
    "alien sci-fi aesthetic, dark chitinous plating with bioluminescent blue veins, "
    "full body humanoid, game character, front-facing, neutral expression, "
    "symmetrical, standing upright with arms out, no background"
)


def generate_litta_base() -> str:
    """Generate a fresh Litta mesh via text-to-3D and return the task ID for rigging."""
    print("Generating Litta base mesh (preview) ...")
    r = requests.post(
        f"{BASE}/openapi/v2/text-to-3d",
        headers=HEADERS,
        json={
            "mode": "preview",
            "prompt": LITTA_PROMPT,
            "ai_model": "meshy-5",
            "topology": "quad",
            "target_polycount": 15000,
        },
    )
    if not r.ok:
        print(f"  text-to-3d error {r.status_code}: {r.text}")
        sys.exit(1)
    preview_id = r.json()["result"]
    print(f"  Preview task: {preview_id}")
    poll(f"{BASE}/openapi/v2/text-to-3d/{preview_id}", "Litta preview")

    print("Generating Litta base mesh (refine) ...")
    r = requests.post(
        f"{BASE}/openapi/v2/text-to-3d",
        headers=HEADERS,
        json={"mode": "refine", "preview_task_id": preview_id},
    )
    if not r.ok:
        print(f"  refine error {r.status_code}: {r.text}")
        sys.exit(1)
    refine_id = r.json()["result"]
    print(f"  Refine task: {refine_id}")
    result = poll(f"{BASE}/openapi/v2/text-to-3d/{refine_id}", "Litta refine", interval=12)

    # Also download the base mesh for reference
    base_dest = LITTA_DIR / "litta_base.glb"
    download(result["model_urls"]["glb"], base_dest)

    return refine_id


def rig_litta() -> str:
    base_task_id = generate_litta_base()

    print("Creating rigging task ...")
    r = requests.post(
        f"{BASE}/openapi/v1/rigging",
        headers=HEADERS,
        json={"input_task_id": base_task_id, "height_meters": 1.75},
    )
    if not r.ok:
        print(f"  Rigging error {r.status_code}: {r.text}")
        sys.exit(1)
    task_id = r.json()["result"]
    print(f"  Rigging task: {task_id}")

    result = poll(f"{BASE}/openapi/v1/rigging/{task_id}", "Rigging")
    return task_id


def generate_animations(rig_task_id: str) -> None:
    for name, action_id in ANIMATIONS.items():
        dest = LITTA_DIR / f"litta_{name}.glb"
        if dest.exists():
            print(f"  Skipping {name} (already exists)")
            continue

        print(f"Generating animation: {name} (action_id={action_id}) ...")
        r = requests.post(
            f"{BASE}/openapi/v1/animations",
            headers=HEADERS,
            json={"rig_task_id": rig_task_id, "action_id": action_id},
        )
        r.raise_for_status()
        task_id = r.json()["result"]

        result = poll(f"{BASE}/openapi/v1/animations/{task_id}", name)
        glb_url = result["result"]["animation_glb_url"]
        download(glb_url, dest)


def generate_weapon(name: str, prompt: str) -> None:
    dest = WEAPON_DIR / f"{name}.glb"
    if dest.exists():
        print(f"  Skipping {name} (already exists)")
        return

    print(f"Generating weapon: {name} ...")

    # Preview stage
    r = requests.post(
        f"{BASE}/openapi/v2/text-to-3d",
        headers=HEADERS,
        json={
            "mode": "preview",
            "prompt": prompt,
            "ai_model": "meshy-5",
            "topology": "quad",
            "target_polycount": 10000,
        },
    )
    r.raise_for_status()
    preview_id = r.json()["result"]
    print(f"  Preview task: {preview_id}")
    poll(f"{BASE}/openapi/v2/text-to-3d/{preview_id}", f"{name} preview")

    # Refine stage
    r = requests.post(
        f"{BASE}/openapi/v2/text-to-3d",
        headers=HEADERS,
        json={
            "mode": "refine",
            "preview_task_id": preview_id,
        },
    )
    r.raise_for_status()
    refine_id = r.json()["result"]
    print(f"  Refine task: {refine_id}")
    result = poll(f"{BASE}/openapi/v2/text-to-3d/{refine_id}", f"{name} refine", interval=12)

    glb_url = result["model_urls"]["glb"]
    download(glb_url, dest)


RIG_ID_FILE = PROJECT / "scripts" / ".rig_task_id"


def main() -> None:
    print("=== Meshy generation ===\n")

    if RIG_ID_FILE.exists():
        rig_task_id = RIG_ID_FILE.read_text().strip()
        print(f"Reusing rig task: {rig_task_id}")
    else:
        rig_task_id = rig_litta()
        RIG_ID_FILE.write_text(rig_task_id)
    print()

    generate_animations(rig_task_id)
    print()

    for name, prompt in WEAPONS.items():
        generate_weapon(name, prompt)

    print("\nDone. Update LittaModel.gd _SOURCES to reference the new litta_*.glb files.")


if __name__ == "__main__":
    main()
