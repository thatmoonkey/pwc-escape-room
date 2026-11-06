class_name Leaderboard
extends RefCounted

## THE RUN'S BOARD, KEPT ON THE DEVICE.
##
## The end-of-run screen lets a crew put their score, a name and a way to reach
## them on a leaderboard. This is that leaderboard's storage, and it is
## deliberately local: no network, no account, no server that can be down in a
## conference basement. Every platform the game ships to can write user:// - a
## browser's indexed database, an Android app's own storage, a headset's - so
## the board works identically in a PWA, an APK and a headset, online or not.
##
## The shape of an entry is the shape of the form on the completion screen:
##
##     { "id", "name", "contact", "score", "at", "callsign" }
##
## A score is sanitised to a whole number and a name to printable text, because
## a save file is a file: a player can edit it, and nothing downstream may be
## trusted to be well formed. An entry with nothing to show is refused rather
## than stored, so the board never contains half a row.
##
## Static and dependency-free, like GameState: the completion screen reads it,
## nothing here reads a screen.

const PATH := "user://leaderboard.json"
const VERSION := 1
const MAX_ENTRIES := 50
const NAME_MAX := 24
const CONTACT_MAX := 64
## A phone number shorter than this is a typo, not a number.
const PHONE_DIGITS_MIN := 7

## Newest-loaded board, highest score first. Empty until load_data() runs.
static var entries: Array = []
## What the last player typed, so the next run's form is not a blank form.
static var last_name: String = ""
static var last_contact: String = ""
static var _loaded: bool = false


static func load_data() -> void:
	if _loaded:
		return
	_loaded = true
	entries.clear()
	if not FileAccess.file_exists(PATH):
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != VERSION:
		return
	var saved: Variant = data.get("entries", [])
	if saved is Array:
		for raw in saved:
			if raw is Dictionary:
				var entry: Dictionary = _clean(raw)
				if not entry.is_empty():
					entries.append(entry)
	last_name = String(data.get("last_name", ""))
	last_contact = String(data.get("last_contact", ""))
	_sort()


static func save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Leaderboard: could not write %s" % PATH)
		return
	file.store_string(JSON.stringify({
		"version": VERSION,
		"entries": entries,
		"last_name": last_name,
		"last_contact": last_contact,
	}, "  "))
	file.close()


## Put a run on the board. Everything is validated before anything is written,
## and the answer says why when it is refused, so the form can say it too.
## Returns { "ok", "error", "entry", "rank" }.
##
## require_contact is false only where a contact cannot be typed at all - in a
## headset with no keyboard - so that the score can still be recorded. Every
## other platform asks for the address or number properly.
static func submit(display_name: String, contact: String, score: int,
		require_contact: bool = true) -> Dictionary:
	load_data()
	var kept_name: String = _clean_name(display_name)
	if kept_name.length() < 2:
		return {"ok": false, "error": "Add a name of at least two characters."}
	var kept_contact: String = _clean_contact(contact)
	if require_contact and not is_valid_contact(kept_contact):
		return {"ok": false, "error": "Add an email address or a phone number we can reach you on."}
	if kept_contact != "" and not is_valid_contact(kept_contact):
		return {"ok": false, "error": "That contact does not look like an email address or a phone number."}
	var kept_score: int = maxi(score, 0)
	var entry := {
		"id": "%d-%d" % [Time.get_ticks_usec(), entries.size()],
		"name": kept_name,
		"contact": kept_contact,
		"score": kept_score,
		"at": Time.get_datetime_string_from_system(),
		"callsign": GameState.callsign_or_default(),
	}
	entries.append(entry)
	last_name = kept_name
	last_contact = kept_contact
	_sort()
	while entries.size() > MAX_ENTRIES:
		entries.pop_back()
	save()
	return {"ok": true, "error": "", "entry": entry, "rank": rank_of(String(entry["id"]), kept_score)}


## Where an entry stands on the board, 1-based.
static func rank_of(_id: String, score: int) -> int:
	var rank: int = 1
	for entry in entries:
		if int(entry.get("score", 0)) > int(score):
			rank += 1
	return rank


static func top(limit: int) -> Array:
	load_data()
	return entries.slice(0, mini(limit, entries.size()))


static func count() -> int:
	load_data()
	return entries.size()


static func best_score() -> int:
	load_data()
	if entries.is_empty():
		return 0
	return int(entries[0].get("score", 0))


# --- Validation -------------------------------------------------------------------


## A name is printable text, trimmed, capped, with no control characters. It is
## displayed on the board, so it may not carry anything that would break a row.
static func _clean_name(value: String) -> String:
	var kept: String = ""
	for character in value.strip_edges():
		if kept.length() >= NAME_MAX:
			break
		if character.unicode_at(0) < 32:
			continue
		kept += character
	return kept.strip_edges()


static func _clean_contact(value: String) -> String:
	var kept: String = value.strip_edges()
	if kept.length() > CONTACT_MAX:
		kept = kept.substr(0, CONTACT_MAX)
	return kept


## Either an email address or a phone number. This is a sanity gate, not a proof:
## it refuses the obviously empty and the obviously malformed, and it never
## blocks a real address for a reason it cannot explain to the player.
static func is_valid_contact(value: String) -> bool:
	if value == "":
		return false
	if value.contains("@"):
		var parts: PackedStringArray = value.split("@")
		if parts.size() != 2:
			return false
		var domain: String = parts[1]
		return not parts[0].is_empty() and domain.contains(".") and not domain.begins_with(".")
	var digits: int = 0
	for character in value:
		var code: int = character.unicode_at(0)
		if code >= 48 and code <= 57:
			digits += 1
		elif character not in ["+", "-", " ", "(", ")", "."]:
			return false
	return digits >= PHONE_DIGITS_MIN


## True when the contact looks like an email rather than a phone number, so a
## label can say "REPLY BY EMAIL" instead of guessing.
static func is_email(value: String) -> bool:
	return value.contains("@")


# --- Internals --------------------------------------------------------------------


## An entry as read back from disk, or empty when it cannot be shown. The board
## is a record of real submissions, so a row missing its name or its score is a
## corrupted row and is dropped rather than displayed as blanks.
static func _clean(raw: Dictionary) -> Dictionary:
	var kept_name: String = _clean_name(String(raw.get("name", "")))
	if kept_name.length() < 2:
		return {}
	var score: Variant = raw.get("score", -1)
	if not (score is float or score is int):
		return {}
	return {
		"id": String(raw.get("id", "%d" % Time.get_ticks_usec())),
		"name": kept_name,
		"contact": _clean_contact(String(raw.get("contact", ""))),
		"score": maxi(int(score), 0),
		"at": String(raw.get("at", "")),
		"callsign": String(raw.get("callsign", "")),
	}


static func _sort() -> void:
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_score: int = int(a.get("score", 0))
		var b_score: int = int(b.get("score", 0))
		if a_score == b_score:
			return String(a.get("at", "")) < String(b.get("at", ""))
		return a_score > b_score)
