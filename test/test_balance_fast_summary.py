import json
from pathlib import Path
import tempfile
import unittest
from summarize_balance_fast import summarize


def row(seed, mode, value, death=None):
    return dict(seed=seed, simulation_mode=mode, config=dict(duration=600, data_sha256='same'),
                final_stage=2, dps=value, normal_ttk=2, boss_ttk=4, upgrades=0,
                damage={'laser': value*600}, weapon_damage_share={'laser': 1},
                defence=dict(first_death=None if death is None else {'time': death}, deaths=0),
                resources={key: {'1': value} for key in ('income', 'spending', 'balance')},
                system_uses={'charge': 0}, wall_seconds=2 if mode == 'exact' else 1,
                core_hash=mode, projectile_processing={})


class SummaryTests(unittest.TestCase):
    def compare(self, rows):
        with tempfile.TemporaryDirectory(dir=Path.cwd()/'.runtime') as directory:
            for index, run in enumerate(rows):
                Path(directory, f'accuracy_{index}.json').write_text(json.dumps(run), encoding='utf-8')
            return summarize(Path(directory))

    def test_absolute_errors_do_not_cancel(self):
        report = self.compare([row(1, 'exact', 100), row(1, 'fast', 90),
                               row(2, 'exact', 100), row(2, 'fast', 110)])
        group = report['results']['600']
        dps = next(r for r in group['rows'] if r['metric'] == 'dps')
        self.assertEqual(dps['avg_error'], 10)
        self.assertEqual(dps['max_error'], 10)
        self.assertFalse(dps['within_reference'])
        self.assertEqual(group['performance']['speedup'], 2)

    def test_censored_and_zero_reference_are_not_zero_error(self):
        report = self.compare([row(1, 'exact', 0), row(1, 'fast', 10, death=50)])
        rows = report['results']['600']['rows']
        for metric in ('dps', 'first_death_seconds'):
            value = next(r for r in rows if r['metric'] == metric)
            self.assertIsNone(value['max_error'])
            self.assertEqual(value['undefined_or_presence_mismatch_seeds'], [1])

    def test_incomplete_pair_is_not_estimated(self):
        report = self.compare([row(1, 'exact', 100)])
        self.assertEqual(report['results'], {})
        self.assertEqual(report['incomplete_pairs'], [[600, 1]])


if __name__ == '__main__':
    unittest.main()
