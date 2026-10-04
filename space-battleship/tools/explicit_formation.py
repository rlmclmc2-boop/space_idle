"""Optional monGroup coordinates: logical battle units, indexed by source slot.

This is an input check, not visual approval. The actual scene additionally
checks its configured hull/protection geometry, entry sweep and front line.
"""
import math


def validate(group, enemies):
    if 'formation_positions' not in group:
        return
    points = group['formation_positions']
    slots = group['slots']
    if not isinstance(points, list) or len(points) != len(slots):
        raise ValueError('formation_positions must match all source slots')
    occupied = []
    for slot, (enemy_id, point) in enumerate(zip(slots, points)):
        if enemy_id is None:
            if point is not None:
                raise ValueError(f'empty slot {slot} has coordinates')
            continue
        if not isinstance(point, list) or len(point) != 2 or any(
            type(v) not in (int, float) or not math.isfinite(v) for v in point
        ):
            raise ValueError(f'occupied slot {slot} needs two finite coordinates')
        x, y = point
        if not 54 <= x <= 518 or not 80 <= y <= 350:
            raise ValueError(f'occupied slot {slot} is outside input bounds')
        occupied.append((slot, int(enemies[str(enemy_id)]['size']), x, y))
    for i, (slot, size, x, y) in enumerate(occupied):
        for other, other_size, ox, oy in occupied[i + 1:]:
            if x == ox and y == oy:
                raise ValueError(f'coincident slots {slot}/{other}')
            if (size >= 4 and other_size < size and y > oy) or (other_size >= 4 and size < other_size and oy > y):
                raise ValueError(f'large hull {slot} is ahead of smaller hull {other}')
        if size >= 4 and abs(x - 286) > 150:
            raise ValueError(f'large hull {slot} must remain in the central sector')
