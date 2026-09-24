class_name AudioController
extends Node
## Adapter that plays the catalogue sound events and the music tracks.
##
## Every sound effect is gated by the [AudioLimiter] Rules Core (F13-01): event
## intervals, per-event and global voice caps, and priority steals. Playback runs
## through a code-built pool of [AudioStreamPlayer]s on [member sfx_bus]; music uses
## two players on [member music_bus] and crossfades between them. Menu sounds come
## from the Viewport's focus changes and the [Interface]'s action requests, coalesced
## to at most one per frame with accept outranking focus.
##
## F13-03 attaches this to `Main/Audio` (`process_mode = ALWAYS`, so the limiter and
## the menu sounds run while the tree is paused) and wires the gameplay producers;
## this script connects nothing but its own UI sources, in [method setup].


## Emitted after a catalogue event started a voice on the SFX pool.
signal event_played(event: StringName)

## The 17 catalogue event ids (.scratch/audio/spec.md "Event catalogue").
const EVENTS: Array[StringName] = [
	&"ui_focus", &"ui_accept", &"player_shot", &"enemy_hit", &"graze",
	&"shield_broken", &"player_hit", &"bomb_used", &"player_defeated",
	&"pickup_power", &"pickup_shield", &"enemy_defeated", &"checkpoint_activated",
	&"threat_warning", &"boss_phase_changed", &"boss_defeated", &"stage_cleared",
]

## The limiter rule per catalogue event, as `x` = minimum interval in seconds,
## `y` = voices of this event, `z` = priority where higher wins. Intervals and
## voices are Astra's revised selection (`sound_effects/selection.json`, F13-04);
## priorities are the spec's "Event catalogue" proposals.
const EVENT_RULES := {
	&"ui_focus": Vector3(0.12, 1, 3),
	&"ui_accept": Vector3(0.15, 1, 3),
	&"player_shot": Vector3(0.25, 1, 0),
	&"enemy_hit": Vector3(0.2, 1, 0),
	&"graze": Vector3(0.3, 1, 1),
	&"shield_broken": Vector3(0.3, 1, 3),
	&"player_hit": Vector3(0.3, 1, 3),
	&"bomb_used": Vector3(0.5, 1, 3),
	&"player_defeated": Vector3(2.5, 1, 4),
	&"pickup_power": Vector3(0.5, 1, 1),
	&"pickup_shield": Vector3(0.6, 1, 2),
	&"enemy_defeated": Vector3(0.25, 1, 1),
	&"checkpoint_activated": Vector3(1.0, 1, 2),
	&"threat_warning": Vector3(1.5, 1, 2),
	&"boss_phase_changed": Vector3(1.0, 1, 3),
	&"boss_defeated": Vector3(2.0, 1, 4),
	&"stage_cleared": Vector3(2.0, 1, 4),
}

## The music track ids PLANEJAMENTO allows (spec "Cross-feature contracts"). Route
## and boss tracks may share one stream; [method play_music] never restarts a
## stream that is already playing.
const MUSIC_TRACK_IDS: Array[StringName] = [
	&"menu", &"stage_01_route", &"stage_01_boss", &"stage_02_route", &"stage_02_boss",
]

## The voice duration used when a stream reports no length.
const MIN_VOICE_SECONDS := 0.1

## The volume a music fade starts from and ends at; effectively silent.
const FADE_FLOOR_DB := -60.0

@export_group("Sound effects")
## Catalogue event id to stream. Every sound effect must be non-looping: the
## limiter counts a voice for the stream's length. Keys outside [constant EVENTS]
## and null streams are reported and ignored.
@export var event_streams: Dictionary[StringName, AudioStream] = {}
## Per-event volume in dB; events missing here play at 0.
@export var event_volume_db: Dictionary[StringName, float] = {}
## Global sound-effect voice cap; also the size of the player pool.
@export var max_voices: int = 12
## Bus every sound-effect player sends to.
@export var sfx_bus: StringName = &"SFX"

