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

const CREDIT_FALLBACK := "Image: ESA Mars Express (saved on this computer)"
const CREDIT_NASA := "Image: NASA Image and Video Library"

const PAGES: Array[Dictionary] = [
	{
		"title": "Welcome to Mars!",
		"body": "You made it! After months in space, your team has landed in [b]Jezero Crater[/b] on Mars. Long ago there was a lake here. NASA scientists want to find out if tiny life lived in it.\n\nYou are very far from home. A radio message to Earth takes minutes, and help takes [b]2 to 3 Sols[/b] to arrive. A Sol is one day on Mars.\n\nYour job: [b]stay alive for 20 Sols[/b] and build a safe home on Mars!",
	},
	{
		"title": "Every choice has a price",
		"body": "[b]Nothing is free![/b] Every choice uses something, like energy or air. You can see the costs on each button before you choose.\n\nSome jobs can [b]fail[/b], just like in real space missions. If a job fails, you still pay the costs, but you do not get the reward. Then you can try again!\n\nEach of you has a job: [b]Engineer, Biologist, Doctor[/b] or [b]Generalist[/b]. Experts are better at their own tasks, so they have a bigger chance to succeed. The first player is also the Commander and decides a second tie.\n\nEach Sol brings a new event. Sometimes a real event from space happens too, and you must solve it together!",
	},
	{
		"title": "Your goals",
		"body": "[b]1. Stay healthy.[/b] Keep everyone's Health above 50 all the time.\n\n[b]2. Grow food.[/b] Grow 3 harvests of roots and good bacteria.\n\n[b]3. Free the rover.[/b] In 2009, the Spirit rover got stuck in soft sand and NASA spent months trying to free it. Now a rover is stuck in the dunes of Jezero!\n\n[b]4. Earthquake sensors.[/b] Build and place 3 sensors outside. Place all 3 before Sol 13 and you will get a warning before a Marsquake!\n\n[b]5. Oxygen machine.[/b] Build MOXIE. It costs lots of energy, but when it is done, the base stops losing oxygen every day.",
	},
]

var _page: int = 0
var _leaving: bool = false
var _typing_tween: Tween = null

@onready var background: TextureRect = %Background
@onready var credit_label: Label = %CreditLabel
@onready var title_label: Label = %TitleLabel
@onready var body_label: RichTextLabel = %BodyLabel
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
		tween.tween_property(body_label, "modulate:a", 0.0, PAGE_FADE)
		await tween.finished

	title_label.text = PAGES[_page]["title"]
	body_label.text = PAGES[_page]["body"]
	body_label.modulate.a = 1.0
	_start_typing()
	page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	back_button.disabled = _page == 0
	next_button.text = "Start mission!" if _page == PAGES.size() - 1 else "Next"


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
