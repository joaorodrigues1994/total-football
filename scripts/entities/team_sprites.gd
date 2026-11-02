class_name TeamSprites
extends RefCounted
## Uniformes por time: recolore o spritesheet-base neutro (player_team_a.png) trocando por cor exata os três
## tons do time (principal, claro, escuro) pela cor primária e o branco (número, listra do capacete, meias)
## pela secundária. Todo o resto (contorno, pele, calça, máscara, sapato, transparência) passa intacto.
## Uma textura por par de cores, em cache.

const BASE_SHEET := "res://assets/sprites/player_team_a.png"
const BASE_PRIMARY := Color8(31, 78, 140)
const BASE_SECONDARY := Color8(236, 236, 240)

static var _cache := {}


static func sheet_for(primary: Color, secondary: Color) -> Texture2D:
	var key := "%s|%s" % [primary.to_html(false), secondary.to_html(false)]
	if not _cache.has(key):
		var base: Texture2D = load(BASE_SHEET)
		_cache[key] = ImageTexture.create_from_image(recolor(base.get_image(), primary, secondary))
	return _cache[key]


## Cópia do spritesheet-base com as cores do time. Compara em 8 bits para a troca ser exata.
static func recolor(base: Image, primary: Color, secondary: Color) -> Image:
	var swaps := {
		_key(BASE_PRIMARY): primary,
		_key(TeamStyle.light(BASE_PRIMARY)): TeamStyle.light(primary),
		_key(TeamStyle.dark(BASE_PRIMARY)): TeamStyle.dark(primary),
		_key(BASE_SECONDARY): secondary,
	}
	var result := base.duplicate() as Image
	for y in result.get_height():
		for x in result.get_width():
			var c := result.get_pixel(x, y)
			if c.a == 0.0:
				continue
			var k := _key(c)
			if swaps.has(k):
				var to: Color = swaps[k]
				result.set_pixel(x, y, Color(to.r, to.g, to.b, c.a))
	return result


static func _key(c: Color) -> int:
	return (c.r8 << 16) | (c.g8 << 8) | c.b8
