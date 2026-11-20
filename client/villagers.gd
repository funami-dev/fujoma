class_name Villagers
extends Node3D
## Island residents. Their routines are computed from island time, so every client shows them
## in the same place without any server traffic.

const WALK_SPEED := 1.6  # m/s
const TALK_RANGE := 3.5
const NAME_COLOR := Color(1.0, 0.85, 0.4)

## schedule: [start hour, spot] sorted by hour. At each start they walk from the previous spot.
const DEFS := {
	"mara": {
		"name": "Mara", "skin": 1, "sleep": [22.0, 8.0], "wander": 0.3,
		"schedule": [[0.0, Vector2(0, -6.3)]],
	},
	"ole": {
		"name": "Ole", "skin": 0, "sleep": [22.0, 5.0], "wander": 0.7,
		"schedule": [
			[5.0, Vector2(26.2, -26.2)], [11.0, Vector2(-3, 1.5)], [14.0, Vector2(-35.7, -9.6)],
			[18.0, Vector2(3, 2)], [22.0, Vector2(-3.5, -1)],
		],
	},
	"pia": {
		"name": "Pia", "skin": 1, "tint": Color(0.75, 0.95, 0.75), "sleep": [21.0, 7.0], "wander": 0.8,
		"schedule": [
			[7.0, Vector2(-4.7, 17.4)], [10.0, Vector2(-12.7, 12.7)], [13.0, Vector2(-5.2, -19.3)],
			[16.0, Vector2(12.7, 12.7)], [19.0, Vector2(2.5, -1.5)], [21.0, Vector2(-4.7, 17.4)],
		],
	},
}

const LINES := {
	"ole": {
		"morning": ["Moin! Vor Mittag beißen die Fische am besten.", "Ich sitz hier schon seit Sonnenaufgang. Herrlich ruhig."],
		"day": ["Mara zahlt 40 Münzen für jeden Fisch, wusstest du das?", "Bastel dir eine Angel aus 3 Holz und versuch's am Ufer."],
		"evening": ["Nichts geht über einen Abend auf dem Dorfplatz.", "Langer Tag. Drei gefangen, fünf verloren."],
	},
	"pia": {
		"morning": ["Guten Morgen! Die Äpfel sind heute ganz frisch.", "Die Bäume tragen nach einer Weile neue Äpfel. Pflück sie nicht ganz leer!"],
		"day": ["Hast du dein Haus schon eingerichtet? Über „Bauen“ geht das ganz leicht.", "Mit Blumentöpfen sieht alles gleich viel netter aus.", "Hast du die kleinen Wuselwesen gesehen? Die sind so schüchtern!", "Leg dir doch ein Beet an! Mit einer Schaufel geht das ganz leicht.", "Gieß deine Pflanzen jeden Tag, dann wachsen sie über Nacht ein Stück."],
		"evening": ["Bei Sonnenuntergang ist die Insel am schönsten.", "Wenn es dunkel wird, leuchten die Lampen so gemütlich."],
	},
	"mara": {
		"morning": ["Willkommen in meinem Laden! Was darf's sein?"],
		"day": ["Willkommen in meinem Laden! Was darf's sein?", "Heute gibt's frische Ware. Schau dich ruhig um!"],
		"evening": ["Ich hab noch ein bisschen offen. Was brauchst du?"],
	},
}

var avatars: Dictionary = {}  # id -> Avatar
var _line_index: Dictionary = {}


func _ready() -> void:
	for id: String in DEFS:
		var a := Avatar.new()
		a.setup("npc_" + id, DEFS[id]["name"], DEFS[id].get("tint", Color.WHITE), DEFS[id]["skin"])
		a.set_name_color(NAME_COLOR)
		add_child(a)
		avatars[id] = a


func update(player_pos: Vector3, delta: float) -> void:
	var t := IslandClock.seconds_of_day()
	var h := t / 3600.0
	for id: String in DEFS:
		var a: Avatar = avatars[id]
		var info := _position_at(id, t)
		a.position = Vector3(info["pos"].x, 0, info["pos"].y)
		var sleeping := is_sleeping(id, h)
		a.set_status("Zzz" if sleeping else "")

		var face: Vector2 = info["dir"]
		if face == Vector2.ZERO:
			var to_player := Vector2(player_pos.x - a.position.x, player_pos.z - a.position.z)
			if to_player.length() < 4.0 and not sleeping:
				face = to_player
			elif id == "mara":
				face = Vector2(0, 1)  # look across the counter
			else:
				face = -Vector2(a.position.x, a.position.z)
		if face.length() > 0.01:
			a.rotation.y = lerp_angle(a.rotation.y, atan2(-face.x, -face.y), minf(1.0, 8.0 * delta))


func is_sleeping(id: String, h := -1.0) -> bool:
	if h < 0.0:
		h = IslandClock.hour()
	var s: Array = DEFS[id]["sleep"]
	return IslandClock.in_hours(h, s[0], s[1])


## {"pos": Vector2, "dir": Vector2 (zero when standing)} at `t` seconds of the island day.
func _position_at(id: String, t: float) -> Dictionary:
	var sched: Array = DEFS[id]["schedule"]
	var cur := sched.size() - 1
	for i in sched.size():
		if sched[i][0] * 3600.0 <= t:
			cur = i
	var prev := (cur - 1 + sched.size()) % sched.size()
	var from: Vector2 = sched[prev][1]
	var to: Vector2 = sched[cur][1]
	var elapsed := fposmod(t - sched[cur][0] * 3600.0, 86400.0)
	var dist := from.distance_to(to)
	var travelled := elapsed * WALK_SPEED
	if travelled < dist:
		return {"pos": from.lerp(to, travelled / dist), "dir": (to - from).normalized()}
	var pos := to
	if not is_sleeping(id, t / 3600.0):
		var phase := float(id.hash() % 100)
		var w: float = DEFS[id]["wander"]
		pos += Vector2(sin(t / 9.0 + phase), cos(t / 13.0 + phase)) * w
	return {"pos": pos, "dir": Vector2.ZERO}


func nearest(pos: Vector3) -> String:
	var best := ""
	var best_d := TALK_RANGE
	for id: String in avatars:
		var d := (avatars[id] as Avatar).position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = id
	return best


func display_name(id: String) -> String:
	return DEFS[id]["name"]


## Next dialogue line for `id`, depending on the time of day and the player's inventory.
func line_for(id: String, inv: Dictionary) -> String:
	var h := IslandClock.hour()
	var who: String = DEFS[id]["name"]
	if is_sleeping(id, h):
		if id == "mara":
			return "Zzz ... (%s schläft. Der Laden öffnet um %d Uhr.)" % [who, Defs.SHOP_OPEN_HOUR]
		return "Zzz ... (%s schläft tief und fest.)" % who
	if id == "ole" and int(inv.get("fish", 0)) > 0:
		return "Oh, ein Fisch! Verkauf ihn an Mara oder behalt ihn, wie du magst."
	var period := "morning" if h < 11.0 else ("day" if h < 18.0 else "evening")
	var lines: Array = LINES[id][period]
	var i := int(_line_index.get(id, 0))
	_line_index[id] = i + 1
	return lines[i % lines.size()]
