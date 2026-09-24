class_name StageDirector
extends Node3D
## Adapter on a stage's `Stage` root: plays its [StageDefinition] through an
## [EncounterMachine]. It arms each Encounter's EntryVolume and ExitVolume and reports
## them, spawns every requested Wave and every reward Pickup under `RuntimeActors`,
## scores each defeat once and reports it, and relays off-screen threats to the HUD and
## stage clear to the Session. Enemies report outcomes; the machine decides progression
## (ENGINEERING_BRIEF 4.G).
##
## The Session calls [method check_setup] before the stage enters the tree and refuses the
## stage on any message, then [method setup] once after the ship is bound, then
## [method start_attempt] at every Attempt. Gates, Checkpoints and PortalLinks arrive in
## F10-02, Retry in F10-03. The Director sits under `WorldRoot`, which is PAUSABLE, so it
## stops while paused.


## The last Encounter of the stage completed. The Session connects it deferred.
signal stage_cleared
## A live enemy is threatening from off screen on [param side] (-1 left, +1 right).
signal threat_reported(side: int)
## A reward Pickup was accepted: re-emitted from [signal Pickup.accepted], for audio
## (F13-03). Its [param score_awarded] already reached the Run; never add it again.
signal pickup_accepted(pickup_id: StringName, kind: Pickup.Kind, score_awarded: int)

## Holds one child per Encounter, named by its id (`docs/STAGE_01_HANDOFF.md`).
const ENCOUNTERS_PATH := ^"Encounters"
## Where spawned enemies and Pickups go; never an authored node.
const RUNTIME_ACTORS_PATH := ^"RuntimeActors"
const ENTRY_VOLUME_NAME := ^"EntryVolume"
const EXIT_VOLUME_NAME := ^"ExitVolume"

## The authored route. Required, and it must validate.
@export var stage_definition: StageDefinition
## The actor scene of every Wave kind the route names; each root is an [EnemyActor].
@export var actor_scenes: Dictionary[StringName, PackedScene] = {}
## The [EnemyDefinition] of every Wave kind the route names.
@export var enemy_definitions: Dictionary[StringName, EnemyDefinition] = {}
## A [Pickup] scene of kind POWER. Required.
@export var power_pickup_scene: PackedScene
## A [Pickup] scene of kind SHIELD. Required.
@export var shield_pickup_scene: PackedScene
## Radius, in world units, of the horizontal circle a reward of more than one Pickup is
## laid out on around its marker. Claude's proposal.
@export var reward_spread: float = 1.5

var _machine: EncounterMachine
var _run_state: RunState
var _combat_state: CombatState
var _projectile_system: ProjectileSystem
var _player: Node3D
## One per Attempt, seeded by the Session and injected into every enemy.
var _rng := RandomNumberGenerator.new()
var _runtime_actors: Node3D
## The score of each enemy spawned and not yet reported defeated, by enemy id: the first
## report scores and erases it, so a repeat scores nothing.
var _live_enemies: Dictionary[StringName, int] = {}


func _physics_process(delta: float) -> void:
	if _machine != null:
		_machine.tick(delta)


## Every problem that stops this stage from playing, each naming the stage id and the
## path; empty when it can play. It resolves relative paths only, so it works before the
## stage enters the tree.
func check_setup() -> PackedStringArray:
	var errors: PackedStringArray = []
	var missing: PackedStringArray = []
	if stage_definition == null:
		missing.append("stage_definition")
	if power_pickup_scene == null:
		missing.append("power_pickup_scene")
	if shield_pickup_scene == null:
		missing.append("shield_pickup_scene")
	var stage_id := _stage_id()
	for field: String in missing:
		errors.append("stage '%s': required export '%s' is not set" % [stage_id, field])
	if not get_node_or_null(RUNTIME_ACTORS_PATH) is Node3D:
		errors.append("stage '%s': no Node3D at '%s'" % [stage_id, RUNTIME_ACTORS_PATH])
	if stage_definition == null:
		return errors
	var content_errors := stage_definition.validate()
	for message: String in content_errors:
		errors.append("stage '%s': content: %s" % [stage_id, message])
	if not content_errors.is_empty():
		return errors
	for encounter: EncounterDefinition in stage_definition.encounters:
		errors.append_array(_check_encounter(encounter))
	# An enemy refuses a definition that does not validate, and a Wave that never spawns
	# never completes: refuse the stage instead.
	for kind: StringName in enemy_definitions:
		var definition := enemy_definitions[kind]
		if definition != null:
			for message: String in definition.validate():
				errors.append("stage '%s': enemy_definitions '%s': %s" % [stage_id, kind, message])
	return errors


