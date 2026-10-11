"""QA-only two loop-boundary timers grouped by actual logical parent step."""
from pathlib import Path
import shutil

def prepare(project: Path, root: Path):
    shutil.copy2(root/'test/projectile_step_timer.gd',project/'projectile_step_timer.gd')
    for filename,kind in [('game.gd','base'),('presented_battle_game.gd','presented')]:
        path=project/'scripts'/filename
        source=path.read_text(encoding='utf-8')
        signature=next(line for line in source.splitlines() if line.startswith('func tick_projectiles('))
        original='_step_timing_'+kind+'_tick_projectiles'
        replacement=signature+"\n\tvar timer=Engine.get_meta(\"projectile_step_timer\")\n\tif not timer.enabled:\n\t\t"+original+"(dt);return\n\tvar began=Time.get_ticks_usec()\n\t"+original+"(dt)\n\tvar elapsed=Time.get_ticks_usec()-began\n\ttimer.record(\""+kind+"\",elapsed,dt)\n\n"+signature.replace('tick_projectiles',original,1)
        assert source.count(signature)==1
        path.write_text(source.replace(signature,replacement,1),encoding='utf-8')
    path=project/'probe.gd';source=path.read_text(encoding='utf-8')
    source=source.replace(' Engine.set_meta("saved_perf",meter)',' Engine.set_meta("saved_perf",meter)\n Engine.set_meta("projectile_step_timer",preload("res://projectile_step_timer.gd").new())',1)
    source=source.replace('  logical_ticks+=1','  logical_ticks+=1\n  Engine.get_meta("projectile_step_timer").begin_step()',1)
    marker='    sample_started=true;wall_start='
    assert marker in source
    source=source.replace(marker,'    Engine.get_meta("projectile_step_timer").begin_sample()\n'+marker,1)
    source=source.replace('  row.clock_validation={','  row.projectile_step_timing=Engine.get_meta("projectile_step_timer").report(self,tick_count)\n  row.clock_validation={',1)
    source=source.replace(' scene.queue_free();await process_frame;await process_frame',' scene.queue_free();await process_frame;await process_frame\n Engine.remove_meta("projectile_step_timer")',1)
    path.write_text(source,encoding='utf-8')
