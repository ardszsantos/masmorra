extends Resource
## Exit reward offer. Values and the effect scene are stored in .tres resources.

enum Kind { UPGRADE, HEALTH, STAMINA }

@export var reward_id: StringName
@export var display_name: String
@export_enum("common", "space", "normal", "medieval", "polygons") var world: String = "common"
@export var kind: Kind = Kind.UPGRADE
@export var icon: Texture2D
@export var color := Color.WHITE
@export var upgrade_scene: PackedScene
@export_range(1.0, 1000.0, 1.0) var amount: float = 20.0


func world_name() -> String:
	match world:
		"space": return "Espaço"
		"normal": return "Mundo normal"
		"medieval": return "Medieval"
		"polygons": return "Polígonos"
	return "Comum"
