extends VBoxContainer
const ERRORS := {"ShipLocked": "舰体尚未解锁"}
var _campaign
var _host: Callable
var ship_picker: OptionButton

var _gallery:=GridContainer.new()
var _cards:Dictionary={}
var _comparison:=Label.new()
var _pending_choices: bool = false

func _init(campaign, refit: Callable, command: Callable, hull_provider:Callable=Callable()) -> void:
	_campaign = campaign
	_host = command
	preload("res://src/ui/module_widgets.gd").heading(self,"舰体机库","挂载与无人机容量对照")
	if hull_provider.is_valid():
		var comparison:=ScrollContainer.new();comparison.custom_minimum_size.y=350;comparison.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;add_child(comparison)
		comparison.add_child(preload("res://src/ui/fleet_scale_view.gd").new(hull_provider))
	_gallery.columns=2;add_child(_gallery)
	_comparison.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;add_child(_comparison)
	ship_picker = OptionButton.new()
	add_child(ship_picker)
	ship_picker.item_selected.connect(func(_i):_refresh_inspection())
	_host.call(self, "切换舰船", func():
		var id: String = "" if ship_picker.selected < 0 else str(ship_picker.get_item_metadata(ship_picker.selected))
		var result: Dictionary = _campaign.change_ship(id, refit)
		var reason: String = str(result.get("reason", ""))
		if not result.get("ok", false) and ERRORS.has(reason): result.message = ERRORS[reason]
		return result)
	_campaign.ship_changed.connect(_queue_choices)
	_campaign.progress_changed.connect(_queue_choices)
	_queue_choices()

func _queue_choices() -> void:
	_pending_choices = true

func _refresh_choices() -> void:
	ship_picker.clear()
	for option in _campaign.ship_options():
		var index: int = ship_picker.item_count
		ship_picker.add_item(option.name)
		ship_picker.set_item_metadata(index, option.id)
		ship_picker.set_item_disabled(index, not option.enabled)
		if option.selected: ship_picker.select(index)
		if not _cards.has(option.id):
			var card=preload("res://src/ui/module_widgets.gd").plate(_gallery)
			card.get_parent().size_flags_horizontal=Control.SIZE_EXPAND_FILL
			var file:String={"Frigate":"01-frigate.png","Destroyer":"02-destroyer.png","Cruiser":"03-cruiser.png","Battleship":"04-battleship.png","Heavy_Battleship":"05-heavy-battleship.png"}[option.id]
			preload("res://src/ui/module_widgets.gd").image(card,"res://assets/ui/ships/fleet_20261019/"+file,Vector2(0,190))
			var label=preload("res://src/ui/module_widgets.gd").label(card,option.name,20)
			var choose:=Button.new();choose.text="查看舰体";card.add_child(choose)
			choose.pressed.connect(func():
				for i in ship_picker.item_count:
					if str(ship_picker.get_item_metadata(i))==str(option.id):ship_picker.select(i);_refresh_inspection())
			_cards[option.id]={"label":label,"button":choose}
		var facts:Dictionary=_campaign.ship_facts(option.id)
		_cards[option.id].label.text="%s%s\n武器 %d · 防具 %d · 无人机 %d"%[option.name," · 当前舰体" if option.selected else "" if option.enabled else " · 未解锁",facts.mounts.weapon,facts.mounts.defence,facts.drone_capacity]
	_refresh_inspection()

func _ready() -> void:
	resized.connect(func():_gallery.columns=2 if size.x>=700 else 1)
	process_priority = 1

func _process(_dt: float) -> void:
	_flush_pending()

func _flush_pending() -> void:
	if is_visible_in_tree() and _pending_choices:
		_pending_choices = false
		_refresh_choices()

func _refresh_inspection()->void:
	if ship_picker.selected<0:return
	var next:Dictionary=_campaign.ship_facts(str(ship_picker.get_item_metadata(ship_picker.selected)))
	var current:Dictionary=_campaign.ship_facts()
	_comparison.text="挂载对照：武器 %d → %d · 防具 %d → %d · 无人机 %d → %d\n确认切换后由当前配装系统重排槽位。"%[current.mounts.weapon,next.mounts.weapon,current.mounts.defence,next.mounts.defence,current.drone_capacity,next.drone_capacity]
