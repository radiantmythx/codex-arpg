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

## Mana System
The player now uses mana to power abilities. Basic attacks consume mana and the
player regenerates 1 mana per second up to a base maximum of 50. Affixes and
items can modify maximum mana and regeneration rates.

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

Several sample definitions are included covering additive and increased bonuses
for Body, Mind, Soul, Luck, movement speed, maximum health/mana and their
regeneration.  Unique examples like `life_steal.tres` and `body_to_mind.tres`
demonstrate the flag system.

Three sample items – `mystic_ring.tres`, `mystic_amulet.tres` and
`mystic_boots.tres` – showcase how to create items that can roll any of these
affixes.

### Crafting with Chaos Orbs
When a **Chaos Orb** is on the cursor, right‑clicking an item consumes one orb
and rerolls all of that item's affixes. Affix tiers are rolled with weighted
probabilities; lower tier numbers (better rolls) are rarer than higher tier
numbers.

### Displaying Affixes
Hovering over an item tag in the world or over an inventory slot now shows the
item's affixes in its tooltip.

## Enemy Behavior
Enemies now wander around randomly until the player gets close. When the player
enters the `detection_range` exported on `enemy.gd`, the enemy will chase the
player. If the player reaches `attack_range`, the enemy performs a short
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
When the enemy dies every entry is rolled and a matching `item_drop.tscn`
instance is spawned for successful rolls.

### Updating Existing Scenes
1. Open your enemy scene in Godot and ensure `enemy.gd` is attached to the root
   `CharacterBody3D`.
2. Set the exported properties such as movement speeds, detection and attack
   ranges.  Configure `base_damage_low/high`, `base_damage_types` and the enemy
   `tier`, then assign the `drop_table` with your item resources.
3. The player scene automatically belongs to the **"players"** group so enemies
   will find it without additional setup.


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