@export_group("Music")
## Music track id to stream. With this empty, every music call is a silent no-op
## (the game ships without music unless D-01 finds a permitted track).
@export var music_tracks: Dictionary[StringName, AudioStream] = {}
## Bus both music players send to.
@export var music_bus: StringName = &"Music"
## Crossfade duration in seconds between music tracks; 0 switches at once.
@export var music_crossfade_seconds: float = 1.0

var _limiter: AudioLimiter
var _sfx_players: Array[AudioStreamPlayer] = []
## The limiter voice each pool player holds, parallel to [member _sfx_players].
var _player_voice_ids: Array[int] = []
var _music_players: Array[AudioStreamPlayer] = []
var _music_tween: Tween
var _current_music_player: AudioStreamPlayer
var _current_music_id: StringName = &""
var _valid_event_streams: Dictionary[StringName, AudioStream] = {}
var _valid_music_tracks: Dictionary[StringName, AudioStream] = {}
var _queued_focus: bool = false
var _queued_accept: bool = false
## The event [method play_event_after] holds, or `&""`, and the event it waits out.
var _waiting_event: StringName = &""
var _waiting_after: StringName = &""
var _interface_setup: bool = false
var _disabled: bool = false


func _ready() -> void:
	if max_voices < 1:
		push_error("%s: required export 'max_voices' must be at least 1" % get_path())
		_disable()
		return
	if AudioServer.get_bus_index(sfx_bus) < 0:
		push_error("%s: required export 'sfx_bus' names no audio bus ('%s')" % [get_path(), sfx_bus])
		_disable()
		return
	if AudioServer.get_bus_index(music_bus) < 0:
		push_error("%s: required export 'music_bus' names no audio bus ('%s')" % [get_path(), music_bus])
		_disable()
		return
	_collect_valid_streams()
	_limiter = AudioLimiter.new(max_voices)
	for event: StringName in EVENTS:
		var rule: Vector3 = EVENT_RULES[event]
		_limiter.set_rule(event, rule.x, int(rule.y), int(rule.z))
	_limiter.voice_stolen.connect(_on_voice_stolen)
	for _index: int in range(max_voices):
		var sfx_player := AudioStreamPlayer.new()
		sfx_player.bus = sfx_bus
		add_child(sfx_player)
		_sfx_players.append(sfx_player)
		_player_voice_ids.append(AudioLimiter.REFUSED)
	for _index: int in range(2):
		var music_player := AudioStreamPlayer.new()
		music_player.bus = music_bus
		add_child(music_player)
		_music_players.append(music_player)


## Ticks the limiter, plays the waiting event once its voice-to-wait-out expired, and
## plays the coalesced UI sound of this frame. Runs while the tree is paused once
## attached to `Main/Audio` (ALWAYS): audio is presentation, and menu sounds work on
## Pause.
func _process(delta: float) -> void:
	if _limiter != null:
		_limiter.tick(delta)
		if not _waiting_event.is_empty() and _limiter.active_count(_waiting_after) == 0:
			var event: StringName = _waiting_event
			_waiting_event = &""
			play_event(event)
	if _queued_accept:
		_queued_accept = false
		_queued_focus = false
		play_event(&"ui_accept")
	elif _queued_focus:
		_queued_focus = false
		play_event(&"ui_focus")


## Connects the two UI sound sources, once: the Viewport's `gui_focus_changed`
## (queues `ui_focus`) and [param interface]'s `action_requested` (queues
## `ui_accept` for every action except `back_refused`). A second call, a null
## interface, or a call while outside the tree is a `push_error` and nothing else.
func setup(interface: Interface) -> void:
	if _interface_setup:
		push_error("%s: setup() was already called; the first connections stay" % get_path())
		return
	if interface == null:
		push_error("%s: setup() needs a non-null Interface" % get_path())
		return
	if not is_inside_tree():
		push_error("%s: setup() needs the controller inside the tree, for its Viewport" % get_path())
		return
	_interface_setup = true
	get_viewport().gui_focus_changed.connect(_on_gui_focus_changed)
	interface.action_requested.connect(_on_interface_action_requested)


