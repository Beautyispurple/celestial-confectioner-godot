class_name SamplerSkillsRegistry
extends RefCounted
## Shared slot order and labels for Sampler + Confectioner's Case.

const SLOT_BREATH_TEMPERING := 0
const SLOT_BREATH_AERATION := 1
const SLOT_SENSORY_SIFTING := 2
const SLOT_COLD_SHEEN := 3
const SLOT_DRAGEE_TOOLKIT := 4
const SLOT_JOURNAL := 5

## `dialog` = Dialogic variable name, or "_dragee_sampler_" for CelestialDrageeDisposal.is_dragee_sampler_unlocked().
## `gate`: "always" if unlocked ⇒ usable in Sampler; "panic_ge_2" = Breath Aeration needs Heat ≥ 2 in play.
static func skill_slots() -> Array[Dictionary]:
	return [
		{"dialog": "breath_tempering_unlocked", "label": "Breath\nTempering", "gate": "always"},
		{"dialog": "breath_aeration_unlocked", "label": "Breath\nAeration", "gate": "panic_ge_2"},
		{"dialog": "sensory_sifting_unlocked", "label": "Sensory\nSifting", "gate": "always"},
		{"dialog": "cold_sheen_unlocked", "label": "Cold\nSheen", "gate": "always"},
		{"dialog": "_dragee_sampler_", "label": "Dragee\ntoolkit", "gate": "always"},
		{"dialog": "journal_unlocked", "label": "Journal", "gate": "always"},
	]
