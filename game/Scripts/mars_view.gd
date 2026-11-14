class_name MarsView
extends Control
## Ventana de la cabina: muestra una imagen de Marte que cambia según el evento.
##
## Cada evento puede traer un bloque "scene" en events.json:
##   image      nombre de un archivo en res://Images/Mars/ (opcional; si no existe se usa
##              la imagen base: el cráter visto desde el suelo, de MarsLandscape)
##   pan        [x, y] entre 0 y 1: hacia dónde mira la cámara (x: izquierda-derecha;
##              y: más cielo o más suelo, siempre con el horizonte a la vista)
##   effect     none | dust | flare | quake | dark | green | cool
##   intensity  0..1 (fuerza del efecto)
## Para usar una foto real de un evento basta con guardarla en res://Images/Mars/
## con el nombre indicado en "image"; no hace falta tocar código.

const SCENE_IMAGE_DIR: String = "res://Images/Mars/"
const ZOOM: float = 1.4
const PAN_Y_MIN: float = 0.3    # límites verticales de la cámara: el horizonte no sale de la ventana
const PAN_Y_MAX: float = 0.75
const PAN_SECONDS: float = 1.2
const FADE_SECONDS: float = 0.8
const SHAKE_PIXELS: float = 6.0
const STORM_FADE_SECONDS: float = 1.5

## Tormenta de arena: capas de ruido que cruzan la pantalla hacia la derecha a distinta
## velocidad (más lentas al fondo, más rápidas delante), más una neblina de polvo.
const STORM_SHADER: String = """
shader_type canvas_item;

uniform sampler2D noise_tex : repeat_enable, filter_linear;
uniform vec4 sand_dark : source_color = vec4(0.62, 0.36, 0.16, 1.0);
uniform vec4 sand_light : source_color = vec4(0.96, 0.74, 0.45, 1.0);
uniform float intensity = 0.0;

void fragment() {
	vec2 far_layer = vec2(UV.x * 0.9 - TIME * 0.22, UV.y * 2.4);
	vec2 mid_layer = vec2(UV.x * 1.7 - TIME * 0.55, UV.y * 3.6 + 0.31);
	vec2 near_layer = vec2(UV.x * 3.2 - TIME * 1.10, UV.y * 5.0 + 0.67);
	float n = texture(noise_tex, far_layer).r * 0.5
			+ texture(noise_tex, mid_layer).r * 0.3
			+ texture(noise_tex, near_layer).r * 0.2;
	float gusts = smoothstep(0.38, 0.80, n);
	float haze = 0.35 + 0.35 * texture(noise_tex, vec2(UV.x * 0.4 - TIME * 0.05, UV.y * 0.8)).r;
	float alpha = clamp((gusts * 0.75 + haze * 0.30) * intensity, 0.0, 0.92);
	COLOR = vec4(mix(sand_dark.rgb, sand_light.rgb, n), alpha);
}
"""

## Efectos: color de velo, y si lleva tormenta, polvo, destellos o temblor.
const EFFECTS: Dictionary = {
	"none": {"tint": Color(0.0, 0.0, 0.0, 0.0)},
	"dust": {"tint": Color(0.85, 0.5, 0.2, 0.3), "storm": true, "dust": true},
	"flare": {"tint": Color(1.0, 0.8, 0.3, 0.2), "pulse": true},
	"quake": {"tint": Color(0.1, 0.05, 0.05, 0.3), "shake": true},
	"dark": {"tint": Color(0.0, 0.0, 0.0, 0.55)},
	"green": {"tint": Color(0.25, 0.8, 0.35, 0.28)},
	"cool": {"tint": Color(0.3, 0.6, 1.0, 0.25)},
}

var _image: TextureRect
var _tint: ColorRect
var _flash: ColorRect
var _dust: CPUParticles2D
var _storm: ColorRect
var _storm_intensity: float = 0.0
var _storm_tween: Tween = null

var _base_texture: Texture2D
var _using_base: bool = true
var _pan: Vector2 = Vector2(0.5, 0.5)
var _shake_strength: float = 0.0
var _shake_offset: Vector2 = Vector2.ZERO
var _pan_tween: Tween = null
var _tint_tween: Tween = null
var _flash_tween: Tween = null


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_image)

	_tint = _make_overlay(Color(0, 0, 0, 0))
	_storm = _make_storm()
	_dust = _make_dust()
	add_child(_dust)
	_flash = _make_overlay(Color(1.0, 0.92, 0.65, 0.0))

	# Los hijos que ya hubiera en la escena (barra superior, pie de foto...) quedan encima.
	move_child(_image, 0)
	move_child(_tint, 1)
	move_child(_storm, 2)
	move_child(_dust, 3)
	move_child(_flash, 4)

	_base_texture = _make_landscape_texture()
	_image.texture = _base_texture
	resized.connect(_apply_layout)
	_apply_layout()
	set_process(false)


func _process(_delta: float) -> void:
	# Solo está activo mientras dura un temblor.
	_shake_offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength
	_apply_layout()


