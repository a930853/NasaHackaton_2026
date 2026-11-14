class_name NasaApi
extends HTTPRequest
## Pre-loads the Jezero image from the NASA Image and Video Library when the game
## starts, so the intro scene already has it by the time it opens.
## Main calls fetch() once. The result is cached in static variables and also
## announced through Events.nasa_data_received.

const IMAGE_SEARCH_URL := "https://images-api.nasa.gov/search?q=jezero%20crater&media_type=image"
const REQUEST_TIMEOUT := 3.0

static var cached_texture: Texture2D = null
static var cached_title: String = ""

var _fetching: bool = false
var _searching: bool = true
var _candidates: Array[String] = []
var _title: String = ""


func _ready() -> void:
	timeout = REQUEST_TIMEOUT
	request_completed.connect(_on_request_completed)


func fetch() -> void:
	if _fetching or cached_texture != null:
		return
	_fetching = true
	_searching = true
	if request(IMAGE_SEARCH_URL) != OK:
		_fail(ERR_CANT_CONNECT)


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if _searching:
		_handle_search(result, code, body)
	else:
		_handle_image(result, code, body)


func _handle_search(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail(code if code != 0 else result)
		return
	var data: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (data is Dictionary):
		_fail(ERR_PARSE_ERROR)
		return
	var items: Array = data.get("collection", {}).get("items", [])
	for item in items:
		var links: Array = item.get("links", [])
		if links.is_empty():
			continue
		var href: String = links[0].get("href", "")
		if href.is_empty():
			continue
		var info: Array = item.get("data", [])
		_title = info[0].get("title", "") if not info.is_empty() else ""
		# Try a medium resolution first and, if it does not exist, the thumbnail.
		_candidates = [href.replace("~thumb", "~medium"), href]
		_searching = false
		_request_next_candidate()
		return
	_fail(ERR_FILE_NOT_FOUND)


func _request_next_candidate() -> void:
	if _candidates.is_empty():
		_fail(ERR_FILE_NOT_FOUND)
		return
	var url: String = _candidates.pop_front()
	if request(url) != OK:
		_request_next_candidate()


func _handle_image(result: int, code: int, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_request_next_candidate()
		return
	var image := Image.new()
	var err: int = image.load_jpg_from_buffer(body)
	if err != OK:
		err = image.load_png_from_buffer(body)
	if err != OK:
		_request_next_candidate()
		return
	cached_texture = ImageTexture.create_from_image(image)
	cached_title = _title
	_fetching = false
	Events.nasa_data_received.emit({"image": cached_texture, "title": cached_title})


func _fail(error_code: int) -> void:
	_fetching = false
	push_warning("NasaApi: image not available (%d); the local image will be used." % error_code)
	Events.nasa_api_failed.emit(error_code)
