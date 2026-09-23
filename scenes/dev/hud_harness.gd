extends Node
## Dev harness for F4-03: plays a scripted, input-free sequence over the combat HUD's boss
## panel, attack cue and threat indicators, in front of the static combat arena, and
## checks each step as it goes. Dev only: never loaded by `scenes/main.tscn`.
##
## Run it with `tools/godot.ps1 --path . res://scenes/dev/hud_harness.tscn` (add
## `--headless` for the checks alone). With a display it writes
## `docs/validation/combat-hud-boss-3.png` and `combat-hud-boss-2.png`. It prints one
## `HUD_HARNESS ok|FAIL <step>` line per check, then `HUD_HARNESS_OK` or
## `HUD_HARNESS_FAILED <n>`, and quits with the number of failures as the exit code.
## The clamped Phase count and the ignored bar and side each print one expected `ERROR`.


const SHOT_PREFIX := "res://docs/validation/combat-hud-boss-"
## Names and cues as STAGE_DESIGN and GUIDE Section 15 spell them.
const FINAL_BOSS_NAME := "Guardião das Lanternas"
const FINAL_BOSS_CUE := "Ritual das Lanternas"
const MINIBOSS_NAME := "Sentinela da Tempestade"
## Seconds the Phase 1 drain takes on screen.
const DRAIN_SECONDS := 1.0
## Slack around a timer's end: a check this long before it expects the node shown, and
## this long after it expects it hidden.
const TIMER_SLACK := 0.15

## The HUD instance under `HudLayer`.
@export var hud: Hud

var _failures: int = 0


func _ready() -> void:
	if hud == null:
		push_error("%s: required export 'hud' is not set" % get_path())
		process_mode = Node.PROCESS_MODE_DISABLED
		return
	_run.call_deferred()


func _run() -> void:
	await _seconds(0.2)
	await _three_phase_boss()
	await _cue_timers()
	await _threat_timers()
	await _timers_freeze_while_paused()
	await _two_phase_boss()
	_phase_count_is_clamped_and_hide_boss_resets()
	_unbind_clears_the_boss_panel()
	if _failures == 0:
		print("HUD_HARNESS_OK")
	else:
		print("HUD_HARNESS_FAILED %d" % _failures)
	get_tree().quit(_failures)


func _three_phase_boss() -> void:
	hud.show_boss(FINAL_BOSS_NAME, 3)
	_check("three-Phase boss: panel and name shown", _node(^"BossStatus").visible and _label(^"BossStatus/BossName").text == FINAL_BOSS_NAME)
	_check("three-Phase boss: three full, lit bars", _bars_shown() == [100.0, 100.0, 100.0] and _bar_lit(0) and _bar_lit(2))
	var elapsed := 0.0
	while elapsed < DRAIN_SECONDS:
		elapsed += await _frame()
		hud.set_phase_health(0, 1.0 - elapsed / DRAIN_SECONDS)
	hud.set_phase_health(0, 0.0)
	hud.set_phase_health(1, 0.6)
	_check("Phase 1 drained to 0 and dimmed", is_zero_approx(_bar(0).value) and _bar(0).modulate == hud.completed_phase_modulate)
	_check("Phase 2 at 60 and lit, Phase 3 untouched", is_equal_approx(_bar(1).value, 60.0) and _bar_lit(1) and is_equal_approx(_bar(2).value, 100.0))
	hud.set_phase_health(1, 1.7)
	_check("a ratio above 1 fills the bar", is_equal_approx(_bar(1).value, 100.0))
	hud.set_phase_health(1, 0.6)
	hud.show_attack_cue(FINAL_BOSS_CUE, 1.5)
	hud.show_threat(-1, 1.0)
	await _seconds(0.3)
	_check("cue and left threat shown", _node(^"AttackName").visible and _label(^"AttackName").text == FINAL_BOSS_CUE and _node(^"ThreatLeft").visible)
	await _capture("3")


func _cue_timers() -> void:
	hud.show_attack_cue("Primeiro", 1.0)
	await _seconds(1.0 - TIMER_SLACK)
	_check("cue still shown just before its seconds", _node(^"AttackName").visible)
	await _seconds(2.0 * TIMER_SLACK)
	_check("cue hidden after its seconds", not _node(^"AttackName").visible)
	hud.show_attack_cue("Primeiro", 1.0)
	await _seconds(0.6)
	hud.show_attack_cue("Segundo", 1.0)
	await _seconds(0.6)
	_check("a new cue replaced the text and restarted the timer", _node(^"AttackName").visible and _label(^"AttackName").text == "Segundo")
	await _seconds(0.4 + TIMER_SLACK)
	_check("the new cue hid after its own seconds", not _node(^"AttackName").visible)


