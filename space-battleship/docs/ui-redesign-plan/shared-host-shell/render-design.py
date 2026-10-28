"""Export static design HTML and typography evidence; never opens a game/session/save."""
from pathlib import Path
import argparse
import hashlib
import json
from playwright.sync_api import sync_playwright

parser = argparse.ArgumentParser()
parser.add_argument('--base-url', default='http://127.0.0.1:8765')
parser.add_argument('--chromium', default='/usr/bin/chromium')
args = parser.parse_args()
root = Path(__file__).resolve().parent
route = args.base_url.rstrip('/') + '/docs/ui-redesign-plan/shared-host-shell/'
with sync_playwright() as playwright:
    browser = playwright.chromium.launch(executable_path=args.chromium, headless=True, args=['--no-sandbox'])
    page = browser.new_page(viewport={'width': 1440, 'height': 1400}, device_scale_factor=1)
    page.goto(route + 'typography.html')
    page.evaluate('window.ready')
    result = page.evaluate('window.measurement')
    result['font_sha256'] = hashlib.sha256((root / '../../../assets/fonts/NotoSansSC.ttf').resolve().read_bytes()).hexdigest()
    result['browser'] = browser.version
    result['font_loaded'] = page.evaluate("document.fonts.check('450 16px ShipSC')")
    page.locator('[data-case=normal] .bar').screenshot(path=str(root / 'evidence/header-normal-1x.png'))
    page.screenshot(path=str(root / 'evidence/header-type-1x.png'), full_page=True)
    (root / 'evidence/header-type-metrics.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    page.set_viewport_size({'width': 1440, 'height': 900})
    records = []
    for state in ['normal', 'more', 'collapsed']:
        page.goto(route + 'host-preview.html?state=' + state)
        page.evaluate('window.ready')
        page.screenshot(path=str(root / 'evidence' / ('h2-' + state + '-1440x900.png')))
        records.append(page.evaluate('window.designOnly'))
    (root / 'evidence/host-assembly-record.json').write_text(json.dumps(records, ensure_ascii=False, indent=2) + '\n')
    browser.close()
print('Static design export complete. This is neither Godot execution nor game verification.')
