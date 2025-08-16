# Codex ARPG Setup

This repository contains a simple Godot 4 project configured for a modular action RPG. It demonstrates basic WASD movement and a right-click melee attack that rotates toward the cursor with area feedback.

## Scenes
- `scenes/Player.tscn` – CharacterBody3D with a camera and `player.gd` script.
- `scenes/Main.tscn` – Main scene that instantiates the Player.

The `project.godot` file is configured to run `scenes/Main.tscn` by default and defines input actions for movement and attacking.

## Creating Additional Scenes
1. Open the project in Godot.
2. Add 3D nodes (enemies, environment, etc.) to `scenes/Main.tscn` or create new scenes that can be instanced into Main.
3. Extend `player.gd` or create additional scripts for abilities, items, and other gameplay elements to keep things modular.

## Controls
- **WASD** – Move the player.
- **Right Mouse Button** – Rotate toward the clicked position and perform a melee attack. The attack area is displayed briefly as a red cylinder in front of the player.
- **Q** – Activate the secondary skill (e.g., the Haste aura).
- **Dodge action** – Perform a directional dodge roll with a short invincibility window. Configure the input mapping in Project Settings.

## Player Animations
The `player.gd` script now drives an `AnimationTree` for directional movement and attack animations.

### Setting up the AnimationTree
1. In `scenes/Player.tscn` add your character model with an `AnimationPlayer` containing at minimum: `idle`, `run_left`, `run_right`, `run_up`, `run_down`, `slash` and `cast` animations.
2. Add an `AnimationTree` node and assign the `AnimationPlayer` to it. Set **Tree Root** to `StateMachine` and enable the tree.
3. Inside the state machine create a state named **move** using an `AnimationNodeBlendSpace2D`. Place the run animations at
   - `(0, 0)` – idle
   - `(-1, 0)` – run_left
   - `(1, 0)` – run_right
   - `(0, -1)` – run_up
   - `(0, 1)` – run_down
4. Create states named **slash** and **cast**. Wrap each animation in an `AnimationNodeTimeScale` so their speed can be changed at runtime.
5. Add transitions from **move** to **slash** and **cast**, and back to **move** when the animations finish.
6. In the Player node's inspector set **animation_tree_path** to the new `AnimationTree`.

`player.gd` updates the blend position at `parameters/move/blend_position` using the player's movement relative to the cursor. Attack states are entered by name via the skill's `animation_name` property and their `TimeScale/scale` parameter is adjusted using the character's attack speed.

### Slash timing
Skill resources now expose `animation_name`, `attack_time` and `cancel_time`. For a slash attack set:
```
duration     – length of the slash animation at 1× speed
attack_time  – when the hit should occur
cancel_time  – when the remaining animation can be cancelled
animation_name = "slash"
```
The player script accelerates or slows the animation based on `attack_speed` and triggers the skill at `attack_time`.

### Dodge Roll
The player can perform a quick dodge roll to evade danger.

1. In **Project Settings → Input Map** add an action named `dodge` and bind a key or gamepad button.
2. Create a `roll` animation on the player's `AnimationPlayer`.
3. In the `AnimationTree` state machine add a state called `roll` that plays this animation and connect it from `move` back to `move`.
4. Tune the Player node's exported `dodge_speed`, `dodge_duration`, `dodge_cooldown` and `dodge_invincibility_time` values as desired.

During a roll the player moves in their last movement direction, passes through enemies but still collides with the environment and ignores incoming damage for a brief window.

## Camera
The main camera now tracks the player character. It preserves the original
offset configured in the scene and lerps toward the player each frame. When the
inventory is open the camera shifts sideways by `inventory_camera_shift` so the
UI does not obscure the action.

## Mana System
The player now uses mana to power abilities. Basic attacks consume mana and the
player regenerates 1 mana per second up to a base maximum of 50. Affixes and
items can modify maximum mana and regeneration rates.

## Skill Hotbar UI
`skill_icon.gd` displays icons for equipped skills and shows their cooldowns,
active state and whether the player has enough mana.

### Setup
1. Add a `TextureButton` for each hotbar slot.
2. Optionally add child nodes:
   - `TextureProgressBar` for cooldown progress.
   - `Control` (e.g. `ColorRect`) to highlight when the skill is active.
   - `Control` for an overlay when mana is insufficient.
3. Attach `scripts/ui/skill_icon.gd` to the button.
4. Set **player_path**, **slot_index** and the overlay NodePaths in the inspector.
5. Hovering the button displays the skill name and description.
6. Fill out the new `description` field on each `Skill` resource to populate the tooltip.


