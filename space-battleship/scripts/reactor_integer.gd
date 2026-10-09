extends RefCounted
## Reactor-only unsigned integers: int fast path, canonical decimal strings beyond it.
## Persisted strings are bounded; compact conversion never renders all their digits.
const BASE:=10000
const INT_LIMIT:int=9223372036854774784
const JSON_EXACT:int=9007199254740991
# Work bound, not an int64 cap: ~12.9K levels at the current growth rate.
# Bounds cold quadratic share arithmetic and hostile imported strings.
const MAX_DIGITS:=1024
static var long_operations:=0
static var growth_cache:Dictionary={}
static func valid(v) -> bool:
 if v is int:return v>=0
 if v is float:return is_finite(v) and v>=0 and v<=float(INT_LIMIT) and v==floorf(v)
 if not v is String or v.is_empty() or v.length()>MAX_DIGITS:return false
 if v.length()>1 and v[0]=="0":return false
 for c in v:
  if c<"0" or c>"9":return false
 return true
static func normalize(v):
 if v is int:return maxi(0,v)
 if v is float:return int(floorf(v)) if is_finite(v) and v>=0 and v<=float(INT_LIMIT) else 0
 return small(str(v)) if valid(v) else 0
static func small(s:String):
 while s.length()>1 and s[0]=="0":s=s.substr(1)
 if s.is_empty():return 0
 var limit:=str(INT_LIMIT)
 return int(s) if s.length()<limit.length() or (s.length()==limit.length() and s<=limit) else s
static func encode(v):return str(v) if v is String or (v is int and v>JSON_EXACT) else v
static func digits(v) -> String:return str(v)
static func compare(a,b) -> int:
 if a is int and b is int:return 0 if a==b else 1 if a>b else -1
 var x:=digits(a);var y:=digits(b)
 if x.length()!=y.length():return 1 if x.length()>y.length() else -1
 return 0 if x==y else 1 if x>y else -1
static func minimum(a,b):return a if compare(a,b)<=0 else b
static func limbs(v) -> Array[int]:
 var s:=digits(v);var result:Array[int]=[];var end:=s.length()
 while end>0:
  var start:=maxi(0,end-4);result.append(int(s.substr(start,end-start)));end=start
 return result
static func trim(a:Array[int]) -> Array[int]:
 while a.size()>1 and a.back()==0:a.pop_back()
 return a
static func value(a:Array[int]):
 trim(a)
 if a.is_empty():return 0
 var s:=str(a.back())
 for i in range(a.size()-2,-1,-1):s+=str(a[i]).pad_zeros(4)
 return small(s)
static func add(a,b):
 if a is int and b is int and b<=INT_LIMIT-a:return a+b
 long_operations+=1
 var x:=limbs(a);var y:=limbs(b);var out:Array[int]=[];var carry:=0
 for i in maxi(x.size(),y.size()):
  var n: int=(x[i] if i<x.size() else 0)+(y[i] if i<y.size() else 0)+carry
  out.append(n%BASE);carry=n/BASE
 if carry:out.append(carry)
 return value(out)
static func sub_arrays(x:Array[int],y:Array[int]) -> Array[int]:
 var out:Array[int]=[];var borrow:=0
 for i in x.size():
  var n:int=x[i]-(y[i] if i<y.size() else 0)-borrow;borrow=1 if n<0 else 0
  out.append(n+BASE if n<0 else n)
 return trim(out)
static func subtract(a,b):
 if compare(a,b)<=0:return 0
 if a is int and b is int:return a-b
 long_operations+=1
 return value(sub_arrays(limbs(a),limbs(b)))
static func multiply(a,b):
 if compare(a,0)==0 or compare(b,0)==0:return 0
 if a is int and b is int and b<=INT_LIMIT/a:return a*b
 long_operations+=1
 var x:=limbs(a);var y:=limbs(b);var out:Array[int]=[];out.resize(x.size()+y.size());out.fill(0)
 for i in x.size():
  var carry:=0
  for j in y.size():
   var n:int=out[i+j]+x[i]*y[j]+carry;out[i+j]=n%BASE;carry=n/BASE
  out[i+y.size()]=carry
 return value(out)
