"""Resolve static GDScript/scene dependencies; dynamic resources stay explicit.

This is a conservative lexical closure, not a GDScript compiler. Godot import
remains the authority for syntax/types. Comments and strings cannot introduce
class-name dependencies, but literal res:// references are followed separately.
"""
import re
from pathlib import Path, PurePosixPath

TOKENS = re.compile(r'\#[^\n]*|"""[\s\S]*?"""|\'\'\'[\s\S]*?\'\'\'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'')
CLASS = re.compile(r'^\s*class_name\s+(\w+)', re.M)


def scan(text):
    resources = set()

    def hide(match):
        token = match.group()
        if not token.startswith('#'):
            value = token.strip('"\'')
            if value.startswith('res://'):
                resources.add(value[6:])
        return ''.join('\n' if c == '\n' else ' ' for c in token)

    code = TOKENS.sub(hide, text)
    return code, resources


def local_file(root, relative):
    path = PurePosixPath(relative)
    if path.is_absolute() or '..' in path.parts or '\\' in relative or ':' in relative:
        raise ValueError(f'Invalid project dependency: {relative}')
    result = root / relative
    if not result.is_file():
        raise FileNotFoundError(result)
    if not result.resolve().is_relative_to(root.resolve()):
        raise ValueError(f'Dependency escapes project: {relative}')
    return result


def closure(root: Path, entries, aliases=None):
    """Return scripts and literal resources reached from project-relative roots.

    aliases maps packaged scene paths (e.g. entry.gd) to source template paths.
    Dynamic paths are returned as prefixes and checked by the packaging caller.
    """
    aliases = aliases or {}
    classes = {}
    for source in sorted((root / 'scripts').rglob('*.gd')):
        code, _ = scan(source.read_text(encoding='utf-8'))
        match = CLASS.search(code)
        if match:
            name = match[1]
            if name in classes:
                raise ValueError(f'Duplicate class_name: {name}')
            classes[name] = source.relative_to(root).as_posix()
    pending = list(entries)
    visited, resources = set(), set()
    while pending:
        name = pending.pop()
        name = aliases.get(name, name)
        if name in visited:
            continue
        source = local_file(root, name)
        visited.add(name)
        code, refs = scan(source.read_text(encoding='utf-8'))
        if source.suffix == '.gd':
            pending.extend(classes[token] for token in set(re.findall(r'\b\w+\b', code)) if token in classes)
        for ref in refs:
            if Path(ref).suffix in {'.gd', '.tscn', '.tres'}:
                pending.append(ref)
            else:
                resources.add(ref)
    return visited, resources