## Skills and Tags
Skills are `Resource` files that carry tags describing how they behave. Supported tags include `Melee`, `Spell`, `Projectile`, `AoE`, `Aura`, `Channel`, `Summon` and `Movement`. Affixes can grant flat or increased damage to specific tags such as `physical_damage_melee` or `holy_damage_spell`. Damage from equipped items is applied when a skill with matching tags is used, allowing weapons and armor to contribute to spell or melee damage independently.

Affixes may also modify `aoe_inc` to increase the size of any skill tagged with `AoE`.

The project now includes generic projectile, melee, blast and aura skill bases. Skills may spawn optional on-hit or explosion effects that scale with the caster's area bonuses. A buff system allows temporary modifiers on players and enemies. Sample abilities include **Haste** (a mana-reserving aura that boosts move speed), **Holy Smite** (a holy blast at the cursor) and **Icicle Blast** (a slowing projectile). Enemies use the same framework and attack with the basic melee skill.

## Rune System
Runes act as itemized mini-skills. Two rune slots combine to create a single ability.

### Setting Up Rune Slots
1. In the inventory UI scene add a container node with four `RuneSlot` children.
2. Assign `scripts/rune_slot.gd` to each child and set `skill_slot_index` (0 for main, 1 for secondary) and `rune_index` (0 or 1).
3. On the `InventoryUI` node, set **rune_slots_parent_path** to the container from step 1.
4. Player `player.gd` automatically creates a `RuneManager`. When runes are equipped the manager builds the resulting skill and assigns it to the corresponding skill slot.

Single runes provide basic skills such as **Melee Strike**, **Blessing**, **Area Blast** and **Time Bolt**. Mixing two runes yields combination skills like **Explosive Strike** (Strike+Area), **Enchanted Strike** (Strike+Buff) or **Temporal Aura** (Buff+Time). Runes roll up to three affixes which are combined when the resulting skill is cast.

### Rune Damage
Runes now define their own base damage range and damage type using the `base_damage_low`, `base_damage_high` and `base_damage_type` fields in their `.tres` files. When runes are combined, each portion of the generated skill uses the base damage and type of its contributing rune. Flat damage affixes on runes apply only to the skill they create, while equipment affixes continue to apply globally to all skills. Damage over time buffs also expose `base_damage_low` and `base_damage_high`, allowing their DPS to be scaled by the caster's stats when applied.

Updated resources:
- `resources/runes/item_strike_rune.tres`
- `resources/runes/item_area_rune.tres`
- `resources/runes/item_time_rune.tres`
- `resources/runes/item_buff_rune.tres`
- `resources/skills/rune_time.tres`
- `resources/skills/rune_strike_time.tres`

### Damage Snapshotting
Projectile, melee and blast skills now roll and store their damage when cast.
This snapshot allows projectiles and delayed explosions to apply the correct
damage even if the caster dies before they land. When creating or editing a
skill `.tres` resource, make sure its `base_damage_low`, `base_damage_high` and
`damage_type` fields are set so the snapshot has values to roll. If you want
custom visual effects or projectile scenes, create a new `.tscn` in the editor
and assign it to the skill's exported `projectile_scene`, `on_hit_effect` or
`explosion_effect` properties.

### Adding New Skills
1. Create a script extending `Skill` (see `scripts/skills/` for examples) and export any parameters you need.
2. Create a new `.tres` resource in `resources/skills/` that points to the script and assign appropriate tags.
3. Assign the resource to a player's or enemy's exported skill slot in the editor or via a script.

Generic projectile and blast skills let you assign optional `projectile_scene`, `on_hit_effect` and `explosion_effect` scenes. If left empty a simple placeholder mesh is used.

## Setup Instructions
1. Launch the Godot editor and open the project folder.
2. Press **Play** to run. The player can move and attack.
3. Use the provided scripts as a starting point for building a larger ARPG.
4. Run `godot --headless --check` to verify scripts compile after changes.


## Creating Enemy Scenes
This repository includes an `enemy.gd` script that handles health and death logic.
Follow these steps in the Godot editor to create your own enemy scene:

1. **Create a new scene** with a `CharacterBody3D` as the root node.
2. **Attach** `scripts/enemy.gd` to the root node.
3. Add a `CollisionShape3D` and `MeshInstance3D` as children for collision and visuals.
4. Configure the new damage fields:
   - **base_damage_low/high** – roll damage between these values.
   - **base_damage_types** – one or more damage types the enemy deals.
   - **tier** – choose `PACK`, `LEADER` or `BOSS` to scale health and damage.