## Cambia imagen, encuadre y efecto con una transición suave.
func show_scene(scene: Dictionary) -> void:
	_set_texture(str(scene.get("image", "")))
	var pan_values: Array = scene.get("pan", [0.5, 0.5])
	_move_pan(Vector2(float(pan_values[0]), float(pan_values[1])))
	_set_effect(str(scene.get("effect", "none")), float(scene.get("intensity", 1.0)))


# ------------------------------------------------------------------ Construcción

func _make_overlay(color: Color) -> ColorRect:
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(overlay)
	return overlay


## Capa de tormenta: una textura de ruido (FBM) que un shader desplaza con el tiempo.
func _make_storm() -> ColorRect:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.frequency = 0.012

	var texture := NoiseTexture2D.new()
	texture.noise = noise
	texture.width = 512
	texture.height = 256
	texture.seamless = true  # para que al repetirse no se vean los bordes

	var shader := Shader.new()
	shader.code = STORM_SHADER
	var storm_material := ShaderMaterial.new()
	storm_material.shader = shader
	storm_material.set_shader_parameter("noise_tex", texture)
	storm_material.set_shader_parameter("intensity", 0.0)

	var rect := _make_overlay(Color.WHITE)
	rect.material = storm_material
	return rect


func _set_storm_intensity(value: float) -> void:
	_storm_intensity = value
	(_storm.material as ShaderMaterial).set_shader_parameter("intensity", value)


func _make_dust() -> CPUParticles2D:
	var dust := CPUParticles2D.new()
	dust.emitting = false
	dust.amount = 100
	dust.lifetime = 2.2
	dust.preprocess = 2.0
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(4.0, 100.0)
	dust.direction = Vector2(1.0, 0.12)
	dust.spread = 10.0
	dust.gravity = Vector2.ZERO
	dust.initial_velocity_min = 300.0
	dust.initial_velocity_max = 520.0
	dust.scale_amount_min = 2.0
	dust.scale_amount_max = 6.0
	dust.color = Color(0.95, 0.72, 0.4, 0.7)
	return dust


# ---------------------------------------------------------------------- Imagen

## Dibuja el paisaje del cráter una sola vez en un SubViewport y usa su resultado como imagen.
func _make_landscape_texture() -> Texture2D:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(MarsLandscape.WORLD_SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.add_child(MarsLandscape.new())
	add_child(viewport)
	return viewport.get_texture()


func _set_texture(image_name: String) -> void:
	var path: String = SCENE_IMAGE_DIR + image_name
	if not image_name.is_empty() and ResourceLoader.exists(path):
		_image.texture = load(path)
		_using_base = false
	else:
		_image.texture = _base_texture
		_using_base = true


func _move_pan(target: Vector2) -> void:
	if _pan_tween != null:
		_pan_tween.kill()
	_pan_tween = create_tween()
	_pan_tween.tween_method(_set_pan, _pan, target, PAN_SECONDS)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _set_pan(value: Vector2) -> void:
	_pan = value
	_apply_layout()


## La foto es más grande que la ventana (ZOOM) y se desplaza para enseñar zonas distintas.
func _apply_layout() -> void:
	if _image == null:
		return
	var zoomed: Vector2 = size * ZOOM
	_image.size = zoomed
	_image.position = -(zoomed - size) * Vector2(_pan.x, lerpf(PAN_Y_MIN, PAN_Y_MAX, _pan.y)) + _shake_offset
	_dust.position = Vector2(-20.0, size.y * 0.5)
	_dust.emission_rect_extents = Vector2(4.0, size.y * 0.5)


# ---------------------------------------------------------------------- Efectos

func _set_effect(effect: String, intensity: float) -> void:
	var config: Dictionary = EFFECTS.get(effect, EFFECTS["none"])
	var strength: float = clampf(intensity, 0.0, 1.0)

	# Velo de color
	var tint: Color = config["tint"]
	tint.a *= strength
	if _tint_tween != null:
		_tint_tween.kill()
	_tint_tween = create_tween()
	_tint_tween.tween_property(_tint, "color", tint, FADE_SECONDS)

	# Tormenta de arena (ruido animado): sube poco a poco al empezar y se apaga al terminar
	var storm_target: float = strength if config.get("storm", false) else 0.0
	if _storm_tween != null:
		_storm_tween.kill()
	_storm_tween = create_tween()
	_storm_tween.tween_method(_set_storm_intensity, _storm_intensity, storm_target, STORM_FADE_SECONDS)

	# Polvo que cruza la pantalla
	var has_dust: bool = config.get("dust", false)
	if has_dust:
		_dust.amount = int(60.0 + 140.0 * strength)
	_dust.emitting = has_dust

	# Destellos (llamarada solar)
	if _flash_tween != null:
		_flash_tween.kill()
	_flash.color.a = 0.0
	if config.get("pulse", false):
		_flash_tween = create_tween().set_loops()
		_flash_tween.tween_property(_flash, "color:a", 0.45 * strength, 0.5)
		_flash_tween.tween_property(_flash, "color:a", 0.0, 1.1)

	# Temblor (terremoto)
	_shake_strength = SHAKE_PIXELS * strength if config.get("shake", false) else 0.0
	set_process(_shake_strength > 0.0)
	if _shake_strength == 0.0:
		_shake_offset = Vector2.ZERO
		_apply_layout()
