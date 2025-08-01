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

## Item & Inventory System
This project now includes a very small inventory framework built entirely with
scripts. `player.gd` instantiates an `Inventory` node at runtime, so the player
already has a container for items.

### Using Items
1. Create a new resource using **Item** (`scripts/item.gd`) for each item type.
2. To make something collectible, add an `Area3D` node to your scene and attach
   `scripts/item_pickup.gd`. Assign the `item` property to the Item resource and
   set an optional amount.
3. When the player enters the pickup area, the item is added to the player's
   inventory automatically.

You can inspect or modify the contents of the player's inventory through the
`inventory` property on `player.gd` or by attaching the `Inventory` script to
other nodes if needed.

