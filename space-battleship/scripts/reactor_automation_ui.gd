extends RefCounted
const A=preload("res://scripts/reactor_automation.gd")
const I=preload("res://scripts/reactor_integer.gd")
const SKIN=preload("res://scripts/dialog_presentation.gd")
var owner_ref:WeakRef
var panel:
 get:return owner_ref.get_ref()
var crew_hint:Label
var bar:HBoxContainer
var upgrade:CheckBox
var allocate:CheckBox
var presets:Array[Button]=[]
var dialog:ConfirmationDialog
var draft:Dictionary={}
var sliders:Dictionary={}
var captions:Dictionary={}
var slot_apply:Array[Button]=[]
var slot_labels:Array[Label]=[]
var idle:Label
var changing:=false
func game():return panel.host.game
func text(key:String,values:Dictionary={}) -> String:return UIText.t("reactor.automation."+key,values)
func button(parent:Node,key:String,action:Callable,values:Dictionary={}) -> Button:
 var b=Button.new();b.text=text(key,values);SKIN.button_skin(b);b.add_theme_font_size_override("font_size",18);b.pressed.connect(action);parent.add_child(b);return b
func setup(owner) -> void:
 owner_ref=weakref(owner)
 panel.readout_plate(panel,Vector2(48,1080),Vector2(546,88))
 bar=HBoxContainer.new();bar.position=Vector2(60,1084);bar.size=Vector2(522,40);bar.add_theme_constant_override("separation",4);panel.add_child(bar)
 upgrade=CheckBox.new();upgrade.text=text("upgrade");bar.add_child(upgrade)
 allocate=CheckBox.new();allocate.text=text("allocate");bar.add_child(allocate)
 for toggle in [upgrade,allocate]:
  toggle.add_theme_font_size_override("font_size",18);toggle.add_theme_font_override("font",panel.host.font);
  for state in ["font_color","font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color","font_disabled_color"]:toggle.add_theme_color_override(state,panel.INK)
  toggle.tooltip_text=text("requires_crew")
 upgrade.toggled.connect(func(enabled):A.set_enabled(game(),"upgrade",enabled);refresh())
 allocate.toggled.connect(func(enabled):A.set_enabled(game(),"allocate",enabled);refresh())
 var choices=HBoxContainer.new();choices.position=Vector2(60,1126);choices.size=Vector2(522,40);choices.add_theme_constant_override("separation",8);panel.add_child(choices)
 button(choices,"settings",show_settings)
 for index in 3:presets.append(button(choices,"slot",func():A.apply_slot(game(),index);panel.refresh(),{"slot":str(index+1)}))
 crew_hint=Label.new();crew_hint.text=text("no_dispatch");crew_hint.tooltip_text=text("requires_crew")
 crew_hint.size_flags_horizontal=Control.SIZE_EXPAND_FILL;crew_hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;crew_hint.vertical_alignment=VERTICAL_ALIGNMENT_CENTER
 crew_hint.mouse_filter=Control.MOUSE_FILTER_PASS;crew_hint.add_theme_font_size_override("font_size",18);crew_hint.add_theme_color_override("font_color",panel.INK);bar.add_child(crew_hint)
 panel.tree_exiting.connect(func():
  if is_instance_valid(dialog):dialog.queue_free())
 refresh()
func refresh() -> void:
 var state:Dictionary=game().profile.reactorAutomation
 var dispatched=game().profile.crew.any(func(item):return item.assignmentType=="reactor_upgrade" and game().crew.active(game(),item))
 panel.host.set_ui_value(crew_hint,"visible",not dispatched)
 if upgrade.button_pressed!=state.upgrade:upgrade.set_pressed_no_signal(state.upgrade)
 if allocate.button_pressed!=state.allocate:allocate.set_pressed_no_signal(state.allocate)
 for index in 3:
  var empty:bool=state.presets[index].is_empty()
  panel.host.set_ui_value(presets[index],"disabled",empty or not game().reactor_unlocked())
  panel.host.set_ui_value(presets[index],"text",text("empty_slot" if empty else "slot",{"slot":str(index+1)}))
 if dialog!=null and dialog.visible:refresh_slots()
