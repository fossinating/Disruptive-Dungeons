extends RefCounted
## Part and color data for the vertical-slice demo (see docs/rework-proposal.md).

const COLORS: Array[String] = ["blue", "green", "red", "purple"]

# Same four colors as the jam's Objects/DisruptionField.gd.
const FIELD_COLOR := {
	"blue": Color(99.0 / 255, 155.0 / 255, 1.0),
	"green": Color(106.0 / 255, 190.0 / 255, 48.0 / 255),
	"red": Color(172.0 / 255, 50.0 / 255, 50.0 / 255),
	"purple": Color(125.0 / 255, 51.0 / 255, 154.0 / 255),
}

const COLOR_NAME := {"blue": "Blue", "green": "Green", "red": "Red", "purple": "Purple"}

const SLOT_KEYS: Array[String] = ["Q", "E", "R", "F"]

# Each other active part that shares a color adds this much strength.
const SYNERGY_PER_PART := 0.15
# Penalty on the other parts of the color a Faraday Cage protects.
const SHIELD_PENALTY := 0.7

const PARTS := {
	"ram": {
		"name": "Ram Plating", "colors": ["blue"], "kind": "Weapon", "active": false, "cd": 0.0,
		"desc": "Hit bots while moving faster than your top speed (Boost, Heat Vent, long falls) to deal damage based on speed. No contact damage while that fast.",
	},
	"boost": {
		"name": "Boost", "colors": ["blue"], "kind": "Utility", "active": true, "cd": 1.6,
		"desc": "Dash toward the cursor.",
	},
	"slam": {
		"name": "Ground Slam", "colors": ["green"], "kind": "Weapon", "active": true, "cd": 0.8,
		"desc": "In the air: slam straight down. The shockwave hits harder the farther you fell.",
	},
	"djump": {
		"name": "Double Jump", "colors": ["green"], "kind": "Utility", "active": false, "cd": 0.0,
		"desc": "Jump once more in the air.",
	},
	"shotgun": {
		"name": "Shotgun", "colors": ["red"], "kind": "Weapon", "active": true, "cd": 0.45,
		"desc": "Six-pellet blast with recoil. Builds a lot of heat.",
	},
	"vent": {
		"name": "Heat Vent", "colors": ["red"], "kind": "Utility", "active": true, "cd": 2.2,
		"desc": "Blast flame at the cursor and get thrown the other way. Dumps all your heat.",
	},
	"drone": {
		"name": "Attack Drone", "colors": ["purple"], "kind": "Weapon", "active": false, "cd": 0.0,
		"desc": "Orbits you and shoots the nearest bot it can see.",
	},
	"hack": {
		"name": "Hack", "colors": ["purple"], "kind": "Utility", "active": true, "cd": 6.0,
		"desc": "Flip the nearest field to the next color.",
	},
	"coil": {
		"name": "Static Coil", "colors": ["blue", "purple"], "kind": "Weapon", "active": false, "cd": 0.0,
		"desc": "Roll at top speed to charge. Your next basic shot chains lightning between bots.",
	},
	"fins": {
		"name": "Thruster Fins", "colors": ["green", "red"], "kind": "Utility", "active": false, "cd": 0.0,
		"desc": "Hold jump while falling to hover. Builds heat.",
	},
	"siphon": {
		"name": "Field Siphon", "colors": ["green"], "kind": "Overload", "active": false, "cd": 0.0,
		"overload": true,
		"desc": "Only works inside a green field. There, your basic shot fires twice as fast and pierces.",
	},
	"cage": {
		"name": "Faraday Cage", "colors": [], "kind": "Shield", "active": false, "cd": 0.0,
		"shield": true,
		"desc": "Your chosen color ignores fields, but that color's other parts always run at 70%.",
	},
}


static func ui_color(color: String) -> Color:
	return FIELD_COLOR[color].lightened(0.3)


static func part_color(id: String) -> Color:
	var colors: Array = PARTS[id].colors
	return ui_color(colors[0]) if colors.size() > 0 else Color(0.8, 0.78, 0.74)


static func color_line(id: String) -> String:
	var p: Dictionary = PARTS[id]
	var names := []
	for c in p.colors:
		names.append(COLOR_NAME[c])
	var color_text := " + ".join(names) if names.size() > 0 else "No color"
	return "%s · %s" % [color_text, p.kind]