## Binds the Director to the Session's cores, the [ProjectileSystem] and the ship, creates
## its [EncounterMachine] and arms every Encounter's volumes. Once per Director: a
## second call is reported and changes nothing. Call it after [method check_setup] came
## back empty and the stage is in the tree.
func setup(run_state: RunState, combat_state: CombatState, projectile_system: ProjectileSystem, player: Node3D) -> void:
	if _machine != null:
		push_error("%s: setup was already called; ignored" % get_path())
		return
	_run_state = run_state
	_combat_state = combat_state
	_projectile_system = projectile_system
	_player = player
	_runtime_actors = get_node(RUNTIME_ACTORS_PATH) as Node3D
	_machine = EncounterMachine.new()
	_machine.setup(stage_definition)
	_machine.wave_requested.connect(_on_wave_requested)
	_machine.rewards_requested.connect(_on_rewards_requested)
	_machine.encounter_completed.connect(_on_encounter_completed)
	_machine.stage_cleared.connect(stage_cleared.emit)
	for encounter: EncounterDefinition in stage_definition.encounters:
		var root := _encounter_root(encounter.id)
		# Deferred: entry spawns Area3D actors and Pickups, which must not happen inside
		# the physics flush that reports the body.
		_arm(root.get_node(ENTRY_VOLUME_NAME) as Area3D, _on_entry_body_entered.bind(encounter.id))
		_arm(root.get_node(EXIT_VOLUME_NAME) as Area3D, _on_exit_body_entered.bind(encounter.id))


## Starts an Attempt with a new random stream seeded by [param attempt_seed], and begins
## the first Encounter: `PlayerStart` already lies inside its EntryVolume, so no
## `body_entered` would begin it.
func start_attempt(attempt_seed: int) -> void:
	if _machine == null:
		push_error("%s: start_attempt before setup; ignored" % get_path())
		return
	_rng = RandomNumberGenerator.new()
	_rng.seed = attempt_seed
	if not stage_definition.encounters.is_empty():
		_machine.notify_entered(stage_definition.encounters[0].id)


## The world-space merge of the active Encounter's EntryVolume and ExitVolume boxes: the
## route cross-section over the Encounter's length, for keeping enemies and the boss
## arena reachable. An empty [AABB] when no Encounter is active.
func get_active_encounter_bounds() -> AABB:
	if _machine == null:
		return AABB()
	var active_id := _machine.get_active_encounter_id()
	if active_id.is_empty():
		return AABB()
	var root := _encounter_root(active_id)
	return _volume_box(root.get_node(ENTRY_VOLUME_NAME) as Area3D).merge(_volume_box(root.get_node(EXIT_VOLUME_NAME) as Area3D))


## The progression core, for tests and dev tools to read. Null before [method setup].
func get_machine() -> EncounterMachine:
	return _machine


func _check_encounter(encounter: EncounterDefinition) -> PackedStringArray:
	var errors: PackedStringArray = []
	var stage_id := _stage_id()
	var path := NodePath("%s/%s" % [ENCOUNTERS_PATH, encounter.id])
	var root := get_node_or_null(path)
	if root == null:
		errors.append("stage '%s': no Encounter node at '%s'" % [stage_id, path])
		return errors
	for volume_name: NodePath in [ENTRY_VOLUME_NAME, EXIT_VOLUME_NAME]:
		var volume := root.get_node_or_null(volume_name) as Area3D
		if volume == null:
			errors.append("stage '%s': no Area3D at '%s/%s'" % [stage_id, path, volume_name])
		elif _box_shape(volume) == null:
			# The Encounter bounds, and so every enemy's spawn, come from these boxes.
			errors.append("stage '%s': '%s/%s' has no CollisionShape3D child with a BoxShape3D" % [stage_id, path, volume_name])
	for wave: WaveDefinition in encounter.waves:
		for index: int in wave.spawn_markers.size():
			var marker := wave.spawn_markers[index]
			if not root.get_node_or_null(marker) is Node3D:
				errors.append("stage '%s': Wave marker '%s/%s' is not a Node3D" % [stage_id, path, marker])
			var kind := wave.enemy_kind_at(index)
			if actor_scenes.get(kind) == null:
				errors.append("stage '%s': Wave kind '%s' at '%s/%s' has no 'actor_scenes' entry" % [stage_id, kind, path, marker])
			if enemy_definitions.get(kind) == null:
				errors.append("stage '%s': Wave kind '%s' at '%s/%s' has no 'enemy_definitions' entry" % [stage_id, kind, path, marker])
	for reward: RewardDefinition in encounter.rewards:
		if not root.get_node_or_null(reward.origin_marker) is Node3D:
			errors.append("stage '%s': reward marker '%s/%s' is not a Node3D" % [stage_id, path, reward.origin_marker])
	return errors


func _arm(volume: Area3D, handler: Callable) -> void:
	volume.monitoring = true
	volume.body_entered.connect(handler, CONNECT_DEFERRED)


func _on_entry_body_entered(body: Node3D, encounter_id: StringName) -> void:
	if is_instance_valid(body) and body == _player:
		_machine.notify_entered(encounter_id)


func _on_exit_body_entered(body: Node3D, encounter_id: StringName) -> void:
	if is_instance_valid(body) and body == _player:
		_machine.notify_exited(encounter_id)


