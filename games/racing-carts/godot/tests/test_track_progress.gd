extends GutTest

const L := 1000.0

# A kart that starts on the grid (just behind the line) and crosses it once.
func _past_the_line() -> TrackProgress:
	var p := TrackProgress.new(L)
	p.update(0.98 * L)
	p.update(0.02 * L)
	return p

func test_forward_crossing_counts_lap():
	var p := _past_the_line()
	p.update(0.5 * L)
	p.update(0.9 * L)
	p.update(0.1 * L)
	assert_eq(p.laps_done, 1)

func test_first_crossing_from_grid_is_not_a_lap():
	var p := TrackProgress.new(L)
	p.update(0.98 * L)
	assert_lt(p.distance(), 0.0)
	p.update(0.02 * L)
	assert_eq(p.laps_done, 0)
	assert_almost_eq(p.distance(), 0.02 * L, 0.001)

func test_reverse_crossing_does_not_count():
	var p := _past_the_line()
	p.update(0.95 * L)
	assert_eq(p.laps_done, 0)
	assert_lt(p.distance(), 0.0)

func test_reverse_then_forward_is_net_zero():
	var p := _past_the_line()
	p.update(0.5 * L)
	p.update(0.9 * L)
	p.update(0.1 * L)
	p.update(0.9 * L)
	p.update(0.1 * L)
	assert_eq(p.laps_done, 1)

func test_lap_needs_most_of_the_track():
	var p := _past_the_line()
	p.update(0.5 * L)
	p.update(0.1 * L)
	assert_eq(p.laps_done, 0)
	assert_almost_eq(p.distance(), 0.1 * L, 0.001)

func test_laps_never_go_below_zero():
	var p := _past_the_line()
	p.update(0.9 * L)
	p.update(0.1 * L)
	p.update(0.9 * L)
	p.update(0.1 * L)
	p.update(0.9 * L)
	assert_eq(p.laps_done, 0)

func test_distance_grows_with_laps():
	var p := _past_the_line()
	var before := p.distance()
	for lap in 2:
		p.update(0.5 * L)
		p.update(0.9 * L)
		p.update(0.1 * L)
		assert_gt(p.distance(), before)
		before = p.distance()
	assert_eq(p.laps_done, 2)
	assert_almost_eq(p.distance(), 2 * L + 0.1 * L, 0.001)
