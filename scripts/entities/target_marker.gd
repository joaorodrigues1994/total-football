class_name TargetMarker
extends Node2D
## Triângulo amarelo sobre o recebedor selecionado para o passe.


func _draw() -> void:
	var pts := PackedVector2Array([Vector2(-4, -24), Vector2(4, -24), Vector2(0, -17)])
	draw_colored_polygon(pts, Color("f2d230"))
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0.1, 0.1, 0.1), 1.0)
