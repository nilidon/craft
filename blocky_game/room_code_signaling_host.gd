extends Node
class_name RoomCodeSignalingHost
## Registers room code + UDP port with an HTTP signaling server; heartbeats until stopped.

const HEARTBEAT_SEC := 40.0

var _http: HTTPRequest
var _timer: Timer
var _base: String
var _code: String
var _port: int
var _advertise: String
var _busy := false


func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_timer = Timer.new()
	_timer.wait_time = HEARTBEAT_SEC
	_timer.one_shot = false
	_timer.timeout.connect(_on_heartbeat_timeout)
	add_child(_timer)


func start_signaling(
	base_url: String,
	room_code: String,
	game_port: int,
	advertise_host: String = ""
) -> void:
	_base = base_url.strip_edges().trim_suffix("/")
	_code = room_code
	_port = game_port
	_advertise = advertise_host.strip_edges()
	if _base.is_empty() or _code.is_empty() or _port < 1:
		return
	if _http != null:
		_http.cancel_request()
	_busy = false
	_post("/register", _register_body())
	_timer.stop()
	_timer.start()


func stop_signaling() -> void:
	_timer.stop()
	if _base.is_empty() or _code.is_empty() or _port < 1:
		return
	if _busy:
		return
	_busy = true
	var err := _http.request(
		_base + "/unregister",
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(_register_body())
	)
	if err != OK:
		_busy = false


func _exit_tree() -> void:
	stop_signaling()


func _register_body() -> Dictionary:
	var d := {"code": _code, "port": _port}
	if not _advertise.is_empty():
		d["advertise_host"] = _advertise
	return d


func _post(path: String, body: Dictionary) -> void:
	if _busy:
		return
	_busy = true
	var err := _http.request(
		_base + path,
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	if err != OK:
		_busy = false
		push_error("Room signaling HTTP request failed (%d)." % err)


func _on_request_completed(
	_result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_busy = false
	if response_code != 200:
		push_warning(
			"Room signaling: HTTP %d — %s"
			% [response_code, body.get_string_from_utf8().substr(0, 200)])


func _on_heartbeat_timeout() -> void:
	if _base.is_empty():
		return
	_post("/heartbeat", _register_body())
