class_name PlayerSprites
extends RefCounted
## Monta as animações a partir do spritesheet 24x24 (ver tools/gen_player_sprites.py).

const FRAME := 24
const ROWS := ["idle_side", "run_side", "idle_down", "run_down", "idle_up", "run_up"]
const FRAME_COUNT := {"idle": 2, "run": 4}
const SPEED := {"idle": 2.0, "run": 10.0}


static func build(sheet: Texture2D) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in ROWS.size():
		var anim: String = ROWS[row]
		var kind := anim.split("_")[0]
		frames.add_animation(anim)
		frames.set_animation_loop(anim, true)
		frames.set_animation_speed(anim, SPEED[kind])
		for f in FRAME_COUNT[kind]:
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(f * FRAME, row * FRAME, FRAME, FRAME)
			frames.add_frame(anim, atlas)
	return frames
