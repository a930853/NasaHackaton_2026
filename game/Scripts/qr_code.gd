class_name QrCode
extends RefCounted
## Generador de códigos QR (ISO/IEC 18004) en GDScript, sin dependencias: Godot no trae uno y
## la partida no debe depender de servicios externos para enseñarlo.
##
## Modo byte (UTF-8), corrección de errores M (~15 %) y versiones 1-10: hasta 213 bytes, de sobra
## para "https://<dominio>/controller/?room=K7MP". Sigue el algoritmo de la biblioteca de
## referencia de Nayuki (MIT): https://www.nayuki.io/page/qr-code-generator-library
##
##   var texture := QrCode.to_texture("https://example.com/controller/?room=K7MP")

## Por versión (nivel M): [codewords totales, codewords de corrección por bloque,
##                         bloques del grupo 1, datos por bloque, bloques del grupo 2, datos por bloque]
const VERSIONS_M: Array = [
	[],
	[26, 10, 1, 16, 0, 0],
	[44, 16, 1, 28, 0, 0],
	[70, 26, 1, 44, 0, 0],
	[100, 18, 2, 32, 0, 0],
	[134, 24, 2, 43, 0, 0],
	[172, 16, 4, 27, 0, 0],
	[196, 18, 4, 31, 0, 0],
	[242, 22, 2, 38, 2, 39],
	[292, 22, 3, 36, 2, 37],
	[346, 26, 4, 43, 1, 44],
]
## Centros de los patrones de alineación por versión.
const ALIGNMENT: Array = [
	[], [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34],
	[6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50],
]
const MAX_VERSION: int = 10
const FORMAT_BITS_M: int = 0   # el nivel M se codifica como 00 en la información de formato
const QUIET_ZONE: int = 4      # margen blanco obligatorio alrededor, en módulos

static var _exp: PackedInt32Array = PackedInt32Array()
static var _log: PackedInt32Array = PackedInt32Array()


## Textura con el QR (negro sobre blanco, con margen). Cada módulo ocupa `module_px` píxeles;
## se puede escalar más en pantalla con filtro "nearest" sin que se emborrone.
## Devuelve null si el texto no cabe.
static func to_texture(text: String, module_px: int = 8) -> ImageTexture:
	var modules: Array = encode(text)
	if modules.is_empty():
		return null
	var size: int = modules.size()
	var side: int = (size + QUIET_ZONE * 2) * module_px
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGB8)
	image.fill(Color.WHITE)
	for y in size:
		for x in size:
			if modules[y][x]:
				image.fill_rect(Rect2i((x + QUIET_ZONE) * module_px, (y + QUIET_ZONE) * module_px,
					module_px, module_px), Color.BLACK)
	return ImageTexture.create_from_image(image)


## Matriz de módulos: Array de filas (Array de bool, true = negro). Vacía si el texto no cabe.
static func encode(text: String) -> Array:
	var data: PackedByteArray = text.to_utf8_buffer()
	var version: int = 0
	for v in range(1, MAX_VERSION + 1):
		if 4 + _count_bits(v) + data.size() * 8 <= _data_codewords(v) * 8:
			version = v
			break
	if version == 0:
		push_error("QrCode: el texto es demasiado largo (%d bytes)." % data.size())
		return []

	var codewords: PackedInt32Array = _add_error_correction(version, _data_bits(version, data))
	var qr := _Matrix.new(17 + version * 4)
	_draw_function_patterns(qr, version)
	_draw_codewords(qr, codewords)

	# Se prueba cada una de las 8 máscaras y se queda la que deja el QR más fácil de leer.
	var best_mask: int = 0
	var best_penalty: int = 1 << 30
	for mask in 8:
		_apply_mask(qr, mask)
		_draw_format_bits(qr, mask)
		var penalty: int = _penalty(qr)
		if penalty < best_penalty:
			best_penalty = penalty
			best_mask = mask
		_apply_mask(qr, mask)  # deshacer (XOR)
	_apply_mask(qr, best_mask)
	_draw_format_bits(qr, best_mask)
	return qr.modules


# ------------------------------------------------------------------- Datos

static func _count_bits(version: int) -> int:
	return 8 if version <= 9 else 16


static func _data_codewords(version: int) -> int:
	var spec: Array = VERSIONS_M[version]
	return spec[2] * spec[3] + spec[4] * spec[5]


