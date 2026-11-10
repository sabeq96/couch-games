extends GutTest
# The item registry, the roll, and a kart holding and using an item.

# Odds by rank fraction: [weight at r = 0, weight at r = 1].
const ODDS := {
	"boost": [1.0, 4.0],
	"shield": [3.0, 1.0],
	"banana": [3.0, 1.0],
	"rocket": [0.5, 3.5],
}

var world: ItemWorld

func before_each():
	world = ItemWorld.new()
	add_child_autofree(world)

func _kart() -> Kart:
	var kart: Kart = load("res://scenes/kart.tscn").instantiate()
	add_child_autofree(kart)
	return kart

func test_weights_match_odds_table():
	assert_gt(ItemRegistry.all().size(), 0)
	for item in ItemRegistry.all():
		assert_has(ODDS, item.id)
		assert_ne(item.icon, "", item.id + " has an icon")
		assert_almost_eq(item.weight(0.0), ODDS[item.id][0], 0.0001, item.id + " at r = 0")
		assert_almost_eq(item.weight(1.0), ODDS[item.id][1], 0.0001, item.id + " at r = 1")
		assert_eq(ItemRegistry.by_id(item.id), item)

func test_roll_is_weighted():
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {}
	var total := 0.0
	for item in ItemRegistry.all():
		counts[item.id] = 0
		total += maxf(0.0, item.weight(1.0))
	for i in 10000:
		counts[ItemRegistry.roll(1.0, rng).id] += 1
	for item in ItemRegistry.all():
		assert_almost_eq(counts[item.id] / 10000.0, maxf(0.0, item.weight(1.0)) / total, 0.02, item.id + " share at r = 1")
	if counts.has("rocket"):
		assert_gt(counts.rocket / 10000.0, 0.3, "rocket above 30 % at r = 1")
	assert_gt(counts.boost / 10000.0, 0.3, "boost above 30 % at r = 1")

func test_pick_counts_negative_weights_as_zero():
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var counts := [0, 0, 0, 0]
	for i in 10000:
		counts[ItemRegistry.pick([2.0, -5.0, 1.0, 0.0], rng)] += 1
	assert_eq(counts[1], 0, "negative weight never drawn")
	assert_eq(counts[3], 0, "zero weight never drawn")
	assert_almost_eq(counts[0] / 10000.0, 2.0 / 3.0, 0.02)

func test_rank_fraction_and_neighbours():
	var a := _kart()
	var b := _kart()
	var c := _kart()
	world.karts = [a, b, c]
	world.order = [2, 0, 1] # c leads, then a, then b
	world.distances = [50.0, 20.0, 80.0]
	assert_eq(world.rank_fraction(c), 0.0)
	assert_eq(world.rank_fraction(a), 0.5)
	assert_eq(world.rank_fraction(b), 1.0)
	assert_eq(world.kart_ahead(a), c)
	assert_null(world.kart_ahead(c))
	assert_eq(world.kart_behind(a), b)
	assert_null(world.kart_behind(b))
	assert_eq(world.gap_to(a, c), 30.0)

func test_rank_fraction_alone_is_zero():
	var a := _kart()
	world.karts = [a]
	world.order = [0]
	world.distances = [0.0]
	assert_eq(world.rank_fraction(a), 0.0)

func test_roll_takes_one_second_then_holds():
	var kart := _kart()
	kart.give_item("boost")
	assert_eq(kart.held_item, "boost")
	assert_eq(kart.roll_left, KartTuning.ITEM_ROLL_TIME)
	kart.use_item_pressed(world)
	assert_eq(kart.held_item, "boost", "not usable while rolling")
	await wait_physics_frames(roundi(KartTuning.ITEM_ROLL_TIME * 60) - 3)
	assert_gt(kart.roll_left, 0.0, "still rolling")
	await wait_physics_frames(6)
	assert_eq(kart.roll_left, 0.0, "rolled")
	assert_eq(kart.held_item, "boost", "held")
	await wait_physics_frames(30)
	assert_almost_eq(kart.held_for, 0.5, 0.1, "held_for counts after the roll")
	kart.use_item_pressed(world)
	assert_eq(kart.held_item, "", "used")
	assert_true(kart.is_boosted(), "the boost item boosts")

func test_no_use_while_spinning():
	var kart := _kart()
	kart.give_item("boost")
	await wait_physics_frames(roundi(KartTuning.ITEM_ROLL_TIME * 60) + 2)
	kart.spin_out()
	kart.use_item_pressed(world)
	assert_eq(kart.held_item, "boost", "kept while spinning")
	assert_false(kart.is_boosted())
	await wait_physics_frames(roundi(KartTuning.SPIN_TIME * 60) + 2)
	kart.use_item_pressed(world)
	assert_eq(kart.held_item, "", "used after the spin")

func test_hit_without_shield_spins():
	var kart := _kart()
	kart.hit()
	assert_true(kart.is_spinning())

func test_hit_with_shield_pops_it():
	var kart := _kart()
	kart.shield(KartTuning.SHIELD_TIME)
	assert_true(kart.has_shield())
	kart.hit()
	assert_false(kart.has_shield(), "the shield popped")
	assert_false(kart.is_spinning(), "no spin")
