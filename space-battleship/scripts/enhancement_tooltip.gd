class_name EnhancementTooltip
extends RefCounted
## Bounded presentation for long enhancement descriptions; no copied gameplay state.
class HoverLabel extends Label:
 func _make_custom_tooltip(for_text:String)->Object:return EnhancementTooltip.content(for_text)
class HoverRichText extends RichTextLabel:
 func _make_custom_tooltip(for_text:String)->Object:return EnhancementTooltip.content(for_text)
static func content(for_text:String)->Control:
 var panel=PanelContainer.new()
 var box=StyleBoxFlat.new();box.bg_color=Color("182e3e");box.content_margin_left=12;box.content_margin_right=12;box.content_margin_top=10;box.content_margin_bottom=10
 panel.add_theme_stylebox_override("panel",box)
 var label=Label.new();label.name="TooltipLabel";label.text=for_text;label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.custom_minimum_size=Vector2(620,0)
 label.add_theme_font_override("font",preload("res://scripts/shell_presentation.gd").face(500));label.add_theme_font_size_override("font_size",20);label.add_theme_color_override("font_color",Color("f4f0df"))
 panel.add_child(label);return panel
