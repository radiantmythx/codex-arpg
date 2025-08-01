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

