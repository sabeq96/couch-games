class_name RaceRules extends RefCounted
## Pure race rules: the grid, the race order, players' places, when the race is over, and catch-up.

const KART_COUNT := 6
const TOTAL_LAPS := 3
const COUNTDOWN := 3.0 ## s before GO
const FINISH_GRACE := 30.0 ## s


## Six entries in grid order: the human slots ascending, then -1 for bots.
static func grid(human_slots: Array[int]) -> Array[int]:
	var order := human_slots.duplicate()
	order.sort()
	while order.size() < KART_COUNT:
		order.append(-1)
	return order


## karts: `[{id, finished_at (-1 if not), distance}]`. Returns ids, finished first by time, then by distance.
static func ranking(karts: Array[Dictionary]) -> Array[int]:
	var sorted := karts.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_done: bool = a.finished_at >= 0.0
		var b_done: bool = b.finished_at >= 0.0
		if a_done != b_done:
			return a_done
		if a_done:
			return a.finished_at < b.finished_at
		return a.distance > b.distance)
	var ids: Array[int] = []
	for kart in sorted:
		ids.append(kart.id)
	return ids


## `[{slot, place}]` for the karts in id_to_slot (the humans), place counted among all karts in the ranking.
static func places(ranking_ids: Array[int], id_to_slot: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in ranking_ids.size():
		if id_to_slot.has(ranking_ids[i]):
			result.append({ "slot": id_to_slot[ranking_ids[i]], "place": i + 1 })
	return result


## finished_at: each kart's finish in race seconds, -1 while racing; is_human: per kart, true for a player's kart.
## Over when every human finished, or FINISH_GRACE after the first human finished; with no human finished, FINISH_GRACE
## after the last bot finished (never when there are no bots).
static func is_over(now: float, finished_at: Array[float], is_human: Array[bool]) -> bool:
	var first_human := -1.0
	var humans_all_finished := true
	var has_human := false
	var last_bot := -1.0
	var has_bot := false
	var bots_all_finished := true
	for i in finished_at.size():
		var at := finished_at[i]
		if is_human[i]:
			has_human = true
			humans_all_finished = humans_all_finished and at >= 0.0
			if at >= 0.0 and (first_human < 0.0 or at < first_human):
				first_human = at
		else:
			has_bot = true
			bots_all_finished = bots_all_finished and at >= 0.0
			last_bot = maxf(last_bot, at)
	if has_human and humans_all_finished:
		return true
	if first_human >= 0.0:
		return now >= first_human + FINISH_GRACE
	return has_bot and bots_all_finished and now >= last_bot + FINISH_GRACE


## Top speed multiplier: 1 for the leader (rank_index 0), up to 1 + CATCHUP for the last kart; 1 while paused.
static func catchup_scale(rank_index: int, kart_count: int, wall_paused: bool) -> float:
	if wall_paused:
		return 1.0
	return 1.0 + KartTuning.CATCHUP * rank_index / (kart_count - 1)
