class_name SocietyChart
extends Control
var history: Array = []
var metric := "population"
func _ready() -> void:
	custom_minimum_size = Vector2(0, 130)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var font := ThemeDB.fallback_font
	var area := Rect2(46, 18, maxf(1, size.x - 62), size.y - 48)
	draw_rect(area, Color("102a31"))
	if history.is_empty():
		draw_string(font, Vector2(12, 52), "A new sample is recorded each year.", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, GameHUD.MUTED)
		return
	var peak := 1.0
	for s in history: peak = maxf(peak, s[metric])
	for value in [0.0, peak]:
		var y: float = area.end.y - value / peak * area.size.y
		draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color("345259"))
		draw_string(font, Vector2(1, y + 4), str(int(value)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameHUD.MUTED)
	var points := PackedVector2Array()
	var first: int = history[0].year
	var span := maxi(1, int(history[-1].year) - first)
	for s in history: points.append(Vector2(area.position.x + float(s.year - first) / span * area.size.x, area.end.y - float(s[metric]) / peak * area.size.y))
	if points.size() > 1: draw_polyline(points, GameHUD.ACCENT, 2, true)
	else: draw_circle(points[0], 3, GameHUD.ACCENT)
	draw_string(font, Vector2(46, size.y - 8), "Year %s" % first, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameHUD.MUTED)
	draw_string(font, Vector2(size.x - 75, size.y - 8), "Year %s" % history[-1].year, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GameHUD.MUTED)
