"""Generate deterministic independent Decimal.from_float wallet test vectors."""
from decimal import Decimal, getcontext
from pathlib import Path
import json
import random


def encode(value: Decimal):
    if not value:
        return []
    sign, digits, exponent = value.as_tuple()
    assert sign == 0
    coefficient = int("".join(map(str, digits)))
    position, remainder = divmod(exponent, 4)
    coefficient *= 10**remainder
    raw = {}
    while coefficient:
        coefficient, digit = divmod(coefficient, 10000)
        if digit:
            raw[position] = digit
        position += 1
    output = []
    positions = sorted(raw)
    index = 0
    while index < len(positions):
        position = positions[index]
        digit = raw[position]
        carry = (digit + 5000) // 10000
        digit -= 10000 * carry
        if digit:
            output.append({"p": str(position), "d": digit})
        if carry:
            following = position + 1
            if following not in raw:
                positions.insert(index + 1, following)
            raw[following] = raw.get(following, 0) + carry
        index += 1
    return output


def main():
    getcontext().prec = 1100
    rng = random.Random(129819)
    vectors = []
    for _ in range(250):
        a = rng.randint(0, 10**8) / (10 ** rng.randint(0, 7))
        b = rng.randint(0, 10**8) / (10 ** rng.randint(0, 7))
        decimal_sum = Decimal.from_float(a) + Decimal.from_float(b)
        # Decimal stores exact binary64 values at default unlimited conversion
        # precision; addition needs enough context for the largest fractional tail.
        vectors.append({"a": a, "b": b, "blocks": encode(decimal_sum)})
    target = Path(__file__).with_name("sparse_decimal_oracle.json")
    target.write_text(json.dumps(vectors, separators=(",", ":")), encoding="utf-8")
    print(f"wrote {len(vectors)} vectors to {target.name}")


if __name__ == "__main__":
    main()
