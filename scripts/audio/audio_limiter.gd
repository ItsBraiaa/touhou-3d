class_name AudioLimiter
extends RefCounted
## Node-free rules core that grants and expires sound-effect voices.
##
## The AudioController owns playback and supplies a rule for each event. This core
## enforces event intervals, per-event and global voice caps, and priority-based steals.


## A request result meaning that no voice was granted.
const REFUSED: int = 0
const _EPSILON: float = 0.000001


## Emitted synchronously when a granted request replaces an active voice.
signal voice_stolen(voice_id: int)


class _Rule:
	extends RefCounted

	var _min_interval: float = 0.0
	var _max_voices: int = 1
	var _priority: int = 0


class _Voice:
	extends RefCounted

	var _event: StringName = &""
	var _priority: int = 0
	var _remaining: float = 0.0


var _max_voices: int
var _next_voice_id: int = 1
var _rules: Dictionary[StringName, _Rule] = {}
var _interval_remaining: Dictionary[StringName, float] = {}
var _voices: Dictionary[int, _Voice] = {}


## Creates the limiter with a global cap shared by every event.
func _init(max_voices: int) -> void:
	assert(max_voices >= 1, "AudioLimiter: max_voices must be at least 1")
	_max_voices = max_voices


## Adds or replaces the limits and priority for [param event].
func set_rule(event: StringName, min_interval: float, max_voices: int, priority: int) -> void:
	assert(min_interval >= 0.0, "AudioLimiter: min_interval must not be negative")
	assert(max_voices >= 1, "AudioLimiter: event max_voices must be at least 1")
	var rule := _Rule.new()
	rule._min_interval = min_interval
	rule._max_voices = max_voices
	rule._priority = priority
	_rules[event] = rule


## Requests an event voice for [param duration] seconds, or returns [constant REFUSED].
## A full global cap can be reclaimed only from the oldest voice at the lowest strictly
## lower priority; voices are never stolen from the requesting event itself.
func request(event: StringName, duration: float) -> int:
	assert(duration > 0.0, "AudioLimiter: duration must be positive")
	if not _rules.has(event):
		return REFUSED
	var rule: _Rule = _rules[event]
	if float(_interval_remaining.get(event, 0.0)) > _EPSILON:
		return REFUSED
	if active_count(event) >= rule._max_voices:
		return REFUSED
	if _voices.size() == _max_voices:
		var victim_id: int = _find_victim(rule._priority)
		if victim_id == REFUSED:
			return REFUSED
		_voices.erase(victim_id)
		voice_stolen.emit(victim_id)
	var voice_id: int = _next_voice_id
	_next_voice_id += 1
	var voice := _Voice.new()
	voice._event = event
	voice._priority = rule._priority
	voice._remaining = duration
	_voices[voice_id] = voice
	_interval_remaining[event] = rule._min_interval
	return voice_id


## Advances event intervals and voice lifetimes by [param delta] seconds.
func tick(delta: float) -> void:
	assert(delta >= 0.0, "AudioLimiter: delta must not be negative")
	for event: StringName in _interval_remaining.keys():
		var remaining_interval: float = float(_interval_remaining[event]) - delta
		_interval_remaining[event] = 0.0 if remaining_interval <= _EPSILON else remaining_interval
	for voice_id: int in _voices.keys():
		var voice: _Voice = _voices[voice_id]
		voice._remaining -= delta
		if voice._remaining <= _EPSILON:
			_voices.erase(voice_id)


## Clears all active voices and interval timers while retaining rules and never-reused ids.
func clear() -> void:
	_voices.clear()
	_interval_remaining.clear()


## Returns whether [param voice_id] currently owns an active voice.
func is_active(voice_id: int) -> bool:
	return _voices.has(voice_id)


## Counts active voices for [param event], or all voices when [param event] is empty.
func active_count(event: StringName = &"") -> int:
	if event == &"":
		return _voices.size()
	var count: int = 0
	for voice_id: int in _voices:
		var voice: _Voice = _voices[voice_id]
		if voice._event == event:
			count += 1
	return count


func _find_victim(request_priority: int) -> int:
	var victim_id: int = REFUSED
	var victim_priority: int = 0
	for voice_id: int in _voices:
		var voice: _Voice = _voices[voice_id]
		if voice._priority >= request_priority:
			continue
		if (
			victim_id == REFUSED
			or voice._priority < victim_priority
			or (voice._priority == victim_priority and voice_id < victim_id)
		):
			victim_id = voice_id
			victim_priority = voice._priority
	return victim_id
