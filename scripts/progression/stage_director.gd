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
## [method start_attempt] at every Attempt the stage starts or restarts from its entry,
## and [method retry_from_checkpoint] for a Retry from a Checkpoint. Since F10-02 it also opens each [Gate] when its
## Encounter completes, activates each [Checkpoint] once through its own
## [CheckpointStore] (clearing hostile fire first), hides a PortalLink when its guard dies,
## and sets every Gate and link from the machine's state (`_apply_progress`). Since F10-03
## Defeat's Retry restores in place ([method retry_from_checkpoint]). The Director sits
## under `WorldRoot`, which is PAUSABLE, so it stops while paused.


## The last Encounter of the stage completed. The Session connects it deferred.
signal stage_cleared
## A live enemy is threatening from off screen on [param side] (-1 left, +1 right).
signal threat_reported(side: int)
## A reward Pickup was accepted: re-emitted from [signal Pickup.accepted], for audio
## (F13-03). Its [param score_awarded] already reached the Run; never add it again.
signal pickup_accepted(pickup_id: StringName, kind: Pickup.Kind, score_awarded: int)
## The Checkpoint [param checkpoint_id] activated for the first time: resources refilled,
## the Attempt committed and a Snapshot recorded. For presentation, such as an arch glow.
signal checkpoint_activated(checkpoint_id: StringName)

## Holds one child per Encounter, named by its id (`docs/STAGE_01_HANDOFF.md`).
const ENCOUNTERS_PATH := ^"Encounters"
## Holds one [Gate] per Encounter `gate_id`, named by it.
const GATES_PATH := ^"Gates"
## Where the ship enters the stage (GUIDE Section 5), and where Retry puts it before any
## Checkpoint.
const PLAYER_START_PATH := ^"PlayerStart"
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
## The PortalLink each portal guard feeds, by the guard's enemy id
## (`&"S1-04/Wave1_Sentry1"` → `^"Environment/PortalLinks/GuardLink1"`), relative to the
## stage root. A link hides when its guard dies and shows again while its Encounter is
## not complete.
@export var guard_links: Dictionary[StringName, NodePath] = {}
## Stage-relative portal light paths keyed by Seal id.
@export var portal_lights: Dictionary[StringName, NodePath] = {}
@export var resolved_light_material: Material
## Stage 2 commits the prerequisite Checkpoint even when the ship misses its arch.
@export var activate_checkpoint_on_entry: bool = false

var _seals: Dictionary[StringName, Seal] = {}
var _guard_seals: Dictionary[StringName, Seal] = {}
var _guard_actors: Dictionary[StringName, EnemyActor] = {}

var _machine: EncounterMachine
## One per Director, so a new stage load or a Restart starts at Stage Entry with no
## Checkpoint.
var _checkpoint_store: CheckpointStore
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
	errors.append_array(_check_gates_checkpoints_and_links())
	errors.append_array(_check_seals())
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
	_machine.gate_opened.connect(_on_gate_opened)
	for encounter: EncounterDefinition in stage_definition.encounters:
		var root := _encounter_root(encounter.id)
		# Deferred: entry spawns Area3D actors and Pickups, which must not happen inside
		# the physics flush that reports the body.
		_arm(root.get_node(ENTRY_VOLUME_NAME) as Area3D, _on_entry_body_entered.bind(encounter.id))
		_arm(root.get_node(EXIT_VOLUME_NAME) as Area3D, _on_exit_body_entered.bind(encounter.id))
	_setup_checkpoints()
	_setup_seals()
	_apply_progress()


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