## Plays one catalogue event through the limiter. An id outside [constant EVENTS]
## is a `push_error`; a catalogue id with no stream returns false silently. True
## when a voice was granted and started, after [signal event_played] was emitted.
func play_event(event: StringName) -> bool:
	if _disabled:
		return false
	if not EVENTS.has(event):
		push_error("%s: play_event got '%s', which is not a catalogue event" % [get_path(), event])
		return false
	var stream: AudioStream = _valid_event_streams.get(event, null)
	if stream == null:
		return false
	var voice_id: int = _limiter.request(event, maxf(stream.get_length(), MIN_VOICE_SECONDS))
	if voice_id == AudioLimiter.REFUSED:
		return false
	var player_index: int = _free_player_index()
	# The pool equals the global cap, so a granted voice always has a player.
	assert(player_index >= 0, "AudioController: a voice was granted with no free player")
	var player: AudioStreamPlayer = _sfx_players[player_index]
	player.stream = stream
	player.volume_db = event_volume_db.get(event, 0.0)
	player.play()
	_player_voice_ids[player_index] = voice_id
	event_played.emit(event)
	return true


## Plays [param event] once no voice of [param after] is active: at once when none is,
## else from [method _process] on the frame the limiter expires the last one, so the
## two follow each other instead of overlapping. One event waits at a time; a later
## call replaces it, and [method stop_all] drops it. Both ids must be catalogue events.
func play_event_after(event: StringName, after: StringName) -> void:
	if _disabled:
		return
	if not EVENTS.has(event) or not EVENTS.has(after):
		push_error(
			"%s: play_event_after got '%s' after '%s'; both must be catalogue events"
			% [get_path(), event, after]
		)
		return
	if _limiter.active_count(after) == 0:
		play_event(event)
		return
	_waiting_event = event
	_waiting_after = after


## Stops every sound-effect voice, drops the event [method play_event_after] holds and
## clears the limiter's voices and intervals (the core half of a stage unload). Music is
## left alone: it changes through [method play_music] and [method stop_music].
func stop_all() -> void:
	if _disabled or _limiter == null:
		return
	for index: int in _sfx_players.size():
		_sfx_players[index].stop()
		_player_voice_ids[index] = AudioLimiter.REFUSED
	_waiting_event = &""
	_limiter.clear()


## Stops every sound effect and the music at once, drops every queued and waiting
## sound, and disables the controller for good: the Session's last call before it
## quits. A stream still playing when the engine exits is never released, and Godot
## reports it as "resources still in use at exit".
func silence() -> void:
	stop_all()
	_queued_accept = false
	_queued_focus = false
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for player: AudioStreamPlayer in _music_players:
		player.stop()
	_current_music_player = null
	_current_music_id = &""
	_disable()


## Starts [param track], crossfading with the track in play over
## [member music_crossfade_seconds]. A stream already playing continues, even under
## another id; an unmapped id stops the music; with [member music_tracks] empty
## every music call is a silent no-op.
func play_music(track: StringName) -> void:
	if _disabled or music_tracks.is_empty():
		return
	var stream: AudioStream = _valid_music_tracks.get(track, null)
	if stream == null:
		stop_music()
		return
	if (
		_current_music_player != null
		and _current_music_player.playing
		and _current_music_player.stream == stream
	):
		_current_music_id = track
		return
	var player: AudioStreamPlayer = _idle_music_player()
	var old_player: AudioStreamPlayer = _current_music_player
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	for other: AudioStreamPlayer in _music_players:
		if other != player and other != old_player and other.playing:
			other.stop()
	player.stream = stream
	if music_crossfade_seconds <= 0.0:
		if old_player != null and old_player != player:
			old_player.stop()
		player.volume_db = 0.0
		player.play()
	else:
		player.volume_db = FADE_FLOOR_DB
		player.play()
		_music_tween = create_tween()
		_music_tween.set_parallel(true)
		_music_tween.tween_property(player, "volume_db", 0.0, music_crossfade_seconds)
		if old_player != null and old_player != player:
			_music_tween.tween_property(
				old_player, "volume_db", FADE_FLOOR_DB, music_crossfade_seconds
			)
			_music_tween.chain().tween_callback(old_player.stop)
	_current_music_player = player
	_current_music_id = track


