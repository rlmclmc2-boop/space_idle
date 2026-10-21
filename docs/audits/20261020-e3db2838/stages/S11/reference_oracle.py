"""Independent decimal reference for the S11 audit-only Godot prototype."""
from decimal import Decimal, localcontext, ROUND_FLOOR
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]
DATA = json.loads((ROOT / "space-battleship/data/game_data.json").read_text(encoding="utf-8"))


def quote(row, level):
    base = Decimal(str(float(row["cost_1"])))
    if level == 1 or row.get("costMulti_1") is None:
        return int(base.to_integral_value(rounding="ROUND_CEILING"))
    factor = Decimal(str(1.0 + float(row["costMulti_1"])))
    value = base * factor ** (level - 1)
    if value <= 0:
        return int(value.to_integral_value(rounding="ROUND_CEILING"))
    if value < 100:
        return int((value / 10).to_integral_value(rounding=ROUND_FLOOR) * 10 + 5)
    step = Decimal(10) ** (value.adjusted() - 1)
    return int(((value / step + Decimal("0.5")).to_integral_value(rounding=ROUND_FLOOR)) * step)


def main():
    out = {}
    with localcontext() as context:
        context.prec = 5000
        for key in ("laser", "armour"):
            row = DATA["equipment"][key][0]
            for level in (3873, 3901):
                out[f"{key}:{level}"] = str(quote(row, level))
            out[f"{key}:batch:3900:10"] = str(sum(quote(row, n) for n in range(3901, 3911)))
        zero = {"cost_1": 0, "costMulti_1": 0.2}
        # Godot 4.7.2 constructs the test operand as 1.25e-300 * 1e-8;
        # String.num_scientific reports its binary64 value as this decimal.
        subnormal = {"cost_1": float("1.2499999999999996e-308"), "costMulti_1": 9.0}
        out["zero:4000"] = str(quote(zero, 4000))
        for level in (309, 310, 311):
            out[f"subnormal:{level}"] = str(quote(subnormal, level))
        out["subnormal:batch:308:3"] = str(sum(quote(subnormal, n) for n in range(309, 312)))
    target = ROOT / "space-battleship/test/audit_s11_quote_oracle.json"
    target.write_text(json.dumps(out, indent=2) + "\n", encoding="utf-8")
    print(f"oracle_cases={len(out)} max_digits={max(map(len, out.values()))}")


if __name__ == "__main__":
    main()