## Defeat's Retry, in place: returns false and changes nothing before any Checkpoint
## activated (the Session Restarts instead). Otherwise removes every runtime actor and
## Pickup of the failed Attempt, restores the latest Snapshot into the cores (resources,
## committed statistics, completed and rewarded Encounters, flags; queued Waves are
## cancelled), takes [param player], the new ship, and a new random stream seeded by
## [param attempt_seed], and sets every Gate and link from the restored state. The
## Session has already cleared the field and spawned the ship at
## [method get_respawn_transform]; it begins the Attempt afterwards.
func retry_from_checkpoint(player: PlayerController, attempt_seed: int) -> bool:
	if _checkpoint_store.latest() == null:
		return false
	for child: Node in _runtime_actors.get_children():
		_runtime_actors.remove_child(child)
		child.queue_free()
	_live_enemies.clear()
	_guard_actors.clear()
	_checkpoint_store.retry_into(_combat_state, _run_state, _machine)
	_player = player
	_rng = RandomNumberGenerator.new()
	_rng.seed = attempt_seed
	_apply_progress()
	return true


## Where Retry puts the ship: the latest activated Checkpoint's `Respawn`, or
## `PlayerStart` before any.
func get_respawn_transform() -> Transform3D:
	var checkpoint_id := _checkpoint_store.latest_checkpoint_id()
	if checkpoint_id.is_empty():
		return (get_node(PLAYER_START_PATH) as Node3D).global_transform
	var definition := stage_definition.find_checkpoint(checkpoint_id)
	return (get_node(definition.node_path) as Checkpoint).get_respawn_transform()


## The latest activated Checkpoint's `display_name`, for the Defeat screen, or `""`
## before any (the screen then reads "Início da fase").
func retry_location_name() -> String:
	var checkpoint_id := _checkpoint_store.latest_checkpoint_id()
	if checkpoint_id.is_empty():
		return ""
	return stage_definition.find_checkpoint(checkpoint_id).display_name


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
		_enter_with_checkpoint(encounter_id)


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
		_setup_guard(actor, enemy_id)


## The first report of [param enemy_id] scores its definition's value and reaches the
## machine; a repeat does nothing. The actor frees itself.
func _on_enemy_defeated(enemy_id: StringName, encounter_id: StringName) -> void:
	if not _live_enemies.has(enemy_id):
		return
	var score: int = _live_enemies[enemy_id]
	_live_enemies.erase(enemy_id)
	_hide_guard_link(enemy_id)
	_run_state.add_score(score)
	_machine.notify_enemy_defeated(enemy_id, encounter_id)
	_report_guard_defeat(enemy_id)


## Spawns every reward of the Encounter: `count` Pickups of its kind at its marker, on a
## horizontal circle of [member reward_spread] when there is more than one, with ids
## `&"<encounter_id>/power_<n>"` and `&"<encounter_id>/shield_<n>"`, n from 1 per kind.
func _on_rewards_requested(encounter_id: StringName) -> void:
	var encounter := stage_definition.find_encounter(encounter_id)
	var root := _encounter_root(encounter_id)
	var numbers: Dictionary[int, int] = {RewardDefinition.Kind.POWER: 0, RewardDefinition.Kind.SHIELD: 0}
	for reward: RewardDefinition in encounter.rewards:
		if _reward_seal(encounter, reward) != null:
			continue
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
		_enter_with_checkpoint(encounter_id)


