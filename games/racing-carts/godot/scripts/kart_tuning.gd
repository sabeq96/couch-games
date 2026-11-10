class_name KartTuning extends RefCounted
## Every kart handling and bounce value, in one place. Metres, seconds, radians.

const MAX_SPEED := 20.0 ## m/s
const ACCEL := 12.0 ## m/s²
const BRAKE_DECEL := 24.0 ## m/s², also the rate of reversing
const REVERSE_MAX := 6.0 ## m/s
const COAST_DECEL := 4.0 ## m/s², with neither pedal, and above top speed
const STEER_RATE := 2.4 ## rad/s at full steer and at least 5 m/s
const GRIP := 3.0 ## 1/s, how fast sideways speed decays
const SLIP := 0.35 ## share of a heading change the velocity does not follow; it becomes sideways speed
const BOOST_FACTOR := 1.6 ## top speed multiplier while boosted
const PAD_BOOST_TIME := 1.0 ## s
const MUD_TOP_FACTOR := 0.5 ## top speed multiplier on mud
const MUD_DECEL := 16.0 ## m/s², instead of COAST_DECEL while on mud and above the mud top speed
const SPIN_TIME := 1.2 ## s
const CATCHUP := 0.06
const CATCHUP_WALL_PAUSE := 2.0 ## s
const WALL_SPEED_KEEP := 0.8 ## share of the speed along the wall kept on contact
const WALL_BOUNCE := 4.0 ## m/s off a wall
const WALL_BOUNCE_BOOSTED := 7.0 ## m/s off a wall while boosted
const KART_BOUNCE := 3.0 ## m/s apart
const KART_BOUNCE_BOOSTED_OTHER := 8.0 ## m/s for the kart hit by a boosted one
const KART_BOUNCE_BOOSTED_SELF := 2.0 ## m/s for the boosted kart that hits