## Modo byte, longitud, datos, terminador y relleno hasta la capacidad de la versión.
static func _data_bits(version: int, data: PackedByteArray) -> PackedInt32Array:
	var bits: Array[int] = []
	_append_bits(bits, 0b0100, 4)
	_append_bits(bits, data.size(), _count_bits(version))
	for b in data:
		_append_bits(bits, b, 8)
	var capacity: int = _data_codewords(version) * 8
	_append_bits(bits, 0, mini(4, capacity - bits.size()))
	_append_bits(bits, 0, (8 - bits.size() % 8) % 8)
	var pad: int = 0xEC
	while bits.size() < capacity:
		_append_bits(bits, pad, 8)
		pad ^= 0xEC ^ 0x11
	var result := PackedInt32Array()
	for i in range(0, bits.size(), 8):
		var value: int = 0
		for j in 8:
			value = (value << 1) | bits[i + j]
		result.append(value)
	return result


static func _append_bits(bits: Array[int], value: int, length: int) -> void:
	for i in range(length - 1, -1, -1):
		bits.append((value >> i) & 1)


## Reparte los datos en bloques, añade la corrección Reed-Solomon de cada uno y los intercala.
static func _add_error_correction(version: int, data: PackedInt32Array) -> PackedInt32Array:
	var spec: Array = VERSIONS_M[version]
	var ec_length: int = spec[1]
	var generator: PackedInt32Array = _rs_generator(ec_length)
	var data_blocks: Array[PackedInt32Array] = []
	var ec_blocks: Array[PackedInt32Array] = []
	var offset: int = 0
	for group in [[spec[2], spec[3]], [spec[4], spec[5]]]:
		for n in group[0]:
			var block: PackedInt32Array = data.slice(offset, offset + group[1])
			offset += group[1]
			data_blocks.append(block)
			ec_blocks.append(_rs_remainder(block, generator))
	var result := PackedInt32Array()
	var longest: int = 0
	for block in data_blocks:
		longest = maxi(longest, block.size())
	for i in longest:
		for block in data_blocks:
			if i < block.size():
				result.append(block[i])
	for i in ec_length:
		for block in ec_blocks:
			result.append(block[i])
	return result


# ------------------------------------------------------------- Reed-Solomon

static func _init_gf() -> void:
	if not _exp.is_empty():
		return
	_exp.resize(512)
	_log.resize(256)
	var x: int = 1
	for i in 255:
		_exp[i] = x
		_log[x] = i
		x <<= 1
		if x & 0x100:
			x ^= 0x11D
	for i in range(255, 512):
		_exp[i] = _exp[i - 255]


static func _gf_mul(a: int, b: int) -> int:
	if a == 0 or b == 0:
		return 0
	return _exp[_log[a] + _log[b]]


