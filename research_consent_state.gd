extends Node

## Persists research metrics opt-in for sessions that skip the research notice (e.g. Load Game).
## New Game always shows research notice + consent pack each time; this file does not gate those.
const _PATH := "user://celestial_first_run.cfg"
const _SEC := "first_run"

var research_metrics_opt_in: bool = false


func _ready() -> void:
	_load()


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_PATH) != OK:
		research_metrics_opt_in = false
		return
	if not ReleaseMode.IS_RESEARCH_RELEASE:
		return
	research_metrics_opt_in = bool(cfg.get_value(_SEC, "research_metrics_opt_in", false))


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.load(_PATH)
	if ReleaseMode.IS_RESEARCH_RELEASE:
		cfg.set_value(_SEC, "research_metrics_opt_in", research_metrics_opt_in)
	cfg.save(_PATH)


func record_research_notice_accepted() -> void:
	research_metrics_opt_in = true
	save()