## Spawns one enemy per marker of the Wave, at the marker's transform.
func _on_wave_requested(encounter_id: StringName, wave_index: int) -> void:
	var wave: WaveDefinition = stage_definition.find_encounter(encounter_id).waves[wave_index]
	var root := _encounter_root(encounter_id)
	var bounds := get_active_encounter_bounds()
	for index: int in wave.spawn_markers.size():
		var marker_path := wave.spawn_markers[index]
		var kind := wave.enemy_kind_at(index)
		var definition := enemy_definitions[kind]
		var enemy_id := EncounterMachine.enemy_id(encounter_id, marker_path)
		var node := actor_scenes[kind].instantiate()
		var actor := node as EnemyActor
		if actor == null:
			push_error("%s: 'actor_scenes' entry '%s' does not have an EnemyActor root; %s is not spawned" % [get_path(), kind, enemy_id])
			node.free()
			continue
		_runtime_actors.add_child(actor)
		actor.global_transform = (root.get_node(marker_path) as Node3D).global_transform
		if not actor.spawn_setup(definition, enemy_id, encounter_id, _rng, _projectile_system, _player, bounds):
			actor.queue_free()  # It reported why; a refused actor is the caller's to free.
			continue
		actor.defeated.connect(_on_enemy_defeated)
		actor.threat_reported.connect(threat_reported.emit)
		_live_enemies[enemy_id] = definition.score


## The first report of [param enemy_id] scores its definition's value and reaches the
## machine; a repeat does nothing. The actor frees itself.
func _on_enemy_defeated(enemy_id: StringName, encounter_id: StringName) -> void:
	if not _live_enemies.has(enemy_id):
		return
	var score: int = _live_enemies[enemy_id]
	_live_enemies.erase(enemy_id)
	_run_state.add_score(score)
	_machine.notify_enemy_defeated(enemy_id, encounter_id)


## Spawns every reward of the Encounter: `count` Pickups of its kind at its marker, on a
## horizontal circle of [member reward_spread] when there is more than one, with ids
## `&"<encounter_id>/power_<n>"` and `&"<encounter_id>/shield_<n>"`, n from 1 per kind.
func _on_rewards_requested(encounter_id: StringName) -> void:
	var encounter := stage_definition.find_encounter(encounter_id)
	var root := _encounter_root(encounter_id)
	var numbers: Dictionary[int, int] = {RewardDefinition.Kind.POWER: 0, RewardDefinition.Kind.SHIELD: 0}
	for reward: RewardDefinition in encounter.rewards:
		var origin := (root.get_node(reward.origin_marker) as Node3D).global_position
		var is_power := reward.kind == RewardDefinition.Kind.POWER
		for index: int in reward.count:
			numbers[reward.kind] += 1
			var pickup_id := StringName("%s/%s_%d" % [encounter_id, "power" if is_power else "shield", numbers[reward.kind]])
			var offset := Vector3.ZERO
			if reward.count > 1:
				var angle := TAU * index / reward.count
				offset = Vector3(cos(angle), 0.0, sin(angle)) * reward_spread
			_spawn_pickup(power_pickup_scene if is_power else shield_pickup_scene, pickup_id, origin + offset)


func _spawn_pickup(scene: PackedScene, pickup_id: StringName, at: Vector3) -> void:
	var node := scene.instantiate()
	var pickup := node as Pickup
	if pickup == null:
		push_error("%s: %s does not have a Pickup root; %s is not spawned" % [get_path(), scene.resource_path, pickup_id])
		node.free()
		return
	_runtime_actors.add_child(pickup)
	pickup.global_position = at
	pickup.setup(pickup_id, _combat_state, _player)
	pickup.accepted.connect(pickup_accepted.emit)


## An Encounter's ExitVolume and the next EntryVolume can overlap, and a volume the ship
## is already inside reports no new `body_entered`: after a completion, the next
## Encounter is begun at once when the ship is already in its EntryVolume. Deferred, so
## the machine finishes its completion signals first.
func _on_encounter_completed(encounter_id: StringName) -> void:
	var next_id := stage_definition.find_encounter(encounter_id).next_id
	if not next_id.is_empty():
		_enter_if_inside.call_deferred(next_id)


func _enter_if_inside(encounter_id: StringName) -> void:
	if not is_instance_valid(_player):
		return
	var entry := _encounter_root(encounter_id).get_node(ENTRY_VOLUME_NAME) as Area3D
	if entry.overlaps_body(_player):
		_machine.notify_entered(encounter_id)


func _encounter_root(encounter_id: StringName) -> Node:
	return get_node(NodePath("%s/%s" % [ENCOUNTERS_PATH, encounter_id]))


## The world-space box of the volume's first box-shaped [CollisionShape3D], which
## [method check_setup] guarantees.
func _volume_box(volume: Area3D) -> AABB:
	var shape_node := _box_shape(volume)
	var size := (shape_node.shape as BoxShape3D).size
	return shape_node.global_transform * AABB(-size * 0.5, size)


## The volume's first [CollisionShape3D] child holding a [BoxShape3D], or null.
func _box_shape(volume: Area3D) -> CollisionShape3D:
	for child: Node in volume.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is BoxShape3D:
			return shape_node
	return null


func _stage_id() -> StringName:
	return stage_definition.id if stage_definition != null else StringName(name)
