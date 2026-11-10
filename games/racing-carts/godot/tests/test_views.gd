extends GutTest
# Views in the race scene off the web: Bridge plays slots 0 and 1, so there are two views with a chase camera each.

var race: Race
var views: Views

func before_each():
	race = load("res://scenes/race.tscn").instantiate()
	add_child_autofree(race)
	views = race.get_node("Views")

func _kart_in_slot(slot: int) -> Kart:
	for child in race.get_children():
		if child is Kart and child.slot == slot:
			return child
	return null

func _containers() -> Array[SubViewportContainer]:
	var found: Array[SubViewportContainer] = []
	for node in views.find_children("*", "SubViewportContainer", true, false):
		found.append(node)
	return found

func test_views_follow_their_karts_by_slot():
	assert_eq(views.view_count(), 2)
	for slot in [0, 1]:
		var camera := views.camera_for(slot)
		assert_not_null(camera, "camera for slot %d" % slot)
		assert_eq(camera.target, _kart_in_slot(slot), "slot %d follows its own kart" % slot)
		assert_true(camera.current, "camera %d is current in its viewport" % slot)
		assert_eq(camera.get_viewport().find_world_3d(), race.get_viewport().find_world_3d(), "one shared world")
	assert_null(views.camera_for(3), "no view for an absent slot")
	assert_null(race.get_viewport().get_camera_3d(), "the main viewport renders no 3D camera")

func test_views_relayout_on_resize():
	views.set_anchors_preset(Control.PRESET_TOP_LEFT) # stand-in for a window resize: free the size from the anchors
	views.size = Vector2(1000, 600)
	await wait_physics_frames(1)
	var expected := ViewLayout.rects(2, Vector2(1000, 600))
	var containers := _containers()
	assert_eq(containers.size(), 2)
	for i in containers.size():
		assert_eq(containers[i].get_parent().position, expected[i].position, "view %d border position" % i)
		assert_eq(containers[i].get_parent().size, expected[i].size, "view %d border size" % i)
		assert_eq(containers[i].size, expected[i].size - Vector2(8, 8), "view %d inset by the 4 px border" % i)

func test_shake_only_own_view():
	await wait_physics_frames(60)
	var still := views.camera_for(1).global_position
	race.get_node("ItemWorld").hit(_kart_in_slot(0))
	await wait_physics_frames(3)
	var settled := views.camera_for(0)
	assert_gt(settled.shake_offset().length(), 0.05, "the hit kart's view shakes")
	assert_eq(views.camera_for(1).shake_offset(), Vector3.ZERO, "the other view does not")
	assert_almost_eq(views.camera_for(1).global_position, still, Vector3.ONE * 0.01, "the other camera stays put")
	await wait_physics_frames(roundi(ChaseCamera.SHAKE_TIME * 60) + 2)
	assert_eq(settled.shake_offset(), Vector3.ZERO, "the shake is over after %.1f s" % ChaseCamera.SHAKE_TIME)

func test_camera_sits_behind_kart():
	await wait_physics_frames(90)
	var kart := _kart_in_slot(0)
	var camera := views.camera_for(0)
	var forward := KartPhysics.forward(kart.heading)
	var offset := camera.global_position - kart.position
	assert_almost_eq(-offset.dot(forward), 7.0, 0.5, "7 m behind")
	assert_almost_eq(offset.y, 3.0, 0.5, "3 m above")
	assert_almost_eq(camera.fov, 70.0, 0.01)

func test_same_target_again_keeps_easing():
	var camera := views.camera_for(0)
	await wait_physics_frames(2)
	var kart := _kart_in_slot(0)
	kart.heading += 1.0 # a sudden turn: the camera should ease, not jump
	camera.target = kart
	await wait_physics_frames(1)
	var forward := KartPhysics.forward(kart.heading)
	assert_lt(-(camera.global_position - kart.position).dot(forward), 6.5, "still easing toward the new heading")
