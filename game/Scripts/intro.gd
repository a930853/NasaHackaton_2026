extends Control
## Mission intro scene: explains the situation, the rules and the objectives.
## Shown page by page. The background image is requested from the NASA Image and
## Video Library and, if that fails or is slow, the local image stays.

const NEXT_SCENE := "gameplay"
const FALLBACK_IMAGE: Texture2D = preload("res://Images/MonsCloud_MarsExpress_1920.jpg")
const PAGE_FADE := 0.25

const CREDIT_FALLBACK := "Image: ESA Mars Express (local file)"
const CREDIT_NASA := "Image: NASA Image and Video Library"

const PAGES: Array[Dictionary] = [
	{
		"title": "Jezero Crater, Mars",
		"body": "After months of travel, [b]you have finally reached Mars[/b]. Your base stands in Jezero Crater, an ancient lake where NASA searches for signs of past life.\n\nFrom now on you are on your own: Earth is minutes away by radio, and any help takes [b]2 to 3 Sols[/b] to arrive. (A Sol is one Martian day.)\n\nYour mission is to survive and build a stable colony.",
	},
	{
		"title": "Every decision has a price",
		"body": "[b]Nothing is free.[/b] Every action or decision you make carries a cost for the future: saving today may cost you tomorrow.\n\nEach of you has a [b]role[/b] with different skills: Engineer, Biologist, Doctor and Generalist. An expert in a task does it better and spends fewer resources.\n\nTo complete the objectives, [b]missions[/b], or rather [b]events[/b], will appear. They directly affect your stats, both [b]individual[/b] and for the [b]whole group[/b].\n\n[b]Real-time events[/b] may also happen, simulating what is really going on on Mars. You will have to solve them together.",
	},
	{
		"title": "Mission objectives",
		"body": "[b]1. Healthy crew.[/b] Keep everyone's health above 50% at all times.\n\n[b]2. Stable colony.[/b] Successfully grow 3 harvests of roots and probiotics.\n\n[b]3. Stuck rover.[/b] In 2009 the Spirit rover got trapped in soft sand, and NASA spent months trying to free it. Your challenge: free the rover stuck in the dunes of Jezero.\n\n[b]4. Seismic sensor network (InSight).[/b] Build and place 3 sensors outside. If they are all in place before Sol 20, the network will warn you 1 turn ahead of any collapse.\n\n[b]5. MOXIE oxygen generator.[/b] Building it costs a lot of energy, but once complete it removes the passive oxygen drain and makes you self-sufficient, without taking resources away from the Biologist.",
	},
]

var _page: int = 0
var _leaving: bool = false

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

	back_button.pressed.connect(_on_back_pressed)
	next_button.pressed.connect(_on_next_pressed)
	skip_button.pressed.connect(_leave)

	_show_page(0, false)
	next_button.grab_focus()


func _show_page(index: int, animate: bool = true) -> void:
	_page = clampi(index, 0, PAGES.size() - 1)

	if animate:
		var tween := create_tween()
		tween.tween_property(body_label, "modulate:a", 0.0, PAGE_FADE)
		await tween.finished

	title_label.text = PAGES[_page]["title"]
	body_label.text = PAGES[_page]["body"]
	page_label.text = "%d / %d" % [_page + 1, PAGES.size()]
	back_button.disabled = _page == 0
	next_button.text = "Start mission!" if _page == PAGES.size() - 1 else "Next"

	if animate:
		var tween_in := create_tween()
		tween_in.tween_property(body_label, "modulate:a", 1.0, PAGE_FADE)


func _on_back_pressed() -> void:
	if _page > 0:
		_show_page(_page - 1)


func _on_next_pressed() -> void:
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
