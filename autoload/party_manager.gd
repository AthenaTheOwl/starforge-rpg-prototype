extends Node
## PartyManager — Manages party roster, active party, character stats.
##
## Characters are loaded from JSON data files in data/characters/.
## Active party is max 4 members for combat; full roster available outside combat.

# All recruited characters keyed by character_id
var roster: Dictionary = {}
# Active party (up to 4 character_ids for combat)
var active_party: Array[String] = []
# Max active party size
const MAX_ACTIVE := 4
# Loadouts keyed by character_id
var _loadouts: Dictionary = {}

signal party_changed()
signal character_joined(character_id: String)
signal character_stat_changed(character_id: String, stat: String)
signal xp_gained(character_id: String, amount: int)
signal level_up(character_id: String, new_level: int)


func _ready() -> void:
	pass


## Load a character definition from a JSON data file and add to roster.
func recruit_character(character_id: String) -> void:
	if character_id in roster:
		return
	var data := _load_character_data(character_id)
	if data.is_empty():
		push_warning("Character data not found: %s" % character_id)
		return
	roster[character_id] = data
	if active_party.size() < MAX_ACTIVE:
		active_party.append(character_id)
	character_joined.emit(character_id)
	party_changed.emit()


func remove_from_active(character_id: String) -> void:
	active_party.erase(character_id)
	party_changed.emit()


func add_to_active(character_id: String) -> void:
	if character_id in roster and character_id not in active_party:
		if active_party.size() < MAX_ACTIVE:
			active_party.append(character_id)
			party_changed.emit()


func get_character(character_id: String) -> Dictionary:
	return roster.get(character_id, {})


## Return the loadout for a character, creating a blank one if absent.
func get_loadout(character_id: String) -> Loadout:
	if character_id not in _loadouts:
		_loadouts[character_id] = Loadout.new()
	return _loadouts[character_id]


## Replace a character's entire loadout.
func set_loadout(character_id: String, loadout: Loadout) -> void:
	_loadouts[character_id] = loadout
	party_changed.emit()


func get_active_characters() -> Array[Dictionary]:
	var chars: Array[Dictionary] = []
	for id in active_party:
		if id in roster:
			chars.append(roster[id])
	return chars


## Modify a character stat (hp, heat, charges, etc.)
func modify_stat(character_id: String, stat: String, amount: int) -> void:
	if character_id not in roster:
		return
	var c: Dictionary = roster[character_id]
	if stat in c:
		c[stat] = clampi(c[stat] + amount, 0, c.get(stat + "_max", 999))
		character_stat_changed.emit(character_id, stat)


func heal_party() -> void:
	for id in roster:
		var c: Dictionary = roster[id]
		c["hp"] = c.get("hp_max", 100)
		c["heat"] = 0
		# Restore charges
		if "abilities" in c:
			for ability in c["abilities"]:
				ability["charges"] = ability.get("charges_max", 1)


# --- Leveling System ---

## Award XP to all party members (active get full, reserve get 50%).
func award_xp(amount: int) -> void:
	# Active party gets full XP
	for character_id in active_party:
		if character_id in roster:
			award_xp_to(character_id, amount)

	# Reserve characters get 50% XP
	for character_id in roster:
		if character_id not in active_party:
			award_xp_to(character_id, amount / 2)


## Award XP to a specific character.
func award_xp_to(character_id: String, amount: int) -> void:
	if character_id not in roster:
		return

	var c: Dictionary = roster[character_id]
	c["xp"] = c.get("xp", 0) + amount
	xp_gained.emit(character_id, amount)

	# Check for level up
	while check_level_up(character_id):
		apply_level_up(character_id)


## Check if character has enough XP to level up.
func check_level_up(character_id: String) -> bool:
	if character_id not in roster:
		return false

	var c: Dictionary = roster[character_id]
	var current_level: int = c.get("level", 1)
	var current_xp: int = c.get("xp", 0)
	var threshold: int = get_xp_for_next_level(current_level)

	return current_xp >= threshold and current_level < 5


## Apply automatic level-up rewards and increment level.
func apply_level_up(character_id: String) -> void:
	if character_id not in roster:
		return

	var c: Dictionary = roster[character_id]
	var current_level: int = c.get("level", 1)
	var xp_threshold: int = get_xp_for_next_level(current_level)

	# Deduct XP threshold
	c["xp"] = c.get("xp", 0) - xp_threshold

	# Increment level
	c["level"] = current_level + 1

	# Apply automatic rewards
	c["hp_max"] = c.get("hp_max", 100) + 5
	c["heat_capacity"] = c.get("heat_capacity", 5) + 2

	# Grant 1 stat point for manual assignment
	c["stat_points"] = c.get("stat_points", 0) + 1

	level_up.emit(character_id, c["level"])


