extends "res://qa/hyperspace_player_policy.gd"
## Explicit QA experiment: preserve earned history/automation, suppress new manual dispatch only.
func manual_retry_allowed(_g,_route:String,_level:int,_now:float)->bool:
 return false
func pending_manual_action(_g,_now:float)->Dictionary:
 return {}
