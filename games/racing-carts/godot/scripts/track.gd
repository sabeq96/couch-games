class_name Track extends Node3D
## The race track: its centre line (a closed Curve3D in CentreLine), road, walls, boost pads and mud.
## Offsets run along the centre line in the direction of travel, 0 at the start line.

const GRID_FIRST_ROW := 4.0 ## metres behind the start line
const GRID_ROW_GAP := 6.0
const GRID_LATERAL := 3.0
const TURN_STEP := 5.0 ## m between the directions sampled by turn_ahead
const ROAD_HALF_WIDTH := 6.0 ## m from the centre line to the inner face of a wall (the Road polygon)

var _centre: Path3D:
	get: return $CentreLine

func length() -> float:
	return _centre.curve.get_baked_length()

func offset_of(world_pos: Vector3) -> float:
	return _centre.curve.get_closest_offset(_centre.to_local(world_pos))

## lateral: metres to the right of the direction of travel.
func point_at(offset: float, lateral: float) -> Vector3:
	var centre := _centre.to_global(_centre.curve.sample_baked(fposmod(offset, length()), true))
	return centre + direction_at(offset).cross(Vector3.UP) * lateral

## Metres to the right of the centre line at the closest offset (negative on the left), ignoring height.
func lateral_of(world_pos: Vector3) -> float:
	var offset := offset_of(world_pos)
	var from_centre := world_pos - point_at(offset, 0.0)
	return from_centre.dot(direction_at(offset).cross(Vector3.UP))

## Unit and flat (y = 0).
func direction_at(offset: float) -> Vector3:
	var curve := _centre.curve
	var behind := _centre.to_global(curve.sample_baked(fposmod(offset - 0.5, length()), true))
	var ahead := _centre.to_global(curve.sample_baked(fposmod(offset + 0.5, length()), true))
	var d := ahead - behind
	d.y = 0.0
	return d.normalized()

## How much the track turns over the next `distance` metres, both ways counted (an S-bend does not cancel out).
func turn_ahead(offset: float, distance: float) -> float:
	var total := 0.0
	var previous := direction_at(offset)
	var step := TURN_STEP
	while step <= distance:
		var direction := direction_at(offset + step)
		total += previous.angle_to(direction)
		previous = direction
		step += TURN_STEP
	return total

## index 0..5: even indices on the left column, odd on the right, row by row behind the line.
func grid_transform(index: int) -> Transform3D:
	var offset := -(GRID_FIRST_ROW + (index / 2) * GRID_ROW_GAP)
	var lateral := GRID_LATERAL if index % 2 == 1 else -GRID_LATERAL
	return Transform3D(Basis.looking_at(direction_at(offset)), point_at(offset, lateral))
