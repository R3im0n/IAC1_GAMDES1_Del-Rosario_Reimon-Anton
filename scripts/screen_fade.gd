extends CanvasLayer
## A full-screen black rectangle that can fade in and out.
## Usage:  var fade = preload("res://scripts/screen_fade.gd").new()
##         get_tree().current_scene.add_child(fade)
##         await fade.fade_out(0.4)   # screen goes black
##         await fade.fade_in(0.4)    # screen comes back
##         fade.queue_free()

var rect : ColorRect


func _init() -> void:
	layer = 100                                   # on top of everything
	process_mode = Node.PROCESS_MODE_ALWAYS       # keeps fading while the game is paused

	rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.modulate.a = 0.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(rect)


func fade_out(time: float = 0.4) -> void:
	await _fade_to(1.0, time)


func fade_in(time: float = 0.4) -> void:
	await _fade_to(0.0, time)


func _fade_to(alpha: float, time: float) -> void:
	var tween := create_tween()
	tween.tween_property(rect, "modulate:a", alpha, time)
	await tween.finished
