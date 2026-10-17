"""Pack unmodified Godot PNG frames into a short APNG review clip."""

from pathlib import Path
import struct
import zlib

EVIDENCE = Path(__file__).parent / "evidence"
SIGNATURE = b"\x89PNG\r\n\x1a\n"


def chunks(path):
    raw = path.read_bytes()
    assert raw.startswith(SIGNATURE)
    offset = len(SIGNATURE)
    while offset < len(raw):
        length = struct.unpack_from(">I", raw, offset)[0]
        kind = raw[offset + 4 : offset + 8]
        data = raw[offset + 8 : offset + 8 + length]
        yield kind, data
        offset += length + 12


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


frames = sorted(EVIDENCE.glob("motion-??.png"))
assert len(frames) == 12
parts = [list(chunks(path)) for path in frames]
header = next(data for kind, data in parts[0] if kind == b"IHDR")
size = header[:8]
assert all(next(data for kind, data in frame if kind == b"IHDR")[:8] == size for frame in parts)

output = bytearray(SIGNATURE)
output += chunk(b"IHDR", header)
output += chunk(b"acTL", struct.pack(">II", len(frames), 0))
sequence = 0
for index, frame in enumerate(parts):
    control = struct.pack(">IIIIIHHBB", sequence, *struct.unpack(">II", size), 0, 0, 1, 10, 0, 0)
    output += chunk(b"fcTL", control)
    sequence += 1
    for kind, data in frame:
        if kind != b"IDAT":
            continue
        if index == 0:
            output += chunk(b"IDAT", data)
        else:
            output += chunk(b"fdAT", struct.pack(">I", sequence) + data)
            sequence += 1
output += chunk(b"IEND", b"")
(EVIDENCE / "motion.png").write_bytes(output)
