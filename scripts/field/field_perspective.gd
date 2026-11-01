class_name FieldPerspective
extends RefCounted
## Perspectiva visual levemente inclinada (só apresentação; a física e as regras continuam planas).
## As linhas de jarda convergem para o centro da tela: no topo do campo ficam mais próximas dele.

## Escala horizontal no topo do campo (1.0 = sem inclinação, na base).
const TOP_SCALE := 0.82


## X de tela (em coordenadas de mundo) de um ponto do campo, dado o X central da câmera.
static func project_x(world_x: float, world_y: float, camera_x: float) -> float:
	var t := clampf(world_y / FieldConstants.yards_to_px(FieldConstants.WIDTH_YARDS), 0.0, 1.0)
	return camera_x + (world_x - camera_x) * lerpf(TOP_SCALE, 1.0, t)


static func camera_x(node: Node) -> float:
	var cam := node.get_viewport().get_camera_2d()
	return cam.get_screen_center_position().x if cam else 0.0