func show_settings() -> void:
 if dialog==null:build_dialog()
 draft=A.capture(game());refresh_draft();refresh_slots();dialog.popup_centered(Vector2i(660,600))
func build_dialog() -> void:
 dialog=ConfirmationDialog.new();dialog.title=text("settings_title");dialog.ok_button_text=text("apply_ratio");dialog.cancel_button_text=UIText.t("system.cancel");dialog.size=Vector2i(660,600);panel.add_child(dialog);SKIN.dialog(dialog)
 var body=VBoxContainer.new();body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);body.offset_left=20;body.offset_right=-20;body.offset_top=16;body.offset_bottom=-70;body.add_theme_constant_override("separation",8);dialog.add_child(body)
 var tools=HBoxContainer.new();body.add_child(tools)
 button(tools,"current",func():draft=A.capture(game());refresh_draft())
 button(tools,"equal",func():draft=A.balanced(game());refresh_draft())
 for key in game().reactor_modules():
  var row=HBoxContainer.new();body.add_child(row)
  var label=Label.new();label.custom_minimum_size.x=190;label.add_theme_font_size_override("font_size",20);row.add_child(label);captions[key]=label
  var slider=HSlider.new();slider.min_value=0;slider.max_value=100;slider.step=0.01;slider.custom_minimum_size=Vector2(300,36);slider.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(slider);sliders[key]=slider
  slider.value_changed.connect(func(value):edit_ratio(key,value))
 idle=Label.new();idle.add_theme_font_size_override("font_size",18);body.add_child(idle)
 for index in 3:
  var row=HBoxContainer.new();body.add_child(row)
  var label=Label.new();label.custom_minimum_size.x=190;label.add_theme_font_size_override("font_size",20);row.add_child(label);slot_labels.append(label)
  button(row,"save_ratio",func():A.save_slot(game(),index,draft);refresh();refresh_slots())
  slot_apply.append(button(row,"apply_ratio",func():A.apply_slot(game(),index);panel.refresh();dialog.hide()))
 dialog.confirmed.connect(func():A.apply(game(),draft);panel.refresh())
func refresh_draft() -> void:
 changing=true
 var keys:Array=sliders.keys();var weights:Array=[];var assigned=0
 for key in keys:
  var weight=I.normalize(draft.weights.get(key,0));weights.append(weight);assigned=I.add(assigned,weight)
 weights.append(I.subtract(I.normalize(draft.total),assigned))
 var displayed=preload("res://scripts/reactor_allocation_growth.gd").distribute(100,weights,I.normalize(draft.total))
 for index in keys.size():
  var key=keys[index]
  sliders[key].set_value_no_signal(I.ratio(weights[index],I.normalize(draft.total))*100.0);sliders[key].editable=game().reactor_module_unlocked(key)
  captions[key].text=UIText.data_text("reactor",key)+" "+str(displayed[index])+"%"
 idle.text=text("idle",{"percent":str(displayed.back())})
 changing=false
func edit_ratio(key:String,value:float) -> void:
 if changing:return
 var total=I.normalize(draft.total);var assigned=0
 for other in draft.weights:
  if other!=key:assigned=I.add(assigned,I.normalize(draft.weights[other]))
 # Preserve every untouched exact weight; only the dragged share is quantized.
 draft.weights[key]=I.minimum(I.share(total,roundi(value*100.0),10000)[0],I.subtract(total,assigned))
 refresh_draft()
func refresh_slots() -> void:
 for index in 3:
  var empty:bool=game().profile.reactorAutomation.presets[index].is_empty()
  slot_labels[index].text=text("empty_slot" if empty else "slot",{"slot":str(index+1)})
  slot_apply[index].disabled=empty or not game().reactor_unlocked()
