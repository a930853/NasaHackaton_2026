class_name MarsLandscape
extends Control
## Paisaje de Marte visto desde el suelo, como lo vería un astronauta de pie en el
## fondo del cráter: cielo anaranjado con el Sol bajo, la pared lejana del cráter,
## dunas y rocas que crecen según se acercan. Se dibuja por código (sin descargar
## nada) y MarsView lo convierte en la imagen base de la ventana.
## El dibujo es siempre el mismo (semilla fija), así que no cambia entre partidas.

const WORLD_SIZE: Vector2 = Vector2(1920, 1080)
const HORIZON: float = 0.5          # altura del horizonte (fracción de la imagen)
const SEED: int = 7
const RIDGE_STEP: float = 16.0

const SKY_TOP: Color = Color(0.22, 0.15, 0.22)
const SKY_MID: Color = Color(0.5, 0.34, 0.36)
const SKY_HORIZON: Color = Color(0.96, 0.7, 0.48)
const GROUND_FAR: Color = Color(0.47, 0.29, 0.2)
const GROUND_NEAR: Color = Color(0.24, 0.13, 0.1)

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	custom_minimum_size = WORLD_SIZE
	size = WORLD_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	_rng.seed = SEED
	var width: float = WORLD_SIZE.x
	var height: float = WORLD_SIZE.y
	var horizon: float = height * HORIZON

	# Cielo y Sol
	_gradient_rect(Rect2(0, 0, width, horizon * 0.55), SKY_TOP, SKY_MID)
	_gradient_rect(Rect2(0, horizon * 0.55 - 1.0, width, horizon * 0.45 + 2.0), SKY_MID, SKY_HORIZON)
	_draw_sun(Vector2(width * 0.7, horizon - 120.0))

	# Pared del cráter, cada capa más cerca (y más oscura) que la anterior
	_draw_ridge(horizon + 4.0, 70.0, 0.004, 1.0, Color(0.74, 0.52, 0.4))
	_gradient_rect(Rect2(0, horizon - 70.0, width, 90.0), Color(1.0, 0.75, 0.5, 0.0), Color(1.0, 0.75, 0.5, 0.3))
	_draw_ridge(horizon + 16.0, 48.0, 0.007, 2.0, Color(0.6, 0.38, 0.28))
	_draw_ridge(horizon + 34.0, 26.0, 0.012, 3.0, Color(0.5, 0.31, 0.22))

	# Suelo, dunas y rocas
	_gradient_rect(Rect2(0, horizon + 40.0, width, height - horizon - 40.0), GROUND_FAR, GROUND_NEAR)
	_draw_dunes(horizon + 40.0, height)
	_draw_rocks(horizon + 45.0, width, height)


# ----------------------------------------------------------------------- Cielo

func _draw_sun(center: Vector2) -> void:
	for i in range(6):
		draw_circle(center, 260.0 - float(i) * 38.0, Color(1.0, 0.85, 0.6, 0.05))
	draw_circle(center, 34.0, Color(1.0, 0.96, 0.85))


# ------------------------------------------------------------------------ Pared

## Silueta irregular de montañas lejanas, generada con ruido.
func _draw_ridge(base_y: float, amplitude: float, frequency: float, seed_offset: float, color: Color) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = SEED + int(seed_offset)
	noise.frequency = 1.0
	var points := PackedVector2Array()
	var x: float = 0.0
	while x <= WORLD_SIZE.x + RIDGE_STEP:
		var bump: float = 0.5 + 0.5 * noise.get_noise_1d(x * frequency * 100.0)
		points.append(Vector2(x, base_y - amplitude * bump))
		x += RIDGE_STEP
	points.append(Vector2(WORLD_SIZE.x + RIDGE_STEP, base_y + 90.0))
	points.append(Vector2(0.0, base_y + 90.0))
	draw_colored_polygon(points, color)


# ------------------------------------------------------------------------ Suelo

