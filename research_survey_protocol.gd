## Survey copy and option lists (IRB placeholders for age/gender — replace per protocol).
class_name ResearchSurveyProtocol
extends RefCounted

const LIKERT_7 := [
	"Strongly disagree",
	"Disagree",
	"Slightly disagree",
	"Neutral",
	"Slightly agree",
	"Agree",
	"Strongly agree",
]

const A1_PLAY_FREQ := ["Daily", "Weekly", "Monthly", "Rarely"]

const AGE_BANDS := ["18–24", "25–34", "35–44", "45–54", "55–64", "65+"]

const GENDER_CHOICES := [
	"Woman",
	"Man",
	"Non-binary",
	"Prefer to self-describe",
	"Prefer not to say",
]

const D1_UPSET := ["No", "A little", "Yes"]

## Post-demo voice-acting reflection (Section B add-on).
const VA_IMPACT_CHOICES := [
	"Added to my experience",
	"Subtracted from my experience",
	"Little or no effect",
	"Not sure",
]

## Ordered keys for formal export (human-readable report).
static func survey_export_order() -> PackedStringArray:
	return PackedStringArray(
		[
			"A1",
			"A2",
			"A3",
			"A3_free",
			"B1",
			"B2",
			"B3",
			"B4",
			"B5",
			"B6",
			"B7",
			"B8",
			"B9",
			"B10",
			"B11",
			"B12",
			"VA_impact",
			"VA_desc",
			"C1",
			"C2",
			"C3",
			"C4",
			"C5",
			"D1",
			"D1b",
			"E1",
			"E2",
			"E3",
			"E4",
			"E5",
			"F_a1",
			"G1",
		]
	)


static func survey_question_title(key: String) -> String:
	match key:
		"A1":
			return "How often do you play video games?"
		"A2":
			return "Age range"
		"A3":
			return "Gender (optional)"
		"A3_free":
			return "Gender — self-describe (optional)"
		"B1":
			return "Overall, the demo was enjoyable."
		"B2":
			return "I understood what to do most of the time."
		"B3":
			return "The pacing felt right for the time I spent."
		"B4":
			return "The challenge felt appropriate (not too easy or too hard)."
		"B5":
			return "I was interested in the characters and story."
		"B6":
			return "Visuals and sound fit the mood of the game."
		"B7":
			return "Controls and interface (outside the breathing exercises) felt clear and responsive."
		"B8":
			return "The demo ran smoothly for me."
		"B9":
			return "The controls for the breathing minigames were easy to use."
		"B10":
			return "The breathing minigames made it clear what I should do at each step."
		"B11":
			return "The optional tools in the Sampler (besides the breathing exercises) felt worth trying."
		"B12":
			return "The optional Sampler tools were easy to understand."
		"VA_impact":
			return "Voice acting — did it add to or subtract from your experience?"
		"VA_desc":
			return "Voice acting — please describe (optional)"
		"C1":
			return "While playing, I felt calm."
		"C2":
			return "While playing, I felt stressed or tense."
		"C3":
			return "I was absorbed in the game (lost track of time)."
		"C4":
			return "The demo produced meaningful emotional reactions for me (pleasant or unpleasant)."
		"C5":
			return "Playing helped take my mind off other worries, at least for a while."
		"D1":
			return "At any point, did the demo feel upsetting or overwhelming in a way you did not want?"
		"D1b":
			return "Follow-up — say more (optional)"
		"E1":
			return "What was the best moment in the demo for you?"
		"E2":
			return "What was most confusing, frustrating, or broken?"
		"E3":
			return "If you could change one thing for the next build, what would it be?"
		"E4":
			return "Did anything in the story or gameplay feel personally resonant?"
		"E5":
			return "Is there anything we should know to make this experience safer or more comfortable for players?"
		"F_a1":
			return "When I was helping Marzi handle situations in the demo, I felt connected to her."
		"G1":
			return "How likely are you to play more of this game when it’s available? (0–10)"
		_:
			return ""


static func survey_key_is_likert(k: String) -> bool:
	if k == "F_a1":
		return true
	if k in ["C1", "C2", "C3", "C4", "C5"]:
		return true
	if k.begins_with("B"):
		var rest := k.substr(1)
		if rest.is_valid_int():
			var n := int(rest)
			return n >= 1 and n <= 12
	return false


static func likert_label(value: Variant) -> String:
	var i: int = 0
	match typeof(value):
		TYPE_INT:
			i = value
		TYPE_FLOAT:
			i = int(value)
		_:
			var s := str(value).strip_edges()
			if s.is_valid_int():
				i = int(s)
			elif s.is_valid_float():
				i = int(float(s))
			else:
				return str(value)
	if i < 1 or i > LIKERT_7.size():
		return str(value)
	return "%d — %s" % [i, LIKERT_7[i - 1]]


## Plain-text formal survey block for copy/export (no BBCode).
static func format_survey_formal_text(surv: Dictionary) -> String:
	if surv.is_empty():
		return ""
	var lines: PackedStringArray = PackedStringArray()
	lines.append("POST-DEMO SURVEY RESPONSE")
	lines.append("=".repeat(48))
	for k in survey_export_order():
		if not surv.has(k):
			continue
		var title: String = survey_question_title(k)
		if title.is_empty():
			title = k
		var raw: Variant = surv[k]
		var answer: String = str(raw).strip_edges()
		if answer.is_empty():
			answer = "(no answer)"
		if survey_key_is_likert(k):
			answer = likert_label(raw)
		lines.append("")
		lines.append("[%s] %s" % [k, title])
		lines.append("Answer: %s" % answer)
	return "\n".join(lines)
