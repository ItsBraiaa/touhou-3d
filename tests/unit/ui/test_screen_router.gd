extends TestCase
## Behavior of the [ScreenRouter] Rules Core: which screen is shown, which overlays sit
## above gameplay, where Back returns to, and which control had focus on each screen.
##
## Expected values come from GUIDE Section 14 "Scene and action registry": Options
## "preserving return destination" and "retain pause if caller is PauseMenu", Credits
## opened from Results "preserving results as return destination", and every "Return to
## caller" row.

var _router: ScreenRouter
## Both signals in emission order: `[&"hidden", id]` or `[&"shown", id, params]`.
var _events: Array[Array] = []


func before_each() -> void:
	_router = ScreenRouter.new()
	_events.clear()


func test_back_from_options_opened_on_the_main_menu_returns_to_the_main_menu() -> void:
	_router.home(ScreenRouter.MAIN_MENU)
	_router.replace(ScreenRouter.OPTIONS)
	assert_eq(_router.current(), ScreenRouter.OPTIONS)
	assert_true(_router.back())
	assert_eq(_router.current(), ScreenRouter.MAIN_MENU)
	assert_eq(_router.visible_stack(), [ScreenRouter.MAIN_MENU])
	assert_false(_router.back(), "the history is empty again")


## Options -> Controls -> Back -> Back: Controls returns to Options, Options to its caller.
func test_back_unwinds_nested_screens_one_caller_at_a_time() -> void:
	_router.home(ScreenRouter.MAIN_MENU)
	_router.replace(ScreenRouter.OPTIONS)
	_router.replace(ScreenRouter.CONTROLS)
	assert_true(_router.back())
	assert_eq(_router.current(), ScreenRouter.OPTIONS)
	assert_eq(_router.visible_stack(), [ScreenRouter.OPTIONS], "Options hides the main menu")
	assert_true(_router.back())
	assert_eq(_router.visible_stack(), [ScreenRouter.MAIN_MENU])
	assert_false(_router.back())


## "Open Options without unpausing combat" and "retain pause if caller is PauseMenu":
## Options covers the Pause overlay, which stays on the stack underneath it.
func test_options_opened_from_pause_returns_to_pause_with_the_hud_underneath() -> void:
	_router.home(ScreenRouter.HUD)
	_router.push(ScreenRouter.PAUSE)
	assert_eq(_router.visible_stack(), [ScreenRouter.HUD, ScreenRouter.PAUSE], "an overlay leaves the HUD visible")
	assert_true(_router.has_overlay(ScreenRouter.PAUSE))

	_router.replace(ScreenRouter.OPTIONS)
	assert_eq(_router.visible_stack(), [ScreenRouter.OPTIONS], "a full screen covers the HUD and the overlay")
	assert_true(_router.has_overlay(ScreenRouter.PAUSE), "still paused under Options")

	assert_true(_router.back())
	assert_eq(_router.visible_stack(), [ScreenRouter.HUD, ScreenRouter.PAUSE])
	assert_true(_router.has_overlay(ScreenRouter.PAUSE), "Back from Options does not resume")

	assert_true(_router.back())
	assert_eq(_router.visible_stack(), [ScreenRouter.HUD])
	assert_false(_router.has_overlay(ScreenRouter.PAUSE))
	assert_false(_router.back(), "nothing under the HUD")


## "Open Credits while preserving results as return destination". Results comes back
## with the params it was opened with, so the adapter can hide Replay or Continue again.
func test_credits_opened_from_results_returns_to_results_with_its_params() -> void:
	var params := {"mode": &"campaign_stage_1"}
	_router.home(ScreenRouter.HUD)
	_router.push(ScreenRouter.RESULTS, params)
	_router.replace(ScreenRouter.CREDITS)
	_record_transitions()
	assert_true(_router.back())
	assert_eq(_router.visible_stack(), [ScreenRouter.HUD, ScreenRouter.RESULTS])
	assert_eq(_events.back(), [&"shown", ScreenRouter.RESULTS, params])


## Defeat and Results are outcomes, not screens the player opened: GUIDE Section 14 gives
## them no Back row, and the gameplay under them has ended. Back from Pause resumes.
func test_back_never_dismisses_defeat_or_results() -> void:
	for outcome: StringName in [ScreenRouter.DEFEAT, ScreenRouter.RESULTS]:
		_router.home(ScreenRouter.HUD)
		_router.push(outcome)
		_record_transitions()
		assert_false(_router.back(), "on %s" % outcome)
		assert_eq(_router.visible_stack(), [ScreenRouter.HUD, outcome])
		assert_eq(_events, [], "on %s" % outcome)
		_router = ScreenRouter.new()


