extends SceneTree
## Offline check of the 17 selected, non-looping SFX streams.

const EVENT_FILES: Dictionary = {
	&"ui_focus": "res://assets/audio/sfx/interface/select_002.ogg",
	&"ui_accept": "res://assets/audio/sfx/interface/confirmation_001.ogg",
	&"player_shot": "res://assets/audio/sfx/scifi/laserSmall_000.ogg",
	&"enemy_hit": "res://assets/audio/sfx/impact/impactGeneric_light_000.ogg",
	&"graze": "res://assets/audio/sfx/interface/drop_001.ogg",
	&"shield_broken": "res://assets/audio/sfx/scifi/forceField_000.ogg",
	&"player_hit": "res://assets/audio/sfx/impact/impactSoft_heavy_000.ogg",
	&"bomb_used": "res://assets/audio/sfx/scifi/explosionCrunch_000.ogg",
	&"player_defeated": "res://assets/audio/sfx/scifi/lowFrequency_explosion_000.ogg",
	&"pickup_power": "res://assets/audio/sfx/interface/drop_002.ogg",
	&"pickup_shield": "res://assets/audio/sfx/digital/phaserUp2.ogg",
	&"enemy_defeated": "res://assets/audio/sfx/impact/impactGeneric_light_003.ogg",
	&"checkpoint_activated": "res://assets/audio/sfx/digital/phaseJump3.ogg",
	&"threat_warning": "res://assets/audio/sfx/digital/twoTone2.ogg",
	&"boss_phase_changed": "res://assets/audio/sfx/digital/phaserUp7.ogg",
	&"boss_defeated": "res://assets/audio/sfx/impact/impactBell_heavy_000.ogg",
	&"stage_cleared": "res://assets/audio/sfx/digital/threeTone1.ogg",
}

const ALLOWED_EVENTS: Array[StringName] = [
	&"ui_focus", &"ui_accept", &"player_shot", &"enemy_hit", &"graze",
	&"shield_broken", &"player_hit", &"bomb_used", &"player_defeated",
	&"pickup_power", &"pickup_shield", &"enemy_defeated",
	&"checkpoint_activated", &"threat_warning", &"boss_phase_changed",
	&"boss_defeated", &"stage_cleared",
]

func _initialize() -> void:
	var failures: int = 0
	if EVENT_FILES.size() != 17:
		failures += 1
		printerr("Expected 17 audio event ids, found ", EVENT_FILES.size())
	for event_id: StringName in EVENT_FILES:
		if not ALLOWED_EVENTS.has(event_id):
			printerr("Unknown audio event id: ", event_id)
			failures += 1
			continue
		var path: String = EVENT_FILES[event_id]
		var stream: AudioStream = load(path) as AudioStream
		if stream == null:
			printerr(event_id, " missing AudioStream: ", path)
			failures += 1
			continue
		var length: float = stream.get_length()
		var looped: bool = false
		if stream is AudioStreamOggVorbis:
			looped = (stream as AudioStreamOggVorbis).loop
		var maximum_length: float = 1.5
		if event_id == &"ui_focus" or event_id == &"ui_accept":
			maximum_length = 0.3
		elif event_id == &"player_shot" or event_id == &"enemy_hit" or event_id == &"graze" or event_id == &"pickup_power":
			maximum_length = 0.4
		elif event_id == &"stage_cleared" or event_id == &"player_defeated" or event_id == &"boss_defeated":
			maximum_length = 3.0
		if length <= 0.0 or length > maximum_length or looped:
			failures += 1
			printerr(event_id, " invalid length or loop flag (limit ", maximum_length, " s)")
		print(event_id, " | ", path, " | length=", snappedf(length, 0.001), " | loop=", looped)
	print("AUDIO_SELECTION failures=", failures, " events=", EVENT_FILES.size())
	quit(1 if failures else 0)
