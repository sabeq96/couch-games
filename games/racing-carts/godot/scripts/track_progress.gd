class_name TrackProgress extends RefCounted
## Counts a kart's laps from its curve offset and gives the race distance used for ranking.
## A lap counts when the offset jumps from the last quarter of the track to the first one.
## Karts start just behind the line, so until they first cross it their offset counts as negative.

var laps_done: int = 0

var _length: float
var _offset := 0.0
var _behind_line := false
var _started := false

func _init(length: float) -> void:
	_length = length

func update(offset: float) -> void:
	if not _started:
		_started = true
		_behind_line = offset > 0.5 * _length
	elif _offset > 0.75 * _length and offset < 0.25 * _length:
		if _behind_line:
			_behind_line = false
		else:
			laps_done += 1
	elif _offset < 0.25 * _length and offset > 0.75 * _length:
		if laps_done > 0:
			laps_done -= 1
		else:
			_behind_line = true
	_offset = offset

func distance() -> float:
	return laps_done * _length + _offset - (_length if _behind_line else 0.0)
