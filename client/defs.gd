class_name Defs
## Item and recipe definitions. Mirrors server/src/protocol.ts.

const ITEM_NAMES := {
	"apple": "Apfel",
	"wood": "Holz",
	"stone": "Stein",
	"fish": "Fisch",
	"fishing_rod": "Angel",
	"fruit_basket": "Obstkorb",
	"campfire": "Lagerfeuer",
	"chair": "Stuhl",
	"table": "Tisch",
	"lamp": "Lampe",
	"bed": "Bett",
	"flower_pot": "Blumentopf",
	"shovel": "Schaufel",
	"watering_can": "Gießkanne",
	"fence": "Zaun",
	"potted_tulip": "Tulpe im Topf",
	"potted_sunflower": "Sonnenblume im Topf",
	"carrot_seeds": "Karottensamen",
	"tomato_seeds": "Tomatensamen",
	"pumpkin_seeds": "Kürbissamen",
	"tulip_seeds": "Tulpenzwiebeln",
	"sunflower_seeds": "Sonnenblumenkerne",
	"carrot": "Karotte",
	"tomato": "Tomate",
	"pumpkin": "Kürbis",
	"tulip": "Tulpe",
	"sunflower": "Sonnenblume",
}

const COINS := "coins"

const EMOTE_LABELS := {"wave": "Winken", "happy": "Freuen", "sad": "Traurig", "dance": "Tanzen"}
const EMOTE_SPEECH := {"wave": "*winkt*", "happy": "*freut sich*", "sad": "*ist traurig*", "dance": "*tanzt*"}

## Mirrors SELL_PRICES and SHOP_CATALOG in server/src/protocol.ts.
const SELL_PRICES := {
	"apple": 10, "wood": 5, "stone": 8, "fish": 40, "fishing_rod": 20, "fruit_basket": 50,
	"campfire": 30, "chair": 15, "table": 30, "lamp": 25, "bed": 45, "flower_pot": 25,
	"shovel": 15, "watering_can": 20, "fence": 5, "potted_tulip": 45, "potted_sunflower": 50,
	"carrot_seeds": 5, "tomato_seeds": 8, "pumpkin_seeds": 10, "tulip_seeds": 4, "sunflower_seeds": 5,
	"carrot": 25, "tomato": 20, "pumpkin": 90, "tulip": 15, "sunflower": 20,
}
const SHOP_CATALOG := {
	"fishing_rod": 60, "chair": 60, "flower_pot": 80, "lamp": 120, "table": 140, "bed": 250,
	"shovel": 50, "watering_can": 80, "carrot_seeds": 20, "tomato_seeds": 30, "pumpkin_seeds": 40,
	"tulip_seeds": 15, "sunflower_seeds": 20,
}
const SHOP_POS := Vector3(0, 0, -5)
const SHOP_RANGE := 4.5  # server allows 5
const SHOP_CLEARANCE := 3.0
const SHOP_COLLISION_CENTER := Vector3(0, 0, -5.2)
const SHOP_COLLISION_RADIUS := 1.7
const SHOP_OPEN_HOUR := 8
const SHOP_CLOSE_HOUR := 22

const PLACEABLE := [
	"fruit_basket", "campfire", "chair", "table", "lamp", "bed", "flower_pot",
	"fence", "potted_tulip", "potted_sunflower",
]

const RECIPES := {
	"fishing_rod": {"wood": 3},
	"fruit_basket": {"apple": 3, "wood": 1},
	"campfire": {"wood": 2, "stone": 3},
	"chair": {"wood": 2},
	"table": {"wood": 4},
	"lamp": {"wood": 1, "stone": 1},
	"bed": {"wood": 6},
	"flower_pot": {"stone": 2},
	"shovel": {"wood": 2, "stone": 1},
	"watering_can": {"stone": 3, "wood": 1},
	"fence": {"wood": 1},
	"potted_tulip": {"flower_pot": 1, "tulip": 1},
	"potted_sunflower": {"flower_pot": 1, "sunflower": 1},
}

