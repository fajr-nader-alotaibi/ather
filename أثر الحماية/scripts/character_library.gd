extends RefCounted
## Original cutouts from the ATHAR character design board, with shared animation data.

const ANIMATIONS := {
	"idle": {"count": 1, "fps": 1.0, "loop": true},
	"walk": {"count": 2, "fps": 7.5, "loop": true},
	"run": {"count": 2, "fps": 10.0, "loop": true},
	"jump": {"count": 1, "fps": 1.0, "loop": false},
	"fall": {"count": 1, "fps": 1.0, "loop": true},
	"land": {"count": 1, "fps": 1.0, "loop": false},
	"double_jump": {"count": 2, "fps": 10.0, "loop": false},
	"air_spin": {"count": 3, "fps": 14.0, "loop": true},
	"interact": {"count": 1, "fps": 1.0, "loop": false},
	# A short celebratory hop reuses two distinct airborne poses from the source board.
	"celebrate": {"count": 2, "fps": 8.0, "loop": false, "source": "double_jump"}
}
const CHARACTER_IDS := ["lina", "rayan"]
const CHARACTER_NAMES_AR := ["لينا — حارسة الغابة", "ريان — مستكشف الأثر"]
const CHARACTER_NAMES_EN := ["Lina — Forest Keeper", "Rayan — Trail Scout"]
const CHARACTER_DESCRIPTIONS_AR := [
	"مستكشفة مرحة تحمل فانوس البذور وتعيد الحياة إلى المسارات.",
	"مستكشف هادئ يجمع الأدلة ويضيء الطريق برفقة رفيقه."
]
const CHARACTER_DESCRIPTIONS_EN := [
	"A bright explorer who carries the seed lantern and restores the trail.",
	"A calm scout who gathers clues and lights the way with his companion."
]
const PALETTE_HEX := ["bf3a2b", "e5a238", "6eaa79", "687fbb", "a277ad", "d9828a"]
const PALETTE_NAMES_AR := ["أحمر التوت", "ذهبي", "أخضر الغابة", "أزرق سماوي", "بنفسجي", "وردي"]
const PALETTE_NAMES_EN := ["Berry", "Amber", "Forest", "Sky", "Lilac", "Rose"]

static var _frame_cache: Dictionary = {}


static func palette_color(index: int) -> Color:
	return Color(PALETTE_HEX[clampi(index, 0, PALETTE_HEX.size() - 1)])


static func palette_name(index: int, language: String) -> String:
	var safe_index := clampi(index, 0, PALETTE_HEX.size() - 1)
	return PALETTE_NAMES_EN[safe_index] if language == "en" else PALETTE_NAMES_AR[safe_index]


static func character_name(index: int, language: String) -> String:
	var safe_index := clampi(index, 0, CHARACTER_IDS.size() - 1)
	return CHARACTER_NAMES_EN[safe_index] if language == "en" else CHARACTER_NAMES_AR[safe_index]


static func character_description(index: int, language: String) -> String:
	var safe_index := clampi(index, 0, CHARACTER_IDS.size() - 1)
	return CHARACTER_DESCRIPTIONS_EN[safe_index] if language == "en" else CHARACTER_DESCRIPTIONS_AR[safe_index]


static func frames_for(character_index: int) -> SpriteFrames:
	var safe_index := clampi(character_index, 0, CHARACTER_IDS.size() - 1)
	var character_id: String = CHARACTER_IDS[safe_index]
	if _frame_cache.has(character_id):
		return _frame_cache[character_id] as SpriteFrames
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for state_variant in ANIMATIONS.keys():
		var state := str(state_variant)
		var spec: Dictionary = ANIMATIONS[state]
		var source_state := str(spec.get("source", state))
		frames.add_animation(state)
		frames.set_animation_speed(state, float(spec["fps"]))
		frames.set_animation_loop(state, bool(spec["loop"]))
		for frame_index in range(int(spec["count"])):
			var path := "res://assets/characters/%s/%s_%02d.png" % [character_id, source_state, frame_index]
			var texture := load(path) as Texture2D
			if texture == null:
				push_error("Missing character frame: " + path)
				continue
			frames.add_frame(state, texture)
	_frame_cache[character_id] = frames
	return frames


static func apply_palette(sprite: AnimatedSprite2D, color_index: int, character_index: int = 0) -> void:
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/shaders/outfit_tint.gdshader") as Shader
	material.set_shader_parameter("outfit_color", palette_color(color_index))
	material.set_shader_parameter("outfit_channel", float(clampi(character_index, 0, 1)))
	sprite.material = material


static func configure_sprite(sprite: AnimatedSprite2D, character_index: int, color_index: int) -> void:
	sprite.sprite_frames = frames_for(character_index)
	apply_palette(sprite, color_index, character_index)
	sprite.centered = true
	sprite.animation = "idle"
	sprite.play("idle")
