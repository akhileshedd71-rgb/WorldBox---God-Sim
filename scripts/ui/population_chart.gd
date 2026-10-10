class_name PopulationChart
extends Control
## Bounded, yearly samples; population and capacity share a labelled axis.
var history: Array = []
func _ready() -> void:
	custom_minimum_size = Vector2(0, 95)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	var font := ThemeDB.fallback_font
	var area := Rect2(30, 13, maxf(1, size.x - 45), maxf(30, size.y - 41))
	draw_rect(area, Color("102a31"))
	if history.is_empty():
		draw_string(font, Vector2(12, 48), "Population history begins at the next year.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GameHUD.MUTED)
		return
	var peak := 12.0
	for sample in history: peak = maxf(peak, maxf(sample.population, sample.housing))
	for value in [0.0, peak]:
		var y: float = area.end.y - value / peak * area.size.y
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("345259"))
		draw_string(font, Vector2(2, y + 4), str(int(value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameHUD.MUTED)
	for key in ["housing", "population"]:
		var points := PackedVector2Array()
		for n in history.size():
			var sample: Dictionary = history[n]
			points.append(Vector2(area.position.x + float(n) / maxi(1, history.size() - 1) * area.size.x, area.end.y - float(sample[key]) / peak * area.size.y))
		var color := Color("67858a") if key == "housing" else GameHUD.ACCENT
		if points.size() > 1: draw_polyline(points, color, 2, true)
		else: draw_circle(points[0], 3, color)
	draw_string(font, Vector2(30, size.y - 7), "Year %s" % history[0].year, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameHUD.MUTED)
	draw_string(font, Vector2(size.x - 64, size.y - 7), "Year %s" % history[-1].year, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameHUD.MUTED)
