extends Node

var _inited: bool = false


func init_if_allowed() -> void:
	if _inited:
		return
	if not ReleaseMode.IS_RESEARCH_RELEASE:
		return
	if not ResearchConsentState.research_metrics_opt_in:
		return
	_inited = true
	if OS.is_debug_build():
		print("[ResearchTelemetry] init_if_allowed (stub)")


func shutdown() -> void:
	if not _inited:
		return
	_inited = false
