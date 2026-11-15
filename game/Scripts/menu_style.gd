class_name MenuStyle
extends RefCounted
## Estilo azul de los botones de las pantallas anteriores a la partida (menú, elección de modo, lobby,
## opciones y tutorial): el marco azul de res://Styles/Button.tres (MarcoBoton.png), que se apaga un
## poco al pasar el ratón (HoverButton.tres), con la fuente del título del menú.
## Uso: MenuStyle.apply(boton) o MenuStyle.apply(boton, 18) para un texto más pequeño.

const NORMAL: StyleBoxTexture = preload("res://Styles/Button.tres")
const HOVER: StyleBoxTexture = preload("res://Styles/HoverButton.tres")
const FONT: Font = preload("res://TextFonts/sixtyfour/static/sixtyfour-math-400-normal.ttf")

const DEFAULT_FONT_SIZE: int = 22
const MIN_HEIGHT: float = 64.0            # el marco azul tiene esquinas de 32 px: más bajo se deforma
const SIDE_PADDING: float = 20.0
const VERTICAL_PADDING: float = 10.0
const DISABLED_DIM: float = 0.45          # cuánto se oscurece un botón desactivado


## Pone a un botón el estilo azul. Conserva el tamaño mínimo que ya tuviera, si es mayor.
static func apply(button: Button, font_size: int = DEFAULT_FONT_SIZE) -> void:
	var normal: StyleBoxTexture = _padded(NORMAL)
	var hover: StyleBoxTexture = _padded(HOVER)
	var disabled: StyleBoxTexture = _padded(NORMAL)
	disabled.modulate_color = Color(DISABLED_DIM, DISABLED_DIM, DISABLED_DIM, 1.0)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("pressed", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("hover_pressed", hover)
	button.add_theme_stylebox_override("disabled", disabled)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_font_override("font", FONT)
	button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size.y = maxf(button.custom_minimum_size.y, MIN_HEIGHT)


## Copia del marco con el relleno interior justo para el texto (el marco se estira con sus esquinas de 32 px).
static func _padded(source: StyleBoxTexture) -> StyleBoxTexture:
	var style: StyleBoxTexture = source.duplicate()
	style.content_margin_left = SIDE_PADDING
	style.content_margin_right = SIDE_PADDING
	style.content_margin_top = VERTICAL_PADDING
	style.content_margin_bottom = VERTICAL_PADDING
	return style
