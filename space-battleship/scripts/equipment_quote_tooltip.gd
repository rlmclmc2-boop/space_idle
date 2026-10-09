extends Button
## Only an existing affordability refresh updates an already-open quote.
var quote_text:Callable
var open_label:WeakRef
func _make_custom_tooltip(_for_text:String)->Object:
 var content:Control=EnhancementTooltip.content(str(quote_text.call()))
 open_label=weakref(content.get_child(0))
 return content
func refresh_open_quote()->void:
 var label=open_label.get_ref() if open_label!=null else null
 if not is_instance_valid(label):return
 var value:String=str(quote_text.call())
 if label.text!=value:label.text=value