## Ondulaciones de arena: más separadas y más anchas cuanto más cerca.
func _draw_dunes(top_y: float, bottom_y: float) -> void:
	for i in range(12):
		var depth: float = float(i + 1) / 13.0
		var y: float = top_y + (bottom_y - top_y) * pow(depth, 1.9)
		var amplitude: float = 4.0 + 28.0 * depth
		var wavelength: float = 0.004 + 0.002 * _rng.randf()
		var phase: float = _rng.randf() * TAU
		var crest := PackedVector2Array()
		var shade := PackedVector2Array()
		var x: float = 0.0
		while x <= WORLD_SIZE.x + 20.0:
			var wave_y: float = y + sin(x * wavelength + phase) * amplitude
			crest.append(Vector2(x, wave_y))
			shade.append(Vector2(x, wave_y + 6.0 * depth + 2.0))
			x += 20.0
		draw_polyline(shade, Color(0.0, 0.0, 0.0, 0.22), 3.0 + 9.0 * depth, true)
		draw_polyline(crest, Color(0.78, 0.5, 0.34, 0.4), 2.0 + 6.0 * depth, true)


func _draw_rocks(top_y: float, width: float, height: float) -> void:
	var rocks: Array[Dictionary] = []
	for i in range(55):
		var depth: float = _rng.randf()
		rocks.append({
			"x": _rng.randf_range(-40.0, width + 40.0),
			"y": lerpf(top_y, height - 20.0, pow(depth, 1.7)),
			"size": lerpf(5.0, 110.0, pow(depth, 1.5)),
			"seed": _rng.randi(),
		})
	# Dos rocas enormes en primer plano para dar sensación de estar en el suelo
	rocks.append({"x": 120.0, "y": height + 10.0, "size": 190.0, "seed": 11})
	rocks.append({"x": width - 170.0, "y": height + 30.0, "size": 230.0, "seed": 12})

	rocks.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["y"] < b["y"])  # primero las lejanas
	for rock in rocks:
		_draw_rock(Vector2(rock["x"], rock["y"]), float(rock["size"]), int(rock["seed"]))


func _draw_rock(base: Vector2, rock_size: float, rock_seed: int) -> void:
	var local := RandomNumberGenerator.new()
	local.seed = rock_seed
	var points := PackedVector2Array()
	var light := PackedVector2Array()
	var count: int = 9
	for i in range(count):
		var angle: float = TAU * float(i) / float(count)
		var jitter: float = local.randf_range(0.78, 1.2)
		var point := Vector2(cos(angle) * rock_size * jitter, sin(angle) * rock_size * 0.62 * jitter)
		if point.y > 0.0:
			point.y *= 0.35  # la base de la roca es más plana
		var world_point: Vector2 = base + point - Vector2(0.0, rock_size * 0.3)
		points.append(world_point)
		# Cara iluminada: la misma forma, más pequeña y desplazada hacia el Sol
		light.append(base + point * 0.7 + Vector2(-rock_size * 0.12, -rock_size * 0.5))

	# Sombra en el suelo, a la derecha de la roca (el Sol está a la derecha del cielo)
	var shadow := PackedVector2Array()
	for i in range(14):
		var angle: float = TAU * float(i) / 14.0
		shadow.append(base + Vector2(rock_size * 0.35 + cos(angle) * rock_size * 1.3, sin(angle) * rock_size * 0.2))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.3))
	draw_colored_polygon(points, Color(0.29, 0.16, 0.12))
	draw_colored_polygon(light, Color(0.46, 0.28, 0.2))
	var outline: PackedVector2Array = points.duplicate()
	outline.append(points[0])
	draw_polyline(outline, Color(0.14, 0.08, 0.06, 0.8), maxf(1.0, rock_size * 0.02), true)


# ------------------------------------------------------------------------ Utilidad

## Rectángulo con degradado vertical (colores por vértice).
func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(
		PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))
