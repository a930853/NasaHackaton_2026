extends Control
## Mission intro scene: explains the situation, the rules and the objectives.
## Shown page by page. The background image is requested from the NASA Image and
## Video Library and, if that fails or is slow, the local image stays.

const NEXT_SCENE := "gameplay"
const FALLBACK_IMAGE: Texture2D = preload("res://Images/MonsCloud_MarsExpress_1920.jpg")
const PAGE_FADE := 0.25

## The text of each page is written letter by letter so it is read, not skipped. It is faster than the
## event text (the pages are long). Pressing Next while it is being written shows the rest at once.
const TYPING_CHARS_PER_SECOND := 55.0
const TYPING_MIN_SECONDS := 1.5
const TYPING_MAX_SECONDS := 10.0
const BUTTON_FONT_SIZE := 18
const IMAGE_GAP := 12
const IMAGE_FADE_IN := 0.4

const CREDIT_FALLBACK := "Image: ESA Mars Express (saved on this computer)"
const CREDIT_NASA := "Image: NASA Image and Video Library"

## Each page: title, body (BBCode) and the pictures shown next to the text.
## "images": [{ "paths": [textures in one row], "caption": text under them, "max": biggest size on screen,
## "pixel": true for pixel art (no smoothing) }]. The pictures are real screenshots of the game
## (res://Images/Tutorial/) and the pixel art of the planets.
const PAGES: Array[Dictionary] = [
	{
		"title": "Welcome to Mars!",
		"body": "You made it! After months in space, your team has landed in [b]Jezero Crater[/b] on Mars. Long ago there was a lake here. NASA scientists want to find out if tiny life lived in it.\n\nYou are very far from home. A radio message to Earth takes minutes. A [b]Sol[/b] is one day on Mars.\n\nYour job: [b]stay alive for 20 Sols[/b] and build a safe home on Mars! Play alone, or with up to 4 friends using their phones.",
		"images": [
			{"paths": ["res://Images/tierra.png", "res://Images/Marte.png"],
				"caption": "From Earth to Mars", "pixel": true, "max": Vector2(360, 140)},
		],
	},
	{
		"title": "Keep the 4 bars alive",
		"body": "Your base has 4 bars: [b]Health[/b], [b]Oxygen[/b], [b]Energy[/b] and [b]Base strength[/b]. They start at 80. [b]If one reaches 0, you lose![/b]\n\nEvery morning they change by themselves:\n- [b]Oxygen[/b] goes down 4, until MOXIE works\n- [b]Energy[/b] goes up 7 (a bit less after Sol 8: dust covers the solar panels)\n- [b]Base strength[/b] goes down 3 (wind and dust)\n- [b]Health[/b] goes down 6 from Sol 4 (stress and radiation)\n\nSo you must keep fixing things!",
		"images": [
			{"paths": ["res://Images/Tutorial/tut_bars.png"],
				"caption": "Click a bar to learn more about it", "max": Vector2(420, 280)},
		],
	},
	{
		"title": "Read, then choose",
		"body": "Each Sol brings a new problem. The story appears [b]letter by letter[/b]: read it! You can choose only when it ends.\n\nThen pick an option. You can see what each one [b]costs[/b], like \"Energy -25\".\n\n[b]Playing alone:[/b] click an option.\n[b]With friends:[/b] everybody votes on their phone, and the option with most votes wins. A tie? Vote again! Tied again? Luck decides.\n\nThe red [b]EVENT[/b] button shows a yellow [b]exclamation mark[/b] when something important happens. Some emergencies have a countdown, so hurry!",
		"images": [
			{"paths": ["res://Images/Tutorial/tut_story.png"],
				"caption": "Read the story, then pick an option", "max": Vector2(450, 200)},
			{"paths": ["res://Images/Tutorial/tut_event_button.png"],
				"caption": "The EVENT button with its yellow mark", "max": Vector2(300, 125)},
		],
	},
	{
		"title": "Jobs take time",
		"body": "[b]Nothing is free![/b] Every choice uses something, like energy or air. Some jobs can [b]fail[/b], just like in real space missions. Then you still pay the costs but get no reward. Often you can try again!\n\nThe astronaut who does a job becomes [b]BUSY[/b] for 1 or 2 Sols. A busy astronaut cannot take new jobs.\n\nA job \"for everyone\" needs the whole crew at home, and leaves the base empty. If everybody is busy, nothing happens that day.\n\nYour crew: [color=#ffd933][b]Engineer[/b][/color], [color=#66e680][b]Biologist[/b][/color], [color=#ff6666][b]Doctor[/b][/color] and [b]Generalist[/b].",
		"images": [
			{"paths": ["res://Images/Tutorial/tut_crew_busy.png"],
				"caption": "A gray helmet means BUSY. It comes back in a few Sols", "max": Vector2(450, 135)},
		],
	},
	{
		"title": "Your tools",
		"body": "[b]Ask Earth for help![/b] Earth sends a hint back in 1 or 2 Sols. Meanwhile, that problem waits. The radio needs 4 Sols to recharge, and it does not work in emergencies or during a solar storm.\n\n[b]WORD BOOK:[/b] new science words appear as you play. Read them there!\n\n[b]MENU:[/b] change the sound, or leave the game and go back to the main menu.",
		"images": [
			{"paths": ["res://Images/Tutorial/tut_word_book.png"],
				"caption": "WORD BOOK: words you discover", "max": Vector2(300, 115)},
			{"paths": ["res://Images/Tutorial/tut_menu_button.png"],
				"caption": "MENU: sound and exit", "max": Vector2(300, 105)},
		],
	},
	{
		"title": "Your goals",
		"body": "[b]1. Stay healthy.[/b] Keep everyone's Health above 50 all the time. It is hard!\n\n[b]2. Grow food.[/b] Grow 3 harvests of roots and good bacteria.\n\n[b]3. Free the rover.[/b] In 2009, the Spirit rover got stuck in soft sand and NASA spent months trying to free it. Now a rover is stuck in the dunes of Jezero!\n\n[b]4. Earthquake sensors.[/b] Build and place 3 sensors outside. Place all 3 before Sol 13 and you will get a warning before a Marsquake!\n\n[b]5. Oxygen machine.[/b] Build MOXIE. When it is done, the base stops losing oxygen every day.",
		"images": [
			{"paths": ["res://Images/Tutorial/tut_goals.png"],
				"caption": "Your goals are always at the top of the screen", "max": Vector2(450, 40)},
			{"paths": ["res://Images/Marte.png"],
				"caption": "Reach Sol 20 alive and you win!", "pixel": true, "max": Vector2(150, 150)},
		],
	},
]