func _threat_timers() -> void:
	hud.show_threat(-1, 0.5)
	hud.show_threat(1, 1.0)
	await _seconds(0.5 + TIMER_SLACK)
	_check("left threat expired on its own timer", not _node(^"ThreatLeft").visible)
	_check("right threat still shown", _node(^"ThreatRight").visible)
	await _seconds(0.5)
	_check("right threat expired too", not _node(^"ThreatRight").visible)
	hud.show_threat(1, 1.0)
	await _seconds(0.5)
	hud.show_threat(1, 0.2)
	await _seconds(0.2 + TIMER_SLACK)
	_check("a shorter repeat did not shorten the timer", _node(^"ThreatRight").visible)
	hud.show_threat(1, 1.0)
	await _seconds(0.5 + TIMER_SLACK)
	_check("a longer repeat extended it", _node(^"ThreatRight").visible)
	await _seconds(0.5)
	_check("and it expired at the extended time", not _node(^"ThreatRight").visible)
	hud.show_threat(0, 1.0)
	_check("side 0 is ignored", not _node(^"ThreatLeft").visible and not _node(^"ThreatRight").visible)


func _timers_freeze_while_paused() -> void:
	hud.show_attack_cue(FINAL_BOSS_CUE, 0.5)
	hud.show_threat(-1, 0.5)
	get_tree().paused = true
	await _seconds(1.0)
	_check("cue and threat kept through 1 s of pause", _node(^"AttackName").visible and _node(^"ThreatLeft").visible)
	get_tree().paused = false
	await _seconds(0.5 + TIMER_SLACK)
	_check("and ran out once unpaused", not _node(^"AttackName").visible and not _node(^"ThreatLeft").visible)


func _two_phase_boss() -> void:
	hud.show_boss(MINIBOSS_NAME, 2)
	hud.set_phase_health(0, 0.45)
	_check("two-Phase boss: name, two bars, the third hidden", _label(^"BossStatus/BossName").text == MINIBOSS_NAME and _bars_shown() == [45.0, 100.0])
	_check("a new boss starts lit", _bar_lit(0) and _bar_lit(1))
	hud.set_phase_health(2, 0.5)
	_check("the hidden third bar is ignored", is_equal_approx(_bar(2).value, 100.0))
	await _seconds(0.3)
	await _capture("2")


func _phase_count_is_clamped_and_hide_boss_resets() -> void:
	hud.show_boss(FINAL_BOSS_NAME, 4)
	_check("four Phases clamped to three", _bars_shown().size() == 3)
	hud.set_phase_health(0, 0.0)
	hud.show_attack_cue(FINAL_BOSS_CUE, 5.0)
	hud.hide_boss()
	_check("hide_boss hides the panel and the cue", not _node(^"BossStatus").visible and not _node(^"AttackName").visible)
	_check("and resets the bars to full and lit", is_equal_approx(_bar(0).value, 100.0) and _bar_lit(0))


func _unbind_clears_the_boss_panel() -> void:
	hud.show_boss(FINAL_BOSS_NAME, 3)
	hud.show_attack_cue(FINAL_BOSS_CUE, 5.0)
	hud.show_threat(-1, 5.0)
	hud.show_threat(1, 5.0)
	hud.unbind()
	var shown: Array[bool] = []
	for path: NodePath in [^"BossStatus", ^"AttackName", ^"ThreatLeft", ^"ThreatRight"]:
		shown.append(_node(path).visible)
	_check("unbind leaves nothing on screen", not shown.has(true))


## Values of the Phase bars that are shown, in order.
func _bars_shown() -> Array[float]:
	var values: Array[float] = []
	for index: int in 3:
		if _bar(index).visible:
			values.append(snappedf(_bar(index).value, 0.01))
	return values


func _bar(index: int) -> ProgressBar:
	return hud.get_node(Hud.PHASE_BAR_PATHS[index]) as ProgressBar


func _bar_lit(index: int) -> bool:
	return _bar(index).modulate == hud.lit_modulate


func _node(path: NodePath) -> CanvasItem:
	return hud.get_node(path) as CanvasItem


func _label(path: NodePath) -> Label:
	return hud.get_node(path) as Label


## Waits one frame and returns its length in seconds.
func _frame() -> float:
	await get_tree().process_frame
	return get_process_delta_time()


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _capture(name_suffix: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var path := SHOT_PREFIX + name_suffix + ".png"
	var result := get_viewport().get_texture().get_image().save_png(path)
	_check("screenshot %s" % path, result == OK)


func _check(label: String, passed: bool) -> void:
	if not passed:
		_failures += 1
	print("HUD_HARNESS %s %s" % ["ok  " if passed else "FAIL", label])
