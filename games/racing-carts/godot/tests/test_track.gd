extends GutTest

var track: Track

func before_each():
	track = load("res://scenes/track.tscn").instantiate()
	add_child_autofree(track)

func test_length_is_about_twice_the_old_track():
	assert_between(track.length(), 850.0, 950.0)

func test_grid_slots_are_distinct():
	for i in 6:
		for j in range(i + 1, 6):
			assert_gt(track.grid_transform(i).origin.distance_to(track.grid_transform(j).origin), 1.0)

func test_grid_slots_sit_on_the_road_behind_the_line():
	for i in 6:
		var pos := track.grid_transform(i).origin
		var offset := track.offset_of(pos)
		assert_between(offset, track.length() - 20.0, track.length(), "slot %d behind the line" % i)
		assert_lt(pos.distance_to(track.point_at(offset, 0.0)), 6.0, "slot %d on the road" % i)

func test_grid_slots_face_the_direction_of_travel():
	for i in 6:
		var forward := -track.grid_transform(i).basis.z
		assert_almost_eq(forward.dot(track.direction_at(0.0)), 1.0, 0.001)

func test_offset_of_point_at_round_trips():
	for o in [0.5, 100.0, 333.0, 600.0, 850.0]:
		assert_almost_eq(track.offset_of(track.point_at(o, 0.0)), o, 0.5)

func test_point_at_lateral_is_to_the_right():
	var right := track.direction_at(0.0).cross(Vector3.UP)
	var delta := track.point_at(0.0, 3.0) - track.point_at(0.0, 0.0)
	assert_almost_eq(delta.dot(right), 3.0, 0.01)

func test_boost_pads_and_mud():
	assert_gte(get_tree().get_nodes_in_group("boost_pad").size(), 6)
	assert_eq(get_tree().get_nodes_in_group("mud").size(), 4)
	for pad in track.get_node("BoostPads").get_children():
		assert_true(pad is Area3D and pad.is_in_group("boost_pad"))
	for mud in track.get_node("Mud").get_children():
		assert_true(mud is Area3D and mud.is_in_group("mud"))

func test_pads_and_mud_lie_on_the_road_along_the_track():
	for area in track.get_node("BoostPads").get_children() + track.get_node("Mud").get_children():
		var offset := track.offset_of(area.global_position)
		assert_lt(area.global_position.distance_to(track.point_at(offset, 0.0)), 3.5, area.name)
		assert_almost_eq((-area.global_basis.z).dot(track.direction_at(offset)), 1.0, 0.01, area.name)

func test_walls_have_collision():
	await wait_physics_frames(2)
	assert_true(track.get_node("WallLeft").use_collision)
	assert_true(track.get_node("WallRight").use_collision)
	var space := track.get_world_3d().direct_space_state
	var from := track.point_at(200.0, 0.0) + Vector3.UP * 0.5
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + track.direction_at(200.0).cross(Vector3.UP) * 20.0))
	assert_false(hit.is_empty(), "a ray to the right hits the wall")
	if not hit.is_empty():
		assert_almost_eq(hit.position.distance_to(from), 6.0, 0.3)
