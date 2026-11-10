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

const G := RaceRules.FINISH_GRACE
const TWO_HUMANS := [true, true, false, false, false, false]

func _is_over(now: float, finished_at: Array, is_human: Array) -> bool:
	var at: Array[float] = []
	at.assign(finished_at)
	var human: Array[bool] = []
	human.assign(is_human)
	return RaceRules.is_over(now, at, human)

func test_finish_rule_all_humans_done():
	assert_true(_is_over(50.0, [49.0, 50.0, -1.0, -1.0, -1.0, -1.0], TWO_HUMANS), "bots still racing")
	assert_false(_is_over(50.0, [49.0, -1.0, -1.0, -1.0, -1.0, -1.0], TWO_HUMANS), "one human still racing")

func test_finish_rule_grace_after_a_human_done():
	var one_done := [60.0, -1.0, -1.0, -1.0, -1.0, -1.0]
	assert_false(_is_over(60.0 + G - 0.1, one_done, TWO_HUMANS))
	assert_true(_is_over(60.0 + G, one_done, TWO_HUMANS))
	# The grace runs from the first human, even if every bot finished earlier.
	assert_false(_is_over(60.0 + G - 0.1, [60.0, -1.0, 10.0, 10.0, 10.0, 10.0], TWO_HUMANS))

func test_finish_rule_all_bots_done_no_human_done():
	assert_false(_is_over(1000.0, [-1.0, -1.0, 70.0, 75.0, 78.0, -1.0], TWO_HUMANS), "a bot still racing")
	var bots_done := [-1.0, -1.0, 70.0, 75.0, 78.0, 80.0]
	assert_false(_is_over(80.0 + G - 0.1, bots_done, TWO_HUMANS))
	assert_true(_is_over(80.0 + G, bots_done, TWO_HUMANS), "30 s after the last bot")

func test_finish_rule_no_bots():
	var six := [true, true, true, true, true, true]
	assert_false(_is_over(1000.0, [-1.0, -1.0, -1.0, -1.0, -1.0, -1.0], six), "nobody done: no bot rule")
	assert_true(_is_over(10.0 + G, [10.0, -1.0, -1.0, -1.0, -1.0, -1.0], six), "grace after the first human")
	assert_true(_is_over(15.0, [10.0, 11.0, 12.0, 13.0, 14.0, 15.0], six), "all humans done")

func test_finish_rule_no_humans():
	var none := [false, false, false, false, false, false]
	var bots_done := [70.0, 71.0, 72.0, 73.0, 74.0, 80.0]
	assert_false(_is_over(80.0 + G - 0.1, bots_done, none))
	assert_true(_is_over(80.0 + G, bots_done, none))

func test_catchup_scale():
	assert_eq(RaceRules.catchup_scale(0, 6, false), 1.0, "the leader")
	assert_almost_eq(RaceRules.catchup_scale(5, 6, false), 1.0 + KartTuning.CATCHUP, 0.0001, "the last kart")
	assert_almost_eq(RaceRules.catchup_scale(2, 6, false), 1.0 + KartTuning.CATCHUP * 2.0 / 5.0, 0.0001)
	assert_eq(RaceRules.catchup_scale(5, 6, true), 1.0, "paused after a wall")
