extends RefCounted
## Strict validation for direct-connect IP / hostname before opening ENet client.


static func is_valid_ipv4(s: String) -> bool:
	var parts := s.split(".")
	if parts.size() != 4:
		return false
	for p in parts:
		if p.is_empty() or not p.is_valid_int():
			return false
		if p.length() > 1 and p.begins_with("0"):
			return false
		var n := int(p)
		if n < 0 or n > 255:
			return false
	return true


static func is_plausible_hostname(s: String) -> bool:
	if s.length() < 1 or s.length() > 253:
		return false
	var rx := RegEx.new()
	if rx.compile("^[a-zA-Z0-9]([a-zA-Z0-9.-]*[a-zA-Z0-9])?$") != OK:
		return false
	return rx.search(s) != null


static func is_valid_client_address(host: String) -> bool:
	var h := host.strip_edges()
	if h.is_empty():
		return false
	if is_valid_ipv4(h):
		return true
	if h == "localhost":
		return true
	if not is_plausible_hostname(h):
		return false
	var resolved := IP.resolve_hostname(h, IP.TYPE_IPV4)
	return not resolved.is_empty()


static func validation_error_hint() -> String:
	return "Enter a valid IPv4 address (e.g. 192.168.1.2) or resolvable hostname."