5. Optionally add the node to an **"enemies"** group for organization.
6. Save the scene, e.g. `scenes/Enemy.tscn`, and instance it into `Main.tscn`.

When the player attacks, any node with a `take_damage` method will lose health
and be removed when it reaches zero.


## Item & Inventory System
This project now includes a very small inventory framework built entirely with
scripts. `player.gd` instantiates an `Inventory` node at runtime, so the player
already has a container for items.

### Using Items
1. Create a new resource using **Item** (`scripts/item.gd`) for each item type.
2. To make something collectible, add an `Area3D` (or a child of a 3D node) and
   attach `scripts/item_pickup.gd`. Assign the `item` property and set an
   optional amount. The script spawns a 2D tag in a canvas layer so the label is
   always the same size on screen.
3. Hover over the tag to view the tooltip and click the label with the **left
   mouse button** to add the item to the player's inventory.
4. A `CanvasLayer` named `ItemTagLayer` will be created automatically at
   runtime. If you prefer to manage it manually, add a `CanvasLayer` with that
   name to your main scene and optionally customize its draw order.

### Equipping 3D Models
Items can display 3D meshes on the player when equipped.  Each `Item` resource
exposes two new properties:

- **model** – `PackedScene` containing the mesh or mesh collection.
- **equip_transform** – orientation and offset applied to the model when
  attached.

#### Importing Weapon or Offhand Models
1. In Blender, orient the weapon so it points forward relative to the player's
   hand and export it as a `.glb`.
2. Drag the file into Godot. The importer will generate a `*.glb` scene.
3. Create an `Item` resource and assign the imported scene to its `model`
   property.
4. Set `equip_slot` to `weapon` or `offhand`.
5. Adjust `equip_transform` by rotating or translating the preview so the model
   lines up with the hand.  The values are applied relative to the hand bone at
   runtime (`mixamorig_RightHand` for weapons and `mixamorig_LeftHand` for
   offhands).

#### Importing Armor Pieces
1. Author the armour in Blender using the same skeleton as the player and
   export to `.glb` ensuring bone names are preserved.
2. Import the file into Godot and save the resulting scene.
3. Create an `Item` resource with `equip_slot` set to `armor` and assign the
   scene to `model`.
4. Optionally tweak `equip_transform` if the mesh needs an offset.

When the player equips an item the scene is instanced and attached to the
appropriate bone or the root skeleton.  All `MeshInstance3D` nodes inside the
scene are re-targeted to the player's skeleton so animations drive the new
mesh.

### Hair and Helmets
Players may have a standalone hair model which is attached to the head at
runtime.  Equipable items expose a new **hide_hair** checkbox.  When an item
with this flag is worn (for example a helmet or hood) the hair model is
temporarily hidden and re-enabled when the item is removed.  Assign the hair
`PackedScene` to the Player's **hair_scene** export and the
`EquipmentVisualManager` will handle attachment and visibility automatically.

### Item Tag Collision Handling
Item tags spawned in the world will now avoid overlapping each other. Every tag
projects its 3D position into screen space and checks for rectangle intersections
with its siblings. When a collision is detected the tag is nudged upward by a
small increment until it no longer overlaps, keeping nearby labels legible.

You can inspect or modify the contents of the player's inventory through the
`inventory` property on `player.gd` or by attaching the `Inventory` script to
other nodes if needed.

### Inventory Cursor Interaction
The inventory UI allows items to be picked up and carried on the cursor similar
to games like Diablo II or Path of Exile.

1. Attach `scripts/inventory_ui.gd` to a `CanvasLayer` in your UI and assign its
   `slots_parent_path` export to a node containing a number of child
   `InventorySlot` controls. Each slot should use `scripts/inventory_slot.gd`.
2. Set the player's `inventory_ui_path` export to this `InventoryUI` node so it
   can open and close the interface.
3. When the inventory is open, clicking a slot picks up its item onto the
   cursor. Click another slot to place it. Closing the inventory hides the icon
   but the item remains on the cursor until the UI is reopened.
4. Picking up a world item while the inventory is open will put that item on the
   cursor instead of adding it directly to the inventory.

## Affix System
Items may roll between three and six affixes. The first three affixes are
guaranteed while each of the remaining slots has a 50% chance to appear. Affixes
are defined as separate resources so new ones can be added without modifying
code.

