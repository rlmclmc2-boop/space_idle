"""Independent decimal-factor bounds for frozen low and edge Godot payloads."""
from decimal import Decimal, Context, ROUND_CEILING, ROUND_FLOOR, ROUND_HALF_UP, localcontext
import json
from pathlib import Path
import struct

ROOT = Path(__file__).resolve().parent


def from_bits(hex_bits: str) -> Decimal:
    return Decimal.from_float(struct.unpack(">d", bytes.fromhex(hex_bits))[0])


def direct_bound(base: Decimal, growth: Decimal, exponent: int, precision: int, rounding: str) -> Decimal:
    ctx = Context(prec=precision, rounding=rounding, Emin=-999_999_999, Emax=999_999_999)
    power = growth
    result = Decimal(1)
    while exponent:
        if exponent & 1:
            result = ctx.multiply(result, power)
        exponent //= 2
        if exponent:
            power = ctx.multiply(power, power)
    return ctx.multiply(base, result)


def quote_bound(value: Decimal) -> int:
    if value == 0:
        return 0
    if value < 100:
        with localcontext() as ctx:
            ctx.prec = max(160, len(value.as_tuple().digits) + 8)
            return int((value / 10).to_integral_value(rounding=ROUND_FLOOR)) * 10 + 5
    step = Decimal(1).scaleb(value.adjusted() - 1)
    with localcontext() as ctx:
        ctx.prec = max(160, len(value.as_tuple().digits) + 8)
        return int(value.quantize(step, rounding=ROUND_HALF_UP))


def main():
    lines = (ROOT / "exploratory_edge_payload_1.stdout.log").read_text(encoding="utf-8").splitlines()
    rows = [json.loads(line) for line in lines if line.startswith("{") and '"kind":"edge_payload"' in line]
    assert len(rows) == 12
    results = []
    for row in rows:
        base = from_bits(row["base_bits"])
        growth = from_bits(row["growth_bits"])
        matched = None
        for precision in (40, 80, 160, 320):
            lo = quote_bound(direct_bound(base, growth, row["level"] - 1, precision, ROUND_FLOOR))
            hi = quote_bound(direct_bound(base, growth, row["level"] - 1, precision, ROUND_CEILING))
            if lo == hi:
                matched = (lo, precision)
                break
        assert matched is not None, row["id"]
        results.append({"id": row["id"], "independent": str(matched[0]), "observed": row["observed"], "precision": matched[1], "match": str(matched[0]) == row["observed"]})
    print(json.dumps({"kind": "independent_edge_payload", "cases": len(results), "mismatches": sum(not x["match"] for x in results), "results": results}, sort_keys=True))
    assert all(x["match"] for x in results)


if __name__ == "__main__":
    main()
