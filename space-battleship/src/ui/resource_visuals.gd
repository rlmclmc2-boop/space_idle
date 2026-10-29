extends RefCounted
## Shared presentation identity; business IDs, amount text and prices stay native.
const ICONS := {
	"1": preload("res://assets/ui/public_shell/resource-iron.svg"),
	"2": preload("res://assets/ui/public_shell/resource-uranium.svg"),
	"chrono": preload("res://assets/ui/public_shell/resource-chrono.svg"),
	"jewel": preload("res://assets/ui/public_shell/resource-jewel.svg"),
	"degenerate_matter": preload("res://assets/ui/public_shell/resource-matter.svg")}
const COLORS := {
	"1": Color("d9b681"),
	"2": Color("8ed4bb"),
	"chrono": Color("86cddf"),
	"jewel": Color("b9abf0"),
	"degenerate_matter": Color("b9c8d5")}
const FALLBACK := Color("ceded9")

static func icon(id: String) -> Texture2D:
	return ICONS.get(id)

static func color(id: String) -> Color:
	return COLORS.get(id, FALLBACK)