### Creating an AffixDefinition
1. Create a new resource using **AffixDefinition** (`scripts/affix_definition.gd`).
2. Fill out the exported properties:
   - **name** – display name of the affix.
   - **description** – template string shown to players. Use `{value}` where the
     rolled number should appear.
   - **stat_key** or **main_stat** – which stat the affix modifies. Suffix
     `_inc` denotes an "increased" (percentage) bonus while the base key is
     additive.
   - **tiers** – an array of `Vector2(min, max)` values for each tier. `T1`
     rolls are the most powerful and hardest to obtain while higher numbers are
     weaker rolls.
   - **flags** – optional keywords that enable unique behaviour. For example,
     the `body_to_mind` flag converts all Body bonuses to Mind.
3. Save the resource inside `resources/affixes/` and assign it to an item's
   `affix_pool` array. Call `reroll_affixes()` to roll new affixes.

### Affix Groups
Multiple items can now share a common pool of affixes. Create an
**AffixGroup** resource (`scripts/items/affix_group.gd`) and populate its
`affixes` array with `AffixDefinition` resources. Items expose a new exported
`affix_groups` array; all definitions from these groups are merged with the
item's own `affix_pool` when `reroll_affixes()` is called.

This allows creating broad categories such as *boots* or *rings* without
manually listing the same affixes on every item. See
`resources/affix_groups/boots.tres` and `resources/items/test_boots.tres` for an
example.

Several sample definitions are included covering additive and increased bonuses
for Body, Mind, Soul, Luck, movement speed, maximum health/mana and their
regeneration.  Unique examples like `life_steal.tres` and `body_to_mind.tres`
demonstrate the flag system.

Three sample items – `mystic_ring.tres`, `mystic_amulet.tres` and
`mystic_boots.tres` – showcase how to create items that can roll any of these
affixes.

### Crafting with Currency Items
Placing a crafting currency on the cursor and right‑clicking an item attempts to
modify that item's affixes. The following currencies are supported:

* **Chaos Orb** – rerolls all affixes.
* **Temper Jewel** – rerolls the tier of one random affix.
* **Culling Jewel** – removes one random affix.
* **Elevating Jewel** – adds a new random affix.
* **Cleansing Jewel** – removes all affixes.

These currencies are only consumed when the action succeeds; for example a
Culling Jewel will not be spent on an item with no affixes.

To create a jewel in Godot 4.4, make a new `.tres` Resource using
`scripts/items/item.gd`, set `item_name` to the jewel's name, assign an icon and
`max_stack`, then place the resource anywhere under `resources/items/`.
Icons can be assigned like the existing `chaos_orb.tres` under
`resources/items/currency/`.

### Displaying Affixes
Hovering over an item tag in the world or over an inventory slot now shows the
item's affixes in its tooltip.

## Enemy Behavior
Enemies now wander around randomly until the player gets close. When the player
enters the `detection_range` exported on `enemy.gd`, the enemy will chase the
player and will continue to pursue until the player moves more than five times
that distance away. If the player reaches `attack_range`, the enemy performs a short
wind‑up before dealing damage. During the wind‑up the enemy's material turns
red to telegraph the attack and then reverts back afterwards.

Each enemy rolls damage from its `base_damage_low/high` range for every type
listed in `base_damage_types`.  These values are merged with the damage of the
skill the enemy uses so designers can create fire‑dealing archers, ice mages and
other variants without custom skills.  The `tier` export controls how tough an
enemy is:

* **PACK** – standard fodder.
* **LEADER** – 50% more health and 25% more damage.  Intended to lead groups.
* **BOSS** – large unique monsters with triple health and double damage.

Enemies can drop loot using the `drop_table` export on `enemy.gd`. Each entry in
the array is a dictionary like `{"item": Item, "chance": 0.5, "amount": 1}`.
Enemies may also reference any number of reusable **DropTable** resources via
the new `drop_tables` array. When the enemy dies all entries from the local
`drop_table` and assigned `DropTable` resources are rolled and a matching
`item_drop.tscn` instance is spawned for successful rolls.
Create shared tables as resources using `scripts/drop_table.gd` and populate
their `entries` array with the same dictionaries used in `drop_table`.
An example can be found at `resources/drop_tables/basic.tres`.

### Updating Existing Scenes
1. Open your enemy scene in Godot and ensure `enemy.gd` is attached to the root
   `CharacterBody3D`.
2. Set the exported properties such as movement speeds, detection and attack
   ranges.  Configure `base_damage_low/high`, `base_damage_types` and the enemy
   `tier`, then assign the `drop_table` with your item resources. Optional
   global tables can be added through the `drop_tables` array.
