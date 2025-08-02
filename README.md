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

## Mana System
The player now uses mana to power abilities. Basic attacks consume mana and the
player regenerates 1 mana per second up to a base maximum of 50. Affixes and
items can modify maximum mana and regeneration rates.

## Setup Instructions
1. Launch the Godot editor and open the project folder.
2. Press **Play** to run. The player can move and attack.
3. Use the provided scripts as a starting point for building a larger ARPG.


## Creating Enemy Scenes
This repository includes an `enemy.gd` script that handles health and death logic.
Follow these steps in the Godot editor to create your own enemy scene:

1. **Create a new scene** with a `CharacterBody3D` as the root node.
2. **Attach** `scripts/enemy.gd` to the root node.
3. Add a `CollisionShape3D` and `MeshInstance3D` as children for collision and visuals.
4. Optionally add the node to an **"enemies"** group for organization.
5. Save the scene, e.g. `scenes/Enemy.tscn`, and instance it into `Main.tscn`.

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

Enemies can drop loot using the `drop_table` export on `enemy.gd`. Each entry in
the array is a dictionary like `{"item": Item, "chance": 0.5, "amount": 1}`.
When the enemy dies every entry is rolled and a matching `item_drop.tscn`
instance is spawned for successful rolls.

### Updating Existing Scenes
1. Open your enemy scene in Godot and ensure `enemy.gd` is attached to the root
   `CharacterBody3D`.
2. Set the exported properties such as movement speeds, detection and attack
   ranges, and configure the `drop_table` with your item resources.
3. The player scene automatically belongs to the **"players"** group so enemies
   will find it without additional setup.

