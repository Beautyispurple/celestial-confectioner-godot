class_name SamplerSkillsRegistry
extends RefCounted
## Shared slot order and labels for Sampler + Confectioner's Case.

const SLOT_BREATH_TEMPERING := 0
const SLOT_BREATH_AERATION := 1
const SLOT_SENSORY_SIFTING := 2
const SLOT_COLD_SHEEN := 3
const SLOT_DRAGEE_DECISIONS := 4
const SLOT_JOURNAL := 5

## `dialog` = Dialogic variable name, or "_dragee_sampler_" for CelestialDrageeDisposal.is_dragee_sampler_unlocked().
## `gate`: "always" if unlocked ⇒ usable in Sampler; "panic_ge_2" = Breath Aeration needs Heat ≥ 2 in play.
static func skill_slots() -> Array[Dictionary]:
	return [
		{
			"dialog": "breath_tempering_unlocked",
			"label": "Breath\nTempering",
			"gate": "always",
			"tooltip": "Slow box breathing. Completing cycles in the Sampler lowers Marzi's Heat.",
		},
		{
			"dialog": "breath_aeration_unlocked",
			"label": "Breath\nAeration",
			"gate": "panic_ge_2",
			"tooltip": "Steady inhale/exhale (no holds). Success lowers Heat a bit and restores Social Battery. Needs Heat ≥ 2 during play.",
		},
		{
			"dialog": "sensory_sifting_unlocked",
			"label": "Sensory\nSifting",
			"gate": "always",
			"tooltip": "Five-senses grounding. Finishing clears Heat and adds a short Heat shield.",
		},
		{
			"dialog": "cold_sheen_unlocked",
			"label": "Cold\nSheen",
			"gate": "always",
			"tooltip": "Cold-water reset. Usually lowers Heat; relief is smaller if Heat is already maxed.",
		},
		{
			"dialog": "_dragee_sampler_",
			"label": "Dragee\nDecisions",
			"gate": "always",
			"tooltip": "Guided exercise to set down a heavy thought (disposal sequence).",
		},
		{
			"dialog": "journal_unlocked",
			"label": "Journal",
			"gate": "always",
			"tooltip": "Private writing space for Marzi (and prompts).",
		},
	]