## Fades the music out over [member music_crossfade_seconds] and stops it.
func stop_music() -> void:
	_current_music_id = &""
	if _disabled or music_tracks.is_empty():
		return
	var player: AudioStreamPlayer = _current_music_player
	_current_music_player = null
	if player == null or not player.playing:
		return
	if _music_tween != null and _music_tween.is_valid():
		_music_tween.kill()
	if music_crossfade_seconds <= 0.0:
		player.stop()
		return
	_music_tween = create_tween()
	_music_tween.tween_property(player, "volume_db", FADE_FLOOR_DB, music_crossfade_seconds)
	_music_tween.tween_callback(player.stop)


## The track in play, or `&""` when no music plays (including during a fade-out).
func get_current_music() -> StringName:
	return _current_music_id


## Sound-effect voices the limiter holds right now.
func get_active_voice_count() -> int:
	if _limiter == null:
		return 0
	return _limiter.active_count()


## The catalogue ids with no usable stream; F13-03's scene test asserts this is empty.
func missing_events() -> PackedStringArray:
	var missing: PackedStringArray = PackedStringArray()
	for event: StringName in EVENTS:
		if not _valid_event_streams.has(event):
			missing.append(event)
	return missing


## Stops this controller after a loud setup error: [method _process] no longer runs
## and [method play_event] and [method play_music] do nothing.
func _disable() -> void:
	_disabled = true
	set_process(false)


## Copies the usable entries of [member event_streams] and [member music_tracks],
## reporting every key outside the catalogue and every null stream (CONVENTIONS
## "Setup errors are loud"); a reported entry is ignored and the rest still work.
func _collect_valid_streams() -> void:
	for event: StringName in event_streams.keys():
		var event_stream: AudioStream = event_streams[event]
		if not EVENTS.has(event):
			push_error(
				"%s: 'event_streams' key '%s' is not a catalogue event; the entry is ignored"
				% [get_path(), event]
			)
			continue
		if event_stream == null:
			push_error(
				"%s: 'event_streams' entry '%s' is null; the entry is ignored"
				% [get_path(), event]
			)
			continue
		_valid_event_streams[event] = event_stream
	for track: StringName in music_tracks.keys():
		var track_stream: AudioStream = music_tracks[track]
		if not MUSIC_TRACK_IDS.has(track):
			push_error(
				"%s: 'music_tracks' key '%s' is not a track id; the entry is ignored"
				% [get_path(), track]
			)
			continue
		if track_stream == null:
			push_error(
				"%s: 'music_tracks' entry '%s' is null; the entry is ignored"
				% [get_path(), track]
			)
			continue
		_valid_music_tracks[track] = track_stream


## The first pool player whose voice is no longer active, or -1 when there is none.
func _free_player_index() -> int:
	for index: int in _sfx_players.size():
		if not _limiter.is_active(_player_voice_ids[index]):
			return index
	return -1


## The music player that is not the current one; with two players one is always idle.
func _idle_music_player() -> AudioStreamPlayer:
	for player: AudioStreamPlayer in _music_players:
		if player != _current_music_player:
			return player
	return _music_players[0]


func _on_voice_stolen(voice_id: int) -> void:
	for index: int in _sfx_players.size():
		if _player_voice_ids[index] == voice_id:
			_sfx_players[index].stop()
			_player_voice_ids[index] = AudioLimiter.REFUSED
			return


func _on_gui_focus_changed(_control: Control) -> void:
	_queued_focus = true


func _on_interface_action_requested(action: StringName, _payload: Dictionary) -> void:
	if action == &"back_refused":
		return
	_queued_accept = true
