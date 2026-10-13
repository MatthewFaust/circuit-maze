class_name BlockListView
extends VBoxContainer
## One list of blocks (main, a function body, or the inside of a loop/if).
## Drops are resolved by ProgramEditor from the mouse position; this view only
## answers geometry questions.

var ref := "main"
var depth := 0
## The visible well around the list; used as the drop target area.
var well: Control
var block_views: Array[Control] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func hit_rect() -> Rect2:
	return well.get_global_rect() if well != null else get_global_rect()


## Insertion index for a drop at this global y.
func index_at(global_y: float) -> int:
	for i in block_views.size():
		var r := block_views[i].get_global_rect()
		if global_y < r.position.y + r.size.y * 0.5:
			return i
	return block_views.size()


## Where to draw the insertion line for index, in global coordinates.
func line_rect(index: int) -> Rect2:
	var area := hit_rect()
	var sep := float(get_theme_constant("separation"))
	var y := area.get_center().y
	if not block_views.is_empty():
		if index < block_views.size():
			y = block_views[index].get_global_rect().position.y - sep / 2.0
		else:
			y = block_views.back().get_global_rect().end.y + sep / 2.0
	return Rect2(area.position.x + 4.0, y - 2.0, maxf(area.size.x - 8.0, 24.0), 4.0)