const INTERACT_RANGE := 3.5  # server allows 4
const SHORE_DISTANCE := 37.0  # island radius 40 minus 3

# Houses and rooms (mirrors server/src/protocol.ts)
const ISLAND_RADIUS := 40.0
const MAX_HOUSES := 12
const HOUSE_RING_RADIUS := 28.0
const HOUSE_COLLISION_RADIUS := 3.2
const ROOM_BASE_X := 500.0
const ROOM_SPACING := 40.0
const ROOM_HALF := 6.0
const ROOM_PLACE_HALF := 5.0
const ROOM_REGION_X := 480.0
const PLACE_RANGE := 5.5  # server allows 6


static func slot_angle(slot: int) -> float:
	return slot * TAU / MAX_HOUSES


static func house_center(slot: int) -> Vector3:
	var a := slot_angle(slot)
	return Vector3(cos(a) * HOUSE_RING_RADIUS, 0, sin(a) * HOUSE_RING_RADIUS)


## Spot in front of the door, toward the island center.
static func door_outside(slot: int) -> Vector3:
	var a := slot_angle(slot)
	return Vector3(cos(a) * (HOUSE_RING_RADIUS - 3.5), 0, sin(a) * (HOUSE_RING_RADIUS - 3.5))


static func room_center(slot: int) -> Vector3:
	return Vector3(ROOM_BASE_X + slot * ROOM_SPACING, 0, 0)


static func room_slot_at(x: float) -> int:
	return roundi((x - ROOM_BASE_X) / ROOM_SPACING)


static func room_exit_spot(slot: int) -> Vector3:
	return room_center(slot) + Vector3(0, 0, 5.5)


# Quirky props on the meadow: [kind, position, footprint radius, scale]. Mirrors PROPS in server/src/protocol.ts.
const PROPS := [
	["bathtub", Vector2(9.2, -15), 2.2, 1.2],
	["signpost", Vector2(11.3, -2.6), 1.2, 1.5],
	["scarecrow", Vector2(-12.5, -15), 1.6, 1.3],
	["laundry", Vector2(-18.8, -0.9), 2.6, 1.1],
	["boot_house", Vector2(-7.9, 32.3), 2.4, 1.25],
	["windmill", Vector2(19.7, 3.9), 1.2, 1.5],
	["ladder", Vector2(32.9, 7.9), 1.2, 1.2],
	["stump_house", Vector2(9.8, 16.4), 1.8, 1.4],
	["birdhouse", Vector2(1.3, 8.6), 1.0, 1.5],
	["crates", Vector2(-2.9, 14.2), 2.0, 1.25],
	["mushroom_house", Vector2(-16.9, 17.2), 2.2, 1.4],
	["wheelbarrow", Vector2(22, -4.5), 1.8, 1.4],
]


# Landscaping (mirrors server/src/protocol.ts). "grass" clears a cell.
const GROUND_TOOLS := [
	["path", "Steinweg", "1 Stein"],
	["gravel", "Kiesweg", "kostenlos"],
	["soil", "Beet", "Schaufel"],
	["pond", "Teich", "Schaufel"],
	["grass", "Gras", "Schaufel"],
]
const GROUND_NEEDS_SHOVEL := ["soil", "pond", "grass"]

# Plants: seed item, watered days until ripe, harvest item.
const PLANTS := {
	"carrot": {"seed": "carrot_seeds", "stages": 3, "yield": "carrot"},
	"tomato": {"seed": "tomato_seeds", "stages": 3, "yield": "tomato"},
	"pumpkin": {"seed": "pumpkin_seeds", "stages": 4, "yield": "pumpkin"},
	"tulip": {"seed": "tulip_seeds", "stages": 2, "yield": "tulip"},
	"sunflower": {"seed": "sunflower_seeds", "stages": 3, "yield": "sunflower"},
}
const SEEDS := ["carrot_seeds", "tomato_seeds", "pumpkin_seeds", "tulip_seeds", "sunflower_seeds"]
