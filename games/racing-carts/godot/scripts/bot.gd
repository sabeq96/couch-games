class_name BotDriver extends RefCounted
## Drives one bot kart: follows a lane along the centre line, cruises below top speed, reacts a little late and lifts
## before sharp turns. Each bot draws its own cruise speed and reaction time. It presses ITEM for one tick when its
## held item's bot_should_use says so.

const LANE_MAX := 3.0 ## m either side of the centre line
const LANE_TIME_MIN := 3.0 ## s
const LANE_TIME_MAX := 6.0 ## s
const AIM_AHEAD := 9.0 ## m along the track
const CRUISE_MIN := 0.85 ## share of MAX_SPEED
const CRUISE_MAX := 0.95
const REACTION_MIN := 0.1 ## s
const REACTION_MAX := 0.3 ## s
const TURN_LOOKAHEAD := 25.0 ## m
const SHARP_TURN := 0.9 ## rad over the lookahead
const LIFT_UNTIL := 0.7 ## share of the cruise speed
const STEER_GAIN := 2.0 ## steer per metre of the unit aim direction to the right

var _rng: RandomNumberGenerator
var _cruise: float
var _reaction: float
var _lane := 0.0
var _lane_left := 0.0
var _lifting := false
var _steers: Array[float] = [] # the steer decided on each past tick, oldest first
var _item_pressed := false # ITEM pressed on the previous tick


func _init(rng: RandomNumberGenerator) -> void:
	_rng = rng
	_cruise = rng.randf_range(CRUISE_MIN, CRUISE_MAX) * KartTuning.MAX_SPEED
	_reaction = rng.randf_range(REACTION_MIN, REACTION_MAX)


## world: without one (a bot alone on a track) it never presses ITEM.
func input_for(kart: Kart, track: Track, dt: float, world: ItemWorld = null) -> Dictionary:
	_lane_left -= dt
	if _lane_left <= 0.0:
		_lane = _rng.randf_range(-LANE_MAX, LANE_MAX)
		_lane_left = _rng.randf_range(LANE_TIME_MIN, LANE_TIME_MAX)

	var offset := track.offset_of(kart.position)
	var fwd := KartPhysics.forward(kart.heading)
	var to_target := track.point_at(offset + AIM_AHEAD, _lane) - kart.position
	to_target.y = 0.0
	_steers.append(clampf(STEER_GAIN * to_target.normalized().dot(fwd.cross(Vector3.UP)), -1.0, 1.0))
	# The steer acted on now is the one decided `_reaction` seconds ago.
	var delay := roundi(_reaction / dt)
	while _steers.size() > delay + 1:
		_steers.pop_front()

	# Catch-up raises a bot's top speed, so its cruise speed scales with it.
	var cruise := _cruise * kart.top_speed_scale
	var speed := kart.velocity.dot(fwd)
	if track.turn_ahead(offset, TURN_LOOKAHEAD) > SHARP_TURN:
		_lifting = true
	if _lifting and speed < LIFT_UNTIL * cruise:
		_lifting = false
	var item := not _item_pressed and world != null and kart.held_item != "" and kart.roll_left <= 0.0 \
		and not kart.is_spinning() and ItemRegistry.by_id(kart.held_item).bot_should_use(kart, world, kart.held_for)
	_item_pressed = item
	return { "steer": _steers[0], "gas": not _lifting and speed < cruise, "brake": false, "item": item }