## Assign a stat point to Attack, Defense, or Lattice.
## Returns true if successful, false if no points available.
func assign_stat_point(character_id: String, stat: String) -> bool:
	if character_id not in roster:
		return false

	var c: Dictionary = roster[character_id]
	if c.get("stat_points", 0) <= 0:
		return false

	match stat:
		"Attack":
			c["attack_bonus"] = c.get("attack_bonus", 0) + 1
			# +5% ability damage (tracked by bonus counter)
		"Defense":
			c["armor"] = c.get("armor", 0) + 3
			c["shields"] = c.get("shields", 0) + 2
			c["wards"] = c.get("wards", 0) + 1
			c["defense_bonus"] = c.get("defense_bonus", 0) + 1
		"Lattice":
			c["lattice_bonus"] = c.get("lattice_bonus", 0) + 1
			# +5% resonance damage, +2% crit chance (tracked by bonus counter)
		_:
			return false

	c["stat_points"] = c["stat_points"] - 1
	character_stat_changed.emit(character_id, stat)
	return true


## Get XP threshold for reaching the next level.
func get_xp_for_next_level(level: int) -> int:
	match level:
		1: return 300
		2: return 600
		3: return 900
		4: return 1200
		_: return 9999  # Max level reached


## Get progress toward next level as a float 0.0-1.0.
func get_level_progress(character_id: String) -> float:
	if character_id not in roster:
		return 0.0

	var c: Dictionary = roster[character_id]
	var current_level: int = c.get("level", 1)
	var current_xp: int = c.get("xp", 0)
	var threshold: int = get_xp_for_next_level(current_level)

	if threshold <= 0:
		return 0.0

	return clampf(float(current_xp) / float(threshold), 0.0, 1.0)


# --- Serialization ---

func serialize() -> Dictionary:
	var loadout_data: Dictionary = {}
	for cid in _loadouts:
		var lo: Loadout = _loadouts[cid]
		var slots: Array[String] = []
		for ab in [lo.core_1, lo.core_2, lo.utility_1, lo.utility_2, lo.reaction, lo.keystone]:
			slots.append(ab.id if ab != null else "")
		loadout_data[cid] = slots
	return {
		"roster": roster.duplicate(true),
		"active_party": active_party.duplicate(),
		"loadouts": loadout_data,
	}


func deserialize(data: Dictionary) -> void:
	roster = data.get("roster", {})
	var ap = data.get("active_party", [])
	active_party.clear()
	for id in ap:
		active_party.append(str(id))
	# Restore loadouts from saved spell ids
	_loadouts.clear()
	var saved_loadouts: Dictionary = data.get("loadouts", {})
	for cid in saved_loadouts:
		var slots: Array = saved_loadouts[cid]
		var lo := Loadout.new()
		if slots.size() >= 6:
			lo.core_1 = Spellbook.get_spell(slots[0]) if slots[0] != "" else null
			lo.core_2 = Spellbook.get_spell(slots[1]) if slots[1] != "" else null
			lo.utility_1 = Spellbook.get_spell(slots[2]) if slots[2] != "" else null
			lo.utility_2 = Spellbook.get_spell(slots[3]) if slots[3] != "" else null
			lo.reaction = Spellbook.get_spell(slots[4]) if slots[4] != "" else null
			lo.keystone = Spellbook.get_spell(slots[5]) if slots[5] != "" else null
		_loadouts[cid] = lo
	party_changed.emit()


# --- Data Loading ---

func _load_character_data(character_id: String) -> Dictionary:
	var path := "res://data/characters/%s.json" % character_id
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return {}
	var data: Dictionary = json.data
	data["id"] = character_id
	# Initialize runtime stats from base stats
	data["hp"] = data.get("hp_max", 100)
	data["heat"] = 0
	# Initialize leveling stats
	data["xp"] = data.get("xp", 0)
	data["level"] = data.get("level", 1)
	data["stat_points"] = data.get("stat_points", 0)
	data["attack_bonus"] = data.get("attack_bonus", 0)
	data["defense_bonus"] = data.get("defense_bonus", 0)
	data["lattice_bonus"] = data.get("lattice_bonus", 0)
	return data