## Coeficientes del polinomio generador de grado `degree` (sin el 1 inicial), de mayor a menor.
static func _rs_generator(degree: int) -> PackedInt32Array:
	_init_gf()
	var result := PackedInt32Array()
	result.resize(degree)
	result.fill(0)
	result[degree - 1] = 1
	var root: int = 1
	for i in degree:
		for j in degree:
			result[j] = _gf_mul(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = _gf_mul(root, 0x02)
	return result


static func _rs_remainder(data: PackedInt32Array, generator: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	result.resize(generator.size())
	result.fill(0)
	for b in data:
		var factor: int = b ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in generator.size():
			result[i] ^= _gf_mul(generator[i], factor)
	return result


# ------------------------------------------------------------------ Matriz

class _Matrix:
	var size: int
	var modules: Array = []      # [y][x] -> bool (true = negro)
	var reserved: Array = []     # [y][x] -> bool (patrón fijo: no lleva datos ni máscara)

	func _init(side: int) -> void:
		size = side
		for y in side:
			var row: Array = []
			row.resize(side)
			row.fill(false)
			modules.append(row)
			reserved.append(row.duplicate())

	func set_fixed(x: int, y: int, dark: bool) -> void:
		modules[y][x] = dark
		reserved[y][x] = true


static func _draw_function_patterns(qr: _Matrix, version: int) -> void:
	var size: int = qr.size
	for i in size:  # patrones de sincronización
		qr.set_fixed(6, i, i % 2 == 0)
		qr.set_fixed(i, 6, i % 2 == 0)
	for corner in [Vector2i(3, 3), Vector2i(size - 4, 3), Vector2i(3, size - 4)]:  # buscadores
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var x: int = corner.x + dx
				var y: int = corner.y + dy
				if x >= 0 and x < size and y >= 0 and y < size:
					var dist: int = maxi(absi(dx), absi(dy))
					qr.set_fixed(x, y, dist != 2 and dist != 4)
	var positions: Array = ALIGNMENT[version]
	var last: int = positions.size() - 1
	for i in positions.size():  # alineación (salvo donde pisarían los buscadores)
		for j in positions.size():
			if (i == 0 and j == 0) or (i == 0 and j == last) or (i == last and j == 0):
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					qr.set_fixed(positions[i] + dx, positions[j] + dy, maxi(absi(dx), absi(dy)) != 1)
	_draw_format_bits(qr, 0)  # reserva su sitio; el valor real se pone al elegir la máscara
	if version >= 7:
		var rem: int = version
		for i in 12:
			rem = (rem << 1) ^ ((rem >> 11) * 0x1F25)
		var bits: int = version << 12 | rem
		for i in 18:
			var dark: bool = ((bits >> i) & 1) != 0
			var a: int = size - 11 + i % 3
			var b: int = floori(i / 3.0)
			qr.set_fixed(a, b, dark)
			qr.set_fixed(b, a, dark)


static func _draw_format_bits(qr: _Matrix, mask: int) -> void:
	var size: int = qr.size
	var data: int = FORMAT_BITS_M << 3 | mask
	var rem: int = data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * 0x537)
	var bits: int = (data << 10 | rem) ^ 0x5412
	var bit := func(i: int) -> bool: return ((bits >> i) & 1) != 0
	for i in range(0, 6):
		qr.set_fixed(8, i, bit.call(i))
	qr.set_fixed(8, 7, bit.call(6))
	qr.set_fixed(8, 8, bit.call(7))
	qr.set_fixed(7, 8, bit.call(8))
	for i in range(9, 15):
		qr.set_fixed(14 - i, 8, bit.call(i))
	for i in range(0, 8):
		qr.set_fixed(size - 1 - i, 8, bit.call(i))
	for i in range(8, 15):
		qr.set_fixed(8, size - 15 + i, bit.call(i))
	qr.set_fixed(8, size - 8, true)  # módulo oscuro fijo


## Coloca los codewords en zigzag por parejas de columnas, de abajo arriba y de arriba abajo.
static func _draw_codewords(qr: _Matrix, codewords: PackedInt32Array) -> void:
	var size: int = qr.size
	var i: int = 0
	var total_bits: int = codewords.size() * 8
	var right: int = size - 1
	while right >= 1:
		if right == 6:
			right = 5  # la columna 6 es el patrón de sincronización
		for vert in size:
			for j in 2:
				var x: int = right - j
				var upward: bool = ((right + 1) & 2) == 0
				var y: int = size - 1 - vert if upward else vert
				if not qr.reserved[y][x] and i < total_bits:
					qr.modules[y][x] = ((codewords[i >> 3] >> (7 - (i & 7))) & 1) != 0
					i += 1
		right -= 2


static func _apply_mask(qr: _Matrix, mask: int) -> void:
	for y in qr.size:
		for x in qr.size:
			if qr.reserved[y][x]:
				continue
			var invert: bool
			match mask:
				0: invert = (x + y) % 2 == 0
				1: invert = y % 2 == 0
				2: invert = x % 3 == 0
				3: invert = (x + y) % 3 == 0
				4: invert = (floori(x / 3.0) + floori(y / 2.0)) % 2 == 0
				5: invert = x * y % 2 + x * y % 3 == 0
				6: invert = (x * y % 2 + x * y % 3) % 2 == 0
				_: invert = ((x + y) % 2 + x * y % 3) % 2 == 0
			if invert:
				qr.modules[y][x] = not qr.modules[y][x]


## Penalización del estándar (reglas 1, 2 y 4) para elegir la máscara. Sirve cualquier máscara;
## esto solo busca la que se lee mejor (sin rachas largas ni bloques del mismo color).
static func _penalty(qr: _Matrix) -> int:
	var size: int = qr.size
	var m: Array = qr.modules
	var result: int = 0
	for horizontal in [true, false]:  # regla 1: rachas de 5 o más del mismo color
		for a in size:
			var run: int = 1
			for b in range(1, size):
				var cur: bool = m[a][b] if horizontal else m[b][a]
				var prev: bool = m[a][b - 1] if horizontal else m[b - 1][a]
				if cur == prev:
					run += 1
					if run == 5:
						result += 3
					elif run > 5:
						result += 1
				else:
					run = 1
	var dark: int = 0
	for y in size:
		for x in size:
			if m[y][x]:
				dark += 1
			if x < size - 1 and y < size - 1:  # regla 2: bloques de 2x2 del mismo color
				var c: bool = m[y][x]
				if c == m[y][x + 1] and c == m[y + 1][x] and c == m[y + 1][x + 1]:
					result += 3
	var total: int = size * size  # regla 4: proporción de negro lejos del 50 %
	var k: int = int(ceil(absf(dark * 20.0 - total * 10.0) / total)) - 1
	result += maxi(k, 0) * 10
	return result
