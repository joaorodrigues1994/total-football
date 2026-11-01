class_name PassFlight
extends RefCounted
## Voo da bola em linha reta (no plano) com arco de altura, de from até to em duration segundos.

var from: Vector2
var to: Vector2
var duration: float
var arc_height: float
var elapsed := 0.0


func _init(p_from: Vector2, p_to: Vector2, p_duration: float, p_arc_height: float) -> void:
	from = p_from
	to = p_to
	duration = maxf(p_duration, 0.05)
	arc_height = p_arc_height


func advance(delta: float) -> void:
	elapsed = minf(elapsed + delta, duration)


func progress() -> float:
	return elapsed / duration


func position() -> Vector2:
	return from.lerp(to, progress())


func height() -> float:
	var t := progress()
	return 4.0 * arc_height * t * (1.0 - t)


func finished() -> bool:
	return elapsed >= duration