var _page: int = 0
var _leaving: bool = false
var _typing_tween: Tween = null

@onready var background: TextureRect = %Background
@onready var credit_label: Label = %CreditLabel
@onready var title_label: Label = %TitleLabel
@onready var body_label: RichTextLabel = %BodyLabel
@onready var image_column: VBoxContainer = %ImageColumn
@onready var page_label: Label = %PageLabel
@onready var back_button: Button = %BackButton
@onready var next_button: Button = %NextButton
@onready var skip_button: Button = %SkipButton


func _ready() -> void:
	_apply_background()
	# If the image has not arrived yet, swap it in as soon as it does.
	if NasaApi.cached_texture == null:
		Events.nasa_data_received.connect(_on_nasa_data_received, CONNECT_ONE_SHOT)

	for button in [back_button, next_button, skip_button]:
		MenuStyle.apply(button, BUTTON_FONT_SIZE)   # same blue buttons as the menu

	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_leave)

	_show_page(0, false)
	next_button.grab_focus()


func _show_page(index: int, animate: bool = true) -> void:
	_page = clampi(index, 0, PAGES.size() - 1)

	if animate:
		_stop_typing()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(body_label, "modulate:a", 0.0, PAGE_FADE)
		tween.tween_property(image_column, "modulate:a", 0.0, PAGE_FADE)
		await tween.finished

	title_label.text = PAGES[_page]["title"]
	body_label.text = PAGES[_page]["body"]
	body_label.modulate.a = 1.0
	_set_images(PAGES[_page].get("images", []))
	_start_typing()
	page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	back_button.disabled = _page == 0
	next_button.text = "Start mission!" if _page == PAGES.size() - 1 else "Next"


