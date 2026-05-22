# MycologyData.gd
# Attach as an Autoload (Project > Project Settings > Autoload)
# Name it: MycologyData
extends Node

## All mushroom definitions for the Cavern Mycology puzzle.
## Each mushroom has a visual_name, subtitle, image path, and smell outcomes.

const MUSHROOMS: Array[Dictionary] = [
	{
		"id": "glowing_blue",
		"visual_name": "The Glowing Blue Mushroom",
		"subtitle": "(Bioluminescent)",
		"texture": "res://assets/mushrooms/glowing_blue.png",  # ← update path to your asset
		"smells": [
			{
				"cue": "Sweet Fruit",
				"action": "EAT",
				"species": "Lunar Cap",
				"effect": "Restores health.",
				"toxic": false,
			},
			{
				"cue": "Burnt Hair",
				"action": "LEAVE IT",
				"species": "Static Spore",
				"effect": "Will cause blindness.",
				"toxic": true,
			},
		],
	},
	{
		"id": "red_spotted",
		"visual_name": "The Red Spotted Mushroom",
		"subtitle": "(Crimson Cap)",
		"texture": "res://assets/mushrooms/red_spotted.png",  # ← update path
		"smells": [
			{
				"cue": "Fresh Dirt / Earthy",
				"action": "EAT",
				"species": "Blood Truffle",
				"effect": "Grants a speed boost.",
				"toxic": false,
			},
			{
				"cue": "Rotten Eggs / Sulfur",
				"action": "LEAVE IT",
				"species": "Magma Cap",
				"effect": "Highly toxic/poisonous.",
				"toxic": true,
			},
		],
	},
	{
		"id": "pale_fleshy",
		"visual_name": "The Pale Fleshy Mushroom",
		"subtitle": "(Ghost Shroom)",
		"texture": "res://assets/mushrooms/pale_fleshy.png",  # ← update path
		"smells": [
			{
				"cue": "Sweet Fruit",
				"action": "LEAVE IT",
				"species": "Corpse Trap",
				"effect": "The sweet smell is a lure. Causes instant paralysis.",
				"toxic": true,
			},
			{
				"cue": "Rotten Eggs / Sulfur",
				"action": "EAT",
				"species": "Sulfur Sponge",
				"effect": "Tastes awful but cures all negative status effects.",
				"toxic": false,
			},
		],
	},
]

## Returns mushroom data by id
func get_mushroom(id: String) -> Dictionary:
	for m in MUSHROOMS:
		if m["id"] == id:
			return m
	return {}