## Every Gate the route names must be a [Gate] with its barrier collision and closed
## visual, every Checkpoint a [Checkpoint] with the definition's id and a `Respawn`, and
## every guard link a [Node3D].
func _check_gates_checkpoints_and_links() -> PackedStringArray:
	var errors: PackedStringArray = []
	var stage_id := _stage_id()
	for encounter: EncounterDefinition in stage_definition.encounters:
		if encounter.gate_id.is_empty():
			continue
		var path := NodePath("%s/%s" % [GATES_PATH, encounter.gate_id])
		var gate := get_node_or_null(path)
		if not gate is Gate:
			errors.append("stage '%s': no Gate (gate.gd) at '%s'" % [stage_id, path])
		elif not gate.get_node_or_null(Gate.COLLISION_PATH) is CollisionShape3D or not gate.get_node_or_null(Gate.CLOSED_VISUAL_PATH) is Node3D:
			errors.append("stage '%s': Gate '%s' needs '%s' and '%s'" % [stage_id, path, Gate.COLLISION_PATH, Gate.CLOSED_VISUAL_PATH])
	for definition: CheckpointDefinition in stage_definition.checkpoints:
		var checkpoint := get_node_or_null(definition.node_path) as Checkpoint
		if checkpoint == null:
			errors.append("stage '%s': no Checkpoint (checkpoint.gd) at '%s'" % [stage_id, definition.node_path])
		elif checkpoint.checkpoint_id != definition.id:
			errors.append("stage '%s': Checkpoint '%s' has checkpoint_id '%s', not '%s'" % [stage_id, definition.node_path, checkpoint.checkpoint_id, definition.id])
		elif not checkpoint.get_node_or_null(Checkpoint.RESPAWN_PATH) is Node3D:
			errors.append("stage '%s': Checkpoint '%s' has no Node3D at '%s'" % [stage_id, definition.node_path, Checkpoint.RESPAWN_PATH])
	# A key that names no spawned enemy would leave its link lit for the whole Attempt.
	var enemy_ids: Dictionary[StringName, bool] = {}
	for encounter: EncounterDefinition in stage_definition.encounters:
		for wave: WaveDefinition in encounter.waves:
			for marker: NodePath in wave.spawn_markers:
				enemy_ids[EncounterMachine.enemy_id(encounter.id, marker)] = true
	for enemy_id: StringName in guard_links:
		if not enemy_ids.has(enemy_id):
			errors.append("stage '%s': guard link key '%s' names no Wave enemy" % [stage_id, enemy_id])
		if not get_node_or_null(guard_links[enemy_id]) is Node3D:
			errors.append("stage '%s': guard link of '%s' at '%s' is not a Node3D" % [stage_id, enemy_id, guard_links[enemy_id]])
	return errors


## Creates this Director's [CheckpointStore] and arms every Checkpoint.
func _setup_checkpoints() -> void:
	_checkpoint_store = CheckpointStore.new()
	for definition: CheckpointDefinition in stage_definition.checkpoints:
		var checkpoint := get_node(definition.node_path) as Checkpoint
		checkpoint.set_armed(true)
		# Deferred: activation clears fire, refills and may spawn the resume Encounter.
		checkpoint.entered.connect(_on_checkpoint_entered, CONNECT_DEFERRED)


## A first valid entry clears hostile fire, then activates the Checkpoint through the
## store (refill, commit, Snapshot), and begins its resume Encounter at once when the
## ship is already inside that EntryVolume, which the machine refused while the
## Checkpoint was inactive. An entry before the preceding Encounter completed, or a
## revisit, does nothing at all: no clear and no refill.
func _on_checkpoint_entered(checkpoint_id: StringName) -> void:
	var definition := stage_definition.find_checkpoint(checkpoint_id)
	if definition == null or not _machine.is_completed(definition.after_encounter_id) \
			or _machine.is_checkpoint_activated(checkpoint_id):
		return
	_projectile_system.clear_hostile_all()
	if not _checkpoint_store.activate(checkpoint_id, _combat_state, _run_state, _machine):
		return
	checkpoint_activated.emit(checkpoint_id)
	_enter_if_inside(definition.resume_encounter_id)


## Clears hostile fire, awarding nothing, then opens the Gate (STAGE_DESIGN "Shared
## encounter rules").
func _on_gate_opened(gate_id: StringName) -> void:
	_projectile_system.clear_hostile_all()
	_gate(gate_id).set_open(true)


## Sets every Gate and PortalLink from the machine's state: a Gate is open only when its
## Encounter is complete, so a Gate a failed Attempt opened closes again, and a guard link
## shows while its Encounter is not complete. Called at the end of [method setup], and
## by [method retry_from_checkpoint] after a restore.
func _apply_progress() -> void:
	_apply_seal_progress()
	var open_ids := _machine.get_open_gate_ids()
	for encounter: EncounterDefinition in stage_definition.encounters:
		if not encounter.gate_id.is_empty():
			_gate(encounter.gate_id).set_open(encounter.gate_id in open_ids)
	for enemy_id: StringName in guard_links:
		var encounter_id := StringName(String(enemy_id).get_slice("/", 0))
		(get_node(guard_links[enemy_id]) as Node3D).visible = not _machine.is_completed(encounter_id)


