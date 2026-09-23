class_name GameSession
extends Node
## Composition root of `scenes/main.tscn` (ADR-0002). Owns the four roots every later
## system is injected into and, for now, only opens the main menu on [member interface].
## Menu actions, Run ownership, pause handling, and stage loading arrive with F2-04;
## nothing here decides gameplay.


## Holds the loaded Stage instance.
@export var world_root: Node3D
## Root of the projectile system (ADR-0004).
@export var projectile_root: Node3D
## Holds menus and the HUD. Processes while the tree is paused.
@export var interface: Interface
## Root of the audio controller. Processes while the tree is paused.
@export var audio: Node


func _ready() -> void:
	if not _validate_exports():
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	interface.show_home(ScreenRouter.MAIN_MENU)


## Reports every unset export with this node's path (CONVENTIONS "Setup errors are loud").
func _validate_exports() -> bool:
	var missing: PackedStringArray = []
	if world_root == null:
		missing.append("world_root")
	if projectile_root == null:
		missing.append("projectile_root")
	if interface == null:
		missing.append("interface")
	if audio == null:
		missing.append("audio")
	for field: String in missing:
		push_error("%s: required export '%s' is not set" % [get_path(), field])
	return missing.is_empty()
