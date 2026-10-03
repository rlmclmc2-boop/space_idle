# First galaxy opens after actual clear60

Parent independent frozen b2dc fresh run cleared60=93552.75 but remained locked past102000s because the first-galaxy source demanded six conquered planets twice. Current source changes only galaxy_1 unlock_type/value to stage_cleared/60; existing feature gate remains clear60. Production feature availability uses GalaxySystem.condition_met; that method retains conquered_planet_count and galaxy_complete for subsequent conditions.

Normal Excel export/projection/protected543 old-field checks pass. Actual production Game/ShipDatabase controlled9 checks PASS with no script errors: reached61 without clearing60, six conquests without60, clear60 with zero conquests opens feature/first-region and permits exploration; old later conquest and completion conditions retain their behavior. Exporter rejects0, fractional/unknown/text/nonfinite stage IDs. This is functional contract evidence, not legal fresh unlock clock or building completion timing.

Reproduce: python test/progression/build_qa.py --output test/work/replay-galaxy60
python test/progression/run_entry.py --project test/work/replay-galaxy60 --entry res://qa/galaxy_clear60_unlock.gd --label galaxy60