## "Any overlay or any non-HUD full screen while a run is active". Without the HUD on the
## stack there is no run, so the main menu and its screens cover nothing.
func test_gameplay_is_covered_by_any_overlay_or_full_screen_above_the_hud() -> void:
	assert_false(_router.is_gameplay_covered(), "nothing shown yet")
	_router.home(ScreenRouter.MAIN_MENU)
	_router.replace(ScreenRouter.OPTIONS)
	assert_false(_router.is_gameplay_covered(), "Options from the main menu, no run")
	_router.home(ScreenRouter.HUD)
	assert_false(_router.is_gameplay_covered(), "flying")
	_router.push(ScreenRouter.PAUSE)
	assert_true(_router.is_gameplay_covered(), "Pause")
	_router.replace(ScreenRouter.OPTIONS)
	assert_true(_router.is_gameplay_covered(), "Options from Pause")
	_router.back()
	_router.back()
	assert_false(_router.is_gameplay_covered(), "resumed")
	_router.push(ScreenRouter.DEFEAT)
	assert_true(_router.is_gameplay_covered(), "Defeat")
	_router.home(ScreenRouter.HUD)
	_router.push(ScreenRouter.RESULTS)
	_router.replace(ScreenRouter.CREDITS)
	assert_true(_router.is_gameplay_covered(), "Credits from Results")


func test_nothing_is_current_or_visible_before_the_first_home() -> void:
	assert_eq(_router.current(), &"")
	assert_eq(_router.visible_stack(), [])
	assert_false(_router.back())


func test_home_clears_history_and_overlays() -> void:
	_router.home(ScreenRouter.HUD)
	_router.push(ScreenRouter.PAUSE)
	_router.replace(ScreenRouter.OPTIONS)
	_router.home(ScreenRouter.MAIN_MENU)
	assert_eq(_router.current(), ScreenRouter.MAIN_MENU)
	assert_eq(_router.visible_stack(), [ScreenRouter.MAIN_MENU])
	assert_false(_router.has_overlay(ScreenRouter.PAUSE))
	assert_false(_router.back(), "no history left")


func test_back_on_a_fresh_home_returns_false_and_emits_nothing() -> void:
	for id: StringName in [ScreenRouter.MAIN_MENU, ScreenRouter.HUD]:
		_router.home(id)
		_record_transitions()
		assert_false(_router.back(), "on %s" % id)
		assert_eq(_router.current(), id)
		assert_eq(_events, [], "on %s" % id)
		_router = ScreenRouter.new()


## Each screen that stops being visible is hidden once, top first, then each screen that
## becomes visible is shown once, bottom first, with its params. A screen that stays
## visible, like the HUD under a new overlay, gets nothing.
func test_transitions_emit_hide_before_show_once_per_screen_with_params() -> void:
	var pause_params := {"score": 1200, "graze": 35}
	var options_params := {"from": &"pause"}
	_record_transitions()

	_router.home(ScreenRouter.HUD)
	assert_eq(_take_events(), [[&"shown", ScreenRouter.HUD, {}]], "home on an empty router")
	_router.push(ScreenRouter.PAUSE, pause_params)
	assert_eq(_take_events(), [[&"shown", ScreenRouter.PAUSE, pause_params]], "the HUD stays visible under Pause")
	_router.replace(ScreenRouter.OPTIONS, options_params)
	assert_eq(_take_events(), [
		[&"hidden", ScreenRouter.PAUSE],
		[&"hidden", ScreenRouter.HUD],
		[&"shown", ScreenRouter.OPTIONS, options_params],
	], "a full screen over Pause")
	_router.back()
	assert_eq(_take_events(), [
		[&"hidden", ScreenRouter.OPTIONS],
		[&"shown", ScreenRouter.HUD, {}],
		[&"shown", ScreenRouter.PAUSE, pause_params],
	], "back to Pause")
	_router.home(ScreenRouter.MAIN_MENU)
	assert_eq(_take_events(), [
		[&"hidden", ScreenRouter.PAUSE],
		[&"hidden", ScreenRouter.HUD],
		[&"shown", ScreenRouter.MAIN_MENU, {}],
	], "End run and return to main menu")


