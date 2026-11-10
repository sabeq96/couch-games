extends GutTest

func test_grid_humans_by_slot_then_bots():
	var humans: Array[int] = [4, 0, 2]
	assert_eq(RaceRules.grid(humans), [0, 2, 4, -1, -1, -1])
	var none: Array[int] = []
	assert_eq(RaceRules.grid(none), [-1, -1, -1, -1, -1, -1])
	var six: Array[int] = [5, 4, 3, 2, 1, 0]
	assert_eq(RaceRules.grid(six), [0, 1, 2, 3, 4, 5])

func test_ranking_finished_first_then_distance():
	var karts: Array[Dictionary] = [
		{ "id": 0, "finished_at": -1.0, "distance": 500.0 },
		{ "id": 1, "finished_at": 90.0, "distance": 2700.0 },
		{ "id": 2, "finished_at": -1.0, "distance": 800.0 },
		{ "id": 3, "finished_at": 85.0, "distance": 2690.0 },
	]
	assert_eq(RaceRules.ranking(karts), [3, 1, 2, 0])

func test_results_places_among_all_karts():
	# Karts 0 and 2 are players in slots 0 and 3; the rest are bots. A player behind a bot gets that place.
	var ranking: Array[int] = [5, 2, 4, 1, 0, 3]
	assert_eq(RaceRules.places(ranking, { 0: 0, 2: 3 }), [{ "slot": 3, "place": 2 }, { "slot": 0, "place": 5 }])

func test_finish_rule_all_humans():
	assert_true(RaceRules.is_over(50.0, 49.0, true, -1.0))

func test_finish_rule_grace_after_first_human():
	assert_false(RaceRules.is_over(60.0 + RaceRules.FINISH_GRACE - 0.1, 60.0, false, -1.0))
	assert_true(RaceRules.is_over(60.0 + RaceRules.FINISH_GRACE, 60.0, false, -1.0))
	# The grace runs from the first human, even if every bot finished earlier.
	assert_false(RaceRules.is_over(60.0 + RaceRules.FINISH_GRACE - 0.1, 60.0, false, 10.0))

func test_finish_rule_no_humans_finished():
	assert_false(RaceRules.is_over(100.0, -1.0, false, -1.0), "bots still racing")
	assert_false(RaceRules.is_over(80.0 + RaceRules.FINISH_GRACE - 0.1, -1.0, false, 80.0))
	assert_true(RaceRules.is_over(80.0 + RaceRules.FINISH_GRACE, -1.0, false, 80.0))

func test_catchup_scale():
	assert_eq(RaceRules.catchup_scale(0, 6, false), 1.0, "the leader")
	assert_almost_eq(RaceRules.catchup_scale(5, 6, false), 1.0 + KartTuning.CATCHUP, 0.0001, "the last kart")
	assert_almost_eq(RaceRules.catchup_scale(2, 6, false), 1.0 + KartTuning.CATCHUP * 2.0 / 5.0, 0.0001)
	assert_eq(RaceRules.catchup_scale(5, 6, true), 1.0, "paused after a wall")
