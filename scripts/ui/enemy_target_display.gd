extends Control
class_name EnemyTargetDisplay
## Displays information about the currently hovered enemy.
##
## The node expects a child `Healthbar` node (provided by you as a `.tscn`)
## and optional `Label` nodes for the enemy's name and level.  All nodes are
## referenced by exported `NodePath`s so they can be wired up in the editor.

@export var healthbar_path: NodePath
@export var name_label_path: NodePath
@export var level_label_path: NodePath

var _healthbar: Node
var _name_label: Label
var _level_label: Label
var _target: Node

func _ready() -> void:
    # Resolve the NodePaths to actual nodes.  If any path is left empty the
    # feature simply remains unused.
    if healthbar_path != NodePath():
        _healthbar = get_node_or_null(healthbar_path)
    if name_label_path != NodePath():
        _name_label = get_node_or_null(name_label_path)
    if level_label_path != NodePath():
        _level_label = get_node_or_null(level_label_path)
    # Hide by default until an enemy is hovered.
    visible = false

func update_enemy(enemy: Node) -> void:
    ## Call this every frame with the enemy under the mouse cursor.
    ## Pass `null` when no enemy is hovered to hide the display.
    if enemy != _target:
        _set_new_target(enemy)
    elif _target:
        _update_health()

func _set_new_target(enemy: Node) -> void:
    # Disconnect previous target if needed and assign the new one.
    if _target and _target.has_signal("died") and _target.is_connected("died", Callable(self, "_on_target_died")):
        _target.disconnect("died", Callable(self, "_on_target_died"))
    _target = enemy
    if _target:
        # Forward name and level to any connected labels or the healthbar scene.
        _update_labels()
        _update_health()
        if _target.has_signal("died"):
            _target.connect("died", Callable(self, "_on_target_died"))
        visible = true
    else:
        visible = false

func _update_health() -> void:
    if _healthbar and _target and _healthbar.has_method("set_health"):
        # Healthbar.tscn should expose `set_health(current, max)`.
        _healthbar.call("set_health", _target.current_health, _target.max_health)
        # If your healthbar scene implements `set_enemy_info(name, level)` we
        # pass those values along so you can display them.
        if _healthbar.has_method("set_enemy_info"):
            _healthbar.call("set_enemy_info", _target.enemy_name, _target.enemy_level)

func _update_labels() -> void:
    if not _target:
        return
    if _name_label:
        _name_label.text = str(_target.enemy_name)
    if _level_label:
        _level_label.text = str(_target.enemy_level)

func _on_target_died() -> void:
    # Automatically hide when the enemy is killed.
    _set_new_target(null)