func test_focus_memory_round_trips_per_screen() -> void:
	_router.home(ScreenRouter.MAIN_MENU)
	_router.remember_focus(ScreenRouter.MAIN_MENU, ^"Layout/OptionsButton")
	_router.replace(ScreenRouter.OPTIONS)
	_router.remember_focus(ScreenRouter.OPTIONS, ^"Layout/Controls/BindingsButton")
	assert_eq(_router.focus_for(ScreenRouter.MAIN_MENU), ^"Layout/OptionsButton")
	assert_eq(_router.focus_for(ScreenRouter.OPTIONS), ^"Layout/Controls/BindingsButton")
	assert_true(_router.focus_for(ScreenRouter.CREDITS).is_empty(), "never remembered")
	_router.remember_focus(ScreenRouter.OPTIONS, ^"Layout/BackButton")
	assert_eq(_router.focus_for(ScreenRouter.OPTIONS), ^"Layout/BackButton", "the latest one wins")
	assert_eq(_router.focus_for(ScreenRouter.MAIN_MENU), ^"Layout/OptionsButton", "the other screen keeps its own")


## GUIDE Section 14: "assign initial focus on screen entry, preserve focus on return".
## A screen keeps its focus while it waits on the stack for Back; once it leaves the
## stack, showing it again is a fresh entry. Otherwise a Pause reopened after Resume
## would start on "End run" whenever that was the last button visited.
func test_focus_is_forgotten_when_its_screen_leaves_the_stack() -> void:
	_router.home(ScreenRouter.HUD)
	_router.push(ScreenRouter.PAUSE)
	_router.remember_focus(ScreenRouter.PAUSE, ^"Layout/MenuButton")
	_router.back()
	_router.push(ScreenRouter.PAUSE)
	assert_true(_router.focus_for(ScreenRouter.PAUSE).is_empty(), "Resume, then pause again")

	_router.home(ScreenRouter.MAIN_MENU)
	_router.remember_focus(ScreenRouter.MAIN_MENU, ^"Layout/QuitButton")
	_router.home(ScreenRouter.HUD)
	_router.home(ScreenRouter.MAIN_MENU)
	assert_true(_router.focus_for(ScreenRouter.MAIN_MENU).is_empty(), "a run in between")

	_router.remember_focus(ScreenRouter.OPTIONS, ^"Layout/BackButton")
	assert_true(_router.focus_for(ScreenRouter.OPTIONS).is_empty(), "a screen not on the stack remembers nothing")


## How the adapter uses it: remember a screen's focus when it is hidden, restore it when
## it is shown. A covered screen is still on the stack when its `screen_hidden` fires,
## so the memory sticks; a screen that Back removes is already off it, so it does not.
func test_focus_remembered_on_hide_comes_back_on_return() -> void:
	_router.screen_hidden.connect(_remember_focus_on_hide)
	_router.home(ScreenRouter.HUD)
	_router.push(ScreenRouter.PAUSE)
	_router.replace(ScreenRouter.OPTIONS)
	_router.replace(ScreenRouter.CONTROLS)
	_router.back()
	assert_eq(_router.focus_for(ScreenRouter.OPTIONS), _focused_on(ScreenRouter.OPTIONS))
	assert_true(_router.focus_for(ScreenRouter.CONTROLS).is_empty(), "Controls left the stack")
	_router.back()
	assert_eq(_router.focus_for(ScreenRouter.PAUSE), _focused_on(ScreenRouter.PAUSE))
	assert_true(_router.focus_for(ScreenRouter.OPTIONS).is_empty(), "Options left the stack")


func _record_transitions() -> void:
	# Method callables, not lambdas: a lambda would hold this test alive from the router.
	_router.screen_hidden.connect(_on_screen_hidden)
	_router.screen_shown.connect(_on_screen_shown)


## The events recorded since the last call, which are then forgotten.
func _take_events() -> Array[Array]:
	var taken := _events.duplicate()
	_events.clear()
	return taken


func _on_screen_hidden(id: StringName) -> void:
	_events.append([&"hidden", id])


func _on_screen_shown(id: StringName, params: Dictionary) -> void:
	_events.append([&"shown", id, params])


func _remember_focus_on_hide(id: StringName) -> void:
	_router.remember_focus(id, _focused_on(id))


## A distinct control path per screen, so one screen's memory cannot pass for another's.
static func _focused_on(id: StringName) -> NodePath:
	return NodePath("Layout/FocusedOn_%s" % id)
