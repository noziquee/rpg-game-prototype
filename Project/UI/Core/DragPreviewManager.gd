extends CanvasLayer

const TOP_LAYER := 1000
const DEFAULT_SIZE := Vector2(64, 64)

var _preview: TextureRect

func _ready() -> void:
	layer = TOP_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS

func start(texture: Texture2D, size: Vector2 = DEFAULT_SIZE) -> void:

	stop()

	_preview = TextureRect.new()
	_preview.texture = texture
	_preview.size = size
	_preview.custom_minimum_size = size
	_preview.top_level = true
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview.modulate = Color(1, 1, 1, 0.85)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE

	add_child(_preview)
	set_process(true)

func stop() -> void:

	if _preview:
		_preview.queue_free()
		_preview = null

	set_process(false)

func _process(_delta: float) -> void:
	if _preview:
		_preview.global_position = _preview.get_viewport().get_mouse_position() - _preview.size / 2.0
