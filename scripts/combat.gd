class_name CombatModel
extends RefCounted

## Pure, deterministic turn resolution. Animation never decides battle outcomes.
const STATS = {
	"Goblin": {"hp": 60, "damage": 20, "attacks": 3, "regen": 0, "block": 0, "reflect": 0},
	"Troll": {"hp": 100, "damage": 25, "attacks": 1, "regen": 5, "block": 0, "reflect": 0},
	"Orc": {"hp": 75, "damage": 10, "attacks": 1, "regen": 0, "block": 10, "reflect": 10}
}
const TYPES = ["Goblin", "Troll", "Orc"]
const SCENARIOS = [
	{"name": "01  Goblin vs Troll", "a": ["Goblin"], "b": ["Troll"]},
	{"name": "02  Goblin vs two Trolls", "a": ["Goblin"], "b": ["Troll", "Troll"]},
	{"name": "03  Troll vs Orc", "a": ["Troll"], "b": ["Orc"]},
	{"name": "04  Troll vs two Orcs", "a": ["Troll"], "b": ["Orc", "Orc"]},
	{"name": "05  Orc vs Goblin", "a": ["Orc"], "b": ["Goblin"]},
	{"name": "06  Orc vs two Goblins", "a": ["Orc"], "b": ["Goblin", "Goblin"]},
	{"name": "07  Random four vs four", "a": [], "b": []}
]

var teams: Array = [[], []]
var units: Dictionary = {}
var turn: int = 0
var finished: bool = false
var winner: int = -2 # -2 ongoing; -1 draw; 0 Alpha; 1 Beta.

func setup(left: Array, right: Array) -> void:
	teams = [[], []]
	units.clear()
	turn = 0
	finished = false
	winner = -2
	var id: int = 0
	for side in range(2):
		var types: Array = left if side == 0 else right
		for type in types:
			var stats: Dictionary = STATS[type]
			units[id] = {"id": id, "side": side, "type": type, "hp": stats.hp, "max_hp": stats.hp}
			teams[side].append(id)
			id += 1
	_check_winner()

func _check_winner() -> void:
	if teams[0].is_empty() or teams[1].is_empty():
		finished = true
		winner = -1 if teams[0].is_empty() and teams[1].is_empty() else (1 if teams[0].is_empty() else 0)

func step() -> Array:
	if finished:
		return []
	turn += 1
	var events: Array = [{"kind": "turn", "turn": turn}]
	var leads: Array = [teams[0][0], teams[1][0]]
	var damage: Dictionary = {leads[0]: 0, leads[1]: 0}
	var healing: Dictionary = {leads[0]: 0, leads[1]: 0}
	# Both leads finish all attacks, including attacks after lethal-looking hits.
	for side in range(2):
		var attacker: Dictionary = units[leads[side]]
		var target: Dictionary = units[leads[1 - side]]
		var attack_stats: Dictionary = STATS[attacker.type]
		var defense: Dictionary = STATS[target.type]
		for hit in range(attack_stats.attacks):
			var blocked: int = mini(attack_stats.damage, defense.block)
			var dealt: int = attack_stats.damage - blocked
			damage[target.id] += dealt
			damage[attacker.id] += defense.reflect
			events.append({"kind": "attack", "actor": attacker.id, "target": target.id,
				"raw": attack_stats.damage, "blocked": blocked, "damage": dealt,
				"reflected": defense.reflect, "hit": hit + 1, "hits": attack_stats.attacks,
				"target_hp": maxi(0, target.hp - damage[target.id]),
				"actor_hp": maxi(0, attacker.hp - damage[attacker.id])})
	# Regeneration offsets the complete damage tally, preserving overkill.
	for id in leads:
		var unit: Dictionary = units[id]
		var regen: int = STATS[unit.type].regen
		if regen > 0:
			var gained: int = mini(regen, unit.max_hp - unit.hp + damage[id])
			healing[id] = gained
			events.append({"kind": "regen", "actor": id, "amount": gained,
				"hp": clampi(unit.hp - damage[id] + gained, 0, unit.max_hp)})
	for id in leads:
		units[id].hp = clampi(units[id].hp - damage[id] + healing[id], 0, units[id].max_hp)
	# Remove both deaths only after all abilities; replacements act next turn.
	for side in range(2):
		var id: int = leads[side]
		if units[id].hp == 0:
			events.append({"kind": "death", "actor": id})
			teams[side].pop_front()
	_check_winner()
	if finished:
		events.append({"kind": "end", "winner": winner})
	return events