func _hide_guard_link(enemy_id: StringName) -> void:
	if guard_links.has(enemy_id):
		(get_node(guard_links[enemy_id]) as Node3D).visible = false


func _gate(gate_id: StringName) -> Gate:
	return get_node(NodePath("%s/%s" % [GATES_PATH, gate_id])) as Gate


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


func _encounter_seals(encounter: EncounterDefinition) -> Array[Seal]:
	var seals: Array[Seal] = []
	var root := _encounter_root(encounter.id).get_node_or_null(^"Seals")
	if root != null:
		for child: Node in root.get_children():
			if child is Seal:
				seals.append(child as Seal)
	return seals


func _reward_seal(encounter: EncounterDefinition, reward: RewardDefinition) -> Seal:
	var root := _encounter_root(encounter.id)
	var origin := root.get_node_or_null(reward.origin_marker)
	if encounter.completion == EncounterDefinition.Completion.OBJECTIVES and origin != null:
		for seal: Seal in _encounter_seals(encounter):
			if seal.is_ancestor_of(origin):
				return seal
	return null


func _check_seals() -> PackedStringArray:
	var errors: PackedStringArray = []
	var known: Dictionary[StringName, Seal] = {}
	for encounter: EncounterDefinition in stage_definition.encounters:
		if encounter.completion != EncounterDefinition.Completion.OBJECTIVES:
			continue
		if _encounter_root(encounter.id) == null:
			continue # The ordinary Encounter check already names the missing root.
		var objective_seals: Dictionary[StringName, Seal] = {}
		var guard_ids: Array[StringName] = []
		for wave: WaveDefinition in encounter.waves:
			for marker: NodePath in wave.spawn_markers:
				guard_ids.append(EncounterMachine.enemy_id(encounter.id, marker))
		for seal: Seal in _encounter_seals(encounter):
			if known.has(seal.seal_id) or seal.seal_id not in encounter.required_objective_ids:
				errors.append("stage '%s': Seal '%s' has duplicate or unnamed objective '%s'" % [_stage_id(), seal.name, seal.seal_id])
			known[seal.seal_id] = seal
			objective_seals[seal.seal_id] = seal
			if seal.guard_links == null:
				errors.append("stage '%s': Seal '%s' has no guard_links" % [_stage_id(), seal.seal_id])
				continue
			for link: Node in seal.guard_links.get_children():
				var marker: NodePath = link.get_meta(&"guard_spawn", NodePath())
				if EncounterMachine.enemy_id(encounter.id, marker) not in guard_ids:
					errors.append("stage '%s': Seal '%s' guard '%s' names no Wave marker" % [_stage_id(), seal.seal_id, marker])
		for objective_id: StringName in encounter.required_objective_ids:
			if not objective_seals.has(objective_id):
				errors.append("stage '%s': objective '%s' has no Seal" % [_stage_id(), objective_id])
		for reward: RewardDefinition in encounter.rewards:
			if String(reward.origin_marker).begins_with("Seals/") and _reward_seal(encounter, reward) == null:
				errors.append("stage '%s': per-Seal reward '%s' has no Seal" % [_stage_id(), reward.origin_marker])
	for seal_id: StringName in portal_lights:
		if not known.has(seal_id):
			errors.append("stage '%s': portal_lights key '%s' names no Seal" % [_stage_id(), seal_id])
		if not get_node_or_null(portal_lights[seal_id]) is GeometryInstance3D:
			errors.append("stage '%s': portal light '%s' is not a GeometryInstance3D" % [_stage_id(), portal_lights[seal_id]])
	if not portal_lights.is_empty() and resolved_light_material == null:
		errors.append("stage '%s': portal_lights requires resolved_light_material" % _stage_id())
	return errors


func _setup_seals() -> void:
	for encounter: EncounterDefinition in stage_definition.encounters:
		if encounter.completion != EncounterDefinition.Completion.OBJECTIVES:
			continue
		for seal: Seal in _encounter_seals(encounter):
			_seals[seal.seal_id] = seal
			seal.setup(_projectile_system, encounter.id)
			seal.seal_destroyed.connect(_on_seal_destroyed.bind(encounter.id))
			seal.guards_activated.connect(_on_seal_guards_activated)
			for link: Node in seal.guard_links.get_children():
				var marker: NodePath = link.get_meta(&"guard_spawn")
				_guard_seals[EncounterMachine.enemy_id(encounter.id, marker)] = seal


