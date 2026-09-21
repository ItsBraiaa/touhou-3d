extends TestCase
## Checks `default_bus_layout.tres`, loaded through `audio/buses/default_bus_layout`:
## the three buses F3 Options binds to, with Music and SFX sending to Master.


func test_three_buses_exist_in_order() -> void:
	assert_eq(AudioServer.get_bus_count(), 3)
	assert_eq(AudioServer.get_bus_name(0), "Master")
	assert_eq(AudioServer.get_bus_name(1), "Music")
	assert_eq(AudioServer.get_bus_name(2), "SFX")


func test_music_and_sfx_send_to_master() -> void:
	assert_eq(AudioServer.get_bus_send(1), &"Master")
	assert_eq(AudioServer.get_bus_send(2), &"Master")