3. The player scene automatically belongs to the **"players"** group so enemies
   will find it without additional setup.

## Hover Target Display
When the mouse cursor rests over an enemy or friendly NPC a small UI at the top
of the screen shows that target's name and health. Enemies are outlined with a
thin red shader while NPCs use a green outline.

1. Instance your custom `Healthbar.tscn` somewhere in the UI and attach
   `scripts/ui/enemy_target_display.gd` (class `TargetDisplay`) to a parent
   `Control`.
2. On the `TargetDisplay` node set:
   - **healthbar_path** – NodePath to the `Healthbar` instance.
   - Optional **name_label_path** and **level_label_path** to `Label` nodes if
     you want the script to fill them automatically.
3. On the Player scene assign **target_display_path** to this `TargetDisplay`
   node.
4. For each enemy or NPC set `enemy_name` and `enemy_level` on their scripts so
   the display can show them.

## NPCs
NPCs are non-combat characters the player can interact with. Clicking an NPC
within range pauses the game, centers the camera on both characters and opens a
dialogue box offering **Talk**, **Trade** or **Quit** options. Trade currently
acts the same as Quit.

### Creating an NPC Scene
1. Add a `CharacterBody3D` and attach `scripts/npc.gd`.
2. Add a `MeshInstance3D` and `CollisionShape3D` much like
   `scenes/enemy.tscn`.
3. Edit the exported properties:
   - **enemy_name/level** – values shown in the hover UI.
   - **dialogue_lines** – array of strings for the Talk option.
   - **can_trade** – hide the Trade button if false.
   - **interaction_range** – how close the player must be to talk.
4. NPCs automatically join the `npc` group and use a green hover outline.

To enable conversations add a `Control` with `scripts/ui/dialogue_box.gd` to a
`CanvasLayer` and set the Player's `dialogue_ui_path` to that node. If left
empty the Player will automatically create a `DialogueBox` under a sibling
`CanvasLayer` at runtime.

## Zone Shards and Level Generation
Zone Shards are consumable items that open a temporary zone. They reuse the existing affix framework so shards can roll modifiers that influence the generated level.

### Creating Zone Shards
1. Create a new resource using **ZoneShard** (`scripts/items/zone_shard.gd`).
2. Assign an icon and optional description.
3. Populate `affix_pool` with zone affix definitions such as:
   - `resources/affixes/zone/enemy_spawn_inc.tres` – increases number of enemy packs.
   - `resources/affixes/zone/enemy_fire_damage.tres` – adds flat fire damage to enemies.
   - `resources/affixes/zone/enemy_hp_inc.tres` – increases enemy life.

Example: `resources/items/zone_shard.tres` shows a shard configured with these affixes. Zone Shards can be rerolled with Chaos Orbs like any other item.

### Generating a Zone
Attach `scripts/ui/zone_shard_slot.gd` to a `Control` that contains an `InventorySlot` for the shard and a `Button` to trigger the run. Export `zone_generator` to a `ZoneGenerator` resource (`scripts/zones/zone_generator.gd`) and set its `enemy_pack_scene` and `boss_scene` in the editor. When the button is pressed the control emits `zone_generated(PackedScene)`; instance this scene and warp the player to begin the encounter.

## Passive Skill Tree
The project now includes a framework for allocating passive skill nodes.
Attach `scripts/passives/passive_tree.gd` to a `Control` that contains all of
your passive nodes and set the following exports:

- **player_path** – NodePath to the player so node effects can modify their
  `Stats`.
- **nodes_parent_path** – Optional path to the node container. If empty the
  tree looks for `PassiveNode` children directly under itself.

Create nodes by instancing Controls with one of the provided scripts:

- `AttributeNode` – grants flat main stats. Set `stat` and `amount`.
- `ModifierNode` – applies an `Affix` resource for standard stat bonuses.
- `MasteryNode` – applies an `Affix` with powerful flags.
- `WarpNode` – special node that links to other warp nodes.

For each node use the exported `connections` array to link it to its neighbors.
Warp nodes expose an additional `warp_connections` array. Set `is_root` on the
starting node; it begins allocated. When the scene runs the tree automatically
creates `Line2D` connections between nodes. Warp links are drawn in blue.

Add passive points with `add_points()` and click nodes to allocate them.
Nodes only become available if at least one connected node leading back to the
root has already been allocated. Allocated nodes immediately apply their effects
to the player's stats.
