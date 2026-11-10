class_name ViewHud extends Control
## One view's HUD: place (top left), lap (top right), the held item as an uppercase word in a pastel pill (bottom
## centre, "?" while it rolls) and "FINISHED 2nd" in the middle once that player is done. Plain text only: the
## default font has no emoji. Font size is max(MIN_FONT, height / 12).

const MIN_FONT := 24 ## px
const FONT_DIVISOR := 12.0 ## font size = view height / this
const TEXT := Color.WHITE
const OUTLINE := Color(0.2, 0.17, 0.27)
const ROLLING_COLOR := Color("#D9D2F0") ## pill fill while the item rolls
const ORDINALS: Array[String] = ["1st", "2nd", "3rd", "4th", "5th", "6th"]

var _place := _label("Place", HORIZONTAL_ALIGNMENT_LEFT)
var _lap := _label("Lap", HORIZONTAL_ALIGNMENT_RIGHT)
var _finished := _label("Finished", HORIZONTAL_ALIGNMENT_CENTER)
var _item := _label("Item", HORIZONTAL_ALIGNMENT_CENTER)
var _pill := PanelContainer.new()
var _pill_style := StyleBoxFlat.new()


func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for label in [_place, _lap, _finished]:
		add_child(label)
	_place.set_anchors_preset(PRESET_TOP_LEFT)
	_lap.set_anchors_preset(PRESET_TOP_RIGHT)
	_lap.grow_horizontal = GROW_DIRECTION_BEGIN
	_finished.set_anchors_preset(PRESET_CENTER)
	_finished.grow_horizontal = GROW_DIRECTION_BOTH
	_finished.grow_vertical = GROW_DIRECTION_BOTH
	_finished.visible = false
	_pill_style.set_corner_radius_all(999)
	_pill.add_theme_stylebox_override("panel", _pill_style)
	_pill.add_child(_item)
	_pill.set_anchors_preset(PRESET_CENTER_BOTTOM)
	_pill.grow_horizontal = GROW_DIRECTION_BOTH
	_pill.grow_vertical = GROW_DIRECTION_BEGIN
	_pill.visible = false
	add_child(_pill)
	resized.connect(_scale_text)
	_scale_text()


## finished_place is 0 while racing.
func show_state(place: int, lap: int, total_laps: int, item_id: String, rolling: bool, finished_place: int) -> void:
	_place.text = ORDINALS[place - 1]
	_lap.text = "LAP %d/%d" % [lap, total_laps]
	_pill.visible = item_id != ""
	if item_id != "":
		_item.text = "?" if rolling else item_id.to_upper()
		_pill_style.bg_color = ROLLING_COLOR if rolling else ItemRegistry.by_id(item_id).hud_color
	_finished.visible = finished_place > 0
	_finished.text = "FINISHED %s" % ORDINALS[finished_place - 1] if finished_place > 0 else ""


func place_text() -> String:
	return _place.text


func lap_text() -> String:
	return _lap.text


func item_text() -> String:
	return _item.text


func item_visible() -> bool:
	return _pill.visible


func item_color() -> Color:
	return _pill_style.bg_color


func finished_text() -> String:
	return _finished.text


func _scale_text() -> void:
	var font := maxi(MIN_FONT, floori(size.y / FONT_DIVISOR))
	var margin := font / 2.0
	for label in [_place, _lap, _finished, _item]:
		label.add_theme_font_size_override("font_size", font)
		label.add_theme_constant_override("outline_size", maxi(4, font / 4))
	_place.position = Vector2(margin, margin * 0.5)
	_lap.offset_right = -margin
	_lap.offset_top = margin * 0.5
	_pill.offset_bottom = -margin
	_pill_style.content_margin_left = margin
	_pill_style.content_margin_right = margin


static func _label(label_name: String, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = label_name
	label.horizontal_alignment = align
	label.add_theme_color_override("font_color", TEXT)
	label.add_theme_color_override("font_outline_color", OUTLINE)
	return label