static func cmp_arrays(a:Array[int],b:Array[int]) -> int:
 if a.size()!=b.size():return 1 if a.size()>b.size() else -1
 for i in range(a.size()-1,-1,-1):
  if a[i]!=b[i]:return 1 if a[i]>b[i] else -1
 return 0
static func mul_small(a:Array[int],n:int) -> Array[int]:
 var out:Array[int]=[];var carry:=0
 for limb in a:
  var next:int=limb*n+carry;out.append(next%BASE);carry=next/BASE
 if carry:out.append(carry)
 return trim(out)
static func divmod(a,b) -> Array:
 assert(compare(b,0)>0,"Reactor integer division requires a positive divisor")
 if compare(a,b)<0:return [0,a]
 if a is int and b is int:return [a/b,a%b]
 long_operations+=1
 var x:=limbs(a);var y:=limbs(b);var out:Array[int]=[];out.resize(x.size());out.fill(0)
 var remainder:Array[int]=[0]
 if b is int and b<=1000000000:
  var carry:=0
  for i in range(x.size()-1,-1,-1):
   var n:int=carry*BASE+x[i];out[i]=n/b;carry=n%b
  return [value(out),carry]
 # Normalize the leading divisor limb so the quotient estimate overshoots
 # by at most two; avoid fourteen full divisor scans per quotient limb.
 var factor:int=BASE/(y.back()+1)
 y=mul_small(y,factor);x=mul_small(x,factor);out.resize(x.size());out.fill(0)
 for i in range(x.size()-1,-1,-1):
  remainder.push_front(x[i]);trim(remainder)
  if cmp_arrays(remainder,y)<0:continue
  var estimate:int=mini(BASE-1,(remainder.back()*BASE+remainder[remainder.size()-2])/y.back()) if remainder.size()>y.size() else mini(BASE-1,remainder.back()/y.back())
  var product:=mul_small(y,estimate)
  while cmp_arrays(product,remainder)>0:
   estimate-=1;product=sub_arrays(product,y)
  out[i]=estimate
  remainder=sub_arrays(remainder,product)
 var residual=value(remainder)
 return [value(out),divmod(residual,factor)[0] if factor>1 else residual]
static func share(amount,weight,total) -> Array:
 if compare(weight,0)==0 or compare(amount,0)==0:return [0,0]
 if compare(weight,total)==0:return [amount,0]
 return divmod(multiply(amount,weight),total)
static func from_growth(v):
 if not GrowthNumber.valid(v):return null
 if not v is Dictionary and float(v)<=float(INT_LIMIT):return int(floorf(float(v)))
 var p:Array=GrowthNumber.parts(v);var exponent:int=int(p[1])
 if exponent<0:return 0
 if exponent>=MAX_DIGITS:return null
 var s:String="%.15f"%float(p[0]);var fractional:int=s.length()-s.find(".")-1
 s=s.replace(".","")
 var shift:=exponent-fractional
 if shift>=0:s+="0".repeat(shift)
 else:s=s.substr(0,maxi(0,s.length()+shift))
 return small(s)
static func as_growth(v):
 if v is int:return float(v)
 if growth_cache.has(v):return growth_cache[v]
 var s:=digits(v);var length:int=mini(16,s.length());var m:=float(s.substr(0,length))/pow(10,length-1)
 var result=GrowthNumber.make(m,s.length()-1)
 if growth_cache.size()>=128:growth_cache.clear()
 growth_cache[v]=result
 return result
static func ratio(a,b) -> float:return GrowthNumber.ratio(as_growth(a),as_growth(b)) if compare(b,0)>0 else 0.0