func _setup_guard(actor: EnemyActor, enemy_id: StringName) -> void:
	if not _guard_seals.has(enemy_id):
		return
	var seal := _guard_seals[enemy_id]
	_guard_actors[enemy_id] = actor
	actor.set_engaged(int(seal.capture()["state"]) != SealRules.State.DORMANT)
	actor.damaged.connect(seal.notify_guard_shot)


func _on_seal_guards_activated(seal_id: StringName) -> void:
	for guard_id: StringName in _guard_actors:
		if _guard_seals[guard_id].seal_id == seal_id and is_instance_valid(_guard_actors[guard_id]):
			_guard_actors[guard_id].set_engaged(true)


func _report_guard_defeat(enemy_id: StringName) -> void:
	if _guard_seals.has(enemy_id):
		_guard_actors.erase(enemy_id)
		_guard_seals[enemy_id].notify_guard_defeated(enemy_id)


func _on_seal_destroyed(seal_id: StringName, encounter_id: StringName) -> void:
	_resolve_portal_light(seal_id)
	_spawn_seal_rewards(seal_id, encounter_id)
	_machine.notify_objective(seal_id)


func _spawn_seal_rewards(seal_id: StringName, encounter_id: StringName) -> void:
	var encounter := stage_definition.find_encounter(encounter_id)
	var numbers: Dictionary[int, int] = {RewardDefinition.Kind.POWER: 0, RewardDefinition.Kind.SHIELD: 0}
	for reward: RewardDefinition in encounter.rewards:
		if _reward_seal(encounter, reward) != _seals[seal_id]:
			continue
		var origin := (_encounter_root(encounter_id).get_node(reward.origin_marker) as Node3D).global_position
		var is_power := reward.kind == RewardDefinition.Kind.POWER
		for index: int in reward.count:
			numbers[reward.kind] += 1
			var pickup_id := StringName("%s/%s_%d" % [seal_id, "power" if is_power else "shield", numbers[reward.kind]])
			var offset := Vector3.ZERO
			if reward.count > 1:
				var angle := TAU * index / reward.count
				offset = Vector3(cos(angle), 0.0, sin(angle)) * reward_spread
			_spawn_pickup(power_pickup_scene if is_power else shield_pickup_scene, pickup_id, origin + offset)


func _resolve_portal_light(seal_id: StringName) -> void:
	if portal_lights.has(seal_id):
		(get_node(portal_lights[seal_id]) as GeometryInstance3D).material_override = resolved_light_material


func _apply_seal_progress() -> void:
	# Every Stage 2 Checkpoint follows the entire Seal encounter. Before CP2-A the
	# Session reloads the stage; after it all three authored Seals stay destroyed.
	var progress: Dictionary = _machine.capture()
	var objectives: PackedStringArray = progress["objectives"]
	for objective_id: String in objectives:
		_resolve_portal_light(StringName(objective_id))


func _enter_with_checkpoint(encounter_id: StringName) -> void:
	if _machine.notify_entered(encounter_id) or not activate_checkpoint_on_entry:
		return
	var encounter := stage_definition.find_encounter(encounter_id)
	if encounter == null or encounter.checkpoint_id.is_empty():
		return
	var checkpoint := stage_definition.find_checkpoint(encounter.checkpoint_id)
	if _machine.is_checkpoint_activated(checkpoint.id) or not _machine.is_completed(checkpoint.after_encounter_id):
		return
	# Only the first incomplete route entry may activate its prerequisite.
	for preceding: EncounterDefinition in stage_definition.encounters:
		if preceding.id == encounter_id:
			_on_checkpoint_entered(checkpoint.id)
			_machine.notify_entered(encounter_id)
			return
		if not _machine.is_completed(preceding.id):
			return
