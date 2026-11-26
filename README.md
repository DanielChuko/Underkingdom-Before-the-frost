# Underkingdom: Before the Frost

An original first-person medieval adventure. Envoy Casimir Vael of Hollowmere
brings the king terrible news from the Arcane University: the sun is dying, an
endless frost is coming, and the kingdom must move underground within two years.

This repository currently holds the **prelude vertical slice**, built in
**Godot 4.3+** with greybox (placeholder) geometry generated from code.

## Running it

1. Install [Godot 4.3 or newer](https://godotengine.org/download) (standard build, no C# needed).
2. In the Project Manager choose **Import**, pick this folder's `project.godot`, then press **Run** (F5).

## Controls

| Action | Keys |
| --- | --- |
| Move / sprint | WASD or arrow keys / Shift |
| Look | Mouse (click the window to capture it, Esc releases it) |
| Interact / talk | E |
| Continue dialogue | Space, Enter, E or left click |
| Pick a dialogue choice | 1-4 or click |
| Journal | J or Tab |

## What's in the slice

1. **Gate (prelude).** Casimir looks up from his map at the city gate. The gate guard stops him; you pick how Casimir answers.
2. **Castle corridor.** You take control inside the castle. The corridor winds twice past locked doors; one guard patrols it, another stands by the open doors to the king's hall. Both have one-liners.
3. **King's hall.** The king stands in the middle of the hall under the kingdom's crest, between red banners, with a staircase to a landing. The full prelude conversation plays, with the king walking to the crest and turning back.
4. **Title.** Fade to *Underkingdom: Before the Frost*, then a bright "Two months later" card.
5. **Act 1.** Casimir wakes in his room (bed, daylight window, candle-lit table and chair, mirror, a blooming flower, a painting of a snowy mountain). The room, kitchen (with the cook) and toilet room open; every other door stays locked. The king, now on his throne, gives the goblin briefing. Leaving through the entrance doors, where the prelude began, ends the slice.

A quest tracker in the top-right corner follows "The Grave Message" and then "Trouble at the Dig".

## Project layout

```
project.godot            Godot project (autoloads: GameState, Quests, Dialogue)
scenes/main.tscn         Entry scene (just runs scripts/main.gd)
scripts/main.gd          Story flow: prelude -> title -> Act 1 -> end of slice
scripts/autoload/        game_state.gd (flags, events, input map), quest_manager.gd, dialogue_manager.gd
scripts/player/player.gd First-person controller and interaction raycast
scripts/world/           greybox.gd helpers, castle_builder.gd, gate_builder.gd, door/npc/prop scripts
scripts/ui/hud.gd        Prompts, toasts, quest tracker, journal, dialogue box, fades and title cards
data/dialogue/*.json     Conversations (gate_guard, king_prelude, king_act1) and barks.json
data/quests.json         Quests and their objectives
data/characters.json     How each character looks (colours, clothes, beard, headwear)
scripts/characters/      humanoid.gd: the character rig, costumes and procedural animation;
                         mesh_lib.gd: lofted body meshes, the sculpted head, hair/beard/mail/helmet shells
assets/textures/         Generated surface textures (albedo, normal, roughness)
tools/gen_textures.py    Generates every texture from seeded noise
tools/validate_data.py   Checks dialogue and quest files (runs in CI)
```

## Art

All art is generated, not taken from asset packs or other games.

- **Textures** (stone walls, flagstone, wood planks, dark wood, cloth, plaster, mud, cobbles) come from `tools/gen_textures.py`. Run `pip install numpy pillow` and `python3 tools/gen_textures.py` to rebuild them; change a `seed` to get a different variation. They tile seamlessly and are applied with triplanar mapping in `scripts/world/surfaces.gd`, so any box gets evenly scaled texturing.
- **Architecture and props** (door frames, pillars, beams, tables, benches, barrels, crates, sacks, shields, rugs, shelves, chandeliers) are assembled from primitives in `scripts/world/decor.gd`.
- **Characters** are jointed rigs (`scripts/characters/humanoid.gd`) whose meshes are generated in code by `scripts/characters/mesh_lib.gd`: smooth lofted torsos, limbs, hands and boots, and a head sculpted from a sphere (brow ridge, eye sockets, nose, cheekbones, lips, jaw and chin) with eyes, heavy lids, ears, hair and beards. They are dressed from `data/characters.json` in worn, muted clothing: mail hauberks, coifs and rusty nasal helms, faded surcoats with torn hems, a fur-trimmed robe and mantle, a stained apron. Vertex colours add dirt toward hems and boots, stains and skin shading, on top of generated chainmail, leather, wool, skin, rusty steel and fur textures. They animate in code with no keyframes: a walk cycle driven by actual movement speed, idle breathing and weight shift, a seated pose for the king, mouth movement and hand gestures while their dialogue line is on screen, and heads that turn to look at you when you're close. Add a new character by adding a look to the JSON and passing its id to `G.npc()`.
- **Fire, dust and light**: particle flames, flickering torch light with shadows, ambient occlusion and a light volumetric haze. A sun beam comes through Casimir's window in Act 1.

## Writing dialogue

Each conversation is a JSON file in `data/dialogue/`, named after its `id`:

```json
{
  "id": "king_act1",
  "start": "k_awake",
  "on_end": { "set": ["act1_briefed"], "events": ["king_briefing_done"] },
  "nodes": {
    "k_awake": { "speaker": "King", "text": "Finally awake, Casimir...", "next": "c_reply" },
    "k_orders": {
      "speaker": "King",
      "text": "...",
      "choices": [
        { "text": "\"Understood, sire.\"", "next": "c_understood" },
        { "text": "\"Where will I find the dig site?\"", "if": "!asked_dig_site", "set": ["asked_dig_site"], "next": "k_where" }
      ]
    }
  }
}
```

Node fields:

- `speaker`, `text`: the line shown. `action`: an optional stage direction shown above it.
- `next`: the following node, or `"end"`. Use `choices` instead of `next` to let the player pick.
- `choices[]`: `text`, `next`, optional `if` (show only when the condition holds) and `set` (flags to set when picked).
- `set` / `clear`: story flags changed when the node is shown. `events`: quest events raised.
- `cue`: a name the level script reacts to (for example `king_to_crest` makes the king walk to the crest).
- `branch`: a node with no `text` can route silently: `"branch": [{"if": "flag", "next": "a"}], "next": "fallback"`.
- Conditions are `flag`, `!flag`, or several joined with commas (all must hold).
- `on_end` (top level) applies `set` / `events` when the conversation finishes.

NPCs that only say one-liners (guards, the cook) read from `barks.json` and cycle through their lines.

Quests list objectives that complete when a matching event is raised, either from dialogue (`events`, `on_end`) or from game code (`GameState.raise("left_castle")`).

Run `python3 tools/validate_data.py` after editing; it reports missing nodes, unreachable lines and malformed quests.

## Next steps

- Replace greybox with art and add voice/sound.
- Act 1 outside the castle: road to the dig site, Quartermaster's shop and the sword.
- Combat and the underground: goblins, bandits (miners who turned on the king), trolls and the early Akabir cult.
