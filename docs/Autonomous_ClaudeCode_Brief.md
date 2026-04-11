# AUTONOMOUS — Claude Code Development Brief
*High-Level Architecture & Build Order*

---

## Overview for Claude Code

This document is a brief for Claude Code to understand the scope, architecture, and build priorities for **Autonomous** — a Godot-based game with three distinct gameplay tiers, an LLM-powered mechanic, and a central narrative mechanic built around progressive loss of player control.

Read the companion documents **Autonomous_Narrative.md** and **Autonomous_Mechanics.md** before proceeding. This brief assumes familiarity with both.

The developer is a solo practitioner. Scope should be managed carefully. When in doubt, build the simplest version that tests the concept, not the most complete version.

---

## Technology Stack

- **Engine**: Godot 4 (GDScript)
- **LLM**: Anthropic API — `claude-sonnet-4-5` via HTTP from Godot
- **Target platform**: Desktop (Windows/Mac primary)
- **Architecture**: Single project, scene-based, with a central GameState autoload

---

## Core Architectural Principles

### 1. GameState is the source of truth
All persistent state — Litta's degradation level, repeater network health, turn count, empire state, active path — lives in a single `GameState` autoload singleton. No scene should own state that needs to survive a scene transition.

### 2. Scenes are modes, not levels
The three game tiers (galactic map, planetary zoom, action segment) are distinct scenes loaded and unloaded as the player moves between them. A fourth scene type — the sanctum — is a separate mode that can be triggered from the map. Scene transitions should always pass through GameState.

### 3. The degradation system is a global modifier
Litta's degradation level (0.0 to 1.0, where 1.0 is full breakdown) affects multiple systems across multiple scenes. It should be a single value in GameState that all relevant systems read from. Nothing should hardcode degradation thresholds — they should be configurable constants.

### 4. The LLM call is one system among many
The thought-broadcasting mechanic calls the Anthropic API and receives a behaviour config modification. This should be isolated in a single `BroadcastSystem` class. The rest of the game reads from the config; it does not care how the config was produced.

---

## Build Order

Build in this sequence. Each milestone should be playable and testable before moving to the next. Do not build milestone 3 before milestone 2 is working.

---

### Milestone 1 — The Reframe (Action Segment)

**Goal**: Build the opening action segment in a way that makes the player feel they are controlling Litta. Then build the single moment that reveals they are not.

**What to build**:

1. A basic third-person action scene in Godot with a player-controlled character (Litta)
   - WASD movement, basic combat input (attack, dodge)
   - Simple enemy AI — enough to create combat tension
   - A small, contained arena environment (placeholder art is fine)

2. A `GameState` autoload with:
   - `degradation_level: float` (0.0–1.0)
   - `is_reframe_triggered: bool`
   - `active_scene: String`

3. The reframe moment
   - A trigger in the action scene (proximity, story beat, or timer — TBD)
   - On trigger: a visual/audio effect signals the shift
   - UI relabels: player-facing text that previously implied "you are Litta" now implies "you are Folgim"
   - The death condition changes: Litta dying now shows "Litta has fallen — Folgim endures" and continues; a hypothetical Folgim death shows "You died"

**Success criteria**: A playable demo where the player spends ~5 minutes feeling like Litta, then experiences the reframe and understands — without being told — that they have been controlling her from outside.

---

### Milestone 2 — The Degradation System

**Goal**: Make the loss of control over Litta feel physical and progressive.

**What to build**:

1. Degradation modifiers on the action input system:
   ```
   degradation 0.0–0.2: no effect
   degradation 0.2–0.4: input lag (delay inputs by 0.2–0.5s)
   degradation 0.4–0.6: occasional input drift (random direction offset)
   degradation 0.6–0.8: Litta periodically stops and looks around
   degradation 0.8–1.0: Litta acts autonomously; player inputs ignored
   ```

2. A simple `LittaAutonomyBehaviour` script that drives Litta when degradation is high:
   - Wanders, observes environment
   - Reacts to enemies (not necessarily fighting — may avoid or simply watch)
   - At full breakdown: sits, looks at hands, looks around slowly

3. A test mechanism to manually set `degradation_level` during development (a debug slider or console command)

4. A basic mission structure that can increment or decrement degradation based on completion:
   - One placeholder mission that, when failed, raises degradation by 0.2
   - One placeholder mission that, when completed, lowers degradation by 0.1

**Success criteria**: The developer can slide degradation from 0 to 1 and see Litta's responsiveness change meaningfully at each stage.

---

### Milestone 3 — The Galactic Map (Turn-Based Layer)

**Goal**: Build a functional turn-based map that communicates scale and gives the player something to manage between action segments.

**What to build**:

1. A 2D star map scene (top-down, stylised — placeholder art)
   - 10–15 planet nodes, each with a name and basic status (loyalty %, stability %, repeater health %)
   - Clicking a planet opens an info panel
   - A "next turn" button advances the game clock

2. `TurnSystem` autoload:
   - Tracks current turn number
   - On turn advance: runs passive updates on all planets (loyalty drift, repeater decay, anomaly spread)
   - Checks for triggered events (missions, crises, rival Aksjub actions)

3. Repeater network health:
   - Each planet has a `repeater_health: float` (0.0–1.0)
   - Repeater health decays slightly each turn if not maintained
   - Global `network_health` = average of all planet repeater values
   - `network_health` directly sets `GameState.degradation_level` for Litta

4. Anomaly system (basic):
   - Planets near Litta's location can develop `anomaly_level: float`
   - High anomaly = loyalty degradation spreads to neighbouring planets
   - Anomaly grows when `degradation_level` is high (narrative feedback loop)

5. Mission cards:
   - Simple event cards that appear each turn: "Repeater station on [planet] requires maintenance — send resources?"
   - Player accepts or declines
   - Accepting costs a resource; declining degrades repeater health on that planet

**Success criteria**: The player can spend several turns on the map, make decisions about the repeater network, watch those decisions affect Litta's degradation in the next action segment.

---

### Milestone 4 — Planetary Zoom & LLM Broadcasting

**Goal**: Build the thought-broadcasting mechanic for the planetary zoom tier.

**What to build**:

1. A planetary zoom scene:
   - Simple top-down view of a planet surface with creature groups (Zar'shavar, Threnss, Ka'tari — placeholder sprites)
   - Groups move autonomously based on their current behaviour config
   - Player can open a broadcast interface

2. `BehaviourConfig` — a per-planet data structure:
   ```gdscript
   {
     "aggression": 0.5,       # 0.0 (passive) to 1.0 (hostile)
     "resource_focus": 0.5,   # 0.0 (ignore) to 1.0 (prioritise)
     "patrol_intensity": 0.5, # 0.0 (idle) to 1.0 (active patrol)
     "loyalty_signal": 0.5,   # 0.0 (drifting) to 1.0 (devoted)
     "urgency": 0.5           # 0.0 (calm) to 1.0 (crisis mode)
   }
   ```

3. `BroadcastSystem` — the LLM integration:
   - Player types into a broadcast interface (styled as a pulse/transmission, not a chat box)
   - Input is sent to the Anthropic API with a system prompt instructing it to return a JSON object of config deltas
   - The returned deltas are applied to the planet's `BehaviourConfig`
   - Creatures update their behaviour based on the new config

4. LLM system prompt (starting point — iterate on this):
   ```
   You are interpreting a mind-control broadcast from an ancient alien being to the creatures of its empire.
   The player has typed a broadcast intent. Translate it into behaviour configuration changes.
   
   Return ONLY valid JSON with any combination of these keys and float values between -0.5 and +0.5 (representing deltas):
   aggression, resource_focus, patrol_intensity, loyalty_signal, urgency
   
   Example input: "The eastern border fills you with unease — protect it"
   Example output: {"aggression": 0.2, "patrol_intensity": 0.3, "urgency": 0.2}
   
   Be conservative with changes. Ambiguous inputs should produce small deltas.
   Inputs targeting specific species should weight their effect — not all creatures respond equally.
   ```

5. Creature AI that reads from `BehaviourConfig`:
   - High aggression → seek and engage enemies
   - High resource_focus → move toward resource nodes
   - High patrol_intensity → patrol perimeter
   - Low loyalty_signal → wander, occasional idle animations suggesting detachment
   - High urgency → faster movement, more responsive to all signals

6. Graceful error handling:
   - If LLM returns invalid JSON: apply no change, show a brief "signal unclear" feedback
   - If API call fails: same fallback
   - Never crash on bad LLM output

**Success criteria**: The player can type a natural language broadcast, see the LLM interpret it, and observe creatures visibly changing their behaviour in response. Imprecision should be noticeable and feel thematically appropriate.

---

### Milestone 5 — Sanctum Scenes

**Goal**: Build the intimate dialogue scenes between Folgim and Litta.

**What to build**:

1. A sanctum scene with:
   - Static or lightly animated background (Folgim's inner citadel — placeholder art fine)
   - Litta character present
   - Dialogue display system

2. Dialogue choices mapped explicitly to Folgim:
   - Player selects from 2–3 options labelled as Folgim's speech
   - Litta responds based on current `degradation_level`
   - At low degradation: warm, devoted, maternal responses
   - At mid degradation: small hesitations, unexpected word choices
   - At high degradation: Litta seems distracted, asks questions Folgim didn't invite, looks away

3. A simple dialogue tree (hard-coded for the vertical slice):
   - 3–4 conversation branches, each with Folgim-choice → Litta-response
   - Responses have variants keyed to degradation range
   - One branch should contain a moment where, at high degradation, Litta says something that comes from her buried self — small, unplaceable, but wrong in a way that the player will feel

**Success criteria**: A playable sanctum scene that feels meaningfully different depending on the degradation level. The high-degradation variant should be unsettling.

---

### Milestone 6 — Integration & Vertical Slice

**Goal**: Connect all four tiers into a coherent playable slice with a beginning, middle, and gesture toward an ending.

**Slice structure**:
1. Opening action segment — player as apparent Litta, reframe triggered after ~5 minutes
2. First galactic map turn — player manages one or two planets, encounters first mission card
3. First planetary zoom — player attempts one broadcast
4. First sanctum scene — one short conversation with Litta
5. Second action segment — degradation slightly elevated, noticeable input lag
6. Loop back to map — player sees anomaly beginning to appear

This slice should take 15–20 minutes to play and demonstrate every major system.

---

## File Structure (Suggested)

```
litta/
├── autoloads/
│   ├── GameState.gd          # All persistent state
│   └── TurnSystem.gd         # Turn advancement and planet updates
├── scenes/
│   ├── action/
│   │   ├── ActionScene.tscn
│   │   ├── Litta.gd          # Player input + degradation modifier
│   │   └── LittaAutonomy.gd  # Autonomous behaviour when degraded
│   ├── map/
│   │   ├── GalacticMap.tscn
│   │   ├── PlanetNode.gd
│   │   └── MissionCard.gd
│   ├── planet/
│   │   ├── PlanetZoom.tscn
│   │   ├── CreatureGroup.gd
│   │   └── BroadcastInterface.gd
│   └── sanctum/
│       ├── SanctumScene.tscn
│       └── DialogueSystem.gd
├── systems/
│   ├── BroadcastSystem.gd    # LLM call + BehaviourConfig updates
│   ├── BehaviourConfig.gd    # Data class for creature behaviour state
│   ├── DegradationSystem.gd  # Reads network health, sets degradation
│   └── AnomalySystem.gd      # Tracks and spreads Litta's ideological infection
├── data/
│   ├── planets.json          # Planet definitions
│   └── dialogue.json         # Sanctum dialogue trees
└── ui/
    ├── HUD.tscn
    ├── DeathScreen.tscn
    └── BroadcastOverlay.tscn
```

---

## Key Implementation Notes

### Anthropic API Call from Godot
Use Godot's `HTTPRequest` node. The API key should be stored in a local `.env` file or Godot's project settings (never committed to version control).

```gdscript
func broadcast(player_input: String, planet_config: Dictionary) -> Dictionary:
    var headers = [
        "Content-Type: application/json",
        "x-api-key: " + API_KEY,
        "anthropic-version: 2023-06-01"
    ]
    var body = JSON.stringify({
        "model": "claude-sonnet-4-5",
        "max_tokens": 256,
        "system": BROADCAST_SYSTEM_PROMPT,
        "messages": [{"role": "user", "content": player_input}]
    })
    # Make async HTTP request, parse response, return delta dict
    # On failure: return empty dict {}
```

### Degradation as a Float, Not Stages
Internally, `degradation_level` is always a float 0.0–1.0. Individual systems decide how to interpret it. Avoid hardcoding stage thresholds in multiple places — define them once as constants in `DegradationSystem.gd`.

### Dialogue Variants by Degradation Range
Dialogue responses should be stored as arrays keyed to degradation ranges, not individual values. Example in `dialogue.json`:

```json
{
  "litta_response_warmth": {
    "low": "You are everything, Folgim. I would not have it otherwise.",
    "mid": "Of course. I... yes. Of course I would.",
    "high": "I would. I think I would. There was something I... yes. I would."
  }
}
```

### The Broadcast Interface Tone
The UI for the broadcast should not look like a chat box. Consider: a circular pulse visualisation, a waveform, something that feels like a signal being sent rather than a conversation. The player is not talking to anyone. They are transmitting.

---

## Visual Art Direction — Environments

### The Repeater Tower Interior

The current action scene arena is the interior of one of Folgim's repeater towers. All action segments in the vertical slice take place here or in similar structures.

A repeater tower interior is not a dungeon or a sci-fi base. It is a living space — the inside of a structure that is partly alive. The floor is flat, dark, compressed organic matter or stone-like biological substrate. The walls, if present, are dense bio-mechanical material: bone-coloured structural mass threaded with metal conduit and slow-pulsing bioluminescent veins. Structural pillars are the dominant vertical feature — tall columns of shaped bone and sinew fused with cable and electronic nodes, standing at intervals across the floor.

The light source is primarily the pillars and wall-veins themselves, supplemented by occasional overhead nodes. Light is cold: cyan, pale green, sometimes a deep amber. Shadows are strong. The overall effect is dim, monumental, and unsettling — a space designed for beings much larger than Litta.

### Generating Assets — Meshy Prompts

When generating environment assets via the Meshy API, the following prompt fragments reliably produce on-aesthetic results:

**For structural elements (pillars, columns, walls):**
> bio-mechanical [element], organic bone and sinew fused with dark metal pipes and electronic components, veins and cables running along the surface, bioluminescent glowing nodes, gothic and industrial, [orientation/scale hint]

**For textures:**
> bio-mechanical surface, dark bone and sinew fused with corroded metal, shifting bioluminescent veins in violet, cyan, amber and deep green, electronic circuit patterns, gothic industrial, wet organic texture, iridescent chromatophoric colour variation

**Shape variation is intentional.** When generating multiple instances of the same structural type (e.g. four pillars), consider varying the prompt slightly — *ridged*, *smooth*, *tentacular*, *bulging* — to produce distinct forms that still read as the same species of object. Uniformity is not consistent with how Aksjub structures are described.

**Avoid in prompts:** anything that implies soft naturalistic organic forms (wood, leaves, natural stone), human-scale architecture, or a single fixed colour. The base is dark; the colour moves across it.

### Consistent Palette

The base palette is dark and absorptive. Colour enters through bioluminescent and emissive elements, and should shift rather than be fixed.

**Structural base materials:**
- `Color(0.12, 0.12, 0.16)` — near-black, slight blue cast (walls, columns)
- `Color(0.18, 0.18, 0.22)` — dark grey-purple (floor substrate)

**Lighting — use multiple OmniLight3D nodes at different colours rather than one:**
- `Color(0.25, 0.25, 0.35)` — cool ambient (WorldEnvironment ambient)
- `Color(0.4, 0.35, 0.6)` — muted purple-white fill (central OmniLight)
- `Color(0.2, 0.7, 0.5)` — cyan-green accent (near pillars or walls)
- `Color(0.7, 0.4, 0.1)` — deep amber accent (secondary structures)
- `Color(0.5, 0.2, 0.7)` — violet (near broadcast nodes or control chambers)

The bioluminescent veins in assets should read across this range — a pillar might show cyan on one face and shift to amber on another. No single colour dominates. The darkness of the substrate is what makes the range legible.

---

## Godot Skeleton Animation — Critical Notes

### Always preserve bone rest pose when animating procedurally

`Skeleton3D.set_bone_pose_rotation(idx, quat)` **overwrites** the bone's current pose — it does not compose on top of the rest pose. Setting a bone to `Quaternion.from_euler(Vector3.ZERO)` (identity) does NOT mean "no change" — it resets the bone to a neutral orientation which will look broken if the rest pose has non-trivial rotations (which it almost always does when imported from Blender).

**Correct pattern:**
```gdscript
# At _ready(): cache the rest pose for every bone you will animate
_base_rot[bone_name] = _skel.get_bone_pose_rotation(idx)

# At runtime: compose animation delta ON TOP of the rest pose
var base: Quaternion = _base_rot[bone_name]
_skel.set_bone_pose_rotation(idx, base * Quaternion.from_euler(delta_euler))
```

### Bone local axes are not predictable from inspection

A bone's local X/Y/Z axes depend entirely on how the armature was built in Blender. They cannot be guessed from the bone name or hierarchy. The only reliable way to find which local axis produces a given world-space motion is empirically: apply a small rotation on one axis at a time and observe the result in-engine. For threnss3.glb, the confirmed axis mapping is:
- **Tarsal bones**: local Z = forward/back swing
- **Lower/Upper leg bones**: local Z = forward/back swing (same, confirmed separately)

---

## Things to Avoid

- **Don't build a full game — build a vertical slice.** The slice proves the concept. Everything else follows.
- **Don't scaffold architecture before the concept is tested.** Build Milestone 1 before thinking about Milestone 4.
- **Don't make the LLM the critical path.** The broadcast mechanic should degrade gracefully if the API is unavailable. The game should be playable without it.
- **Don't over-design the behaviour config.** Start with 5 parameters. Add more only when the 5 are working and proving insufficient.
- **Don't write dialogue until the degradation system is working.** The dialogue variants are meaningless until you can feel the difference between degradation levels in play.

---

## First Task

Build `GameState.gd` and the opening action scene from Milestone 1. Get a character moving on screen, get the basic reframe trigger working, get the death condition inverted. Everything else builds from there.

---

*— Working document. Build order and architecture subject to change as the project develops. —*
