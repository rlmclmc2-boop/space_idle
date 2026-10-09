extends RefCounted
## Last representable double below int64's upper edge; conversion stays safe.
const CAPACITY_LIMIT: int = 9223372036854774784

static func capacity(energy: float) -> int:
	if energy>=float(CAPACITY_LIMIT):return CAPACITY_LIMIT
	return maxi(0,int(floor(energy))) if is_finite(energy) else 0
