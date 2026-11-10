extends GutTest

func test_parse_players_keeps_slots():
	var p = BridgeCodec.parse_players('[{"slot":0,"name":"Alex","color":"#ff0000"},{"slot":5,"name":"Bo","color":"#00ff00"}]')
	assert_eq(p.size(), 2)
	assert_eq(p[1].slot, 5)
	assert_eq(p[1].name, "Bo")
	assert_eq(p[0].color, Color("#ff0000"))

func test_parse_players_bad_json_is_empty():
	assert_eq(BridgeCodec.parse_players("not json").size(), 0)

func test_parse_inputs_reads_known_slots():
	var i = BridgeCodec.parse_inputs('{"2":{"steer":0.5,"gas":true,"brake":false,"item":true}}', [2])
	assert_eq(i[2].steer, 0.5)
	assert_true(i[2].gas)
	assert_true(i[2].item)

func test_parse_inputs_ignores_unknown_slots():
	var i = BridgeCodec.parse_inputs('{"9":{"steer":1,"gas":true,"brake":false,"item":false}}', [0])
	assert_eq(i.keys(), [0])
	assert_eq(i[0], BridgeCodec.NEUTRAL)

func test_parse_inputs_clamps_and_defaults():
	var i = BridgeCodec.parse_inputs('{"0":{"steer":7}}', [0, 1])
	assert_eq(i[0].steer, 1.0)
	assert_false(i[0].gas)
	assert_eq(i[1], BridgeCodec.NEUTRAL)

func test_results_json_keeps_the_places_given():
	var places: Array[Dictionary] = [{ "slot": 5, "place": 2 }, { "slot": 0, "place": 6 }]
	assert_eq(JSON.parse_string(BridgeCodec.results_json(places)), [{"slot": 5.0, "place": 2.0}, {"slot": 0.0, "place": 6.0}])
