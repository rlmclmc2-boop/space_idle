extends RefCounted
## Balance Lab reports finite floats. Preserve ordinary values and reject a
## transaction value when this reporting domain cannot represent it.
const N=preload("res://scripts/growth_number.gd")

static func finite(value:Variant)->Variant:
	if not N.valid(value):return null
	if not value is Dictionary:return float(value)
	var parts:Array=N.parts(value)
	if parts[1]<-300.0 or parts[1]>300.0:return null
	var projected:float=float(parts[0])*pow(10.0,float(parts[1]))
	return projected if is_finite(projected) and projected>0.0 else null

static func ratio(numerator:Variant,denominator:Variant)->Variant:
	if not N.valid(numerator) or not N.valid(denominator):return null
	var floor_denominator=N.maximum(denominator,1)
	if not numerator is Dictionary and not floor_denominator is Dictionary:
		return float(numerator)/float(floor_denominator)
	if N.compare(numerator,0)==0:return 0.0
	var a:Array=N.parts(numerator)
	var b:Array=N.parts(floor_denominator)
	var exponent:float=float(a[1])-float(b[1])
	if exponent<-300.0 or exponent>300.0:return null
	var projected:float=float(a[0])/float(b[0])*pow(10.0,exponent)
	return projected if is_finite(projected) and projected>0.0 else null
