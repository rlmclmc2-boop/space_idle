"""Private-copy scope isolation and in-memory native dynamic replay. No production edits."""
from pathlib import Path
import re
import shutil

NATIVE = {'draw_arc','draw_circle','draw_colored_polygon','draw_line','draw_mesh',
          'draw_polyline','draw_primitive','draw_rect','draw_set_transform','draw_string',
          'draw_style_box','draw_texture_rect','draw_texture_rect_region'}


def native_calls(source):
    # Balanced argument scan: source strings/comments are preserved verbatim.
    pattern = re.compile(r'(?<![\w.])(?:(\w+)\.)?(draw_\w+)\(')
    replacements = []
    for match in pattern.finditer(source):
        if match[2] not in NATIVE:
            continue
        pos = match.end(); start = pos; depth = 1; quote = ''; escape = False
        while depth:
            char = source[pos]
            if quote:
                if escape: escape = False
                elif char == '\\': escape = True
                elif char == quote: quote = ''
            elif char in '\"\'': quote = char
            elif char == '(': depth += 1
            elif char == ')': depth -= 1
            pos += 1
        args = source[start:pos-1]
        replacements.append((match.start(), pos,
            f'Engine.get_meta("render_tape").command({match[1] or "self"},"{match[2]}",[{args}])'))
    for start, stop, replacement in reversed(replacements):
        source = source[:start] + replacement + source[stop:]
    return source


def prepare(project: Path, root: Path, replay: bool):
    game = project / 'scripts/game.gd'
    source = game.read_text(encoding='utf-8')
    begin = source.index('\tmanual_hyperspace.dispatch_queued(self)', source.index('func tick('))
    end = source.index('\tfor drop in drops.duplicate():', begin)
    source = source[:begin] + ('\t# Diagnostic-only: static profile/modifiers retained; noncombat updates omitted.\n'
        '\tprofile.productionElapsed=production_time()+dt\n'
        '\tenhancement_branches.advance_weapons(self,dt)\n') + source[end:]
    game.write_text(source, encoding='utf-8')
    probe = project / 'probe.gd'
    source = probe.read_text(encoding='utf-8')
    source = source.replace(' scene.refresh_structure();scene.refresh_tab_visibility()',
        ' scene.refresh_structure();scene.refresh_tab_visibility()\n'
        ' var scope=preload("res://battle_scope.gd").manifest(g,scene)\n'
        ' print("BATTLE_SCOPE ",JSON.stringify(scope))')
    source = source.replace('  row.missile_parameters={', '  row.battle_scope=scope\n  row.missile_parameters={')
    source = source.replace('  scene.select_system(page)',
        '  scene.select_system(page)\n  scope.hidden_callbacks_disabled=preload("res://battle_scope.gd").isolate_hidden_pages(scene)')
    source = source.replace('  row.battle_scope=scope',
        '  scope.active_native_process_callbacks=preload("res://battle_scope.gd").processing_inventory(scene)\n'
        '  scope.settled_ship_scale=scene.ship_view.viewport.scaling_3d_scale\n  row.battle_scope=scope')
    # A and R0 both end each frame at actual native render completion.
    source = source.replace('   await process_frame\n   if i>=warmup:',
        '   await process_frame\n   await RenderingServer.frame_post_draw\n   if i>=warmup:')
    shutil.copy2(root/'test/battle_scope.gd',project/'battle_scope.gd')
    if replay:
        shutil.copy2(root/'test/native_render_tape.gd',project/'native_render_tape.gd')
        source = source.replace(' Engine.set_meta("saved_perf",meter)',
            ' Engine.set_meta("saved_perf",meter)\n Engine.set_meta("render_tape",preload("res://native_render_tape.gd").new())')
        source = source.replace('  for i in range(count+warmup):',
            '  var tape=Engine.get_meta("render_tape")\n  tape.scene=scene\n  tape.output="res://.runtime/"\n'
            '  for i in range(count+warmup):\n   tape.start_frame(i>=warmup)')
        source = source.replace('   await process_frame\n   await RenderingServer.frame_post_draw\n   if i>=warmup:',
            '   await process_frame\n   await RenderingServer.frame_post_draw\n'
            '   tape.capture(i, {"alive":g.enemies.size(),"projectiles":g.projectiles.size(),"queue":g.missile_queue.size(),"effects":[scene.missile_events.size(),scene.pulse_events.size(),scene.particles.size(),scene.projectile_visuals.size()]})\n'
            '   if i>=warmup:')
        source = source.replace(' FileAccess.open("res://.runtime/whole-perf.json"',
            ' await Engine.get_meta("render_tape").run_replay(self)\n FileAccess.open("res://.runtime/whole-perf.json"')
        source=source.replace(' scene.queue_free();await process_frame;await process_frame',
            ' Engine.get_meta("render_tape").release()\n scene.queue_free();await process_frame;await process_frame\n Engine.remove_meta("render_tape")')
        for path in list((project/'scripts').rglob('*.gd')) + list((project/'dev').rglob('*.gd')):
            code = path.read_text(encoding='utf-8')
            code = native_calls(code)
            code = re.sub(r'(?m)^([ \t]*)func _draw\([^\n]*\n(?=([ \t]+)\S)',
                lambda m: m[0] + m[2] + 'if Engine.get_meta("render_tape").replaying:Engine.get_meta("render_tape").paint(self);return\n' + m[2] + 'Engine.get_meta("render_tape").begin(self,true)\n', code)
            if path.name == 'main.gd':
                code = code.replace('layer.draw.connect(func():draw_surface=layer;painter.call())',
                    'layer.draw.connect(func():\n\t\t\tif Engine.get_meta("render_tape").replaying:Engine.get_meta("render_tape").paint(layer)\n\t\t\telse:\n\t\t\t\tEngine.get_meta("render_tape").begin(layer);draw_surface=layer;painter.call())')
            path.write_text(code,encoding='utf-8')
    # Match animated flame phase in both A and R0; formula/quality unchanged.
    shader=project/'dev/toon_ship/exhaust.gdshader'
    code=shader.read_text(encoding='utf-8').replace('uniform float phase = 0.0;', 'uniform float phase = 0.0;\nuniform float diagnostic_clock = 0.0;').replace('sin(TIME *','sin(diagnostic_clock *')
    shader.write_text(code,encoding='utf-8')
    view=project/'scripts/presented_ship_view.gd'
    code=view.read_text(encoding='utf-8')
    # Explicit phase uses the existing presentation clock, including pause behavior.
    signature='func set_pose('
    at=code.index(signature); end=code.index('\n',at)
    code=code[:end+1]+'\tfor mat in exhaust_materials:mat.set_shader_parameter("diagnostic_clock",time)\n'+code[end+1:]
    view.write_text(code,encoding='utf-8')
    probe.write_text(source,encoding='utf-8')
