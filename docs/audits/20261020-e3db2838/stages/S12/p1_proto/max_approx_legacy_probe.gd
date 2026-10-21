extends "res://max_approx_probe.gd"

func _initialize() -> void:
	var kind: String = OS.get_environment("S12_LEGACY_KIND")
	if kind == "old_exponent":
		requested_wallet_encoded = {"m":1.0,"e":1000000000.0}
	elif kind == "old_exponent_max":
		requested_wallet_encoded = {"m":1.0,"e":1e308}
	elif kind == "old_v1_decimal":
		requested_wallet_encoded = {"v":1,"i":"9".repeat(5000)}
	elif kind == "old_float_half":
		requested_wallet_encoded = 0.5
	elif kind == "old_int_130":
		requested_wallet_encoded = 130
	else:
		requested_wallet_encoded = {"invalid":kind}
	super._initialize()
