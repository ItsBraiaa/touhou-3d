class_name BombBlast
extends Node3D
## The Bomb's blast visual: D-02's `bomb_blast_visual.tscn` (see-through rings with a unit
## outer edge, whose `blast` clip autoplays and hides them), scaled to the Bomb's radius, and
## freed when that clip finishes. It has no collision and decides nothing: the Session clears
## and damages before it appears. It pauses with the tree, under `WorldRoot`. It must keep
## later attacks readable (PLANEJAMENTO Section 4 "Spiritual bomb").


## Seconds from full to invisible: the length of D-02's `blast` clip.
const FADE_SECONDS := 0.4

## The visual's player; its autoplay clip is the blast. Required.
@export var animation_player: AnimationPlayer


func _ready() -> void:
	if animation_player == null or not animation_player.is_playing():
		push_error("%s: 'animation_player' must be set and autoplay the blast clip" % get_path())
		queue_free()
		return
	animation_player.animation_finished.connect(_on_animation_finished)


## Scales the unit visual to [param radius], the Bomb radius in world units.
func setup(radius: float) -> void:
	scale = Vector3.ONE * radius


func _on_animation_finished(_clip: StringName) -> void:
	queue_free()
