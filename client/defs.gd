class_name Defs
## Item and recipe definitions. Mirrors server/src/protocol.ts.

const ITEM_NAMES := {
	"apple": "Apple",
	"wood": "Wood",
	"stone": "Stone",
	"fish": "Fish",
	"fishing_rod": "Fishing rod",
	"fruit_basket": "Fruit basket",
	"campfire": "Campfire",
}

const RECIPES := {
	"fishing_rod": {"wood": 3},
	"fruit_basket": {"apple": 3, "wood": 1},
	"campfire": {"wood": 2, "stone": 3},
}

const INTERACT_RANGE := 3.5  # server allows 4
const SHORE_DISTANCE := 37.0  # island radius 40 minus 3