## Shows the pictures of the page (real screenshots of the game and pixel art) next to the text.
func _set_images(items: Array) -> void:
	for child in image_column.get_children():
		image_column.remove_child(child)
		child.queue_free()

	for item in items:
		var frame := PanelContainer.new()
		frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		frame.add_theme_stylebox_override("panel", _image_frame_style())
		image_column.add_child(frame)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		frame.add_child(box)

		var paths: Array = item["paths"]
		var max_size: Vector2 = item["max"]
		var pixel: bool = bool(item.get("pixel", false))
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", IMAGE_GAP)
		box.add_child(row)
		var each_width: float = (max_size.x - float(IMAGE_GAP * (paths.size() - 1))) / float(paths.size())
		for path in paths:
			if not ResourceLoader.exists(str(path)):
				continue   # a picture that is not imported yet is skipped; the text still works
			var texture: Texture2D = load(str(path))
			var fit: float = minf(each_width / float(texture.get_width()), max_size.y / float(texture.get_height()))
			if pixel and fit >= 1.0:
				fit = floorf(fit)   # whole-number zoom keeps the pixels crisp
			var rect := TextureRect.new()
			rect.texture = texture
			rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			rect.custom_minimum_size = texture.get_size() * fit
			rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if pixel else CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			row.add_child(rect)

		var caption := Label.new()
		caption.text = str(item.get("caption", ""))
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.custom_minimum_size.x = max_size.x
		caption.add_theme_font_size_override("font_size", 14)
		caption.add_theme_color_override("font_color", Color(0.78, 0.88, 1.0))
		box.add_child(caption)

	image_column.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(image_column, "modulate:a", 1.0, IMAGE_FADE_IN)


func _image_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.06, 0.12, 0.88)
	style.border_color = Color(0.35, 0.55, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 10
	style.content_margin_bottom = 8
	return style


## Writes the page letter by letter.
func _start_typing() -> void:
	_stop_typing()
	body_label.visible_ratio = 0.0
	var seconds: float = clampf(float(body_label.get_total_character_count()) / TYPING_CHARS_PER_SECOND,
		TYPING_MIN_SECONDS, TYPING_MAX_SECONDS)
	_typing_tween = create_tween()
	_typing_tween.tween_property(body_label, "visible_ratio", 1.0, seconds)


func _is_typing() -> bool:
	return _typing_tween != null and _typing_tween.is_running()


## Shows the whole page at once.
func _stop_typing() -> void:
	if _typing_tween != null:
		_typing_tween.kill()
		_typing_tween = null
	body_label.visible_ratio = 1.0


func _on_back_pressed() -> void:
	if _is_typing():
		_stop_typing()
		return
	if _page > 0:
		_show_page(_page - 1)


func _on_next_pressed() -> void:
	if _is_typing():
		_stop_typing()   # first press: show the rest of the page; second press: next page
		return
	if _page >= PAGES.size() - 1:
		_leave()
	else:
		_show_page(_page + 1)


func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	back_button.disabled = true
	next_button.disabled = true
	skip_button.disabled = true
	Events.scene_change_requested.emit(NEXT_SCENE)


# --- Background (NASA image pre-loaded by NasaApi, with local fallback) ---

func _apply_background() -> void:
	var texture: Texture2D = NasaApi.cached_texture
	if texture == null:
		background.texture = FALLBACK_IMAGE
		credit_label.text = CREDIT_FALLBACK
		return
	background.texture = texture
	var title: String = NasaApi.cached_title
	credit_label.text = CREDIT_NASA if title.is_empty() else "%s — %s" % [CREDIT_NASA, title]


func _on_nasa_data_received(_data: Dictionary) -> void:
	_apply_background()
