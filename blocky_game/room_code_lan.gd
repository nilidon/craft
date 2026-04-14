extends RefCounted
class_name RoomCodeLan

const CODE_BYTES := 8
const MIN_CODE_LEN := 4

static func normalize_code(s: String) -> String:
	var t := ""
	for ch in s.to_upper():
		if (ch >= "A" and ch <= "Z") or (ch >= "0" and ch <= "9"):
			t += ch
		if t.length() >= CODE_BYTES:
			break
	return t


static func is_valid_room_code(s: String) -> bool:
	return normalize_code(s).length() >= MIN_CODE_LEN
