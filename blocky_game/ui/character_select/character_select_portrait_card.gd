extends Control
## One carousel card: 3D preview, name plate, SELECT, optional side nav chevron.

signal select_pressed
signal nav_step(delta: int)

const Placement := {"LEFT": -1, "CENTER": 0, "RIGHT": 1}

@onready var _preview: Node = $MainColumn/CardFrame/MarginPreview/SkinCard3DPreview
@onready var _name_label: Label = $MainColumn/Nameplate/MarginName/NameLabel
@onready var _select: Button = $MainColumn/SelectButton
@onready var _nav_left: Button = $NavLeft
@onready var _nav_right: Button = $NavRight


func _ready() -> void:
	_select.pressed.connect(func() -> void: select_pressed.emit())
	_nav_left.pressed.connect(func() -> void: nav_step.emit(-1))
	_nav_right.pressed.connect(func() -> void: nav_step.emit(1))
	resized.connect(_on_resized)
	_on_resized()


func _on_resized() -> void:
	pivot_offset = size * 0.5


func configure(placement: int, display_name: String, vox_path: String) -> void:
	_preview.set_vox_path(vox_path)
	_name_label.text = display_name.to_upper()
	var side := placement != Placement.CENTER
	_nav_left.visible = placement == Placement.LEFT
	_nav_right.visible = placement == Placement.RIGHT
	_style_select_button(not side)
	_select.disabled = side
	_select.focus_mode = Control.FOCUS_NONE if side else Control.FOCUS_ALL


func _style_select_button(active: bool) -> void:
	var n := StyleBoxFlat.new()
	var h := StyleBoxFlat.new()
	var p := StyleBoxFlat.new()
	var corner := 5
	for b in [n, h, p]:
		b.corner_radius_top_left = corner
		b.corner_radius_top_right = corner
		b.corner_radius_bottom_right = corner
		b.corner_radius_bottom_left = corner
		b.border_width_bottom = 3 if active else 2
	if active:
		n.bg_color = Color(0.14, 0.68, 0.26, 1)
		h.bg_color = Color(0.18, 0.78, 0.32, 1)
		p.bg_color = Color(0.1, 0.52, 0.18, 1)
		n.border_color = Color(0.05, 0.35, 0.12, 1)
	else:
		n.bg_color = Color(0.28, 0.3, 0.34, 1)
		h.bg_color = Color(0.34, 0.36, 0.4, 1)
		p.bg_color = Color(0.2, 0.22, 0.26, 1)
		n.border_color = Color(0.12, 0.13, 0.15, 1)
	_select.add_theme_stylebox_override("normal", n)
	_select.add_theme_stylebox_override("hover", h)
	_select.add_theme_stylebox_override("pressed", p)
	_select.add_theme_stylebox_override("disabled", n)
	_select.add_theme_color_override("font_color", Color.WHITE)
	_select.add_theme_color_override("font_disabled_color", Color(0.65, 0.67, 0.7, 1))
	_select.add_theme_font_size_override("font_size", 16)
