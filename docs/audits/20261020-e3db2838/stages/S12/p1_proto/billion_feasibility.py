"""Quantitative span/size/work analysis, explicitly not an admission proof."""
from decimal import Decimal, ROUND_CEILING, ROUND_FLOOR, ROUND_HALF_UP, localcontext
import json
from pathlib import Path

from verify_compact_50000 import direct_bound

ROOT = Path(__file__).resolve().parent
T = 1_000_000_000
SAVE_LIMIT = 16 * 1024 * 1024


def main():
    growth = Decimal.from_float(1.0 + 0.2)
    with localcontext() as ctx:
        ctx.prec = 80
        log10_terminal = Decimal(50).log10() + (T - 1) * growth.log10()
    digits = int(log10_terminal) + 1
    span = (digits + 3) // 4
    wallet_raw = (ROOT / "generated_wallets/MAX-50000-GODOT-EXPLORATORY.json").read_bytes()
    wallet = json.loads(wallet_raw)["resources"]["1"]
    blocks = wallet["blocks"]
    positions = [int(row[0]) for row in blocks]
    observed_occupancy = len(blocks) / (max(positions) + 1)
    measured_query_us = 2_383_959
    per_level_us = measured_query_us / 50_000

    def rounded_representation(bound: Decimal) -> list[int]:
        power = bound.adjusted() - 1
        with localcontext() as ctx:
            ctx.prec = 80
            ctx.Emax = 999_999_999
            ctx.Emin = -999_999_999
            rounded = bound.quantize(Decimal(1).scaleb(power), rounding=ROUND_HALF_UP)
            return [int(rounded.scaleb(-power)), power]

    billion_lower = rounded_representation(direct_bound(T, 40, ROUND_FLOOR))
    billion_upper = rounded_representation(direct_bound(T, 40, ROUND_CEILING))
    report = {
        "kind": "billion_span_feasibility_not_admission_proof",
        "target": T,
        "growth_exact_binary64_as_decimal": str(growth),
        "terminal_unrounded_log10": str(log10_terminal),
        "terminal_unrounded_decimal_digits": digits,
        "independent_terminal_quote_bounds_repr": [billion_lower, billion_upper],
        "radix10000_position_span": span,
        "exploratory_50000_blocks": len(blocks),
        "exploratory_50000_position_range": [min(positions), max(positions)],
        "exploratory_50000_occupancy": observed_occupancy,
        "exploratory_minimal_fixture_bytes_not_game_save": len(wallet_raw),
        "minimum_fraction_exceeding_16mib_if_17_bytes_per_block": SAVE_LIMIT / (17 * span),
        "projected_bytes_if_17_bytes_each_and_50000_density_persists": int(17 * span * observed_occupancy),
        "measured_50000_query_us": measured_query_us,
        "per_level_us": per_level_us,
        "linear_billion_projection_seconds": per_level_us * T / 1_000_000,
        "required_levels_per_second_for_10s": T / 10,
        "material_interval": 20,
        "material_per_tier": 10,
        "material_due_through_target": 10 * (T // 20) * ((T // 20) + 1) // 2,
        "conclusion": "Projection only. Final wallet occupancy, canonical serialized bytes, whole-save admission, and possible sublinear exact sum remain unproved; do not reject by exponent or claim gate pass/fail from this estimate.",
    }
    print(json.dumps(report, sort_keys=True))


if __name__ == "__main__":
    main()
